extends Node3D
## Slow idle motion for a decorative Node3D (floating crystal): bob + yaw spin. Visual only; the parent keeps state.

@export var bob_height := 0.08
@export var bob_speed := 1.4
@export var spin_speed := 0.7   # rad/s

var _base_y := 0.0
var _phase := 0.0


func _ready() -> void:
	_base_y = position.y
	_phase = fmod(global_position.x * 0.7 + global_position.z * 0.3, TAU)


func _process(delta: float) -> void:
	_phase += delta * bob_speed
	position.y = _base_y + sin(_phase) * bob_height
	rotation.y += delta * spin_speed
