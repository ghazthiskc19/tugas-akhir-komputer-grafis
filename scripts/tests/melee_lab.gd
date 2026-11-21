extends Node3D
## Melee lab: HUD readout (dummy HP, attack state) and R to reload the lab. No auto-respawn.

@onready var _player = $Player
@onready var _near = $DummyNear
@onready var _far = $DummyFar
@onready var _status: Label = $HUD/Status


func _process(_delta: float) -> void:
	_status.text = "Serang: %s • Dummy depan: %s • Dummy jauh: %s" % [
		"mengayun" if _player.is_attacking() else "siap",
		_hp_text(_near), _hp_text(_far),
	]


func _hp_text(dummy: Node) -> String:
	var health: Node = dummy.health
	return "KO" if health.is_dead else "%d/%d" % [health.current_health, health.max_health]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
