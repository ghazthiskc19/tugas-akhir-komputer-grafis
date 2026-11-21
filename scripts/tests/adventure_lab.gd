extends Node3D
## Playable interaction prototype. Fixed arena, not the procedural island or final level.

const STANDARD := preload("res://scenes/enemies/standard_melee.tscn")
const HEAVY := preload("res://scenes/enemies/heavy_melee.tscn")
const RANGED := preload("res://scenes/enemies/ranged_enemy.tscn")
const SESSION_SCRIPT := preload("res://scripts/world/session_progress.gd")
const INTERACTOR_SCRIPT := preload("res://scripts/interaction/interactor.gd")
const POTION_PICKUP := preload("res://scenes/world/potion_pickup.tscn")
const ARTIFACT_PICKUP := preload("res://scenes/world/artifact_pickup.tscn")
const CHECKPOINT := preload("res://scenes/world/checkpoint.tscn")

@onready var player = $Player
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var resource_label: Label
var prompt_label: Label
var progress_label: Label
var status_label: Label
var session: Node
var interactor: Node

func _ready() -> void:
	# Replace the inherited review obstacles and dummies, retaining its rig, sword and camera setup.
	for path in ["World", "DummyNear", "DummyFar", "HUD"]:
		get_node(path).free()
	_build_world()
	_build_enemies()
	_build_hud()
	_build_session()

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	_box(world, "Ground", Vector3(0,-0.2,0), Vector3(44,0.4,44), Color("a5d6a7"))
	_box(world, "North", Vector3(0,1.25,-22), Vector3(44,2.5,0.5), Color("1b365d"))
	_box(world, "South", Vector3(0,1.25,22), Vector3(44,2.5,0.5), Color("1b365d"))
	_box(world, "West", Vector3(-22,1.25,0), Vector3(0.5,2.5,44), Color("1b365d"))
	_box(world, "East", Vector3(22,1.25,0), Vector3(0.5,2.5,44), Color("1b365d"))
	_box(world, "RangedCover", Vector3(10,1.2,-2), Vector3(4,2.4,0.65), Color("607938"))
	_box(world, "HeavyCover", Vector3(-9,1,-3), Vector3(3,2,0.65), Color("607938"))
	_box(world, "LowStep", Vector3(-5,0.225,9), Vector3(3,0.45,3), Color("ce7f20"))
	_box(world, "HighStep", Vector3(-5,0.4,5), Vector3(3,0.8,3), Color("ce7f20"))
	_world_label(world,"MELEE BIASA",Vector3(0,0.04,4))
	_world_label(world,"HEAVY",Vector3(-13,0.04,-5))
	_world_label(world,"RANGED + COVER",Vector3(13,0.04,-5))
	_world_label(world,"CAMP / CHECKPOINT",Vector3(0,0.04,18))

func _box(parent: Node3D, title: String, position_at: Vector3, dimensions: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = position_at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	material.metallic_specular = 0
	mesh.material = material
	var visible := MeshInstance3D.new()
	visible.mesh = mesh
	body.add_child(visible)
	parent.add_child(body)

func _world_label(parent: Node3D, text: String, where: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = where
	label.rotation_degrees.x = -90
	label.font_size = 40
	label.pixel_size = 0.015
	label.outline_size = 0
	label.modulate = Color("1b365d")
	parent.add_child(label)

func _build_enemies() -> void:
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	var configs := [
		[STANDARD,"Standard",Vector3(0,0,1),&"arena_standard"],
		[HEAVY,"Heavy",Vector3(-13,0,-8),&"arena_heavy"],
		[RANGED,"Ranged",Vector3(13,0,-8),&"arena_ranged"],
	]
	for config in configs:
		var enemy = (config[0] as PackedScene).instantiate()
		enemy.name = config[1]
		enemy.position = config[2]
		enemy.enemy_id = config[3]
		enemy.player_path = NodePath("../../Player")
		enemies.add_child(enemy)

func _build_session() -> void:
	session = SESSION_SCRIPT.new()
	session.name = "Session"
	session.player_path = NodePath("../Player")
	add_child(session)
	session.initialize(player)
	for enemy in $Enemies.get_children():
		session.register_enemy(enemy)
	interactor = INTERACTOR_SCRIPT.new()
	interactor.name = "Interactor"
	interactor.player_path = NodePath("../Player")
	add_child(interactor)
	var checkpoint = CHECKPOINT.instantiate()
	checkpoint.name = "CampCheckpoint"
	checkpoint.checkpoint_id = &"camp"
	checkpoint.position = Vector3(-3,0,15)
	$World.add_child(checkpoint)
	var potion = POTION_PICKUP.instantiate()
	potion.name = "CampPotion"
	potion.pickup_id = &"camp_potion"
	potion.amount = 2
	potion.position = Vector3(3,0,14)
	$World.add_child(potion)
	var artifact = ARTIFACT_PICKUP.instantiate()
	artifact.name = "ArenaArtifact"
	artifact.pickup_id = &"arena_artifact"
	artifact.position = Vector3(0,0,-15)
	$World.add_child(artifact)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	_label(hud,"PROTOTYPE • COMBAT + CHECKPOINT",Vector2(24,18),25)
	hp_bar = _bar(hud,Vector2(24,58),Color("930031"))
	stamina_bar = _bar(hud,Vector2(24,88),Color("607938"))
	resource_label = _label(hud,"",Vector2(24,120),19)
	status_label = _label(hud,"",Vector2(24,149),18)
	_label(hud,"LMB: combo • RMB: block • Shift: sprint • Alt: dodge • Q: potion • E: interaksi",Vector2(24,180),18)
	_label(hud,"WASD + Space • Mouse: kamera • Scroll: zoom • Esc: jeda",Vector2(24,207),18)
	progress_label = _label(hud,"",Vector2(24,240),18)
	prompt_label = _label(hud,"",Vector2(24,660),22)

func _bar(parent: Node, where: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = where
	bar.size = Vector2(300,22)
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	bar.add_theme_stylebox_override("fill",style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _label(parent: Node, text: String, where: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = where
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e8f5e9"))
	label.add_theme_color_override("font_outline_color",Color("1b365d"))
	label.add_theme_constant_override("outline_size",4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _process(_delta: float) -> void:
	var health = player.get_node("Health")
	hp_bar.max_value = health.max_health
	hp_bar.value = health.current_health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	resource_label.text = "HP %d/%d • Stamina %d/%d • Potion %d/%d" % [health.current_health,health.max_health,player.stamina,player.max_stamina,player.potion_count,player.max_potions]
	status_label.text = "Aksi: %s" % player.get_action_state()
	progress_label.text = session.get_status()
	prompt_label.text = interactor.get_prompt()
