extends CharacterBody3D
## I03 ground movement (camera-relative WASD, idle/walk) + I04 jump (opt-in via jump_enabled)
## + single melee attack (opt-in via combat_enabled). Jump has no buffer/coyote/double/variable height.
## Attack: one LMB press = one swing (no hold-repeat, no buffer, no combo). Grounded start only; facing locked
## and movement slowed during the swing; jump disabled during the swing. One hit per victim per swing.

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
const COMBAT := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_CombatMelee.glb"
## Loaded only when combat_enabled.
const COMBAT_CLIPS := {
	&"attack": {"file": COMBAT, "clip": "Melee_1H_Attack_Slice_Horizontal", "loop": false},
}
const MOVING_THRESHOLD := 0.1
## Measured on Melee_1H_Attack_Slice_Horizontal (length 1.3667 s): handslot.r accelerates from ~0.15 (x≈0) and
## reaches the far side of the slash at ~0.22 (x≈-0.86), then follows through slowly. Active window = fraction of clip length.
const ATTACK_ACTIVE_START := 0.15
const ATTACK_ACTIVE_END := 0.30
## Hit box in the player's locked facing frame (+Z forward): center 1.0 m ahead, 1.0 m up; extents 2.0 x 1.4 x 1.6 m.
const ATTACK_BOX_SIZE := Vector3(2.0, 1.4, 1.6)
const ATTACK_BOX_CENTER := Vector3(0.0, 1.0, 1.0)
const ATTACK_RAY_ORIGIN_HEIGHT := 1.0
## Enemy hurtboxes use layer index 3 (bit value 4).
const HURTBOX_MASK := 4
const WORLD_MASK := 1
const DAMAGEABLE_META := &"damageable"

signal attack_started
signal attack_finished
## Emitted once per victim per swing, after damage was actually applied.
signal attack_hit(damageable: Node, amount: int)

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
## False keeps old labs unchanged (no attack input, no attack clip loaded).
@export var combat_enabled := false
@export var attack_damage := 20
## Horizontal speed multiplier while swinging.
@export var attack_move_scale := 0.3

@onready var _model: Node3D = $Rogue
@onready var _anim: AnimationPlayer = $AnimationPlayer
var _camera: Camera3D
var _window_focused := true
var _state := State.GROUND
var _landing_elapsed := 0.0
var _landing_length := 0.0

var _attacking := false
var _attack_time := 0.0
var _attack_length := 0.0
var _attack_basis := Basis.IDENTITY
var _attack_queued := false
var _unpause_frame := -1
## Victims (Damageable instance id) already hit in the current swing; reused, cleared on attack start.
var _hit_victims: Dictionary[int, bool] = {}
var _hit_shape := BoxShape3D.new()
var _hit_query := PhysicsShapeQueryParameters3D.new()
var _ray_query := PhysicsRayQueryParameters3D.new()


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
	if combat_enabled:
		_attack_length = _anim.get_animation(&"attack").length
		# Animation and attack clock advance in the same physics step.
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		_hit_shape.size = ATTACK_BOX_SIZE
		_hit_query.shape = _hit_shape
		_hit_query.collision_mask = HURTBOX_MASK
		_hit_query.collide_with_areas = true
		_hit_query.collide_with_bodies = false
		_hit_query.exclude = [get_rid()]
		_ray_query.collision_mask = WORLD_MASK
		_ray_query.exclude = [get_rid()]
	set_process_unhandled_input(combat_enabled)
	_anim.play(&"idle")


func _notification(what: int) -> void:
	# Keys released while unfocused never reach us; ignore input until focus returns.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_attack_queued = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true
	elif what == NOTIFICATION_PAUSED:
		_attack_queued = false
	elif what == NOTIFICATION_UNPAUSED:
		# Anything delivered in the frame the game resumes (e.g. the Resume click) must not start a swing.
		_attack_queued = false
		_unpause_frame = Engine.get_process_frames()


## _unhandled_input: clicks on GUI (pause overlay, Resume) are consumed before reaching here, and a paused
## tree never delivers input to this node. Only press edges queue a swing (no echo, no hold-repeat).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"attack") or event.is_echo():
		return
	if not _window_focused or get_tree().paused or Engine.get_process_frames() == _unpause_frame:
		return
	_attack_queued = true


## True from attack start until the clip ends (or the swing is cut by leaving the floor).
func is_attacking() -> bool:
	return _attacking


## Seconds since the swing started (0 when idle).
func get_attack_time() -> float:
	return _attack_time


func get_attack_length() -> float:
	return _attack_length


## Active window in seconds (start, end) within the current clip.
func get_attack_window() -> Vector2:
	return Vector2(ATTACK_ACTIVE_START, ATTACK_ACTIVE_END) * _attack_length


func _physics_process(delta: float) -> void:
	var wants_attack := _attack_queued
	_attack_queued = false  # No buffer: a press that cannot start a swing now is dropped.
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
	var speed := base_speed * (attack_move_scale if _attacking else 1.0)
	horizontal = horizontal.move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Jump only on the press edge while grounded (holding Space never re-jumps, no air jump).
	# Allowed during LANDING too, since the body is grounded then.
	var on_floor := is_on_floor()
	var jumped := (
		jump_enabled and _window_focused and on_floor and not _attacking
		and Input.is_action_just_pressed(&"jump")
	)
	if jumped:
		velocity.y = jump_velocity
	elif on_floor:
		velocity.y = -0.1 # keeps the body snapped to the floor
	else:
		velocity.y += get_gravity().y * delta

	if direction != Vector3.ZERO and not _attacking:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_rate * delta))

	# Ceiling hits zero velocity.y here, so rising ends and falling begins naturally.
	move_and_slide()

	if combat_enabled:
		if _attacking:
			_advance_attack(delta)
		elif wants_attack and _window_focused and not jumped and is_on_floor() and _state == State.GROUND:
			_start_attack()
	if _attacking:
		return # The attack clip owns the animation; no locomotion/jump clip fights it.
	if jump_enabled:
		_update_jump_state(jumped, direction != Vector3.ZERO, delta)
	else:
		_play_locomotion()


func _start_attack() -> void:
	_attacking = true
	_attack_time = 0.0
	_attack_basis = Basis(Vector3.UP, rotation.y)
	_hit_victims.clear()
	_anim.stop()  # Always restart from frame 0.
	_anim.play(&"attack", 0.05)
	attack_started.emit()


## Runs once per physics frame. The window test is an interval overlap (previous time, new time], so a long
## frame cannot step over the window; each victim still takes damage at most once per swing.
func _advance_attack(delta: float) -> void:
	var previous := _attack_time
	_attack_time += delta
	if not is_on_floor():
		_end_attack() # Walked off a ledge mid-swing: cut the swing, the jump state plays the fall.
		return
	var window_start := ATTACK_ACTIVE_START * _attack_length
	var window_end := ATTACK_ACTIVE_END * _attack_length
	if _attack_time >= window_start and previous <= window_end:
		_hit_targets()
	if _attack_time >= _attack_length:
		_end_attack()


func _end_attack() -> void:
	_attacking = false
	_attack_time = 0.0
	attack_finished.emit()
	if is_on_floor():
		_play_locomotion() # Fall is handled by the jump state on the next frame.


func _hit_targets() -> void:
	var space := get_world_3d().direct_space_state
	_hit_query.transform = Transform3D(_attack_basis, global_position + _attack_basis * ATTACK_BOX_CENTER)
	var origin := global_position + Vector3(0.0, ATTACK_RAY_ORIGIN_HEIGHT, 0.0)
	for hit in space.intersect_shape(_hit_query, 32):
		var area := hit["collider"] as Node
		if area == null or not area.has_meta(DAMAGEABLE_META):
			continue
		var damageable := area.get_node_or_null(area.get_meta(DAMAGEABLE_META)) as Node
		if damageable == null or _hit_victims.has(damageable.get_instance_id()):
			continue
		# World walls (layer 1) between the player and the hurtbox block the hit. The victim's own body is excluded.
		var exclude: Array[RID] = [get_rid()]
		var body := area.get_parent() as CollisionObject3D
		if body != null:
			exclude.append(body.get_rid())
		_ray_query.exclude = exclude
		_ray_query.from = origin
		_ray_query.to = _hurtbox_center(area)
		if not space.intersect_ray(_ray_query).is_empty():
			continue
		_hit_victims[damageable.get_instance_id()] = true
		if damageable.apply_damage(attack_damage):
			attack_hit.emit(damageable, attack_damage)


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


## Duplicates only the needed clips (idle/walk, plus jump/attack clips when enabled); source imports stay untouched.
func _build_library() -> PackedStringArray:
	var errors := PackedStringArray()
	var skeleton := _model.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		errors.append("Skeleton3D tidak ada di %s" % SKELETON_PATH)
		return errors
	var clips := CLIPS.duplicate()
	if jump_enabled:
		clips.merge(JUMP_CLIPS)
	if combat_enabled:
		clips.merge(COMBAT_CLIPS)
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


## Center of the hurtbox's first CollisionShape3D (the Area3D origin may sit at the feet).
func _hurtbox_center(area: Node) -> Vector3:
	for child in area.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return (area as Node3D).global_position
