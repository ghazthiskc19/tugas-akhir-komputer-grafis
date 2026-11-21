extends StaticBody3D
## Training dummy: static target with a health label. No AI, no movement.

const HIT_COLOR := Color(1.0, 1.0, 1.0)
const FLASH_TIME := 0.12

@onready var health: Node = $Health
@onready var _label: Label3D = $HealthLabel
@onready var _visual: Node3D = $Visual
@onready var _torso: MeshInstance3D = $Visual/Torso

var _material: StandardMaterial3D
var _base_color: Color


func _ready() -> void:
	_material = ((_torso.mesh as BoxMesh).material as StandardMaterial3D).duplicate() as StandardMaterial3D
	_torso.material_override = _material
	_base_color = _material.albedo_color
	health.health_changed.connect(_on_health_changed)
	health.dead.connect(_on_dead)
	_update_label()


func _on_health_changed(_current: int, _maximum: int) -> void:
	_update_label()
	if health.is_dead:
		return
	_material.albedo_color = HIT_COLOR
	create_tween().tween_property(_material, "albedo_color", _base_color, FLASH_TIME)


func _on_dead() -> void:
	# Tip over so the KO state is visible.
	create_tween().tween_property(_visual, "rotation_degrees:x", -80.0, 0.3)


func _update_label() -> void:
	_label.text = "KO" if health.is_dead else "HP %d/%d" % [health.current_health, health.max_health]
