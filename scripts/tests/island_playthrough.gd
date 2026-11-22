extends Node
## P14-05 full-run playthrough bot. Plays res://scenes/world/island_game.tscn from the initial spawn to the ending using
## ONLY player-level input: InputEventKey / InputEventMouseButton events built from the project's own InputMap actions
## (WASD, Shift, Space, E, Q, Alt, LMB, RMB) and real InputEventMouseMotion to aim the camera. WASD is camera-relative, so
## the bot first turns the camera with mouse motion until "forward" points where it wants to go, then holds W; the
## character turns by moving. The bot only READS observable state (positions, states, HP, telegraph zones, interactor
## target) to choose inputs. It never teleports, never writes health/items/progress, never disables AI and never
## touches Engine.time_scale. Every swing, dodge, sprint and interaction is a real input subject to the 0.2 s swing,
## stamina, interactor range and line of sight.
##
## Node runner: ONE implementation for both the editor and the exported game. island_game._ready() instances this script on
## the hidden --qa-playthrough user arg (begin_play without the menu), add_child()s it and calls attach(game, user_args).
##   Editor:  C:/Godot/godot.exe --headless --fixed-fps 60 --path . res://scenes/world/island_game.tscn -- --qa-playthrough
##            (add --shots without --headless for milestone screenshots; keep the window focused, focus loss auto-pauses)
##   Export:  the-lost-island.exe --headless --fixed-fps 60 -- --qa-playthrough
## User args: --shots, --attempts=N (boss tries, default 4). Exit code 0 = ending reached, 1 = failure (last log line names
## stage, position, reason). Log + screenshots: res://tmp/island_playthrough/ in the editor, user://island_playthrough/ exported.
## Order: spawn potion -> Symbol Pillars -> artifact -> Energy Path -> artifact -> Summit climb (jump gap) + artifact + lever ->
## shortcut bridge -> main lane -> boss arena: 3 sockets, altar, fight (retries) -> gate -> dock ending.
## The boss draws its attacks from an unseeded RNG, so the fight is not bit-for-bit repeatable; the bot reacts to it.

const ENC := preload("res://scripts/boss/gatekeeper_encounter.gd")
const EDITOR_OUT_DIR := "res://tmp/island_playthrough/"
const EXPORT_OUT_DIR := "user://island_playthrough/"
const SIM_LIMIT := 1800.0
const PLAYER_RADIUS := 0.45
const BOSS_ARENA_X := 15.5
const BOSS_ARENA_Z_MIN := -13.5
const BOSS_ARENA_Z_MAX := 14.0

var game: Node3D
var OUT_DIR := EDITOR_OUT_DIR
var player: CharacterBody3D
var camera: Node3D
var session: Node
var interactor: Node
var terrain: Node3D
var boss: Node3D
var symbol: Node3D
var energy: Node3D
var summit: Node3D
var presentation: Node

var _opt_shots := false
var _opt_attempts := 4
var _start_frame := 0
var _stage := "init"
var _held: Dictionary = {}
var _pending: Array = []
var _log := PackedStringArray()
var _allow_death := false
var _completed := false
var _gate_opened := false
var _paused_frames := 0
var _esc_sent := 0
var _expect_pause := false
var _shot_count := 0
var _kills := 0
var _boss_attempts := 0
var _deaths := 0
var _react := true

# boss-fight scratch state
var _b_act := &""
var _b_kind := &""
var _b_act_frame := 0
var _b_dodged := false
var _b_evade_dir := Vector3.ZERO


## Called once by the bootstrap scene / the game-root seam after the game node is in the tree.
func attach(game_node: Node3D, args: PackedStringArray) -> void:
	game = game_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	OUT_DIR = EDITOR_OUT_DIR if OS.has_feature("editor") else EXPORT_OUT_DIR
	for arg in args:
		if arg == "--shots":
			_opt_shots = true
		elif arg.begins_with("--attempts="):
			_opt_attempts = maxi(1, int(arg.get_slice("=", 1)))
	# Mouse motion is delivered the moment it is parsed (no one-frame accumulation delay).
	Input.use_accumulated_input = false
	seed(20261122)
	_run.call_deferred()


# ======================================================================================================================
# Main script
# ======================================================================================================================

func _run() -> void:
	await get_tree().physics_frame
	_start_frame = Engine.get_physics_frames()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _wait(0.5)
	await _bind()
	await _wait(1.0)

	_stage = "spawn"
	var start := player.global_position
	_say("start pos=%s hp=%d potions=%d camera_yaw=%.2f" % [start, player.get_health().current_health, player.potion_count, camera.get_yaw()])
	if absf(start.x) > 0.5 or absf(start.z - 85.0) > 0.5 or not player.is_on_floor():
		await _fail("not standing on the initial spawn (0,~0,85): %s floor=%s" % [start, player.is_on_floor()])
	await _shot("00-spawn")

	await _stage_spawn_potion()
	await _stage_symbol_puzzle()
	await _stage_energy_puzzle()
	await _stage_summit()
	await _stage_boss()
	await _stage_ending()


func _bind() -> void:
	player = game.get_node_or_null(^"Player")
	camera = game.get_node_or_null(^"Camera3D")
	session = game.get("session")
	interactor = game.get("interactor")
	terrain = game.get("terrain")
	boss = game.get("boss")
	presentation = game.get("presentation")
	var objectives: Node = game.get("objectives")
	if player == null or camera == null or session == null or interactor == null or terrain == null or boss == null or objectives == null:
		await _fail("island_game is missing Player/Camera3D/session/interactor/terrain/boss/objectives")
	symbol = objectives.get_node_or_null(^"SymbolPillars")
	energy = objectives.get_node_or_null(^"EnergyPath")
	summit = objectives.get_node_or_null(^"SummitRoute")
	if symbol == null or energy == null or summit == null:
		await _fail("objective roots SymbolPillars/EnergyPath/SummitRoute not found under Objectives")
	var needs := {
		"player": [player, ["is_dead", "get_health", "is_attacking", "is_drinking", "is_dodging", "can_interact"]],
		"camera": [camera, ["get_yaw", "is_mouse_captured", "is_paused"]],
		"terrain": [terrain, ["get_route_points"]],
		"symbol": [symbol, ["get_pillar_interactable", "get_solution", "get_progress", "is_solved", "get_artifact"]],
		"energy": [energy, ["get_panel_interactable", "get_orientations", "get_panel_kinds", "is_rotating", "is_solved", "get_artifact"]],
		"summit": [summit, ["get_route_waypoints", "get_lever_position", "is_shortcut_open", "get_artifact"]],
		"boss": [boss, ["get_attack_state", "get_attack_kind", "get_telegraph", "get_boss", "get_mode_name", "get_arena", "is_won"]],
		"interactor": [interactor, ["get_target", "get_prompt"]],
	}
	for key in needs:
		var node: Object = needs[key][0]
		for method: String in needs[key][1]:
			if not node.has_method(method):
				await _fail("dependency %s lacks method %s()" % [key, method])
	if get_tree().get_nodes_in_group(&"player").is_empty():
		await _fail("player is not in group `player` (combat_enabled false?)")
	boss.completed.connect(func() -> void: _completed = true)
	boss.get_arena().gate_opened.connect(func() -> void: _gate_opened = true)
	if get_tree().paused or camera.is_paused():
		await _fail("game is paused at start (menu/intro visible?)")
	if not camera.is_mouse_captured():
		await _fail("camera mouse-look is not captured; mouse motion would be ignored")
	# The first motion after capture is discarded by the camera; spend it with a 1 px real mouse move.
	_mouse_motion(Vector2(1.0, 0.0))
	await _step()


# ======================================================================================================================
# Stages
# ======================================================================================================================

func _stage_spawn_potion() -> void:
	_stage = "spawn_potion"
	var potion := _find_pickup(&"island_potion_0")
	if potion == null:
		_say("no spawn potion found, skipping")
		return
	var before: int = player.potion_count
	await _walk_to(potion.global_position, 1.4, false)
	await _interact(potion, "potion at camp", func() -> bool: return session.is_collected(&"island_potion_0"))
	_say("potion taken: %d -> %d" % [before, player.potion_count])


func _stage_symbol_puzzle() -> void:
	_stage = "symbol_puzzle"
	var center: Vector3 = symbol.global_position
	await _follow(_route_world(&"spawn_symbol", false, center, 26.0), 2.0, true)
	await _walk_to(symbol.to_global(Vector3(0, 0, 14)), 1.0, true)
	await _walk_to(symbol.to_global(Vector3(0, 0, 8)), 1.0, false)
	var solution: Array = symbol.get_solution()
	_say("pillar solution (symbol ids) = %s" % [solution])
	var corners: Array[Vector3] = [Vector3(-2.7, 0, -2.7), Vector3(2.7, 0, -2.7), Vector3(2.7, 0, 2.7), Vector3(-2.7, 0, 2.7)]
	var at := -1
	for step in solution.size():
		var id: int = solution[step]
		# walk the square ring (clear of the seal in the middle and the pillar collision) to this pillar's corner
		if at < 0:
			await _walk_to(symbol.to_global(corners[2]), 0.7, false)
			at = 2
		var path: Array[int] = _ring_path(at, id)
		for corner in path:
			await _walk_to(symbol.to_global(corners[corner]), 0.7, false)
		at = id
		var expect := step + 1
		var item: Node3D = symbol.get_pillar_interactable(id)
		await _interact(item, "pillar %d (step %d/4)" % [id, expect],
			func() -> bool: return symbol.get_progress().size() >= expect or symbol.is_solved())
		await _wait(0.25)
	if not symbol.is_solved():
		await _fail("all four pillars pressed in order but the puzzle is not solved; progress=%s" % [symbol.get_progress()])
	_say("symbol puzzle solved")
	await _shot("01-symbol-solved")
	await _wait(1.4)  # seal fades (collision is already gone)
	var artifact: Node3D = symbol.get_artifact()
	await _walk_to(symbol.to_global(Vector3(0, 0, 1.9)), 0.5, false)
	await _interact(artifact, "forest artifact", func() -> bool: return session.is_collected(&"forest_artifact"))
	_say("forest_artifact collected")
	await _shot("02-forest-artifact")
	# leave through the gap between the two north walls
	await _walk_to(symbol.to_global(Vector3(-2, 0, -2.5)), 0.8, false)
	await _walk_to(symbol.to_global(Vector3(-2, 0, -13)), 1.2, true)


func _stage_summit() -> void:
	_stage = "summit_climb"
	var wps: Array[Vector3] = summit.get_route_waypoints()
	# wps[0..1] are the south entry used by the main road; coming from the east foot we join at the foot of the west ramp.
	await _walk_to(summit.to_global(wps[2]), 1.5, true)
	for i in range(3, wps.size() - 1):
		var a: Vector3 = wps[i - 1]
		var b: Vector3 = wps[i]
		var gap := a.x <= 0.0 and b.x >= 3.0 and a.y > 3.0
		if gap:
			_say("jump gap: from %s to %s" % [a, b])
			await _walk_to(summit.to_global(a), 0.6, false)
			var gate_x: Callable = func() -> bool: return summit.to_local(player.global_position).x >= -0.4
			await _walk_to(summit.to_global(b), 1.6, false, 0.0, gate_x)
		else:
			await _walk_to(summit.to_global(b), 1.2, false)
	_say("summit plateau reached at %s" % [player.global_position])
	await _shot("03-summit-top")
	_stage = "summit_artifact"
	var artifact: Node3D = summit.get_artifact()
	await _walk_to(summit.to_global(Vector3(-15.7, 8.2, -17.0)), 0.5, false)
	await _interact(artifact, "summit artifact", func() -> bool: return session.is_collected(&"summit_artifact"))
	_say("summit_artifact collected")
	await _shot("04-summit-artifact")
	_stage = "summit_lever"
	var lever_stand: Vector3 = summit.get_lever_position() + Vector3(0.9, 0.0, -1.7)
	await _walk_to(summit.to_global(Vector3(-14.5, 8.2, -15.0)), 1.0, false)
	await _walk_to(summit.to_global(lever_stand), 0.5, false)
	var lever := _find_interactable_near(summit.to_global(summit.get_lever_position() + Vector3(0.9, 0, 0)), 0.3)
	if lever == null:
		await _fail("lever interactable not found near the summit lever position")
	await _interact(lever, "bridge lever", func() -> bool: return summit.is_shortcut_open())
	await _wait(1.8)  # segments appear one by one (0.12 s each)
	_stage = "summit_descent"
	_say("descending the shortcut bridge into the main lane")
	_react = false  # the foot guard idles beside the bridge end; the bridge is out of its reach, fight it on open ground
	await _walk_to(summit.to_global(Vector3(-11.5, 8.2, -10.0)), 1.0, false)
	await _walk_to(summit.to_global(Vector3(-11.5, 0.0, 9.9)), 1.2, false)
	await _walk_to(summit.to_global(Vector3(-6.0, 0.0, 12.0)), 1.0, true)
	_react = true
	await _walk_to(summit.to_global(Vector3(1.5, 0.0, 6.0)), 1.0, true)
	await _shot("05-main-lane")
	await _walk_to(summit.to_global(Vector3(1.5, 0.0, -22.0)), 1.0, true)


func _stage_energy_puzzle() -> void:
	_stage = "energy_puzzle"
	var s_center: Vector3 = summit.global_position
	var e_center: Vector3 = energy.global_position
	# symbol exit -> road to the summit foot -> east along the foot -> energy road (arriving from the north)
	await _follow(_route_world(&"symbol_summit", false, symbol.global_position, 26.0, s_center, 36.0), 2.0, true)
	await _walk_to(summit.to_global(Vector3(-24, 0, 10.5)), 2.0, true)
	await _walk_to(summit.to_global(Vector3(0, 0, 10.5)), 2.0, true)
	await _walk_to(summit.to_global(Vector3(30, 0, 10.5)), 2.0, true)
	await _follow(_route_world(&"energy_summit", true, s_center, 36.0, e_center, 24.0), 2.0, true)
	await _walk_to(energy.to_global(Vector3(-6.5, 0, -12)), 1.5, true)
	await _walk_to(energy.to_global(Vector3(-6.5, 0, -4.5)), 1.0, false)
	await _walk_to(energy.to_global(Vector3(-3.5, 0, -2.5)), 0.8, false)
	var stands: Array[Vector3] = [Vector3(-2, 0, 0.6), Vector3(2, 0, 0.6), Vector3(3.6, 0, -2.0)]
	for panel in 3:
		await _walk_to(energy.to_global(stands[panel]), 0.5, false)
		var item: Node3D = energy.get_panel_interactable(panel)
		while true:
			var need := _presses_needed(panel)
			if need == 0:
				break
			_say("panel %d (%s): orientations=%s, %d more press(es)" % [panel + 1, energy.get_panel_kinds()[panel], energy.get_orientations(), need])
			var before: int = energy.get_orientations()[panel]
			await _interact(item, "rotate panel %d" % (panel + 1),
				func() -> bool: return energy.get_orientations()[panel] != before)
			var wait_frames := 0
			while energy.is_rotating() and wait_frames < 60:
				wait_frames += 1
				await _step()
	await _wait(0.5)
	if not energy.is_solved():
		await _fail("panels set per trace() but the energy puzzle is not solved; orientations=%s" % [energy.get_orientations()])
	_say("energy puzzle solved, orientations=%s" % [energy.get_orientations()])
	await _shot("06-energy-solved")
	await _wait(1.4)
	var artifact: Node3D = energy.get_artifact()
	await _walk_to(energy.to_global(Vector3(4.6, 0, -2.0)), 0.4, false)
	await _interact(artifact, "energy artifact", func() -> bool: return session.is_collected(&"energy_artifact"))
	_say("energy_artifact collected")
	await _shot("07-energy-artifact")
	# back out the way we came and over to the summit foot, then up the corridor between ledge and courtyard
	await _walk_to(energy.to_global(Vector3(3.6, 0, -2.0)), 0.8, false)
	await _walk_to(energy.to_global(Vector3(-3.5, 0, -2.5)), 1.0, false)
	await _walk_to(energy.to_global(Vector3(-6.5, 0, -4.5)), 1.0, false)
	await _walk_to(energy.to_global(Vector3(-6.5, 0, -12)), 1.2, true)
	var back := _route_world(&"energy_summit", false, e_center, 24.0, s_center, 36.0)
	await _follow(back, 2.0, true)
	await _walk_to(summit.to_global(Vector3(30, 0, 10.5)), 2.0, true)
	await _walk_to(summit.to_global(Vector3(0, 0, 10.5)), 2.0, true)
	await _walk_to(summit.to_global(Vector3(-19, 0, 10.5)), 1.5, true)


func _stage_boss() -> void:
	_stage = "boss_approach"
	await _walk_to(boss.to_global(Vector3(2.0, 0, 13.0)), 1.0, true)
	await _shot("08-arena-entrance")
	_stage = "boss_sockets"
	var consoles: Dictionary = boss.get_arena().consoles
	var sockets := [
		[&"forest_artifact", Vector3(-6.0, 0, 13.5)],
		[&"summit_artifact", Vector3(0.0, 0, 11.2)],
		[&"energy_artifact", Vector3(6.0, 0, 13.5)],
	]
	for entry in sockets:
		var id: StringName = entry[0]
		if not consoles.has(id):
			await _fail("arena has no socket console for %s" % id)
		await _walk_to(boss.to_global(entry[1]), 0.5, false)
		await _interact(consoles[id], "install " + String(id), func() -> bool: return not consoles[id].can_interact(player))
		_say("socket installed: %s" % id)
	await _shot("09-sockets-installed")
	_stage = "boss_fight"
	var won := false
	for attempt in _opt_attempts:
		_boss_attempts = attempt + 1
		await _boss_to_altar()
		var altar: Node3D = boss.get_arena().altar
		var rearmed: bool = boss.get_mode_name() == &"rearmed"
		await _interact(altar, "altar (%s)" % ("retry" if rearmed else "wake the Gatekeeper"),
			func() -> bool: return boss.is_active())
		await _shot("10-boss-wake-%d" % (attempt + 1))
		var result: String = await _boss_fight()
		_say("boss attempt %d result: %s" % [attempt + 1, result])
		if result == "won":
			won = true
			break
		_deaths += 1
		await _await_boss_rearm()
	if not won:
		await _fail("boss not defeated in %d attempt(s); boss hp=%d/%d" % [_opt_attempts, boss.get_boss_health().current_health, boss.get_boss_health().max_health])
	await _shot("11-boss-defeated")


func _stage_ending() -> void:
	_stage = "ending"
	_allow_death = false
	_say("boss defeated; waiting for the gate")
	var waited := 0
	while not _gate_opened:
		waited += 1
		if waited > 60 * 20:
			await _fail("gate never finished opening after the boss fell")
		await _step()
	await _shot("12-gate-open")
	await _walk_to(boss.to_global(Vector3(0, 0, -10.0)), 1.5, false)
	_expect_pause = true
	var dock := boss.to_global(Vector3(0, 0, -21.5))
	var frames := 0
	_expect_pause = false
	while not _completed:
		frames += 1
		if frames > 60 * 25:
			await _fail("dock trigger never fired (player %s, dock %s)" % [player.global_position, dock])
		var to := _flat(dock - player.global_position)
		if to.length() > 0.8:
			_drive(to, false)
		else:
			_stop()
		await _step()
	_stop()
	_expect_pause = true
	await _wait(1.5)
	var overlay: bool = presentation != null and bool(presentation.get("_completed"))
	await _shot("13-ending")
	if not overlay:
		await _fail("boss.completed fired but the presentation shows no completion screen")
	_say("ENDING reached: completion screen shown, tree paused=%s" % get_tree().paused)
	await _finish(true)


# ======================================================================================================================
# Boss fight
# ======================================================================================================================

func _boss_to_altar() -> void:
	# After a death the encounter puts the player at the retry point south of the entrance.
	var local := boss.to_local(player.global_position)
	if local.z > 14.0:
		await _walk_to(boss.to_global(Vector3(2.0, 0, 13.0)), 1.0, true)
	await _walk_to(boss.to_global(Vector3(2.2, 0, 8.0)), 0.8, false)
	await _walk_to(boss.to_global(Vector3(2.2, 0, 5.5)), 0.4, false)


func _await_boss_rearm() -> void:
	var waited := 0
	while not (boss.get_mode_name() == &"rearmed" and not player.is_dead() and not session.is_respawn_pending()):
		waited += 1
		if waited > 60 * 12:
			await _fail("after death the encounter never re-armed (mode=%s dead=%s)" % [boss.get_mode_name(), player.is_dead()])
		await _step()
	_stop()
	await _wait(0.5)


## Returns "won" or "died". Fails the run only on timeout.
func _boss_fight() -> String:
	_allow_death = true
	_b_act = &""
	_b_kind = &""
	_b_dodged = false
	_b_evade_dir = Vector3.ZERO
	var start := _now()
	var last_report := _now()
	var swings := 0
	_stop()
	while true:
		await _step()
		if boss.is_won():
			_stop()
			_allow_death = false
			return "won"
		if player.is_dead():
			_stop()
			_say("player died in the boss fight (boss hp=%d/%d)" % [boss.get_boss_health().current_health, boss.get_boss_health().max_health])
			return "died"
		if _now() - start > 240.0:
			await _fail("boss fight exceeded 240 s (boss hp=%d/%d, mode=%s, act=%s)" % [boss.get_boss_health().current_health, boss.get_boss_health().max_health, boss.get_mode_name(), boss.get_attack_state()])
		if _now() - last_report > 4.0:
			last_report = _now()
			_say("boss hp=%d/%d phase=%d act=%s/%s | player hp=%d stamina=%d potions=%d pos=%s" % [
				boss.get_boss_health().current_health, boss.get_boss_health().max_health, boss.phase, boss.get_attack_state(), boss.get_attack_kind(),
				player.get_health().current_health, int(player.stamina), player.potion_count, boss.to_local(player.global_position)])
		var mode: StringName = boss.get_mode_name()
		if mode != &"fighting":
			_stop()
			continue
		var act: StringName = boss.get_attack_state()
		var kind: StringName = boss.get_attack_kind()
		if act != _b_act or (act == &"windup" and kind != _b_kind):
			_b_act = act
			_b_kind = kind if kind != &"" else _b_kind
			_b_act_frame = Engine.get_physics_frames()
			if act == &"windup":
				_b_dodged = false
				_b_evade_dir = Vector3.ZERO
		if act == &"windup" or act == &"active":
			_boss_defend(act, kind)
		else:
			_set_action(&"block", false)
			_boss_engage(act)
	return "died"


func _boss_defend(act: StringName, kind: StringName) -> void:
	var tele: Node = boss.get_telegraph()
	var bpos: Vector3 = boss.get_boss().global_position
	var ppos: Vector3 = player.global_position
	var cfg: Dictionary = ENC.ATTACKS[kind] if ENC.ATTACKS.has(kind) else {}
	var exact: bool = tele.contains_circle(ppos)
	var t_hit := _boss_time_to_hit(act, kind, cfg, bpos, ppos)
	var danger: bool = tele.contains_circle(ppos, PLAYER_RADIUS + 0.7)
	var can_dodge: bool = player.stamina >= 25.0 and not player.is_dodging() and not _b_dodged
	if exact and t_hit <= 0.1 and can_dodge:
		_b_dodged = true
		_pulse(&"dodge")
	_set_action(&"block", exact and t_hit <= 0.14 and not can_dodge and not player.is_dodging())
	if not danger:
		_stop()
		return
	# Nearest free spot outside the telegraph (grows ring by ring), keeping the previous heading when several tie.
	var away := _flat(ppos - bpos).normalized()
	var chosen := Vector3.ZERO
	for r in [2.0, 3.0, 4.0, 5.0, 6.5, 8.0, 10.0]:
		var best := -1.0e9
		for i in 16:
			var ang := TAU * float(i) / 16.0
			var dir := Vector3(sin(ang), 0.0, cos(ang))
			var cand: Vector3 = ppos + dir * r
			if tele.contains_circle(cand, PLAYER_RADIUS + 0.7) or not _arena_ok(cand) or not _clear_line(ppos, cand):
				continue
			var score := dir.dot(_b_evade_dir) * 0.6 + dir.dot(away) * 0.2
			if score > best:
				best = score
				chosen = dir
		if chosen != Vector3.ZERO:
			break
	if chosen == Vector3.ZERO:
		_stop()
		return
	_b_evade_dir = chosen
	_drive(chosen, true)


func _boss_time_to_hit(act: StringName, kind: StringName, cfg: Dictionary, bpos: Vector3, ppos: Vector3) -> float:
	if cfg.is_empty():
		return 9.9
	var elapsed := float(Engine.get_physics_frames() - _b_act_frame) / float(Engine.physics_ticks_per_second)
	var hit_delay := float(cfg["hit_at"]) * float(cfg["active"])
	if kind == &"charge":
		var forward: Vector3 = boss.get_boss().global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var ahead := _flat(ppos - bpos).dot(forward)
		var run := maxf(0.0, ahead - float(cfg["front"])) / float(cfg["speed"])
		return (float(cfg["windup"]) - elapsed + run) if act == &"windup" else run
	return (float(cfg["windup"]) - elapsed + hit_delay) if act == &"windup" else maxf(0.0, hit_delay - elapsed)


func _boss_engage(act: StringName) -> void:
	var bpos: Vector3 = boss.get_boss().global_position
	var ppos: Vector3 = player.global_position
	var to := _flat(bpos - ppos)
	var d := to.length()
	# Potion only at the start of a long recovery window (the boss cannot start a new telegraph before it ends).
	var elapsed := float(Engine.get_physics_frames() - _b_act_frame) / float(Engine.physics_ticks_per_second)
	if player.is_drinking():
		_stop()
		return
	if player.get_health().current_health <= 50 and player.potion_count > 0 and act == &"recovery" and _b_kind != &"":
		var cfg: Dictionary = ENC.ATTACKS[_b_kind]
		var pause := 0.6 if boss.phase == 2 else 0.85
		if float(cfg["recovery"]) + pause - elapsed >= 1.8 and d > 3.0:
			_stop()
			_pulse(&"potion")
			return
	var facing_err := absf(angle_difference(player.rotation.y, atan2(to.x, to.z)))
	if d > 2.7:
		_drive(to, d > 6.0)
	elif facing_err > 0.35:
		_drive(to, false)
	else:
		_stop()
		_swing()


# ======================================================================================================================
# Ordinary enemies
# ======================================================================================================================

func _threat() -> Node3D:
	var best: Node3D = null
	var best_d := 1.0e9
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var state: StringName = enemy.get_state_name()
		if state == &"idle" or state == &"return":
			continue
		var rise := player.global_position.y - enemy.global_position.y
		if rise > 0.3 or rise < -2.5:
			continue  # we are on a ledge/bridge above it (or far below): keep walking, fight at the bottom
		var d := _flat(enemy.global_position - player.global_position).length()
		if d < 18.0 and d < best_d:
			best_d = d
			best = enemy
	return best


## Kites a melee enemy: back off while it winds up, rush in and swing while it recovers. Ranged enemies are rushed.
func _fight(enemy: Node3D) -> void:
	var label := "%s(%s)" % [enemy.name, enemy.archetype]
	var cfg: Dictionary = enemy.cfg
	var ranged: bool = enemy.archetype == "ranged"
	var start := _now()
	var last_hp: int = player.get_health().current_health
	_say("fight begins: %s at %s, my hp=%d" % [label, enemy.global_position, last_hp])
	while not enemy.is_dead():
		if player.global_position.y - enemy.global_position.y > 0.4:
			break
		if _now() - start > 90.0:
			await _fail("fight with %s lasted over 90 s (enemy hp=%d)" % [label, enemy.get_node("Health").current_health])
		var to := _flat(enemy.global_position - player.global_position)
		var d := to.length()
		var state: StringName = enemy.get_state_name()
		var hp: int = player.get_health().current_health
		if player.is_drinking():
			_stop()
			await _step()
			continue
		if hp <= 40 and player.potion_count > 0:
			if d > 8.0 or state == &"idle":
				_stop()
				_pulse(&"potion")
			else:
				_drive(-to, true)
			await _step()
			continue
		if int(_now() * 2.0) % 6 == 0 and Engine.get_physics_frames() % 30 == 0:
			_say("  %s state=%s d=%.2f dy=%.2f face_err=%.2f attacking=%s enemy_hp=%d" % [label, state, d, enemy.global_position.y - player.global_position.y, absf(angle_difference(player.rotation.y, atan2(to.x, to.z))), player.is_attacking(), enemy.get_node("Health").current_health])
		var winding := state == &"windup" or state == &"active"
		var reach := float(cfg.get("hit_length", 2.0)) + 0.9
		if winding and not ranged and d < reach:
			_drive(-to, true)
		elif d > 2.0:
			_drive(to, d > 5.0)
		elif absf(angle_difference(player.rotation.y, atan2(to.x, to.z))) > 0.3:
			_drive(to, false)
		else:
			_stop()
			_swing()
		await _step()
	_stop()
	_kills += 1
	_say("fight won: %s, my hp=%d" % [label, player.get_health().current_health])
	await _wait(0.4)


# ======================================================================================================================
# Movement and interaction primitives
# ======================================================================================================================

## Walk (camera-relative W after turning the camera with the mouse) to a world point; fights hostile enemies on the way.
func _walk_to(target: Vector3, tol: float, sprint: bool, timeout := 0.0, jump_when := Callable()) -> void:
	var start := _now()
	var best := 1.0e9
	var best_time := start
	var jumped := false
	var limit := timeout if timeout > 0.0 else _flat(target - player.global_position).length() / 4.5 + 14.0
	while true:
		var delta := _flat(target - player.global_position)
		var dist := delta.length()
		if dist <= tol:
			break
		var now := _now()
		if now - start > limit:
			_stop()
			await _fail("timed out walking to %s (%.1f m left)" % [target, dist])
		if dist < best - 0.4:
			best = dist
			best_time = now
		elif now - best_time > 4.0:
			_stop()
			await _fail("stuck %.1f m from %s (no progress for 4 s)" % [dist, target])
		var threat := _threat() if _react else null
		if threat != null:
			_stop()
			await _fight(threat)
			best = 1.0e9
			best_time = _now()
			continue
		if jump_when.is_valid() and not jumped and player.is_on_floor() and jump_when.call():
			jumped = true
			_pulse(&"jump")
		_drive(delta, sprint and not jumped)
		await _step()
	_stop()


func _follow(points: Array[Vector3], tol: float, sprint: bool) -> void:
	for point in points:
		await _walk_to(point, tol, sprint)


## Terrain route in world space. Reversed on request; drops the points within `cut_from` of the origin-end centre and
## within `cut_to` of the destination centre so the caller can hand over to precise module waypoints.
func _route_world(route: StringName, reverse: bool, from_center: Vector3, cut_from: float, to_center := Vector3.INF, cut_to := 0.0) -> Array[Vector3]:
	var raw: PackedVector3Array = terrain.get_route_points(route)
	var list: Array[Vector3] = []
	for p in raw:
		list.append(terrain.to_global(p))
	if reverse:
		list.reverse()
	var out: Array[Vector3] = []
	for p in list:
		if _flat(p - from_center).length() < cut_from:
			continue
		if to_center != Vector3.INF and _flat(p - to_center).length() < cut_to:
			continue
		out.append(p)
	if out.is_empty():
		_say("route %s: nothing left after cuts" % route)
	return out


func _ring_path(from_corner: int, to_corner: int) -> Array[int]:
	var out: Array[int] = []
	var forward := (to_corner - from_corner + 4) % 4
	var step := 1 if forward <= 2 else -1
	var at := from_corner
	while at != to_corner:
		at = (at + step + 4) % 4
		out.append(at)
	return out


## Minimal presses (E turns a panel one quarter clockwise) to reach any solving orientation of this panel, given the
## other panels' CURRENT orientations; read from the module's own trace(), never written.
func _presses_needed(panel: int) -> int:
	var current: Array = energy.get_orientations()
	var best := 99
	for a in 4:
		for b in 4:
			for c in 4:
				var combo := [a, b, c]
				if energy.trace(combo)["solved"]:
					var cost := 0
					for i in 3:
						cost += (combo[i] - current[i] + 4) % 4
					if cost < best:
						best = cost
						_target_orient = combo
	if best == 99:
		return 0
	return (int(_target_orient[panel]) - int(current[panel]) + 4) % 4


var _target_orient: Array = [0, 0, 0]


func _interact(node: Node3D, label: String, done: Callable) -> void:
	for attempt in 4:
		var waited := 0
		while interactor.get_target() != node and waited < 40:
			waited += 1
			await _step()
		if interactor.get_target() == node:
			break
		if attempt == 3:
			var other: Object = interactor.get_target()
			await _fail("interact '%s': interactor target is %s, wanted %s (player=%s, node=%s, can_interact=%s)" % [
				label, other.name if other != null else "none", node.name, player.global_position, node.global_position, player.can_interact()])
		# a little closer (range/line-of-sight), still by walking
		for i in 14:
			_drive(_flat(node.global_position - player.global_position), false)
			await _step()
		_stop()
	var prompt: String = interactor.get_prompt()
	_pulse(&"interact")
	_say("E: %s  ['%s']" % [label, prompt])
	var frames := 0
	while not done.call():
		frames += 1
		if frames > 150:
			await _fail("interact '%s' had no effect after E (prompt '%s')" % [label, prompt])
		await _step()


func _find_pickup(id: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.get("pickup_id") == id:
			return node as Node3D
	return null


func _find_interactable_near(point: Vector3, radius: float) -> Node3D:
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var item := node as Node3D
		if item != null and _flat(item.global_position - point).length() <= radius:
			return item
	return null


# ======================================================================================================================
# Raw input (everything goes through Input.parse_input_event with the project's own action events)
# ======================================================================================================================

func _viewport_center() -> Vector2:
	return get_tree().root.get_visible_rect().size * 0.5


func _action_event(action: StringName, pressed: bool) -> InputEvent:
	var source: InputEvent = InputMap.action_get_events(action)[0]
	var event: InputEvent = source.duplicate()
	if event is InputEventKey:
		(event as InputEventKey).pressed = pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		mb.pressed = pressed
		mb.position = _viewport_center()
		mb.global_position = mb.position
		mb.button_mask = (1 << (mb.button_index - 1)) if pressed else 0
	return event


func _set_action(action: StringName, pressed: bool) -> void:
	if bool(_held.get(action, false)) == pressed:
		return
	_held[action] = pressed
	Input.parse_input_event(_action_event(action, pressed))


## One press edge now, release after `frames` physics frames.
func _pulse(action: StringName, frames := 2) -> void:
	for entry in _pending:
		if entry[2] == action:
			return
	Input.parse_input_event(_action_event(action, true))
	_pending.append([frames, _action_event(action, false), action])


func _swing() -> void:
	# One fresh press per 4 physics frames: a swing lasts 12 frames, presses inside the combo gate chain the combo,
	# earlier presses are dropped by the game (no buffering), exactly as clicking fast would.
	if Engine.get_physics_frames() % 4 == 0:
		_pulse(&"attack", 2)


func _mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	event.position = _viewport_center()
	event.global_position = event.position
	Input.parse_input_event(event)


## Turn the camera with real mouse motion until its yaw equals `yaw` (mouse right = yaw decreases).
func _aim_yaw(yaw: float) -> void:
	var diff := angle_difference(float(camera.get_yaw()), yaw)
	if absf(diff) < 0.002:
		return
	_mouse_motion(Vector2(-diff / float(camera.mouse_sensitivity), 0.0))


## Face the camera along `heading` and hold W (character turns by itself while moving). Optional Shift sprint.
func _drive(heading: Vector3, sprint: bool) -> void:
	var flat := _flat(heading)
	if flat.length() < 0.01:
		_stop()
		return
	_aim_yaw(atan2(-flat.x, -flat.z))
	_set_action(&"move_forward", true)
	_set_action(&"move_backward", false)
	_set_action(&"move_left", false)
	_set_action(&"move_right", false)
	_set_action(&"sprint", sprint)


func _stop() -> void:
	for action in [&"move_forward", &"move_backward", &"move_left", &"move_right", &"sprint"]:
		_set_action(action, false)


func _release_all() -> void:
	for action in _held.keys():
		_set_action(action, false)
	for entry in _pending:
		Input.parse_input_event(entry[1])
	_pending.clear()


func _arena_ok(point: Vector3) -> bool:
	var local := boss.to_local(point)
	return absf(local.x) <= BOSS_ARENA_X and local.z >= BOSS_ARENA_Z_MIN and local.z <= BOSS_ARENA_Z_MAX


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.6, b + Vector3.UP * 0.6, 1)
	query.exclude = [player.get_rid(), (boss.get_boss() as CollisionObject3D).get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ======================================================================================================================
# Frame stepping, bookkeeping, reporting
# ======================================================================================================================

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _now() -> float:
	return float(Engine.get_physics_frames() - _start_frame) / float(Engine.physics_ticks_per_second)


func _wait(seconds: float) -> void:
	var frames := int(ceil(seconds * Engine.physics_ticks_per_second))
	for i in frames:
		await _step()


func _step() -> void:
	await get_tree().physics_frame
	var keep: Array = []
	for entry in _pending:
		entry[0] -= 1
		if entry[0] <= 0:
			Input.parse_input_event(entry[1])
		else:
			keep.append(entry)
	_pending = keep
	if _now() > SIM_LIMIT:
		await _fail("simulation time limit %d s exceeded" % int(SIM_LIMIT))
	if get_tree().paused and not _expect_pause:
		_paused_frames += 1
		if _paused_frames > 20 and _paused_frames % 30 == 0:
			if _esc_sent >= 3:
				await _fail("SceneTree is paused (window lost focus?). Keep the window in the foreground or run --headless")
			_esc_sent += 1
			_say("tree paused; pressing Esc like a player to resume (%d/3)" % _esc_sent)
			var esc := InputEventKey.new()
			esc.physical_keycode = KEY_ESCAPE
			esc.keycode = KEY_ESCAPE
			esc.pressed = true
			Input.parse_input_event(esc)
			esc = esc.duplicate()
			esc.pressed = false
			_pending.append([2, esc, &"_esc"])
	else:
		_paused_frames = 0
	if not _allow_death and player != null and player.is_dead():
		await _fail("player died (hp 0)")


func _say(text: String) -> void:
	var line := "[%7.1fs %-15s] %s" % [_now(), _stage, text]
	print(line)
	_log.append(line)


func _shot(label: String) -> void:
	if not _opt_shots or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := ProjectSettings.globalize_path(OUT_DIR + "%s.png" % label)
	image.save_png(path)
	_say("screenshot %s" % path)


func _fail(reason: String) -> void:
	_release_all()
	var where := player.global_position if player != null else Vector3.ZERO
	var hp: Variant = player.get_health().current_health if player != null and player.get_health() != null else "?"
	_say("FAIL stage=%s pos=%s hp=%s reason=%s" % [_stage, where, hp, reason])
	await _finish(false)


func _finish(ok: bool) -> void:
	_release_all()
	var summary := "RESULT %s | sim %.1f s | kills=%d boss_attempts=%d deaths=%d | artifacts=%d | %s" % [
		"PASS" if ok else "FAIL", _now(), _kills, _boss_attempts, _deaths,
		session.count_kind(&"artifact") if session != null else -1,
		session.get_status() if session != null else ""]
	_say(summary)
	var file := FileAccess.open(OUT_DIR + "run.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	# Clean shutdown so the exit report lists only real leaks: stop audio, free the game, let the audio server drop
	# finished playbacks (~0.5 s real time), then quit. The runner moves to the root first because it may live under the game.
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root, false)
	tree.paused = false
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for node in tree.root.find_children("*", kind, true, false):
			node.stop()
	for child in tree.root.get_children():
		if child != self:
			child.queue_free()
	for i in 10:
		await tree.physics_frame
	OS.delay_msec(500)
	for i in 10:
		await tree.physics_frame
	tree.quit(0 if ok else 1)
	while true:
		await tree.physics_frame
