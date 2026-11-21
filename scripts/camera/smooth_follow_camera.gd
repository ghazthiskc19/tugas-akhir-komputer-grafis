class_name SmoothFollowCamera
extends Camera3D
## Kamera elevated third-person dengan rotasi tetap dan damping posisi.

@export var target_path: NodePath = ^"../Player"
@export var offset := Vector3(0.0, 7.0, 9.0)
@export var focus_height := 1.0
@export var horizontal_damping := 8.0
@export var vertical_damping := 5.0

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	assert(_target != null, "SmoothFollowCamera: target_path harus menunjuk Node3D")
	set_process(_target != null)
	if _target == null:
		return
	# Rotasi ditetapkan sekali dari offset; tidak ada look_at per frame.
	global_basis = Basis.looking_at(-offset, Vector3.UP)
	global_position = _desired_position()


func _process(delta: float) -> void:
	var desired := _desired_position()
	var pos := global_position
	pos.x = lerpf(pos.x, desired.x, 1.0 - exp(-horizontal_damping * delta))
	pos.z = lerpf(pos.z, desired.z, 1.0 - exp(-horizontal_damping * delta))
	pos.y = lerpf(pos.y, desired.y, 1.0 - exp(-vertical_damping * delta))
	global_position = pos


func _desired_position() -> Vector3:
	return _target.global_position + Vector3(0.0, focus_height, 0.0) + offset
