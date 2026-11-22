extends Node3D
## Penjaga Gerbang: full gate-boss encounter module (arena, sockets, golem, attacks, retry snapshot, gate, completion).
##
## Wiring (parent): instance scenes/boss/gatekeeper_encounter.tscn at (0,0,-100), add_child, then setup(player, session).
## Local space: arena z -15..+15 (access from the SOUTH, +Z), dock exit NORTH (-Z, trigger at z -21). See gatekeeper_arena.gd.
##
## Flow
##  1. Three artifacts (&forest_artifact, &energy_artifact, &summit_artifact; session.collected_ids) are installed at three visible
##     sockets with E. Installed state lives in session.puzzle_progress[&"gatekeeper_sockets"].
##  2. With all three installed the altar can be activated (E): first time = authored wake animation (3.6 s, boss invulnerable),
##     the arena is sealed by an energy barrier, the SNAPSHOT is taken (HP, stamina, potions - once, no healing) and the fight starts.
##  3. Fight: three telegraphed attacks (sweep / slam / charge). The damage area is a world-clipped polygon drawn as the telegraph;
##     direction/position lock at `lock` fraction of the wind-up and never follow the player afterwards. Damage only through
##     player.receive_damage(), so block and dodge i-frames apply. At <= 50% HP (phase 2) the core flares, a roar plays, and the
##     boss sometimes chains two attacks (second telegraph starts after a shortened recovery).
##  4. Player death: the boss freezes; when Session.respawned fires (player already at the checkpoint, full HP) this module
##     resets the boss (full HP, phase 1, no transients, home pose), moves the player to the safe retry point at the arena entrance (local z 13.5, inside the
##     arena, barrier open) and OVERRIDES HP/stamina/potions with the first-attempt snapshot. Artifacts, sockets, puzzles and shortcuts are
##     untouched. The altar offers "retry" (no wake animation). The same snapshot is used for every retry.
##  5. Victory: remaining resources persist (snapshot is dropped), boss collapses and sinks, the south barrier opens at once,
##     the gate seal dissolves and the slabs open; `completed` is emitted once when the player crosses into the dock.
##
## Voluntary exit policy (decided here, docs had none): the arena is sealed from activation until death/retry or victory.
## There is no abort, no leaving through the barrier and no forfeit command; Esc pauses the tree and nothing else. The
## encounter is session state only (no disk save): quitting the game discards it. Falling is impossible (floor + walls).

signal encounter_started
signal encounter_won
signal completed
signal status_changed

const Telegraph := preload("res://scripts/boss/boss_telegraph.gd")
const Arena := preload("res://scripts/boss/gatekeeper_arena.gd")
const GolemAnimations := preload("res://scripts/boss/golem_animations.gd")
const GOLEM_SCENE := "res://assets/third_party/blendswap/rock_golem/rock_golem.glb"

const KEY_SOCKETS := &"gatekeeper_sockets"
const KEY_STARTED := &"gatekeeper_started"
const KEY_SNAPSHOT := &"gatekeeper_snapshot"
const KEY_DEFEATED := &"gatekeeper_defeated"
const KEY_GATE_OPEN := &"gatekeeper_gate_open"
const REQUIRED_ARTIFACTS: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]

enum Mode { DORMANT, WAKING, FIGHTING, PLAYER_DOWN, REARMED, WON }
enum Act { PAUSE, WINDUP, ACTIVE, RECOVERY }
enum ZoneKind { SECTOR, CIRCLE, LANE }

const BOSS_HOME := Vector3(0.0, 0.0, -5.0)
const BOSS_MAX_Z := 4.5
const PHASE_TWO_RATIO := 0.5
const WAKE_LENGTH := 3.6
const WALK_SPEED := 2.6
const TURN_RATE := 2.4
const FIRST_ATTACK_DELAY := 1.4
const RETRY_ATTACK_DELAY := 1.8
const PAUSE_PHASE_ONE := 0.85
const PAUSE_PHASE_TWO := 0.6
const CHAIN_CHANCE := 0.45
const CHAIN_RECOVERY := 0.4
const MODEL_FEET_OFFSET := 9.06
## Per attack: damage (before block), wind-up / active / recovery seconds, `lock` = fraction of the wind-up at which the
## target locks, `hit_at` = fraction of the active phase at which the instant hit is resolved, zone geometry.
const ATTACKS := {
	&"sweep": {
		"damage": 24, "windup": 1.05, "lock": 0.62, "active": 0.22, "recovery": 1.1, "hit_at": 0.4,
		"kind": ZoneKind.SECTOR, "radius": 5.2, "half_arc": 72.0,
		"windup_clip": GolemAnimations.SWEEP_WINDUP, "strike_clip": GolemAnimations.SWEEP_STRIKE, "recover_clip": GolemAnimations.SWEEP_RECOVER,
		"chain": &"slam",
	},
	&"slam": {
		"damage": 38, "windup": 1.55, "lock": 0.66, "active": 0.25, "recovery": 2.4, "hit_at": 0.5,
		"kind": ZoneKind.CIRCLE, "radius": 4.2, "reach": 3.8,
		"windup_clip": GolemAnimations.SLAM_WINDUP, "strike_clip": GolemAnimations.SLAM_STRIKE, "recover_clip": GolemAnimations.SLAM_RECOVER,
		"chain": &"sweep",
	},
	&"charge": {
		"damage": 30, "windup": 1.15, "lock": 0.7, "active": 0.6, "recovery": 1.45, "hit_at": 0.0,
		"kind": ZoneKind.LANE, "width": 3.2, "length": 13.0, "speed": 20.0, "front": 2.0,
		"windup_clip": GolemAnimations.CHARGE_WINDUP, "strike_clip": GolemAnimations.CHARGE_RUN, "recover_clip": GolemAnimations.CHARGE_RECOVER,
		"chain": &"sweep",
	},
}
const COLOR_TRACK := Color(1.0, 0.72, 0.1)
const COLOR_LOCKED := Color(1.0, 0.36, 0.06)
const COLOR_ACTIVE := Color(1.0, 0.1, 0.05)
const CORE_CYAN := Color(0.3, 0.85, 1.0)
const CORE_RED := Color(1.0, 0.32, 0.08)

@export var max_health := 420

var mode := Mode.DORMANT
var act := Act.PAUSE
## 1 above 50% HP, 2 at or below.
var phase := 1
## Number of times the arena was sealed for a fight (first = 1).
var attempt := 0

var _player: Node3D
var _session: Node
var _health: Node
var _arena: Node3D
var _telegraph: Node3D
var _boss: CharacterBody3D
var _pivot: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _anim: AnimationPlayer
var _hurtbox: Area3D
var _core_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _overlay_mat: StandardMaterial3D
var _core_light: OmniLight3D
var _bar_root: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_label: Label3D
var _fx_dust: CPUParticles3D
var _fx_debris: CPUParticles3D
var _fx_hit: CPUParticles3D
var _fx_trail: CPUParticles3D
var _flash_tween: Tween

var _installed: Dictionary = {}
var _snapshot: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()

var _attack: StringName = &""
var _act_time := 0.0
var _act_length := 0.0
var _locked := false
var _hit_resolved := false
var _zone: Dictionary = {}
var _charge_traveled := 0.0
var _chain_next: StringName = &""
var _pause_left := 0.0
var _roar_pending := false
var _roar_left := 0.0
var _last_attack: StringName = &""
var _prev_attack: StringName = &""
var _current_clip: StringName = &""
var _last_hp := 0
var _wake_time := 0.0
var _gate_finished := false
var _completed_emitted := false
var _time := 0.0
var _core_color := Color(0.6, 0.12, 0.1)
var _core_energy := 0.5
var _target_color := Color(0.6, 0.12, 0.1)
var _target_energy := 0.5
var _core_boost := 0.0
var _pulse_speed := 2.0
var _model_rest_y := 0.0


func _ready() -> void:
	_rng.randomize()
	_health = get_node("Health")
	_health.max_health = max_health
	_health.current_health = max_health
	_last_hp = max_health
	_health.health_changed.connect(_on_health_changed)
	_health.dead.connect(_on_boss_dead)
	_arena = Arena.new()
	_arena.name = &"Arena"
	add_child(_arena)
	_arena.build(self)
	_arena.dock_entered.connect(_on_dock_entered)
	_arena.gate_opened.connect(_on_gate_opened)
	_telegraph = Telegraph.new()
	_telegraph.name = &"Telegraph"
	add_child(_telegraph)
	_build_boss()
	_build_fx()
	_arena.set_barrier(false)
	_arena.set_altar_visible(true)
	_set_hurtbox(false)
	_apply_mode_glow()
	_refresh_consoles()
	_build_checkpoint()
	set_physics_process(true)


## Binds the encounter to the player and the session. Call after add_child. Restores persisted gate state.
func setup(player: Node3D, session: Node) -> void:
	_player = player
	_session = session
	if player != null and player.has_signal(&"died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if session != null:
		if session.has_signal(&"respawned") and not session.respawned.is_connected(_on_session_respawned):
			session.respawned.connect(_on_session_respawned)
		if session.has_signal(&"status_changed") and not session.status_changed.is_connected(_refresh_consoles):
			session.status_changed.connect(_refresh_consoles)
		var progress: Dictionary = session.puzzle_progress
		if not progress.has(KEY_SOCKETS):
			progress[KEY_SOCKETS] = {}
		_installed = progress[KEY_SOCKETS]
		if progress.has(KEY_SNAPSHOT):
			_snapshot = progress[KEY_SNAPSHOT]
	for id: StringName in _installed:
		_arena.set_socket_installed(id, true, false)
	var progress_now: Dictionary = session.puzzle_progress if session != null else {}
	if progress_now.get(KEY_DEFEATED, false):
		_restore_won()
	elif progress_now.get(KEY_STARTED, false):
		mode = Mode.REARMED
		_boss_stand_ready()
	_apply_mode_glow()
	_refresh_consoles()


# ---------------------------------------------------------------- public interface

func is_active() -> bool:
	return mode == Mode.WAKING or mode == Mode.FIGHTING or mode == Mode.PLAYER_DOWN


func is_won() -> bool:
	return mode == Mode.WON


func get_boss_health() -> Node:
	return _health


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate()


func get_attack_state() -> StringName:
	return StringName(Act.keys()[act].to_lower())


func get_attack_kind() -> StringName:
	return _attack if act != Act.PAUSE else &""


func get_mode_name() -> StringName:
	return StringName(Mode.keys()[mode].to_lower())


func get_boss() -> CharacterBody3D:
	return _boss


func get_arena() -> Node3D:
	return _arena


func get_telegraph() -> Node3D:
	return _telegraph


func is_telegraph_visible() -> bool:
	return _telegraph.is_shown()


func get_retry_point() -> Vector3:
	return _arena.retry_point_global()


## Deterministic driver for tests: starts `kind` now when the boss is fighting and between attacks.
func force_attack(kind: StringName) -> bool:
	if mode != Mode.FIGHTING or act != Act.PAUSE or not ATTACKS.has(kind):
		return false
	_chain_next = &""
	_start_attack(kind)
	return true


func get_status() -> String:
	match mode:
		Mode.DORMANT:
			return "Gerbang: artefak terpasang %d/3%s" % [_installed.size(), " • siap dibangunkan" if _all_installed() else ""]
		Mode.WAKING:
			return "Penjaga Gerbang bangkit..."
		Mode.FIGHTING:
			return "Penjaga Gerbang • HP %d/%d • Fase %d • %s" % [_health.current_health, _health.max_health, phase, _attack_text()]
		Mode.PLAYER_DOWN:
			return "Penjaga Gerbang • Kembali ke titik retry..."
		Mode.REARMED:
			return "Penjaga Gerbang siap • percobaan ulang (%d)" % attempt
		_:
			return "Penjaga Gerbang runtuh • gerbang %s" % ("terbuka" if _gate_finished else "membuka")


func get_hud_state() -> Dictionary:
	return {
		"name": "Penjaga Gerbang", "hp": _health.current_health, "max_hp": _health.max_health, "phase": phase,
		"state": get_mode_name(), "text": get_status(), "active": is_active(), "attempt": attempt,
	}


# ---------------------------------------------------------------- console rules (called by gate_console.gd)

func can_use_console(console: Node, _player_node: Node) -> bool:
	if console.role == &"socket":
		return mode == Mode.DORMANT and not _installed.has(console.artifact_id) and _has_artifact(console.artifact_id)
	return (mode == Mode.DORMANT and _all_installed()) or mode == Mode.REARMED


func get_console_prompt(console: Node) -> String:
	if console.role == &"socket":
		return "Pasang %s" % console.display_name
	return "Hadapi Penjaga Gerbang lagi" if mode == Mode.REARMED else "Bangunkan Penjaga Gerbang"


func use_console(console: Node, _player_node: Node) -> bool:
	if not can_use_console(console, _player_node):
		return false
	if console.role == &"socket":
		_installed[console.artifact_id] = true
		_arena.set_socket_installed(console.artifact_id, true)
		_flash_runes()
		_apply_mode_glow()
		_refresh_consoles()
		status_changed.emit()
		return true
	_activate()
	return true


func _has_artifact(id: StringName) -> bool:
	return _session != null and _session.has_method(&"is_collected") and _session.is_collected(id)


func _all_installed() -> bool:
	for id in REQUIRED_ARTIFACTS:
		if not _installed.has(id):
			return false
	return true


func _refresh_consoles() -> void:
	if _arena == null:
		return
	for data: Dictionary in Arena.SOCKETS:
		var id: StringName = data["id"]
		var text := ""
		if mode == Mode.DORMANT:
			if _installed.has(id):
				text = "%s terpasang" % data["label"]
			elif _has_artifact(id):
				text = "Pasang %s" % data["name"]
			else:
				text = "Butuh %s" % data["name"]
		elif mode == Mode.REARMED or mode == Mode.WON:
			text = "%s terpasang" % data["label"] if _installed.has(id) else ""
		_arena.set_socket_text(id, text)
	match mode:
		Mode.DORMANT:
			_arena.set_altar_visible(true)
			_arena.set_altar_state(_all_installed(), "Bangunkan Penjaga" if _all_installed() else "Pasang 3 artefak (%d/3)" % _installed.size())
		Mode.REARMED:
			_arena.set_altar_visible(true)
			_arena.set_altar_state(true, "Coba lagi")
		_:
			_arena.set_altar_visible(false)


# ---------------------------------------------------------------- activation / fight start

func _activate() -> void:
	attempt += 1
	# Snapshot = resources at the altar press, BEFORE the wake (first attempt only; later presses never overwrite it).
	_capture_snapshot()
	_arena.set_barrier(true)
	_chain_next = &""
	if mode == Mode.DORMANT:
		mode = Mode.WAKING
		_wake_time = 0.0
		if _session != null:
			_session.puzzle_progress[KEY_STARTED] = true
		_current_clip = GolemAnimations.WAKE
		_anim.play(GolemAnimations.WAKE, 0.1)
		_fire(_fx_dust, _boss.global_position + Vector3(0, 0.2, 0))
		_fire(_fx_debris, _boss.global_position + Vector3(0, 0.6, 0))
	else:
		_begin_fight(RETRY_ATTACK_DELAY)
	_apply_mode_glow()
	_refresh_consoles()
	encounter_started.emit()
	status_changed.emit()


## Called when the wake clip ends (first attempt) or at once on a retry. The snapshot was already taken at activation.
func _begin_fight(first_delay: float) -> void:
	mode = Mode.FIGHTING
	act = Act.PAUSE
	_pause_left = first_delay
	_set_hurtbox(true)
	_bar_root.visible = true
	_update_bar()
	_play_loop(GolemAnimations.IDLE)
	_apply_mode_glow()
	_refresh_consoles()
	status_changed.emit()


func _capture_snapshot() -> void:
	if not _snapshot.is_empty() or _player == null:
		return
	var health = _player.get_health()
	_snapshot = {"hp": health.current_health, "stamina": _player.stamina, "potions": _player.potion_count}
	if _session != null:
		_session.puzzle_progress[KEY_SNAPSHOT] = _snapshot


# ---------------------------------------------------------------- physics loop

func _physics_process(delta: float) -> void:
	match mode:
		Mode.WAKING:
			_wake_time += delta
			if _wake_time >= WAKE_LENGTH:
				_begin_fight(FIRST_ATTACK_DELAY)
		Mode.FIGHTING:
			_tick_fight(delta)


func _process(delta: float) -> void:
	_time += delta
	var blend := 1.0 - exp(-6.0 * delta)
	_core_color = _core_color.lerp(_target_color, blend)
	_core_energy = lerpf(_core_energy, _target_energy, blend)
	_core_boost = move_toward(_core_boost, 0.0, delta * 5.0)
	var pulse := 1.0 + 0.18 * sin(_time * _pulse_speed * TAU * 0.5)
	var energy := _core_energy * pulse + _core_boost
	if _core_mat != null:
		_core_mat.albedo_color = _core_color
		_core_mat.emission = _core_color
		_core_mat.emission_energy_multiplier = energy
		_eye_mat.albedo_color = _core_color
		_eye_mat.emission = _core_color
		_eye_mat.emission_energy_multiplier = maxf(energy * 0.8, 0.0)
		_core_light.light_color = _core_color
		_core_light.light_energy = clampf(energy * 0.35, 0.0, 4.0)


func _tick_fight(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_dead():
		return
	match act:
		Act.PAUSE:
			_tick_pause(delta)
		Act.WINDUP:
			_tick_windup(delta)
		Act.ACTIVE:
			_tick_active(delta)
		Act.RECOVERY:
			_tick_recovery(delta)


func _tick_pause(delta: float) -> void:
	var to_player := _flat_to_player()
	var dist := to_player.length()
	_turn_toward(to_player, TURN_RATE, delta)
	if _roar_left > 0.0:
		_roar_left -= delta
		if _roar_left <= 0.0:
			_play_loop(GolemAnimations.IDLE)
		return
	if _roar_pending:
		_roar_pending = false
		_roar_left = GolemAnimations.clips()[GolemAnimations.ROAR]["length"]
		_current_clip = GolemAnimations.ROAR
		_anim.play(GolemAnimations.ROAR, 0.1)
		_core_boost = 6.0
		_fire(_fx_dust, _boss.global_position + Vector3(0, 0.2, 0))
		_ring_fx(_boss.global_position, 9.0, CORE_RED, 0.7)
		return
	_pause_left -= delta
	if dist > 6.5 and _pause_left > 0.0:
		_walk_toward(to_player / maxf(dist, 0.001), delta)
		_play_loop(GolemAnimations.WALK)
	else:
		_play_loop(GolemAnimations.IDLE)
	if _pause_left <= 0.0:
		_chain_next = &""
		var kind := _choose_attack(dist)
		if phase == 2 and _rng.randf() < CHAIN_CHANCE:
			_chain_next = ATTACKS[kind]["chain"]
		_start_attack(kind)


func _choose_attack(dist: float) -> StringName:
	var weights := {&"sweep": 0.0, &"slam": 0.0, &"charge": 0.0}
	if dist < 7.5:
		weights = {&"sweep": 55.0, &"slam": 45.0, &"charge": 5.0}
	elif dist < 11.0:
		weights = {&"sweep": 15.0, &"slam": 45.0, &"charge": 40.0}
	else:
		weights = {&"sweep": 0.0, &"slam": 25.0, &"charge": 75.0}
	for kind: StringName in weights:
		if kind == _last_attack:
			weights[kind] *= 0.4
		if kind == _last_attack and kind == _prev_attack:
			weights[kind] = 0.0
	var total := 0.0
	for kind: StringName in weights:
		total += weights[kind]
	var roll := _rng.randf() * total
	for kind: StringName in weights:
		roll -= weights[kind]
		if roll <= 0.0 and weights[kind] > 0.0:
			return kind
	return &"slam"


func _start_attack(kind: StringName) -> void:
	_attack = kind
	_prev_attack = _last_attack
	_last_attack = kind
	var cfg: Dictionary = ATTACKS[kind]
	act = Act.WINDUP
	_act_time = 0.0
	_act_length = cfg["windup"]
	_locked = false
	_hit_resolved = false
	_charge_traveled = 0.0
	_zone = {}
	_play_clip(cfg["windup_clip"], _act_length)
	_telegraph.set_color(COLOR_TRACK, 0.5)
	_core_boost = 1.5
	_pulse_speed = 5.0
	_update_zone(cfg)
	status_changed.emit()


func _tick_windup(delta: float) -> void:
	var cfg: Dictionary = ATTACKS[_attack]
	_act_time += delta
	var progress := clampf(_act_time / _act_length, 0.0, 1.0)
	if not _locked:
		_turn_toward(_flat_to_player(), TURN_RATE if _attack != &"charge" else TURN_RATE * 1.3, delta)
		_update_zone(cfg)
		if progress >= float(cfg["lock"]):
			_locked = true
			_telegraph.set_color(COLOR_LOCKED, 0.62)
			_core_boost = 3.0
	_telegraph.set_progress(progress)
	if _act_time >= _act_length:
		_begin_active(cfg)


func _begin_active(cfg: Dictionary) -> void:
	act = Act.ACTIVE
	_act_time = 0.0
	_act_length = float(cfg["active"])
	if _attack == &"charge":
		_act_length = maxf(float(_zone.get("travel", 0.0)) / float(cfg["speed"]), 0.25)
		_play_clip(cfg["strike_clip"], 0.0)
		_fx_trail.emitting = true
	else:
		_play_clip(cfg["strike_clip"], _act_length)
	_telegraph.set_color(COLOR_ACTIVE, 0.85)
	_telegraph.set_progress(1.0)
	_core_boost = 5.0


func _tick_active(delta: float) -> void:
	var cfg: Dictionary = ATTACKS[_attack]
	_act_time += delta
	if _attack == &"charge":
		_tick_charge(cfg, delta)
	elif not _hit_resolved and _act_time >= float(cfg["hit_at"]) * _act_length:
		_hit_resolved = true
		_impact_fx(cfg)
		if _player_in_zone():
			_damage_player(cfg)
	if _act_time >= _act_length:
		_begin_recovery(cfg)


func _tick_charge(cfg: Dictionary, delta: float) -> void:
	var travel := float(_zone["travel"])
	var dir: Vector3 = _zone["dir"]
	var step := minf(float(cfg["speed"]) * delta, travel - _charge_traveled)
	if step > 0.0:
		_boss.velocity = dir * (step / delta)
		_boss.move_and_slide()
		_boss.velocity = Vector3.ZERO
		_charge_traveled = ((_boss.global_position - (_zone["start"] as Vector3)) * Vector3(1, 0, 1)).dot(dir)
	if not _hit_resolved:
		var offset := ((_player.global_position - (_zone["start"] as Vector3)) * Vector3(1, 0, 1)).dot(dir)
		if offset <= _charge_traveled + float(cfg["front"]) and _player_in_zone():
			_hit_resolved = true
			_damage_player(cfg)
	if _charge_traveled >= travel - 0.05 or step <= 0.0:
		_act_time = _act_length  # reached the end of the clipped lane (or blocked): finish this tick


func _begin_recovery(cfg: Dictionary) -> void:
	act = Act.RECOVERY
	_act_time = 0.0
	_act_length = CHAIN_RECOVERY if _chain_next != &"" else float(cfg["recovery"])
	_telegraph.clear()
	_fx_trail.emitting = false
	_pulse_speed = 2.0
	if _attack == &"charge":
		_fire(_fx_dust, _boss.global_position + _boss.global_basis.z * 1.5 + Vector3(0, 0.2, 0))
	_play_clip(cfg["recover_clip"], _act_length)
	_boss.velocity = Vector3.ZERO


func _tick_recovery(delta: float) -> void:
	_act_time += delta
	if _act_time < _act_length:
		return
	if _chain_next != &"":
		var next := _chain_next
		_chain_next = &""
		_start_attack(next)
		return
	act = Act.PAUSE
	_pause_left = PAUSE_PHASE_TWO if phase == 2 else PAUSE_PHASE_ONE
	_attack = &""
	_play_loop(GolemAnimations.IDLE)
	status_changed.emit()


# ---------------------------------------------------------------- attack geometry (world-clipped zones)

func _update_zone(cfg: Dictionary) -> void:
	var origin := _boss.global_position
	var forward := _boss.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var yaw := atan2(forward.x, forward.z)
	match int(cfg["kind"]):
		ZoneKind.SECTOR:
			_zone = _sector_zone(origin, yaw, float(cfg["radius"]), deg_to_rad(float(cfg["half_arc"])))
		ZoneKind.CIRCLE:
			_zone = _circle_zone(origin, forward, yaw, float(cfg["reach"]), float(cfg["radius"]))
		ZoneKind.LANE:
			_zone = _lane_zone(origin, forward, yaw, float(cfg["width"]), float(cfg["length"]), float(cfg["front"]))
	_telegraph.set_zone(_zone["poly"], _zone["origin"], _zone["yaw"], Telegraph.Fill.LANE if int(cfg["kind"]) == ZoneKind.LANE else Telegraph.Fill.RADIAL)


func _sector_zone(origin: Vector3, yaw: float, radius: float, half_arc: float) -> Dictionary:
	var chest := origin + Vector3.UP * 1.2
	var points := PackedVector2Array([Vector2(origin.x, origin.z)])
	var steps := 20
	for i in steps + 1:
		var angle := yaw + lerpf(-half_arc, half_arc, float(i) / steps)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var reach := _clip(chest, dir, radius)
		points.append(Vector2(origin.x + dir.x * reach, origin.z + dir.z * reach))
	return {"poly": points, "origin": origin, "yaw": yaw}


func _circle_zone(origin: Vector3, forward: Vector3, yaw: float, reach: float, radius: float) -> Dictionary:
	var distance := _clip(origin + Vector3.UP * 1.2, forward, reach)
	var center := origin + forward * distance
	var points := PackedVector2Array()
	var steps := 28
	for i in steps:
		var angle := TAU * float(i) / steps
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var r := _clip(center + Vector3.UP * 1.2, dir, radius)
		points.append(Vector2(center.x + dir.x * r, center.z + dir.z * r))
	return {"poly": points, "origin": center, "yaw": yaw, "center": center}


func _lane_zone(origin: Vector3, forward: Vector3, yaw: float, width: float, length: float, front: float) -> Dictionary:
	var right := forward.cross(Vector3.UP).normalized()
	var chest := origin + Vector3.UP * 1.2
	var lane := length
	for lateral in [-width * 0.5, 0.0, width * 0.5]:
		lane = minf(lane, _clip(chest + right * lateral, forward, length))
	var half := width * 0.5
	var back := 1.0
	var a := origin - forward * back
	var b := origin + forward * lane
	var points := PackedVector2Array([
		Vector2(a.x - right.x * half, a.z - right.z * half), Vector2(a.x + right.x * half, a.z + right.z * half),
		Vector2(b.x + right.x * half, b.z + right.z * half), Vector2(b.x - right.x * half, b.z - right.z * half),
	])
	return {"poly": points, "origin": origin, "yaw": yaw, "dir": forward, "start": origin,
		"travel": maxf(lane - front, 0.0), "length": lane}


func _clip(from: Vector3, dir: Vector3, length: float) -> float:
	_ray.from = from
	_ray.to = from + dir * length
	_ray.collision_mask = 1
	_ray.exclude = [_boss.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit["position"]) - 0.05, 0.4)


func _player_in_zone() -> bool:
	return _telegraph.contains_circle(_player.global_position)


func _damage_player(cfg: Dictionary) -> void:
	if _player.is_dead():
		return
	if _player.receive_damage(int(cfg["damage"])):
		_fire(_fx_hit, _player.global_position + Vector3(0, 1.1, 0))


# ---------------------------------------------------------------- boss movement helpers

func _flat_to_player() -> Vector3:
	var delta := _player.global_position - _boss.global_position
	delta.y = 0.0
	return delta


func _turn_toward(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length() < 0.05:
		return
	var current := _boss.global_rotation.y
	var diff := angle_difference(current, atan2(dir.x, dir.z))
	_boss.global_rotation.y = current + clampf(diff, -rate * delta, rate * delta)


func _walk_toward(dir: Vector3, delta: float) -> void:
	var local := to_local(_boss.global_position)
	if local.z >= BOSS_MAX_Z and to_local(_boss.global_position + dir).z > local.z:
		return
	_boss.velocity = dir * WALK_SPEED
	_boss.move_and_slide()
	_boss.velocity = Vector3.ZERO


func _play_loop(clip: StringName) -> void:
	if _current_clip == clip:
		return
	_current_clip = clip
	_anim.play(clip, 0.2)


## Plays a clip scaled so it lasts `duration` seconds (0 = natural speed).
func _play_clip(clip: StringName, duration: float) -> void:
	_current_clip = clip
	var length: float = _anim.get_animation(clip).length
	_anim.play(clip, 0.08, length / duration if duration > 0.0 else 1.0)


# ---------------------------------------------------------------- health / phases / death

func _on_health_changed(current: int, maximum: int) -> void:
	if current < _last_hp:
		_flash_hit()
	_last_hp = current
	_update_bar()
	if mode == Mode.FIGHTING and phase == 1 and current > 0 and float(current) <= float(maximum) * PHASE_TWO_RATIO:
		phase = 2
		_roar_pending = true
		_apply_mode_glow()
		status_changed.emit()


func _on_boss_dead() -> void:
	if mode != Mode.FIGHTING:
		return
	mode = Mode.WON
	act = Act.PAUSE
	_attack = &""
	_chain_next = &""
	_telegraph.clear()
	_fx_trail.emitting = false
	_set_hurtbox(false)
	_boss.collision_layer = 0
	_bar_root.visible = false
	_snapshot = {}
	if _session != null:
		_session.puzzle_progress.erase(KEY_SNAPSHOT)
		_session.puzzle_progress[KEY_DEFEATED] = true
	_current_clip = GolemAnimations.DEATH
	_anim.play(GolemAnimations.DEATH, 0.15)
	_arena.set_barrier(false)
	_apply_mode_glow()
	_refresh_consoles()
	var sequence := create_tween()
	sequence.tween_interval(2.4)
	sequence.tween_callback(_arena.open_gate)
	sequence.tween_interval(1.0)
	sequence.tween_callback(func():
		_fire(_fx_dust, _boss.global_position + Vector3(0, 0.3, 0))
		_fire(_fx_debris, _boss.global_position + Vector3(0, 0.6, 0)))
	sequence.tween_property(_model, "position:y", _model_rest_y - 6.5, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sequence.tween_callback(func(): _boss.visible = false)
	encounter_won.emit()
	status_changed.emit()


func _restore_won() -> void:
	mode = Mode.WON
	_boss.visible = false
	_boss.collision_layer = 0
	_set_hurtbox(false)
	_bar_root.visible = false
	_arena.set_barrier(false)
	for id: StringName in REQUIRED_ARTIFACTS:
		_arena.set_socket_installed(id, true, false)
	if _session != null and _session.puzzle_progress.get(KEY_GATE_OPEN, false):
		_gate_finished = true
		_arena.open_gate(0.01)


func _on_gate_opened() -> void:
	_gate_finished = true
	if _session != null:
		_session.puzzle_progress[KEY_GATE_OPEN] = true
		_session.status_changed.emit()
	status_changed.emit()


func _on_dock_entered(body: Node3D) -> void:
	if body != _player or mode != Mode.WON or not _gate_finished or _completed_emitted:
		return
	_completed_emitted = true
	completed.emit()
	status_changed.emit()


# ---------------------------------------------------------------- player death / retry

func _on_player_died() -> void:
	if mode != Mode.FIGHTING:
		return
	mode = Mode.PLAYER_DOWN
	_stop_attack_state()
	_play_loop(GolemAnimations.IDLE)
	_apply_mode_glow()
	status_changed.emit()


func _on_session_respawned() -> void:
	if mode != Mode.PLAYER_DOWN:
		return
	_retry_reset()


func _retry_reset() -> void:
	_stop_attack_state()
	_health.restore_full()
	_last_hp = _health.current_health
	phase = 1
	_roar_pending = false
	_roar_left = 0.0
	_last_attack = &""
	_prev_attack = &""
	_boss_stand_ready()
	mode = Mode.REARMED
	_arena.set_barrier(false)
	_restore_player()
	_apply_mode_glow()
	_refresh_consoles()
	_update_bar()
	status_changed.emit()


## Player side of the retry: cancel every transient state, safe entrance position, then the EXACT snapshot values.
func _restore_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method(&"restore_for_respawn"):
		_player.restore_for_respawn()
	_player.global_transform = Transform3D(Basis(Vector3.UP, global_basis.get_euler().y + PI), get_retry_point())
	if "velocity" in _player:
		_player.velocity = Vector3.ZERO
	if _snapshot.is_empty():
		return
	var health = _player.get_health()
	health.is_dead = false
	health.current_health = clampi(int(_snapshot["hp"]), 1, health.max_health)
	health.health_changed.emit(health.current_health, health.max_health)
	_player.stamina = clampf(float(_snapshot["stamina"]), 0.0, _player.max_stamina)
	_player.potion_count = clampi(int(_snapshot["potions"]), 0, _player.max_potions)
	_player.resources_changed.emit()


func _stop_attack_state() -> void:
	act = Act.PAUSE
	_attack = &""
	_chain_next = &""
	_locked = false
	_zone = {}
	_telegraph.clear()
	_fx_trail.emitting = false
	_boss.velocity = Vector3.ZERO
	_pulse_speed = 2.0
	_set_hurtbox(false)


## Boss awake and standing at its home pose (no wake animation, no vulnerability).
func _boss_stand_ready() -> void:
	_boss.global_transform = Transform3D(global_basis, to_global(BOSS_HOME))
	_boss.visible = true
	_boss.collision_layer = 9
	_model.position.y = _model_rest_y
	_set_hurtbox(false)
	_bar_root.visible = false
	_current_clip = &""
	_play_loop(GolemAnimations.IDLE)


func _set_hurtbox(enabled: bool) -> void:
	_hurtbox.collision_layer = 4 if enabled else 0


# ---------------------------------------------------------------- visuals

func _apply_mode_glow() -> void:
	var rune := CORE_CYAN
	var rune_energy := 0.4
	match mode:
		Mode.DORMANT:
			_target_color = Color(0.6, 0.12, 0.1)
			_target_energy = 0.5
			rune_energy = 1.2 if _all_installed() else 0.4 + 0.3 * _installed.size()
		Mode.WAKING:
			_target_color = CORE_CYAN
			_target_energy = 3.0
			rune_energy = 2.0
		Mode.FIGHTING:
			if phase == 2:
				_target_color = CORE_RED
				_target_energy = 5.5
				rune = CORE_RED
				rune_energy = 1.5
			else:
				_target_color = CORE_CYAN
				_target_energy = 2.6
				rune_energy = 1.6
		Mode.PLAYER_DOWN, Mode.REARMED:
			_target_color = CORE_CYAN
			_target_energy = 1.1
			rune_energy = 1.0
		Mode.WON:
			_target_color = Color(0.1, 0.1, 0.1)
			_target_energy = 0.0
			rune = Color(0.4, 1.0, 0.6)
			rune_energy = 1.4
	_pulse_speed = 2.0 if phase == 1 else 3.0
	_arena.set_rune(rune, rune_energy)
	_arena.set_seal_active(mode != Mode.WON or not _gate_finished)


func _flash_runes() -> void:
	_core_boost = 2.0


func _flash_hit() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_overlay_mat.albedo_color.a = 0.5
	_flash_tween = create_tween()
	_flash_tween.tween_property(_overlay_mat, "albedo_color:a", 0.0, 0.22)
	_core_boost = maxf(_core_boost, 2.0)


func _update_bar() -> void:
	if _bar_mat == null:
		return
	_bar_mat.set_shader_parameter(&"ratio", clampf(float(_health.current_health) / float(maxi(_health.max_health, 1)), 0.0, 1.0))
	_bar_mat.set_shader_parameter(&"fill_color", Color(1.0, 0.45, 0.12) if phase == 2 else Color(0.35, 0.85, 1.0))
	_bar_label.modulate = Color(1.0, 0.55, 0.3) if phase == 2 else Color(0.85, 0.95, 1.0)


func _impact_fx(cfg: Dictionary) -> void:
	var kind := int(cfg["kind"])
	if kind == ZoneKind.CIRCLE:
		var center: Vector3 = _zone["center"]
		_fire(_fx_dust, center + Vector3(0, 0.2, 0))
		_fire(_fx_debris, center + Vector3(0, 0.4, 0))
		_ring_fx(center, float(cfg["radius"]), COLOR_ACTIVE, 0.45)
	elif kind == ZoneKind.SECTOR:
		var forward := _boss.global_basis.z
		_fire(_fx_dust, _boss.global_position + forward * float(cfg["radius"]) * 0.7 + Vector3(0, 0.3, 0))
		_ring_fx(_boss.global_position, float(cfg["radius"]), COLOR_ACTIVE, 0.3)


func _ring_fx(center: Vector3, radius: float, color: Color, duration: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	ring.material_override = mat
	ring.top_level = true
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(center.x, 0.12, center.z)
	ring.scale = Vector3(0.2, 0.05, 0.2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.05, radius), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


func _fire(particles: CPUParticles3D, at: Vector3) -> void:
	particles.global_position = at
	particles.restart()
	particles.emitting = true


func _attack_text() -> String:
	match act:
		Act.WINDUP:
			return "Bersiap: %s" % _attack_label()
		Act.ACTIVE:
			return "Menyerang: %s" % _attack_label()
		Act.RECOVERY:
			return "Pulih"
		_:
			return "Mengincar"


func _attack_label() -> String:
	match _attack:
		&"sweep":
			return "Sapuan Lengan"
		&"slam":
			return "Hantaman Tanah"
		&"charge":
			return "Terjangan"
	return ""


# ---------------------------------------------------------------- construction (boss, fx)

func _build_boss() -> void:
	_boss = CharacterBody3D.new()
	_boss.name = &"Boss"
	_boss.collision_layer = 9
	_boss.collision_mask = 1
	_boss.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.3
	capsule.height = 4.6
	body_shape.shape = capsule
	body_shape.position = Vector3(0, 2.3, 0)
	_boss.add_child(body_shape)
	_hurtbox = Area3D.new()
	_hurtbox.name = &"Hurtbox"
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.set_meta(&"damageable", NodePath("../../Health"))
	var hurt_shape := CollisionShape3D.new()
	var hurt_capsule := CapsuleShape3D.new()
	hurt_capsule.radius = 1.7
	hurt_capsule.height = 5.2
	hurt_shape.shape = hurt_capsule
	hurt_shape.position = Vector3(0, 2.6, 0)
	_hurtbox.add_child(hurt_shape)
	_boss.add_child(_hurtbox)
	_pivot = Node3D.new()
	_pivot.name = &"Pivot"
	_boss.add_child(_pivot)
	_model = Node3D.new()
	_model.name = &"Model"
	_model.scale = Vector3.ONE * GolemAnimations.MODEL_SCALE
	_model_rest_y = MODEL_FEET_OFFSET * GolemAnimations.MODEL_SCALE
	_model.position.y = _model_rest_y
	_pivot.add_child(_model)
	var golem := (load(GOLEM_SCENE) as PackedScene).instantiate()
	golem.name = &"Golem"
	_model.add_child(golem)
	_skeleton = golem.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_mesh = golem.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	add_child(_boss)
	_boss.global_transform = Transform3D(global_basis, to_global(BOSS_HOME))
	_anim = AnimationPlayer.new()
	_anim.name = &"AnimationPlayer"
	_boss.add_child(_anim)
	_anim.root_node = _anim.get_path_to(_boss)
	var errors := PackedStringArray()
	var library := GolemAnimations.build_library(_skeleton, _boss.get_path_to(_skeleton), NodePath("Pivot"), errors)
	if library == null:
		push_error("Penjaga Gerbang: " + "\n".join(errors))
	else:
		_anim.add_animation_library(&"", library)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.43, 0.4)
	stone.roughness = 0.95
	_mesh.set_surface_override_material(0, stone)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.emission_enabled = true
	_eye_mat.albedo_color = CORE_CYAN
	_eye_mat.emission = CORE_CYAN
	if _mesh.mesh.get_surface_count() > 1:
		_mesh.set_surface_override_material(1, _eye_mat)
	_overlay_mat = StandardMaterial3D.new()
	_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay_mat.albedo_color = Color(1.0, 0.85, 0.6, 0.0)
	_mesh.material_overlay = _overlay_mat
	# Energy core on the chest, follows the pelvis/torso bone.
	var attachment := BoneAttachment3D.new()
	attachment.name = &"CoreAttachment"
	attachment.bone_name = "Bone"
	_skeleton.add_child(attachment)
	_core_mat = StandardMaterial3D.new()
	_core_mat.emission_enabled = true
	_core_mat.albedo_color = _core_color
	_core_mat.emission = _core_color
	var core := MeshInstance3D.new()
	core.name = &"EnergyCore"
	var gem := SphereMesh.new()
	gem.radius = 0.55
	gem.height = 1.3
	gem.radial_segments = 6
	gem.rings = 3
	core.mesh = gem
	core.material_override = _core_mat
	core.position = Vector3(0, 1.35, 0.7)
	attachment.add_child(core)
	_core_light = OmniLight3D.new()
	_core_light.omni_range = 9.0
	_core_light.position = Vector3(0, 3.0, 1.2)
	_boss.add_child(_core_light)
	_build_bar()
	_anim.play(GolemAnimations.DORMANT)
	_current_clip = GolemAnimations.DORMANT


func _build_bar() -> void:
	_bar_root = MeshInstance3D.new()
	_bar_root.name = &"HealthBar"
	var quad := QuadMesh.new()
	quad.size = Vector2(5.2, 0.34)
	_bar_root.mesh = quad
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
uniform float ratio = 1.0;
uniform vec4 fill_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
void vertex() {
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX = (VIEW_MATRIX * billboard * vec4(VERTEX, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 uv = UV;
	bool border = uv.x < 0.012 || uv.x > 0.988 || uv.y < 0.12 || uv.y > 0.88;
	vec3 color = border ? vec3(0.04) : (uv.x <= ratio ? fill_color.rgb : vec3(0.18, 0.05, 0.05));
	ALBEDO = color;
	ALPHA = 0.95;
}
"""
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = shader
	_bar_root.material_override = _bar_mat
	_bar_root.position = Vector3(0, 6.6, 0)
	_bar_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.visible = false
	_bar_root.extra_cull_margin = 10.0
	_boss.add_child(_bar_root)
	_bar_label = Label3D.new()
	_bar_label.text = "PENJAGA GERBANG"
	_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_label.pixel_size = 0.008
	_bar_label.font_size = 44
	_bar_label.outline_size = 12
	_bar_label.no_depth_test = true
	_bar_label.position = Vector3(0, 0.42, 0)
	_bar_root.add_child(_bar_label)
	_update_bar()


func _build_fx() -> void:
	_fx_dust = _make_burst(Color(0.62, 0.55, 0.45), 48, 0.35, 3.0, 8.0, 1.2, -4.0, 0.25)
	_fx_debris = _make_burst(Color(0.38, 0.36, 0.34), 26, 0.28, 5.0, 11.0, 1.1, -22.0, 1.0)
	_fx_hit = _make_burst(Color(1.0, 0.5, 0.2), 22, 0.12, 3.0, 7.0, 0.45, -6.0, 1.0)
	_fx_trail = _make_burst(Color(0.62, 0.55, 0.45), 40, 0.4, 0.8, 2.5, 0.8, -1.0, 0.2)
	_fx_trail.one_shot = false
	_fx_trail.explosiveness = 0.0
	_fx_trail.emitting = false
	_fx_trail.reparent(_boss, false)
	_fx_trail.position = Vector3(0, 0.3, -0.6)
	_fx_trail.local_coords = false


func _make_burst(color: Color, amount: int, size: float, vmin: float, vmax: float, life: float, gravity_y: float, scale_jitter: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 1.0
	particles.lifetime = life
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = vmin
	particles.initial_velocity_max = vmax
	particles.gravity = Vector3(0, gravity_y, 0)
	particles.scale_amount_min = 1.0 - scale_jitter * 0.5
	particles.scale_amount_max = 1.0 + scale_jitter
	var cube := BoxMesh.new()
	cube.size = Vector3(size, size, size)
	particles.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	particles.material_override = mat
	add_child(particles)
	return particles


## Checkpoint inside the arena next to the south entrance (local z 12.5): the ground south of the arena is occupied by the summit route.
func _build_checkpoint() -> void:
	var checkpoint := (load("res://scenes/world/checkpoint.tscn") as PackedScene).instantiate()
	checkpoint.name = &"ArenaCheckpoint"
	checkpoint.checkpoint_id = &"gatekeeper_gate"
	checkpoint.position = Vector3(-10.0, 0.0, 12.5)
	add_child(checkpoint)


## The golem Mesh resource is shared between instances (GLB cache): drop per-instance materials before this one is freed.
func _exit_tree() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.material_overlay = null
		for surface in _mesh.mesh.get_surface_count():
			_mesh.set_surface_override_material(surface, null)
