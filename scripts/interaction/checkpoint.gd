extends "res://scripts/interaction/interactable.gd"
## Checkpoint shrine: activation only moves the respawn point (no healing, no potions).

@export var checkpoint_id: StringName = &""
@export var active_color := Color(0.3, 1.0, 0.6)
@export var inactive_color := Color(0.25, 0.3, 0.35)

@onready var _crystal: MeshInstance3D = get_node_or_null(^"Visual/Crystal")
@onready var _spawn: Node3D = get_node_or_null(^"SpawnPoint")


func _sync_state() -> void:
	var session := _session()
	if session != null and not session.checkpoint_changed.is_connected(_on_checkpoint_changed):
		session.checkpoint_changed.connect(_on_checkpoint_changed)
	_set_active(session != null and session.checkpoint_id == checkpoint_id)


func can_interact(_player: Node) -> bool:
	var session := _session()
	return session != null and session.checkpoint_id != checkpoint_id


func get_prompt() -> String:
	return "Aktifkan checkpoint"


func interact(_player: Node) -> bool:
	var session := _session()
	if session == null:
		return false
	return session.set_checkpoint(checkpoint_id, _spawn if _spawn != null else self)


func _on_checkpoint_changed(id: StringName) -> void:
	_set_active(id == checkpoint_id)


func _set_active(active: bool) -> void:
	if _crystal == null:
		return
	var mat := _crystal.material_override as StandardMaterial3D
	if mat == null:
		return
	var color := active_color if active else inactive_color
	mat.albedo_color = color
	mat.emission = color
	mat.emission_energy_multiplier = 1.6 if active else 0.1
