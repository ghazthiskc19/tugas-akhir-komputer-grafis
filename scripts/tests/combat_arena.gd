extends "res://scripts/tests/adventure_lab.gd"
## Playtest arena for combat feel. Real Player, camera, enemies and Gatekeeper with the island's own rules.
## Not the island: stages are reset on demand so the same fight can be replayed and compared.
## 1 Duel (standard) | 2 Heavy + Ranged | 3 Campuran | 4 Gatekeeper | F5 restart current stage.
## Run: C:/Godot/godot.exe --path . res://scenes/tests/combat_arena.tscn

const BOSS_SCENE := preload("res://scenes/boss/gatekeeper_encounter.tscn")
const START_POTIONS := 3
const FIELD_START := Vector3(0, 0, 14)
const BOSS_ORIGIN := Vector3(0, 0, -70)
const STAGE_NAMES := {1: "1 · Duel melee", 2: "2 · Heavy + Ranged", 3: "3 · Campuran", 4: "4 · Gatekeeper"}
const STAGE_HINTS := {
	1: "Satu musuh biasa. Target: baca combo dua pukulan, balas di celah setelah serangan kedua.",
	2: "Heavy menekan jarak dekat, ranged menembak tiga kali. Pakai cover atau buru ranged dulu.",
	3: "Dua standar + heavy + ranged sekaligus. Jangan biarkan semuanya menyerang bersamaan.",
	4: "Taruh artefak sudah terpasang. Tekan E di altar untuk membangunkan Penjaga Gerbang.",
}

var _stage := 0
var _boss: Node3D
var _alive := 0
var _cleared := false
var _stage_time := 0.0
var _timer_running := false
var _hits := 0
var _blocked := 0
var _damage_taken := 0
var _potions_used := 0
var _deaths := 0
var _stage_label: Label
var _hint_label: Label
var _result_label: Label
var _boss_label: Label


func _ready() -> void:
	for path in ["World", "DummyNear", "DummyFar", "HUD"]:
		get_node(path).free()
	_build_world()
	_build_hud()
	_build_session()
	player.damage_taken.connect(_on_damage_taken)
	player.potion_drunk.connect(func(_healed: int) -> void: _potions_used += 1)
	player.died.connect(func() -> void: _deaths += 1)
	session.respawned.connect(_on_respawned)
	_start_stage.call_deferred(1)


func _build_world() -> void:
	super._build_world()
	var world: Node3D = get_node("World")
	_world_label(world, "SPAWN (stage 1-3)", Vector3(0, 0.04, 16))
	_world_label(world, "Stage 4: tekan 4 untuk pindah ke arena Gatekeeper", Vector3(0, 0.04, -19))


func _build_session() -> void:
	session = SESSION_SCRIPT.new()
	session.name = "Session"
	session.player_path = NodePath("../Player")
	add_child(session)
	session.initialize(player)
	interactor = INTERACTOR_SCRIPT.new()
	interactor.name = "Interactor"
	interactor.player_path = NodePath("../Player")
	add_child(interactor)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	_stage_label = _label(hud, "", Vector2(24, 18), 25)
	hp_bar = _bar(hud, Vector2(24, 58), Color("930031"))
	stamina_bar = _bar(hud, Vector2(24, 88), Color("607938"))
	resource_label = _label(hud, "", Vector2(24, 120), 19)
	status_label = _label(hud, "", Vector2(24, 149), 18)
	_label(hud, "LMB: combo • RMB: block • Shift: lari • Alt: dodge • Q: potion • E: interaksi • Space: lompat • Esc: jeda", Vector2(24, 180), 18)
	_label(hud, "1-4: pilih stage • F5: ulang stage (HP/stamina/potion dipulihkan)", Vector2(24, 207), 18)
	_hint_label = _label(hud, "", Vector2(24, 240), 18)
	progress_label = _label(hud, "", Vector2(24, 268), 18)
	_result_label = _label(hud, "", Vector2(24, 330), 22)
	_boss_label = _label(hud, "", Vector2(24, 300), 20)
	prompt_label = _label(hud, "", Vector2(24, 660), 22)


func _process(_delta: float) -> void:
	var health = player.get_node("Health")
	hp_bar.max_value = health.max_health
	hp_bar.value = health.current_health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	resource_label.text = "HP %d/%d • Stamina %d/%d • Potion %d/%d" % [health.current_health, health.max_health, int(player.stamina), int(player.max_stamina), player.potion_count, player.max_potions]
	status_label.text = "Aksi: %s" % player.get_action_state()
	_stage_label.text = "COMBAT ARENA — %s" % STAGE_NAMES.get(_stage, "")
	_hint_label.text = STAGE_HINTS.get(_stage, "")
	progress_label.text = "Waktu %.1f s • Kena %d (blok %d) • Damage diterima %d • Potion dipakai %d • Mati %d" % [_stage_time, _hits, _blocked, _damage_taken, _potions_used, _deaths]
	prompt_label.text = interactor.get_prompt()
	_boss_label.text = ""
	if _boss != null and is_instance_valid(_boss):
		var state: Dictionary = _boss.get_hud_state()
		_boss_label.text = "BOSS HP %d/%d • fase %d • %s" % [state["hp"], state["max_hp"], state["phase"], state["state"]]
		if _boss.is_active():
			_timer_running = true
	if not _cleared:
		_result_label.text = ""


func _physics_process(delta: float) -> void:
	if _timer_running and not _cleared:
		_stage_time += delta


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or get_tree().paused:
		return
	var target := 0
	match key.keycode:
		KEY_1: target = 1
		KEY_2: target = 2
		KEY_3: target = 3
		KEY_4: target = 4
		KEY_F5: target = _stage
		_: return
	get_viewport().set_input_as_handled()
	if _reload_pending:
		return
	_reload_pending = true
	_start_stage.call_deferred(target)


func _start_stage(n: int) -> void:
	_reload_pending = false
	_stage = n
	_clear_stage()
	_cleared = false
	_stage_time = 0.0
	_hits = 0
	_blocked = 0
	_damage_taken = 0
	_potions_used = 0
	_deaths = 0
	_timer_running = false
	var spot := FIELD_START
	if n == 4:
		_build_boss()
		spot = _boss.to_global(Vector3(-10.0, 0.1, 12.5))
	else:
		_build_enemies_for(n)
	player.global_position = spot
	session.checkpoint_transform = Transform3D(Basis(), spot)
	player.restore_for_respawn()
	player.potion_count = START_POTIONS
	player.resources_changed.emit()
	var health = player.get_node("Health")
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	session.status_changed.emit()


func _clear_stage() -> void:
	session.clear_registrations()
	session.killed_enemy_ids.clear()
	session.puzzle_progress.clear()
	for node_name in ["Enemies", "Boss"]:
		var old := get_node_or_null(node_name)
		if old != null:
			remove_child(old)
			old.queue_free()
	_boss = null
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		projectile.get_parent().remove_child(projectile)
		projectile.free()


func _build_enemies_for(n: int) -> void:
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	var layout: Array = []
	match n:
		1:
			layout = [[STANDARD, Vector3(0, 0, -6)]]
		2:
			layout = [[HEAVY, Vector3(-10, 0, -12)], [RANGED, Vector3(11, 0, -14)]]
		3:
			layout = [[STANDARD, Vector3(-6, 0, -8)], [STANDARD, Vector3(6, 0, -8)], [HEAVY, Vector3(0, 0, -16)], [RANGED, Vector3(13, 0, -12)]]
	_alive = layout.size()
	for i in layout.size():
		var enemy = (layout[i][0] as PackedScene).instantiate()
		enemy.name = "Enemy%d" % i
		enemy.position = layout[i][1]
		enemy.enemy_id = StringName("combat_arena_%d_%d" % [n, i])
		enemy.player_path = NodePath("../../Player")
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.add_child(enemy)
		session.register_enemy(enemy)
	_timer_running = true


func _build_boss() -> void:
	_boss = BOSS_SCENE.instantiate()
	_boss.name = "Boss"
	_boss.position = BOSS_ORIGIN
	add_child(_boss)
	_boss.setup(player, session)
	_boss.encounter_won.connect(_on_boss_won)
	var arena: Node = _boss.get_arena()
	for id: StringName in [&"forest_artifact", &"energy_artifact", &"summit_artifact"]:
		session.claim(id, &"artifact")
		_boss.use_console(arena.consoles[id], player)


func _on_enemy_defeated(_id: StringName) -> void:
	_alive -= 1
	if _alive <= 0 and _stage != 4:
		_finish("STAGE SELESAI")


func _on_boss_won() -> void:
	_finish("GATEKEEPER KALAH")


func _finish(title: String) -> void:
	_cleared = true
	_timer_running = false
	_result_label.text = "%s — %.1f s • kena %d kali • damage diterima %d • potion %d • mati %d. Tekan 1-4 atau F5." % [title, _stage_time, _hits, _damage_taken, _potions_used, _deaths]


func _on_damage_taken(amount: int, blocked: bool) -> void:
	if _cleared:
		return
	if blocked:
		_blocked += 1
	else:
		_hits += 1
	_damage_taken += amount


func _on_respawned() -> void:
	# Fields restart the whole encounter. The Gatekeeper owns its own retry (exact snapshot), so it is left alone.
	if _stage != 4 and not _reload_pending:
		_reload_pending = true
		_start_stage.call_deferred(_stage)
