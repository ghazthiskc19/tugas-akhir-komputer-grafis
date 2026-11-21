extends CharacterBody3D
## I03 ground movement: camera-relative WASD, idle/walk only. No jump, camera follow, or combat.

const SKELETON_PATH := NodePath("Rig_Medium/Skeleton3D")
const GENERAL := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_General.glb"
const MOVEMENT := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_MovementBasic.glb"
const CLIPS := {
	&"idle": {"file": GENERAL, "clip": "Idle_A"},
	&"walk": {"file": MOVEMENT, "clip": "Walking_A"},
}
const MOVING_THRESHOLD := 0.1

@export var camera_path: NodePath
@export var base_speed := 4.0
@export var acceleration := 20.0
@export var deceleration := 25.0
@export var turn_rate := 12.0

@onready var _model: Node3D = $Rogue
@onready var _anim: AnimationPlayer = $AnimationPlayer
var _camera: Camera3D
var _window_focused := true


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	var errors := _build_library()
	if _camera == null:
		errors.append("camera_path tidak menunjuk Camera3D: '%s'" % camera_path)
	if not errors.is_empty():
		push_error("Setup GroundPlayer gagal:\n" + "\n".join(errors))
		set_physics_process(false)
		return
	_anim.play(&"idle")


func _notification(what: int) -> void:
	# Keys released while unfocused never reach us; ignore input until focus returns.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if _window_focused:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")

	# Camera yaw only: right and forward flattened onto the ground plane.
	var camera_basis := _camera.global_basis
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
	var direction := right * input.x - forward * input.y

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	horizontal = horizontal.move_toward(direction * base_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	# Gravity only keeps the body on the floor; there is no jump.
	velocity.y = -0.1 if is_on_floor() else velocity.y + get_gravity().y * delta

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_rate * delta))

	move_and_slide()

	var clip := &"walk" if Vector3(velocity.x, 0.0, velocity.z).length() > MOVING_THRESHOLD else &"idle"
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)


## Duplicates only idle/walk; source imports stay untouched.
func _build_library() -> PackedStringArray:
	var errors := PackedStringArray()
	var skeleton := _model.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		errors.append("Skeleton3D tidak ada di %s" % SKELETON_PATH)
		return errors
	var library := AnimationLibrary.new()
	for mode: StringName in CLIPS:
		var config: Dictionary = CLIPS[mode]
		var clip_name: String = config["clip"]
		var scene := load(config["file"]) as PackedScene
		if scene == null:
			errors.append("Gagal load %s" % config["file"])
			continue
		var source := scene.instantiate()
		var players := source.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip_name):
			errors.append("Klip %s tidak ada di %s" % [clip_name, config["file"]])
		else:
			var animation := (players[0] as AnimationPlayer).get_animation(clip_name).duplicate() as Animation
			animation.loop_mode = Animation.LOOP_LINEAR
			for track in animation.get_track_count():
				var path := String(animation.track_get_path(track))
				var node_path := NodePath(path.get_slice(":", 0))
				if _model.get_node_or_null(node_path) != skeleton or skeleton.find_bone(path.get_slice(":", 1)) < 0:
					errors.append("%s: track %s tidak cocok dengan Rogue" % [clip_name, path])
			library.add_animation(mode, animation)
		source.free()
	if errors.is_empty():
		_anim.add_animation_library(&"", library)
	return errors
