extends Node3D
## Base for interactables: group `interactable`; can_interact(player), get_prompt(), interact(player) -> changed.

@export var prompt_text := "Berinteraksi"
## Offset above origin used for the line-of-sight target.
@export var focus_height := 0.8

var _local_claimed := false


func _ready() -> void:
	add_to_group(&"interactable")
	_sync_state.call_deferred()


func can_interact(_player: Node) -> bool:
	return true


func get_prompt() -> String:
	return prompt_text


func interact(_player: Node) -> bool:
	return false


func get_focus_point() -> Vector3:
	return global_position + Vector3.UP * focus_height


func _sync_state() -> void:
	pass


func _session() -> Node:
	return get_tree().get_first_node_in_group(&"session") if is_inside_tree() else null
