extends Node3D
## Enemy review lab: shows each enemy's state/HP and the player's HP. R reloads the lab.

@onready var _status: Label = $HUD/Status
@onready var _player: Node = $Player


func _process(_delta: float) -> void:
	var parts: PackedStringArray = []
	for enemy in $Enemies.get_children():
		var health: Node = enemy.get_node("Health")
		parts.append("%s: %s %d/%d" % [enemy.enemy_id, enemy.get_state_name(), health.current_health, health.max_health])
	var player_hp := ""
	var player_health := _player.get_node_or_null("Health")
	if player_health != null:
		player_hp = " • Pemain: %d/%d" % [player_health.current_health, player_health.max_health]
	_status.text = " • ".join(parts) + player_hp


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
