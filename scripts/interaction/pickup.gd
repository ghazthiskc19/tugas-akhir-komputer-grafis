extends "res://scripts/interaction/interactable.gd"
## Unique one-shot pickup. kind &"potion" adds potions (only consumed when accepted); other kinds just count.

@export var pickup_id: StringName = &""
@export var kind: StringName = &"artifact"
@export var amount := 1
@export var display_name := "Artefak"
@export var spin_speed := 1.5
@export var bob_height := 0.08

var _visual: Node3D
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	super()
	_visual = get_node_or_null(^"Visual") as Node3D
	if _visual != null:
		_base_y = _visual.position.y


func _process(delta: float) -> void:
	if _visual == null or not visible:
		return
	_time += delta
	_visual.rotate_y(spin_speed * delta)
	_visual.position.y = _base_y + sin(_time * 2.0) * bob_height


func _is_claimed() -> bool:
	var session := _session()
	return _local_claimed or (session != null and session.is_collected(pickup_id))


func can_interact(player: Node) -> bool:
	if not visible or _is_claimed():
		return false
	if kind == &"potion":
		return player.potion_count < player.max_potions
	return true


func get_prompt() -> String:
	return "Ambil %s" % display_name


func interact(player: Node) -> bool:
	if not can_interact(player):
		return false
	if kind == &"potion" and player.add_potions(amount) <= 0:
		return false
	var session := _session()
	if session != null:
		session.claim(pickup_id, kind)
	_local_claimed = true
	_hide_collected()
	return true


func _sync_state() -> void:
	if _is_claimed():
		_hide_collected()


func _hide_collected() -> void:
	hide()
	remove_from_group(&"interactable")
