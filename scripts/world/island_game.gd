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

@export var island_seed: int = 42
@export var procedural: bool = false
@export var start_in_menu: bool = true
var session: Node
var interactor: Node
var terrain: Node3D
var boss: Node3D
var presentation: CanvasLayer
var objectives: Node3D
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	var qa_playthrough := OS.get_cmdline_user_args().has("--qa-playthrough")
	if qa_playthrough:
		start_in_menu = false
	for path in ["World", "DummyNear", "DummyFar", "HUD"]:
		var old := get_node_or_null(path)
		if old != null:
			old.free()
	player.position = Vector3(0, 0.1, 85)
	session = SESSION.new()
	session.name = "Session"
	session.player_path = NodePath("../Player")
	add_child(session)
	session.initialize(player)
	terrain = TERRAIN.new()
	terrain.name = "World"
	terrain.configure(island_seed, procedural)
	add_child(terrain)
	interactor = INTERACTOR.new()
	interactor.name = "Interactor"
	interactor.player_path = NodePath("../Player")
	add_child(interactor)
	objectives = Node3D.new()
	objectives.name = "Objectives"
	add_child(objectives)
	_add_objective(SYMBOL, "SymbolPillars", Vector3(-65, 0, 0))
	_add_objective(ENERGY, "EnergyPath", Vector3(60, 0, 0))
	_add_objective(SUMMIT, "SummitRoute", Vector3(0, 0, -50))
	boss = BOSS.instantiate()
	boss.name = "BossEncounter"
	boss.position = Vector3(0, 0, -100)
	add_child(boss)
	boss.setup(player, session)
	var camp = CHECKPOINT.instantiate()
	camp.name = "CampCheckpoint"
	camp.checkpoint_id = &"camp"
	camp.position = Vector3(-3, 0, 83)
	terrain.add_child(camp)
	for index in 3:
		var potion = POTION.instantiate()
		potion.pickup_id = StringName("island_potion_%d" % index)
		potion.position = [Vector3(3, 0, 83), Vector3(-48, 0, 0), Vector3(44, 0, 0)][index]
		terrain.add_child(potion)
	_build_encounters()
	presentation = PRESENTATION.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.setup(self, player, session, interactor, boss)
	presentation.set_run_options(island_seed, procedural)
	presentation.new_run_requested.connect(_new_run)
	boss.completed.connect(presentation.show_completion)
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
	for config in [[STANDARD, &"grassland_guard", Vector3(0, 0, 48)], [HEAVY, &"grassland_heavy", Vector3(0, 0, 25)], [RANGED, &"crossroads_ranged", Vector3(0, 0, 5)]]:
		var enemy = (config[0] as PackedScene).instantiate()
		enemy.enemy_id = config[1]
		enemy.position = config[2]
		enemy.player_path = NodePath("../../Player")
		enemies.add_child(enemy)
		session.register_enemy(enemy)


func _new_run(seed_value: int, use_procedural: bool) -> void:
	# Deferred replacement avoids freeing a GUI callback or leaving old paused-tree nodes alive.
	_replace_run.call_deferred(seed_value, use_procedural)

func _replace_run(seed_value: int, use_procedural: bool) -> void:
	get_tree().paused = false
	var next := (load("res://scenes/world/island_game.tscn") as PackedScene).instantiate()
	next.island_seed = seed_value
	next.procedural = use_procedural
	next.start_in_menu = false
	var root := get_tree().root
	root.remove_child(self)
	root.add_child(next)
	next.get_tree().current_scene = next
	queue_free()
