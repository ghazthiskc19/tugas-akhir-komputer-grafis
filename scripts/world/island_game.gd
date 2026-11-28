extends Node3D
## One run owns one island, one session and stable objective IDs. Death never regenerates terrain.
const TERRAIN = preload("res://scripts/world/island_terrain.gd")
const SESSION = preload("res://scripts/world/session_progress.gd")
const INTERACTOR = preload("res://scripts/interaction/interactor.gd")
const PRESENTATION = preload("res://scripts/ui/island_presentation.gd")
const SYMBOL = preload("res://scenes/objectives/symbol_pillars.tscn")
const ENERGY = preload("res://scenes/objectives/energy_path.tscn")
const SUMMIT = preload("res://scenes/objectives/summit_route.tscn")
const BOSS = preload("res://scenes/boss/gatekeeper_encounter.tscn")
const CHECKPOINT = preload("res://scenes/world/checkpoint.tscn")
const POTION = preload("res://scenes/world/potion_pickup.tscn")
const STANDARD = preload("res://scenes/enemies/standard_melee.tscn")
const HEAVY = preload("res://scenes/enemies/heavy_melee.tscn")
const RANGED = preload("res://scenes/enemies/ranged_enemy.tscn")
const QA_RUNNER := "res://scripts/tests/island_playthrough.gd"
const SAVE = preload("res://scripts/world/island_save.gd")
const LANDMARKS = preload("res://scripts/world/island_landmarks.gd")
const ATMOSPHERE = preload("res://scripts/world/island_atmosphere.gd")
const UI_THEME = preload("res://scripts/ui/ui_theme.gd")
const PASSAGE = preload("res://scripts/world/central_passage.gd")

@export var island_seed: int = 42
@export var procedural: bool = true
@export var start_in_menu: bool = true
var session: Node
var interactor: Node
var terrain: Node3D
var boss: Node3D
var presentation: CanvasLayer
var objectives: Node3D
var passage: Node3D
var pending_save: Dictionary = {}
var _run_active := false
var _replacing := false
var _qa_mode := false
var _save_elapsed := 0.0
var _save_dirty := false
var _shutting_down := false
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var args := OS.get_cmdline_user_args()
	var qa_playthrough := args.has("--qa-playthrough")
	_qa_mode = qa_playthrough or args.has("--qa-no-save")
	for argument in args:
		if argument.begins_with("--seed="):
			island_seed = argument.trim_prefix("--seed=").to_int()
	if qa_playthrough:
		start_in_menu = false
	if not pending_save.is_empty():
		island_seed = int(pending_save["island_seed"])
		procedural = bool(pending_save["procedural"])
	for path in ["World", "DummyNear", "DummyFar", "HUD"]:
		var old := get_node_or_null(path)
		if old != null:
			old.free()
	terrain = TERRAIN.new()
	terrain.name = "World"
	terrain.configure(island_seed, procedural)
	add_child(terrain)
	player.position = get_world_anchor(&"spawn") + Vector3(0, 0.1, 0)
	session = SESSION.new()
	session.name = "Session"
	session.player_path = NodePath("../Player")
	add_child(session)
	if not pending_save.is_empty() and not session.import_state(pending_save["session"]):
		pending_save.clear()
	session.initialize(player)
	interactor = INTERACTOR.new()
	interactor.name = "Interactor"
	interactor.player_path = NodePath("../Player")
	add_child(interactor)
	objectives = Node3D.new()
	objectives.name = "Objectives"
	add_child(objectives)
	_add_objective(SYMBOL, "SymbolPillars", get_world_anchor(&"symbol"))
	_add_objective(ENERGY, "EnergyPath", get_world_anchor(&"energy"))
	_add_objective(SUMMIT, "SummitRoute", get_world_anchor(&"summit"))
	boss = BOSS.instantiate()
	boss.name = "BossEncounter"
	boss.position = get_world_anchor(&"boss")
	add_child(boss)
	boss.setup(player, session)
	var camp = CHECKPOINT.instantiate()
	camp.name = "CampCheckpoint"
	camp.checkpoint_id = &"camp"
	camp.position = terrain.layout["camp"]
	terrain.add_child(camp)
	for config: Dictionary in terrain.layout["potions"]:
		var potion = POTION.instantiate()
		potion.pickup_id = config["id"]
		potion.position = config["position"]
		terrain.add_child(potion)
	_build_encounters()
	passage = PASSAGE.new()
	passage.name = "CentralPassage"
	add_child(passage)
	passage.build(terrain, session, island_seed)
	var landmarks := LANDMARKS.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.build(terrain)
	var atmosphere := ATMOSPHERE.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.build(self, terrain)
	if not pending_save.is_empty():
		_restore_saved_player()
	presentation = PRESENTATION.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.setup(self, player, session, interactor, boss)
	presentation.set_run_options(island_seed, procedural)
	presentation.new_run_requested.connect(_new_run)
	boss.encounter_started.connect(func(): save_run())
	boss.encounter_won.connect(func(): save_run())
	boss.completed.connect(func(): save_run())
	boss.completed.connect(presentation.show_completion)
	session.status_changed.connect(_mark_save_dirty)
	player.potion_drunk.connect(func(_healed: int): _mark_save_dirty())
	if start_in_menu:
		presentation.show_menu()
	else:
		presentation.begin_play(false)
	if qa_playthrough:
		var runner: Node = (load(QA_RUNNER) as GDScript).new()
		runner.name = "QaPlaythrough"
		add_child(runner)
		runner.attach.call_deferred(self, OS.get_cmdline_user_args())

func _add_objective(scene: PackedScene, title: String, location: Vector3) -> void:
	var module := scene.instantiate() as Node3D
	module.name = title
	module.position = location
	objectives.add_child(module)
	module.setup(player, session)

func _build_encounters() -> void:
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	# Three mixed packs: introductory melee pressure, then ranged support and a heavy anchor.
	# Keep tuning local to the island; labs retain their baseline archetype contracts.
	var scenes := {"standard": STANDARD, "heavy": HEAVY, "ranged": RANGED}
	var tuning := {
		"standard": {"move_speed": 4.4, "damage": 26, "detect_range": 14.0,
			"windup": 0.5, "recovery": 0.45, "cooldown": 0.45, "walk_anim_speed": 1.7},
		"heavy": {"move_speed": 3.1, "damage": 42, "detect_range": 14.0,
			"windup": 0.9, "recovery": 0.85, "cooldown": 0.7, "walk_anim_speed": 1.2},
		"ranged": {"move_speed": 3.6, "damage": 22,
			"windup": 0.7, "recovery": 0.5, "cooldown": 0.85, "walk_anim_speed": 1.5},
	}
	for config: Dictionary in terrain.layout["encounters"]:
		var kind: String = config["archetype"]
		var enemy = (scenes[kind] as PackedScene).instantiate()
		enemy.enemy_id = config["id"]
		enemy.position = config["position"]
		enemy.player_path = NodePath("../../Player")
		enemy.overrides = tuning[kind].duplicate()
		enemies.add_child(enemy)
		session.register_enemy(enemy)


func _new_run(seed_value: int, use_procedural: bool) -> void:
	# Deferred replacement avoids freeing a GUI callback or leaving old paused-tree nodes alive.
	_replace_run.call_deferred(seed_value, use_procedural)

func _replace_run(seed_value: int, use_procedural: bool, saved: Dictionary = {}) -> void:
	if _replacing or _shutting_down:
		return
	_replacing = true
	var tree := get_tree()
	# Stay paused while fading to black (the fade layer runs in PROCESS_MODE_ALWAYS and eats clicks).
	await UI_THEME.fade_out(tree)
	if _shutting_down:
		return
	tree.paused = false
	var next := (load("res://scenes/world/island_game.tscn") as PackedScene).instantiate()
	next.island_seed = seed_value
	next.procedural = use_procedural
	next.start_in_menu = false
	next.pending_save = saved
	var root := tree.root
	root.remove_child(self)
	root.add_child(next)
	next.get_tree().current_scene = next
	queue_free()
	# Not awaited: this node is freed, the static fade helper outlives it. Waits two frames so the new island is
	# rendered before the black lifts.
	UI_THEME.fade_in(tree, UI_THEME.FADE_IN_TIME, 2)

func get_world_anchor(id: StringName) -> Vector3:
	return terrain.layout["anchors"][id]

func has_saved_run() -> bool:
	return SAVE.has_save()

func continue_saved_run() -> void:
	var saved: Dictionary = SAVE.read_save()
	if not saved.is_empty():
		_replace_run.call_deferred(int(saved["island_seed"]), bool(saved["procedural"]), saved)

func begin_run() -> void:
	_run_active = true
	_mark_save_dirty()

func _mark_save_dirty() -> void:
	_save_dirty = true

func _process(delta: float) -> void:
	if not _run_active or _qa_mode:
		return
	_save_elapsed += delta
	if _save_elapsed >= 5.0 or (_save_dirty and _save_elapsed >= 0.5):
		_save_elapsed = 0.0
		# Periodic resource persistence also catches damage without writing every stamina tick.
		save_run()

func save_run() -> bool:
	if not _run_active or _qa_mode or session == null:
		return false
	# Death is an in-flight transaction. Persist only after checkpoint/boss respawn resolves.
	if player.is_dead() or session.is_respawn_pending():
		return false
	var data := {
		"version": 1, "island_seed": island_seed, "procedural": procedural,
		"session": session.export_state(),
		"player": {"hp": player.get_node("Health").current_health,
			"stamina": player.stamina, "potions": player.potion_count},
	}
	var result: Error = SAVE.write_save(data)
	_save_dirty = result != OK
	return result == OK

func _restore_saved_player() -> void:
	player.restore_for_respawn()
	player.global_transform = session.checkpoint_transform
	var resources: Dictionary = pending_save["player"]
	var progress: Dictionary = session.puzzle_progress
	if progress.get(&"gatekeeper_started", false) and not progress.get(&"gatekeeper_defeated", false):
		resources = boss.get_snapshot()
		player.global_position = boss.to_global(Vector3(0, 0.1, 13.5))
	var health := player.get_node("Health")
	health.current_health = clampi(int(resources["hp"]), 1, player.max_hp)
	player.stamina = clampf(float(resources["stamina"]), 0.0, player.max_stamina)
	player.potion_count = clampi(int(resources["potions"]), 0, player.max_potions)
	health.health_changed.emit(health.current_health, health.max_health)
	player.resources_changed.emit()
	pending_save.clear()

## Called only after the presentation's save decision and audio drain. The tree, not the dying game, owns the final timer.
func quit_run(exit_code: int = 0) -> void:
	if _shutting_down:
		return
	_shutting_down = true
	var tree := get_tree()
	tree.paused = true
	UI_THEME.release_resources()
	var effects := tree.root.get_node_or_null(^"CombatVfxHub")
	if effects != null:
		await effects.release_audio()
		effects.queue_free()
	queue_free()
	# Let queued UI/world/effect destruction finish while renderer/audio servers still exist.
	tree.create_timer(0.1, true).timeout.connect(tree.quit.bind(exit_code))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(presentation):
		presentation.request_quit()
