extends Node
## Picks the nearest valid interactable in range with world line of sight; E (press, not hold) interacts.

signal target_changed(target: Node)

@export var player_path: NodePath = ^"../Player"
@export var interact_range := 2.5
@export var eye_height := 1.2
@export_flags_3d_physics var world_mask := 1

var _player: Node3D
var _target: Node3D
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	set_physics_process(true)


func _resolve_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _player_ready() -> bool:
	_resolve_player()
	if _player == null:
		return false
	if _player.has_method(&"is_dead") and _player.is_dead():
		return false
	if _player.has_method(&"can_interact") and not _player.can_interact():
		return false
	return not get_tree().paused


func get_target() -> Node:
	return _target


## HUD text for the current target ("" when none), e.g. "[E] Ambil Ramuan".
func get_prompt() -> String:
	if _target == null or not is_instance_valid(_target) or not _player_ready():
		return ""
	return "[E] %s" % _target.get_prompt()


func _physics_process(_delta: float) -> void:
	var best: Node3D = null
	if _player_ready():
		var best_d := interact_range * interact_range
		var origin := _player.global_position
		for node in get_tree().get_nodes_in_group(&"interactable"):
			var item := node as Node3D
			if item == null or not item.is_visible_in_tree() or not item.can_interact(_player):
				continue
			var delta := item.global_position - origin
			if absf(delta.y) > 2.0:
				continue
			delta.y = 0.0
			var d := delta.length_squared()
			if d < best_d and _has_line_of_sight(item):
				best_d = d
				best = item
	if best != _target:
		_target = best
		target_changed.emit(_target)


func _has_line_of_sight(item: Node3D) -> bool:
	_ray.from = _player.global_position + Vector3.UP * eye_height
	_ray.to = item.get_focus_point()
	_ray.collision_mask = world_mask
	_ray.exclude = [_player.get_rid()] if _player is CollisionObject3D else []
	return _player.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	var pressed: bool
	if InputMap.has_action(&"interact"):
		pressed = event.is_action_pressed(&"interact")
	else:
		pressed = event is InputEventKey and event.physical_keycode == KEY_E
	if not pressed or _target == null or not is_instance_valid(_target) or not _player_ready():
		return
	var target := _target
	if not target.can_interact(_player):
		return
	if target.interact(_player):
		get_viewport().set_input_as_handled()
