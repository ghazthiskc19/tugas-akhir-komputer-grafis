extends CharacterBody3D
## I03 ground movement (camera-relative WASD, idle/walk) + I04 jump (opt-in via jump_enabled).
## No camera follow or combat. Jump has no buffer/coyote/double/variable height.

const SKELETON_PATH := NodePath("Rig_Medium/Skeleton3D")
const GENERAL := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_General.glb"
const MOVEMENT := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_MovementBasic.glb"
const CLIPS := {
	&"idle": {"file": GENERAL, "clip": "Idle_A", "loop": true},
	&"walk": {"file": MOVEMENT, "clip": "Walking_A", "loop": true},
}
## Loaded only when jump_enabled. Only jump_idle loops; start and land are one-shots.
const JUMP_CLIPS := {
	&"jump_start": {"file": MOVEMENT, "clip": "Jump_Start", "loop": false},
	&"jump_idle": {"file": MOVEMENT, "clip": "Jump_Idle", "loop": true},
	&"jump_land": {"file": MOVEMENT, "clip": "Jump_Land", "loop": false},
}
const MOVING_THRESHOLD := 0.1

## GROUND: idle/walk. TAKEOFF: Jump_Start, rising. AIR: Jump_Idle loop (falling, incl. ledge falls).
## LANDING: Jump_Land one-shot on the grounded state; ends by clip length or by movement.
enum State { GROUND, TAKEOFF, AIR, LANDING }

@export var camera_path: NodePath
@export var base_speed := 4.0
@export var acceleration := 20.0
@export var deceleration := 25.0
@export var turn_rate := 12.0
## False keeps exact I03 behavior (no jump input, no jump clips loaded).
@export var jump_enabled := false
## Takeoff velocity in m/s (chosen over a height parameter). Apex = v^2 / (2 * g): 5.1 with g 9.8 gives ~1.33 m.
@export var jump_velocity := 5.1
## Movement input may cut the landing clip short only after this many seconds, so a landing stays visible.
@export var landing_interrupt_time := 0.25

@onready var _model: Node3D = $Rogue
@onready var _anim: AnimationPlayer = $AnimationPlayer
var _camera: Camera3D
var _window_focused := true
var _state := State.GROUND
var _landing_elapsed := 0.0
var _landing_length := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	var errors := _build_library()
	if _camera == null:
		errors.append("camera_path tidak menunjuk Camera3D: '%s'" % camera_path)
	if not errors.is_empty():
		push_error("Setup GroundPlayer gagal:\n" + "\n".join(errors))
		set_physics_process(false)
		return
	if jump_enabled:
		_landing_length = _anim.get_animation(&"jump_land").length
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

	# Jump only on the press edge while grounded (holding Space never re-jumps, no air jump).
	# Allowed during LANDING too, since the body is grounded then.
	var on_floor := is_on_floor()
	var jumped := (
		jump_enabled and _window_focused and on_floor
		and Input.is_action_just_pressed(&"jump")
	)
	if jumped:
		velocity.y = jump_velocity
	elif on_floor:
		velocity.y = -0.1 # keeps the body snapped to the floor
	else:
		velocity.y += get_gravity().y * delta

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_rate * delta))

	# Ceiling hits zero velocity.y here, so rising ends and falling begins naturally.
	move_and_slide()

	if jump_enabled:
		_update_jump_state(jumped, direction != Vector3.ZERO, delta)
	else:
		_play_locomotion()


## Exactly one branch per state/ground combination; every path ends in GROUND, TAKEOFF, AIR or LANDING.
func _update_jump_state(jumped: bool, has_input: bool, delta: float) -> void:
	var grounded := is_on_floor()
	if jumped:
		# From GROUND or LANDING: takeoff interrupts whatever was playing.
		_state = State.TAKEOFF
		_anim.play(&"jump_start", 0.05)
		return

	if not grounded:
		match _state:
			State.GROUND, State.LANDING:
				# Ledge fall, or left the floor while landing: fall pose, no takeoff clip.
				_state = State.AIR
				_anim.play(&"jump_idle", 0.15)
			State.TAKEOFF:
				if velocity.y <= 0.0:
					_state = State.AIR
					_anim.play(&"jump_idle", 0.15)
		return

	match _state:
		State.TAKEOFF, State.AIR:
			# Once per ground transition: the state leaves AIR/TAKEOFF here and cannot re-enter without leaving the floor.
			_state = State.LANDING
			_landing_elapsed = 0.0
			_anim.play(&"jump_land", 0.05)
		State.LANDING:
			_landing_elapsed += delta
			if _landing_elapsed >= _landing_length or (has_input and _landing_elapsed >= landing_interrupt_time):
				_state = State.GROUND
				_play_locomotion()
		State.GROUND:
			_play_locomotion()


func _play_locomotion() -> void:
	var clip := &"walk" if Vector3(velocity.x, 0.0, velocity.z).length() > MOVING_THRESHOLD else &"idle"
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)


## Duplicates only the needed clips (idle/walk, plus jump clips when enabled); source imports stay untouched.
func _build_library() -> PackedStringArray:
	var errors := PackedStringArray()
	var skeleton := _model.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		errors.append("Skeleton3D tidak ada di %s" % SKELETON_PATH)
		return errors
	var clips := CLIPS.duplicate()
	if jump_enabled:
		clips.merge(JUMP_CLIPS)
	var library := AnimationLibrary.new()
	for mode: StringName in clips:
		var config: Dictionary = clips[mode]
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
			animation.loop_mode = Animation.LOOP_LINEAR if config["loop"] else Animation.LOOP_NONE
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
