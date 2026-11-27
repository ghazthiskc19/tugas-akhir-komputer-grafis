extends CharacterBody3D
## I03 ground movement (camera-relative WASD, idle/walk) + I04 jump (opt-in via jump_enabled)
## + combat/resources (opt-in via combat_enabled). Old labs keep combat_enabled = false: no combat input, clips or tree.
##
## Combat summary (combat_enabled):
## - Attack: 3-hit combo (Slice_Horizontal -> Slice_Diagonal -> Chop finisher, x1.75 damage). Every swing lasts exactly
##   attack_duration (0.2 s default): the WHOLE clip is time-scaled onto it (TimeScale on the attack branch only), and the hit
##   window / combo gate are the clip-second values scaled by the same factor. One fresh LMB press = one swing. A fresh
##   press after the combo gate starts the next hit; earlier presses are dropped, holding never repeats, no input
##   buffer. Grounded start only. Movement speed and turning stay free; the swing is a spine-filtered layer so the
##   legs keep the locomotion clip. One hit per victim per swing.
## - Sprint (hold `sprint`): sprint_speed while moving, grounded and not dead/dodging/drinking/blocking. Attacking does
##   not stop it. No stamina cost. Plays Running_A (cadence scaled to speed) + subtle dust/streak particles.
## - Block (hold): damage x0.25 from ALL directions, drains 18 stamina/s plus max(8, incoming damage * 0.8) per hit.
##   An unaffordable impact empties/breaks the guard and deals full damage; exact-cost blocks still reduce that hit.
##   Guard breaks at 0 and needs 20 stamina to resume.
## - Dodge: 25 stamina, 0.25 s motion along the move input (back-step without input), invulnerable for the first 0.18 s;
##   the whole dodge clip is time-scaled onto the duration.
## - Potion (Q): 1.5 s upper-body drink at 0.5 speed. Potion + heal happen ONLY when the channel completes; any damaging
##   hit (blocked or not, not iframe-avoided), dodge, attack, leaving the floor or death cancels it with no cost.
## - Stamina regenerates 25/s after 0.75 s without spending (not while blocking/dodging).
##
## Input / state priorities (one decision per physics tick, evaluated before movement):
##   dead > dodge in progress (all other combat input dropped) > attack in progress (only a combo continuation inside the
##   window is accepted; block/dodge/potion are ignored) > start dodge > start attack (cancels a drink) > start potion
##   > block (held; ignored while drinking). Presses that cannot act this tick are dropped (no buffer).
## All enemy damage MUST go through receive_damage(); it applies iframes, block and potion cancellation.

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
const COMBAT_GENERAL := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_General.glb"
const COMBAT_MOVEMENT := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_MovementAdvanced.glb"
## Loaded only when combat_enabled. "drink" is authored (drink_animation.gd); dodge clips lose their root translation
## track (the body is moved by physics, so the mesh must not also slide).
const COMBAT_CLIPS := {
	&"attack_1": {"file": COMBAT, "clip": "Melee_1H_Attack_Slice_Horizontal", "loop": false},
	&"attack_2": {"file": COMBAT, "clip": "Melee_1H_Attack_Slice_Diagonal", "loop": false},
	&"attack_3": {"file": COMBAT, "clip": "Melee_1H_Attack_Chop", "loop": false},
	&"block": {"file": COMBAT, "clip": "Melee_Blocking", "loop": true},
	&"run": {"file": MOVEMENT, "clip": "Running_A", "loop": true},
	&"dodge_forward": {"file": COMBAT_MOVEMENT, "clip": "Dodge_Forward", "loop": false, "strip_root": true},
	&"dodge_back": {"file": COMBAT_MOVEMENT, "clip": "Dodge_Backward", "loop": false, "strip_root": true},
	&"dodge_left": {"file": COMBAT_MOVEMENT, "clip": "Dodge_Left", "loop": false, "strip_root": true},
	&"dodge_right": {"file": COMBAT_MOVEMENT, "clip": "Dodge_Right", "loop": false, "strip_root": true},
	&"death": {"file": COMBAT_GENERAL, "clip": "Death_A", "loop": false},
}
const DODGE_CLIPS: Array[StringName] = [&"dodge_forward", &"dodge_back", &"dodge_left", &"dodge_right"]
const POTION_PROP := "res://assets/third_party/kaykit/dungeon/bottle_A_green.gltf"
const POTION_HAND_BONE := "handslot.l"
const MOVING_THRESHOLD := 0.1
const ATTACK_FADE_IN := 0.015
const ATTACK_FADE_OUT := 0.025
const DODGE_FADE_OUT := 0.1
## Per hit, in seconds of the ORIGINAL (unscaled) clip, measured on handslot.r speed peaks: active = window in which the
## hit box may damage; combo = earliest second at which a fresh press continues the chain (-1 = last hit). _ready
## converts both to real swing time (x attack_duration / clip length). Hit box follows facing (+Z), size in metres.
const ATTACK_STEPS: Array[Dictionary] = [
	{"clip": &"attack_1", "active": Vector2(0.20, 0.42), "combo": 0.70, "damage": 1.0,
		"box_size": Vector3(2.0, 1.4, 1.6), "box_center": Vector3(0.0, 1.0, 1.0)},
	{"clip": &"attack_2", "active": Vector2(0.34, 0.55), "combo": 0.60, "damage": 1.0,
		"box_size": Vector3(2.0, 1.4, 1.6), "box_center": Vector3(0.0, 1.0, 1.0)},
	{"clip": &"attack_3", "active": Vector2(0.48, 0.70), "combo": -1.0, "damage": 1.75,
		"box_size": Vector3(2.4, 1.6, 1.9), "box_center": Vector3(0.0, 1.0, 1.1)},
]
## Locomotion clip cadence: playback speed = ground speed / reference speed (clamped).
const WALK_REF_SPEED := 4.0
const RUN_REF_SPEED := 6.0
const LOCO_SCALE_MIN := 0.6
const LOCO_SCALE_MAX := 1.75
## Sprint particles only emit while the real speed is above this (blocked against a wall = no dust).
const SPRINT_EFFECT_MIN_SPEED := 4.5
const ATTACK_RAY_ORIGIN_HEIGHT := 1.0
## Enemy hurtboxes use layer index 3 (bit value 4).
const HURTBOX_MASK := 4
const WORLD_MASK := 1
const DAMAGEABLE_META := &"damageable"
const ATTACK_FILTER_ROOT_BONE := "spine"
const PARAM_BASE := &"parameters/base/transition_request"
const PARAM_ATTACK := &"parameters/attack/request"
const PARAM_ATTACK_PICK := &"parameters/attack_pick/transition_request"
const PARAM_DRINK := &"parameters/drink/request"
const PARAM_DODGE := &"parameters/dodge/request"
const PARAM_DODGE_PICK := &"parameters/dodge_pick/transition_request"
const PARAM_BLOCK := &"parameters/block/blend_amount"
const PARAM_LIFE := &"parameters/life/transition_request"
const PARAM_ATTACK_SCALE := &"parameters/attack_scale/scale"
const PARAM_DODGE_SCALE := &"parameters/dodge_scale/scale"
const PARAM_WALK_SCALE := &"parameters/walk_scale/scale"
const PARAM_RUN_SCALE := &"parameters/run_scale/scale"
const BLOCK_BLEND_RATE := 10.0
const Damageable := preload("res://scripts/combat/damageable.gd")
const DrinkAnimation := preload("res://scripts/player/drink_animation.gd")
const SprintEffects := preload("res://scripts/player/player_sprint_effects.gd")
const Vfx := preload("res://scripts/vfx/combat_vfx.gd")
const GuardAppearance := preload("res://scripts/enemies/guard_appearance.gd")

signal attack_started
signal attack_finished
## Emitted once per victim per swing, after damage was actually applied.
signal attack_hit(damageable: Node, amount: int)
## HP, stamina or potions changed (stamina emits every physics tick while it moves).
signal resources_changed
## Once per death. A respawn (restore_for_respawn) re-arms it.
signal died
## Damage was applied to the player (after block reduction); blocked tells whether the guard absorbed part of it.
signal damage_taken(amount: int, blocked: bool)
## A start was refused: &"dodge" (stamina), &"potion" (none left / HP full), &"block" (guard broken).
signal action_refused(action: StringName)
signal potion_drunk(healed: int)
signal potion_cancelled

## GROUND: idle/walk. TAKEOFF: Jump_Start, rising. AIR: Jump_Idle loop (falling, incl. ledge falls).
## LANDING: Jump_Land one-shot on the grounded state; ends by clip length or by movement.
enum State { GROUND, TAKEOFF, AIR, LANDING }

@export var camera_path: NodePath
@export var base_speed := 6.0
@export var sprint_speed := 9.0
@export var acceleration := 40.0
@export var deceleration := 45.0
## Swing length in seconds for every hit; clips are time-scaled so the whole clip fits it. Change at runtime with
## set_attack_duration(): it applies from the NEXT swing, a swing in progress keeps its own timings.
@export_range(0.1, 0.6, 0.01) var attack_duration := 0.2
@export var turn_rate := 12.0
## False keeps exact I03 behavior (no jump input, no jump clips loaded).
@export var jump_enabled := false
## Takeoff velocity in m/s (chosen over a height parameter). Apex = v^2 / (2 * g): 5.1 with g 9.8 gives ~1.33 m.
@export var jump_velocity := 5.1
## Movement input may cut the landing clip short only after this many seconds, so a landing stays visible.
@export var landing_interrupt_time := 0.25
## False keeps old labs unchanged (no combat input, no combat clips loaded, no Health node, not in group `player`).
@export var combat_enabled := false
@export var attack_damage := 20
@export_group("Resources")
@export var max_hp := 100
@export var max_stamina := 100.0
@export var max_potions := 5
@export var starting_potions := 3
@export var potion_heal := 40
@export var stamina_regen := 25.0
@export var stamina_regen_delay := 0.75
@export_group("Defense")
@export_range(0.0, 1.0) var block_damage_factor := 0.25
@export var block_drain := 18.0
## After the guard broke at 0 stamina, blocking needs this much stamina again.
@export var block_resume_stamina := 20.0
@export var block_speed_factor := 0.6
@export var dodge_cost := 25.0
@export var dodge_duration := 0.25
@export var dodge_iframes := 0.18
## Dodge speed eases from dodge_speed down to dodge_speed * dodge_end_factor over dodge_duration.
@export var dodge_speed := 12.0
@export var dodge_end_factor := 0.4
@export var potion_speed_factor := 0.5

@onready var _model: Node3D = $Rogue
@onready var _anim: AnimationPlayer = $AnimationPlayer
var _camera: Camera3D
var _window_focused := true
var _state := State.GROUND
var _landing_elapsed := 0.0
var _landing_length := 0.0
var _sprinting := false
var _has_sprint_action := false
var _sprint_effects: Node3D
var _walk_scale := 1.0
var _run_scale := 1.0
## Real-time (swing seconds) hit window / combo gate per step and the clip time-scale per step.
var _step_active: Array[Vector2] = []
var _step_combo: Array[float] = []
var _step_scale: Array[float] = []
var _attack_node: AnimationNodeOneShot
var _dodge_node: AnimationNodeOneShot
var _attack_combo_gate := -1.0

var stamina := 0.0
var potion_count := 0
var _health: Node
var _dead := false

var _attacking := false
var _combo_step := -1
var _attack_time := 0.0
var _attack_length := 0.0
var _attack_active := Vector2.ZERO
var _attack_damage_now := 0
var _attack_queued := false
var _dodge_queued := false
var _potion_queued := false
var _has_dodge_action := false
var _has_block_action := false
var _has_potion_action := false
var _unpause_frame := -1

var _blocking := false
var _block_broken := false
var _block_blend := 0.0
var _since_stamina_spend := 0.0
var _dodging := false
var _dodge_time := 0.0
var _dodge_dir := Vector3.ZERO
var _drinking := false
var _drink_time := 0.0
var _drink_length := 0.0
var _bottle: Node3D

var _tree: AnimationTree
var _base_node: AnimationNodeTransition
var _base_state: StringName
## Victims (Damageable instance id) already hit in the current swing; reused, cleared on attack start.
var _hit_victims: Dictionary[int, bool] = {}
var _hit_shape := BoxShape3D.new()
var _hit_query := PhysicsShapeQueryParameters3D.new()
var _ray_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	GuardAppearance.apply_player(_model)
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
		_drink_length = _anim.get_animation(&"drink").length
		_build_attack_timings()
		_attack_length = attack_duration
		_attack_active = _step_active[0]
		_hit_query.shape = _hit_shape
		_hit_query.collision_mask = HURTBOX_MASK
		_hit_query.collide_with_areas = true
		_hit_query.collide_with_bodies = false
		_hit_query.exclude = [get_rid()]
		_ray_query.collision_mask = WORLD_MASK
		_ray_query.exclude = [get_rid()]
		_has_dodge_action = InputMap.has_action(&"dodge")
		_has_block_action = InputMap.has_action(&"block")
		_has_potion_action = InputMap.has_action(&"potion")
		_has_sprint_action = InputMap.has_action(&"sprint")
		_sprint_effects = SprintEffects.new()
		_sprint_effects.name = &"SprintEffects"
		add_child(_sprint_effects)
		_sprint_effects.setup()
		Vfx.hub_for(self)
		_setup_health()
		stamina = max_stamina
		potion_count = clampi(starting_potions, 0, max_potions)
		add_to_group(&"player")
		resources_changed.emit()
	set_process_unhandled_input(combat_enabled)
	if _tree == null:
		_anim.play(&"idle")


func _notification(what: int) -> void:
	# Keys released while unfocused never reach us; ignore input until focus returns.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_stop_sprint()
		_drop_queued_input()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true
	elif what == NOTIFICATION_PAUSED:
		_stop_sprint()
		_drop_queued_input()
	elif what == NOTIFICATION_UNPAUSED:
		# Anything delivered in the frame the game resumes (e.g. the Resume click) must not start an action.
		_drop_queued_input()
		_unpause_frame = Engine.get_process_frames()


## _unhandled_input: clicks on GUI (pause overlay, Resume) are consumed before reaching here, and a paused
## tree never delivers input to this node. Only press edges queue an action (no echo, no hold-repeat).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _dead:
		return
	if not _window_focused or get_tree().paused or Engine.get_process_frames() == _unpause_frame:
		return
	if event.is_action_pressed(&"attack"):
		_attack_queued = true
	elif _has_dodge_action and event.is_action_pressed(&"dodge"):
		_dodge_queued = true
	elif _has_potion_action and event.is_action_pressed(&"potion"):
		_potion_queued = true


# --- Public interface -------------------------------------------------------------------------------------------

## True from attack start until the chain ends (or the swing is cut by leaving the floor).
func is_attacking() -> bool:
	return _attacking


## Seconds since the current swing started (0 when idle).
func get_attack_time() -> float:
	return _attack_time


## Length in seconds of the current swing (the first hit's when idle).
func get_attack_length() -> float:
	return _attack_length


## Damage window in seconds (start, end) within the current swing (the first hit's when idle).
func get_attack_window() -> Vector2:
	return _attack_active


## 1..3 while swinging, 0 otherwise.
func get_combo_step() -> int:
	return _combo_step + 1 if _attacking else 0


func is_dead() -> bool:
	return _dead


func is_blocking() -> bool:
	return _blocking


func is_dodging() -> bool:
	return _dodging


func is_drinking() -> bool:
	return _drinking


## 0..1 progress of the potion channel (0 when not drinking).
func get_drink_progress() -> float:
	return _drink_time / _drink_length if _drinking and _drink_length > 0.0 else 0.0


func can_interact() -> bool:
	return combat_enabled and not _dead and not _attacking and not _dodging and not _drinking


## The Health module (Node `Health`, scripts/combat/damageable.gd). Read it; damage the player via receive_damage().
func get_health() -> Node:
	return _health


## &"dead", &"attack", &"dodge", &"drink", &"block", &"air", &"move" or &"idle".
func get_action_state() -> StringName:
	if _dead:
		return &"dead"
	if _attacking:
		return &"attack"
	if _dodging:
		return &"dodge"
	if _drinking:
		return &"drink"
	if _blocking:
		return &"block"
	if not is_on_floor():
		return &"air"
	if is_sprinting():
		return &"sprint"
	return &"move" if Vector3(velocity.x, 0.0, velocity.z).length() > MOVING_THRESHOLD else &"idle"


## True while the sprint action is really active: held, moving on the floor at ground speed, none of the blocking states.
func is_sprinting() -> bool:
	return _sprinting and not _dead and is_on_floor() and Vector3(velocity.x, 0.0, velocity.z).length() > MOVING_THRESHOLD


## The only damage entry point for enemies. True when damage was applied to Health (also when the guard reduced it);
## false while dead, for non-positive amounts and while the dodge iframes avoid the hit. An applied hit cancels a potion.
func receive_damage(amount: int) -> bool:
	if not combat_enabled or _dead or amount <= 0 or _health == null:
		return false
	if _dodging and _dodge_time < dodge_iframes:
		return false
	var was_blocking := _blocking
	var blocked := _blocking
	if blocked:
		var impact := maxf(8.0, float(amount) * 0.8)
		blocked = stamina >= impact
		stamina = maxf(0.0, stamina - impact) if blocked else 0.0
		_since_stamina_spend = 0.0
		if stamina <= 0.0:
			_blocking = false
			_block_broken = true
			if not _block_refused_latch:
				_block_refused_latch = true
				action_refused.emit(&"block")
		resources_changed.emit()
	var final_amount := maxi(1, roundi(amount * block_damage_factor)) if blocked else amount
	_cancel_drink()
	if not _health.apply_damage(final_amount):
		return false
	damage_taken.emit(final_amount, blocked)
	_vfx_damage(blocked, was_blocking and _block_broken)
	return true


## Returns how many were accepted (capped at max_potions).
func add_potions(amount: int) -> int:
	var accepted := clampi(amount, 0, max_potions - potion_count)
	if accepted > 0:
		potion_count += accepted
		resources_changed.emit()
	return accepted


## Respawn: full HP/stamina, clears ALL transient states, input and animation; potion_count is preserved.
func restore_for_respawn() -> void:
	_drop_queued_input()
	_cancel_drink()
	if _attacking:
		_end_attack()
	if _dodging:
		_end_dodge()
	_stop_sprint()
	_blocking = false
	_block_broken = false
	_block_blend = 0.0
	_since_stamina_spend = 0.0
	_dead = false
	_state = State.GROUND
	_landing_elapsed = 0.0
	velocity = Vector3.ZERO
	stamina = max_stamina
	if _tree != null:
		_tree.set(PARAM_BLOCK, 0.0)
		_tree.set(PARAM_LIFE, "alive")
		_tree.set(PARAM_ATTACK, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_tree.set(PARAM_DRINK, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_tree.set(PARAM_DODGE, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_base_state = &"idle"
		_base_node.xfade_time = 0.0
		_tree.set(PARAM_BASE, "idle")
	if _health != null:
		_health.restore_full()
	resources_changed.emit()


# --- Physics -----------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var wants_attack := _attack_queued
	var wants_dodge := _dodge_queued
	var wants_potion := _potion_queued
	_drop_queued_input()  # No buffer: a press that cannot act now is dropped.
	var input := Vector2.ZERO
	var block_held := false
	if _window_focused and not _dead:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
		block_held = _has_block_action and Input.is_action_pressed(&"block")

	# Camera yaw only: right and forward flattened onto the ground plane.
	var camera_basis := _camera.global_basis
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
	var direction := right * input.x - forward * input.y

	var grounded := is_on_floor() and _state == State.GROUND
	if combat_enabled and not _dead:
		_decide_combat(wants_attack, wants_dodge, wants_potion, block_held, direction, grounded, delta)
		_sprinting = (
			_has_sprint_action and _window_focused and grounded and direction != Vector3.ZERO
			and not _dodging and not _drinking and not _blocking and Input.is_action_pressed(&"sprint")
		)
	else:
		_sprinting = false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _dodging:
		var t := clampf(_dodge_time / dodge_duration, 0.0, 1.0)
		horizontal = _dodge_dir * dodge_speed * lerpf(1.0, dodge_end_factor, t)
	elif _dead:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	else:
		var rate := acceleration if direction != Vector3.ZERO else deceleration
		var speed := sprint_speed if _sprinting else base_speed
		horizontal = horizontal.move_toward(direction * speed * _speed_factor(), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Jump only on the press edge while grounded (holding Space never re-jumps, no air jump).
	# Allowed during LANDING too, since the body is grounded then. Not during attack/dodge/drink/death.
	var on_floor := is_on_floor()
	var jumped := (
		jump_enabled and _window_focused and on_floor and not _attacking and not _dodging and not _drinking
		and not _dead and Input.is_action_just_pressed(&"jump")
	)
	if jumped:
		velocity.y = jump_velocity
	elif on_floor:
		velocity.y = -0.1 # keeps the body snapped to the floor
	else:
		velocity.y += get_gravity().y * delta

	if direction != Vector3.ZERO and not _dodging and not _dead:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_rate * delta))

	# Ceiling hits zero velocity.y here, so rising ends and falling begins naturally.
	move_and_slide()

	if combat_enabled:
		_advance_combat(delta)
		_update_sprint_effects()
	# Locomotion/jump base keeps updating during layered actions; they are separate filtered/full-body layers.
	if jump_enabled:
		_update_jump_state(jumped, direction != Vector3.ZERO, delta)
	else:
		_play_locomotion()


func _speed_factor() -> float:
	if _drinking:
		return potion_speed_factor
	if _blocking:
		return block_speed_factor
	return 1.0


func _drop_queued_input() -> void:
	_attack_queued = false
	_dodge_queued = false
	_potion_queued = false


## Priority resolution, see the header. Runs once per tick before movement.
func _decide_combat(wants_attack: bool, wants_dodge: bool, wants_potion: bool, block_held: bool,
		direction: Vector3, grounded: bool, delta: float) -> void:
	if _dodging:
		_blocking = false
		return
	if _attacking:
		_blocking = false
		if wants_attack and _combo_step < ATTACK_STEPS.size() - 1:
			var combo_start := _attack_combo_gate
			if _attack_time >= combo_start and _attack_time < _attack_length:
				_start_attack(_combo_step + 1)
		return
	if wants_dodge and grounded and _try_dodge(direction):
		return
	if wants_attack and grounded:
		_start_attack(0)
		return
	if wants_potion:
		_try_potion(grounded)
	_update_block(block_held and grounded and not _drinking, delta)


func _start_attack(step: int) -> void:
	_cancel_drink()
	_blocking = false
	if _attacking:
		attack_finished.emit()
	_attacking = true
	_combo_step = step
	_attack_time = 0.0
	_hit_victims.clear()
	var data: Dictionary = ATTACK_STEPS[step]
	_attack_length = attack_duration
	_attack_combo_gate = _step_combo[step]
	_attack_active = _step_active[step]
	_tree.set(PARAM_ATTACK_SCALE, _step_scale[step])
	_attack_node.fadeout_time = ATTACK_FADE_OUT * _step_scale[step]  # Fade runs in clip time inside the TimeScale branch.
	_attack_damage_now = roundi(attack_damage * float(data["damage"]))
	_hit_shape.size = data["box_size"]
	_tree.set(PARAM_ATTACK_PICK, String(data["clip"]))
	_tree.set(PARAM_ATTACK, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)  # Restarts the upper-body layer at frame 0.
	attack_started.emit()


func _try_dodge(direction: Vector3) -> bool:
	if stamina < dodge_cost:
		action_refused.emit(&"dodge")
		return false
	_cancel_drink()
	stamina -= dodge_cost
	_since_stamina_spend = 0.0
	_blocking = false
	_dodging = true
	collision_mask = 1  # Dodge passes through enemy bodies (layer 16); walls still block.
	_dodge_time = 0.0
	var facing := Basis(Vector3.UP, rotation.y)
	_dodge_dir = direction.normalized() if direction != Vector3.ZERO else -(facing * Vector3.BACK)
	var local := facing.inverse() * _dodge_dir
	var clip := DODGE_CLIPS[0]  # Model faces +Z, its left side is +X.
	if absf(local.x) > absf(local.z):
		clip = &"dodge_left" if local.x > 0.0 else &"dodge_right"
	elif local.z < 0.0:
		clip = &"dodge_back"
	var dodge_scale := _anim.get_animation(clip).length / dodge_duration
	_tree.set(PARAM_DODGE_SCALE, dodge_scale)
	_dodge_node.fadeout_time = DODGE_FADE_OUT * dodge_scale
	_tree.set(PARAM_DODGE_PICK, String(clip))
	_tree.set(PARAM_DODGE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Vfx.dust_puff(self, global_position + Vector3(0.0, 0.15, 0.0), Color(0.78, 0.72, 0.62, 0.6), 0.9)
	Vfx.ring(self, global_position + Vector3(0.0, 0.08, 0.0), 1.1, Vfx.STEEL, 0.3, 0.16)
	resources_changed.emit()
	return true


func _try_potion(grounded: bool) -> void:
	if _drinking:
		return
	if potion_count <= 0 or _health.current_health >= _health.max_health or not grounded:
		action_refused.emit(&"potion")
		return
	_drinking = true
	_drink_time = 0.0
	_tree.set(PARAM_DRINK, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update_block(want: bool, delta: float) -> void:
	var was_blocking := _blocking
	if _block_broken and stamina >= block_resume_stamina:
		_block_broken = false
	if want and _block_broken:
		if not was_blocking and not _block_refused_latch:
			action_refused.emit(&"block")
		_block_refused_latch = true
	elif not want:
		_block_refused_latch = false
	_blocking = want and not _block_broken and stamina > 0.0
	if _blocking:
		stamina -= block_drain * delta
		_since_stamina_spend = 0.0
		if stamina <= 0.0:
			stamina = 0.0
			_blocking = false
			_block_broken = true
			_block_refused_latch = true
			action_refused.emit(&"block")
			Vfx.guard_break(self, global_position + Vector3(0.0, 1.1, 0.0) + _vfx_forward() * 0.35, _vfx_forward())
			Vfx.shake(self, 0.55)
			Vfx.sound(self, &"guard_break")


var _block_refused_latch := false


## Runs once per physics frame after movement: timers, hit scan, drink completion, stamina, block blend.
func _advance_combat(delta: float) -> void:
	if _dead:
		return
	if _dodging:
		_dodge_time += delta
		if _dodge_time >= dodge_duration:
			_end_dodge()
	if _attacking:
		_advance_attack(delta)
	if _drinking:
		_advance_drink(delta)
	if not _blocking and not _dodging:
		_since_stamina_spend += delta
		if _since_stamina_spend >= stamina_regen_delay and stamina < max_stamina:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	_block_blend = move_toward(_block_blend, 1.0 if _blocking else 0.0, BLOCK_BLEND_RATE * delta)
	_tree.set(PARAM_BLOCK, _block_blend)
	if stamina != _last_stamina:
		_last_stamina = stamina
		resources_changed.emit()


var _last_stamina := -1.0


func _end_dodge() -> void:
	_dodging = false
	collision_mask = 17
	_dodge_time = 0.0
	_tree.set(PARAM_DODGE, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


func _advance_drink(delta: float) -> void:
	_drink_time += delta
	if not is_on_floor():
		_cancel_drink()
		return
	_set_bottle_visible(_drink_time >= DrinkAnimation.RAISE_TIME * 0.3 and _drink_time < DrinkAnimation.LOWER_START + 0.15)
	if _drink_time < _drink_length:
		return
	_drinking = false
	_drink_time = 0.0
	_set_bottle_visible(false)
	potion_count = maxi(potion_count - 1, 0)
	var healed: int = _health.heal(potion_heal)
	if healed > 0:
		_vfx_heal()
	potion_drunk.emit(healed)
	resources_changed.emit()


## Aborts the channel without consuming or healing. No-op when not drinking.
func _cancel_drink() -> void:
	if not _drinking:
		return
	_drinking = false
	_drink_time = 0.0
	_set_bottle_visible(false)
	if _tree != null:
		_tree.set(PARAM_DRINK, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	potion_cancelled.emit()


func _set_bottle_visible(shown: bool) -> void:
	if _bottle != null:
		_bottle.visible = shown


## Runs once per physics frame. The window test is an interval overlap (previous time, new time], so a long
## frame cannot step over the window; each victim still takes damage at most once per swing.
func _advance_attack(delta: float) -> void:
	var previous := _attack_time
	_attack_time += delta
	if not is_on_floor():
		_end_attack() # Walked off a ledge mid-swing: cut the swing, the jump state plays the fall.
		return
	if previous < _attack_active.x and _attack_time >= _attack_active.x:
		_vfx_swing()
	if _attack_time >= _attack_active.x and previous <= _attack_active.y:
		_hit_targets()
	if _attack_time >= _attack_length - 0.0005:
		_end_attack()


func _end_attack() -> void:
	_attacking = false
	_combo_step = -1
	_attack_time = 0.0
	_attack_length = attack_duration
	_attack_active = _step_active[0]
	_tree.set(PARAM_ATTACK, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	attack_finished.emit()


func _hit_targets() -> void:
	var space := get_world_3d().direct_space_state
	var facing := Basis(Vector3.UP, global_rotation.y)
	var center: Vector3 = ATTACK_STEPS[_combo_step]["box_center"]
	_hit_query.transform = Transform3D(facing, global_position + facing * center)
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
		if damageable.apply_damage(_attack_damage_now):
			_vfx_hit(area)
			attack_hit.emit(damageable, _attack_damage_now)
			if not _attacking:
				return # A hit handler ended the swing (e.g. respawn); stop scanning.


# --- VFX hooks (all drawing lives in scripts/vfx/combat_vfx.gd) ----------------------------------------------------

func _vfx_forward() -> Vector3:
	return Basis(Vector3.UP, global_rotation.y) * Vector3.BACK


func _vfx_swing() -> void:
	var forward := _vfx_forward()
	var center := global_position + Vector3(0.0, 1.0, 0.0) + forward * 0.15
	if _combo_step >= ATTACK_STEPS.size() - 1:
		Vfx.slash(self, center, global_rotation.y, 2.6, 220.0, Vfx.GOLD, 0.32, 22.0, false)
		Vfx.ring(self, global_position + forward * 1.0 + Vector3(0.0, 0.1, 0.0), 1.9, Vfx.GOLD, 0.35, 0.25)
	else:
		var odd := _combo_step % 2 == 1
		Vfx.slash(self, center, global_rotation.y, 1.95, 160.0, Vfx.STEEL, 0.26, 36.0 if odd else -36.0, odd)


func _vfx_hit(area: Node) -> void:
	var finisher := _combo_step >= ATTACK_STEPS.size() - 1
	Vfx.shake(self, 0.75 if finisher else 0.45)
	Vfx.hit_stop(self, 0.14 if finisher else 0.07)
	if finisher:
		Vfx.sound(self, &"finisher")
	var victim := area.get_parent()
	if victim != null and victim.has_method(&"react_hit"):
		victim.call(&"react_hit", global_position, finisher)
	Vfx.hit_spark(self, _hurtbox_center(area), _vfx_forward() + Vector3.UP * 0.3, finisher,
		Vfx.GOLD if finisher else Color(1.0, 0.92, 0.6))


func _vfx_damage(blocked: bool, broke := false) -> void:
	var forward := _vfx_forward()
	var chest := global_position + Vector3(0.0, 1.1, 0.0) + forward * 0.35
	if broke:
		# Guard shatter: unlike a block spark (small, steel) this is a wide white-blue burst with the strongest shake.
		Vfx.guard_break(self, chest, forward)
		Vfx.shake(self, 1.0)
		Vfx.hit_stop(self, 0.12)
		Vfx.sound(self, &"guard_break")
		Vfx.screen_flash(self, Color(0.55, 0.85, 1.0) if blocked else Vfx.HURT_RED, 0.8)
		if not blocked:
			Vfx.burst(self, Vfx.Kind.SPARK, chest, forward + Vector3.UP * 0.5, Vfx.HURT_RED, 1.1)
	elif blocked:
		Vfx.hit_spark(self, chest, forward + Vector3.UP * 0.2, false, Vfx.STEEL)
		Vfx.shake(self, 0.32)
		Vfx.ring(self, global_position + Vector3(0.0, 0.08, 0.0), 1.0, Vfx.STEEL, 0.25, 0.14)
	else:
		Vfx.burst(self, Vfx.Kind.FLASH, chest, Vector3.UP, Color(1.0, 0.45, 0.35), 1.1)
		Vfx.burst(self, Vfx.Kind.SPARK, chest, forward + Vector3.UP * 0.5, Vfx.HURT_RED, 1.1)
		Vfx.burst(self, Vfx.Kind.GLOW, chest, Vector3.UP, Vfx.HURT_RED, 0.9)
		Vfx.shake(self, 0.85)
		Vfx.hit_stop(self, 0.09)
		Vfx.screen_flash(self, Vfx.HURT_RED, 0.9)


func _vfx_heal() -> void:
	var feet := global_position + Vector3(0.0, 0.1, 0.0)
	Vfx.burst(self, Vfx.Kind.HEAL, feet, Vector3.UP, Vfx.HEAL_GREEN, 1.0)
	Vfx.burst(self, Vfx.Kind.GLOW, feet + Vector3(0.0, 0.9, 0.0), Vector3.UP, Vfx.HEAL_GREEN, 1.2)
	Vfx.ring(self, feet, 1.2, Vfx.HEAL_GREEN, 0.6, 0.18)


# --- Health ------------------------------------------------------------------------------------------------------

func _setup_health() -> void:
	_health = get_node_or_null("Health")
	if _health == null:
		_health = Damageable.new()
		_health.name = &"Health"
		_health.max_health = max_hp
		add_child(_health)
	_health.health_changed.connect(_on_health_changed)
	_health.dead.connect(_on_health_dead)


func _on_health_changed(_current: int, _maximum: int) -> void:
	resources_changed.emit()


func _on_health_dead() -> void:
	if _dead:
		return
	_dead = true
	_drop_queued_input()
	_cancel_drink()
	_blocking = false
	_stop_sprint()
	if _dodging:
		_end_dodge()
	if _attacking:
		_end_attack()
	if _tree != null:
		_tree.set(PARAM_BLOCK, 0.0)
		_tree.set(PARAM_LIFE, "dead")
	_block_blend = 0.0
	resources_changed.emit()
	died.emit()


# --- Animation ---------------------------------------------------------------------------------------------------

## Exactly one branch per state/ground combination; every path ends in GROUND, TAKEOFF, AIR or LANDING.
func _update_jump_state(jumped: bool, has_input: bool, delta: float) -> void:
	var grounded := is_on_floor()
	if jumped:
		# From GROUND or LANDING: takeoff interrupts whatever was playing.
		_state = State.TAKEOFF
		_play_base(&"jump_start", 0.05)
		return

	if not grounded:
		match _state:
			State.GROUND, State.LANDING:
				# Ledge fall, or left the floor while landing: fall pose, no takeoff clip.
				_state = State.AIR
				_play_base(&"jump_idle", 0.15)
			State.TAKEOFF:
				if velocity.y <= 0.0:
					_state = State.AIR
					_play_base(&"jump_idle", 0.15)
		return

	match _state:
		State.TAKEOFF, State.AIR:
			# Once per ground transition: the state leaves AIR/TAKEOFF here and cannot re-enter without leaving the floor.
			_state = State.LANDING
			_landing_elapsed = 0.0
			_play_base(&"jump_land", 0.05)
		State.LANDING:
			_landing_elapsed += delta
			if _landing_elapsed >= _landing_length or (has_input and _landing_elapsed >= landing_interrupt_time):
				_state = State.GROUND
				_play_locomotion()
		State.GROUND:
			_play_locomotion()


## Base locomotion/jump clip. Combat mode routes it through the AnimationTree transition (action layers untouched);
## otherwise it plays on the AnimationPlayer exactly as before.
func _play_base(clip: StringName, fade: float) -> void:
	if _tree == null:
		if _anim.current_animation != clip:
			_anim.play(clip, fade)
		return
	if _base_state == clip:
		return
	_base_state = clip
	_base_node.xfade_time = fade
	_tree.set(PARAM_BASE, String(clip))


func _play_locomotion() -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var clip := &"idle"
	if speed > MOVING_THRESHOLD:
		clip = &"run" if _tree != null and is_sprinting() else &"walk"
	if _tree != null:
		_update_locomotion_scale(speed)
	_play_base(clip, 0.15)


## Cadence of walk/run follows ground speed (TimeScale nodes sit on those two clips only).
func _update_locomotion_scale(speed: float) -> void:
	var walk := clampf(speed / WALK_REF_SPEED, LOCO_SCALE_MIN, LOCO_SCALE_MAX)
	if absf(walk - _walk_scale) > 0.02:
		_walk_scale = walk
		_tree.set(PARAM_WALK_SCALE, walk)
	var run := clampf(speed / RUN_REF_SPEED, LOCO_SCALE_MIN, LOCO_SCALE_MAX)
	if absf(run - _run_scale) > 0.02:
		_run_scale = run
		_tree.set(PARAM_RUN_SCALE, run)


func _stop_sprint() -> void:
	_sprinting = false
	if _sprint_effects != null:
		_sprint_effects.set_active(false)


## Dust/streak only while the sprint is really running: grounded, input held and not blocked by a wall.
func _update_sprint_effects() -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	_sprint_effects.set_active(is_sprinting() and speed > SPRINT_EFFECT_MIN_SPEED and not get_tree().paused)


## Clamps to 0.1..0.6 s and rebuilds the per-step window/gate/scale tables. A swing in progress keeps the length,
## window, combo gate and tree scale it started with (all captured in _start_attack); the new value applies from the
## next swing. While idle, get_attack_length()/get_attack_window() report the new values at once.
func set_attack_duration(value: float) -> void:
	attack_duration = clampf(value, 0.1, 0.6)
	if _step_active.is_empty():
		return  # Not built yet (before _ready or combat disabled): _build_attack_timings() reads the value.
	_build_attack_timings()
	if not _attacking:
		_attack_length = attack_duration
		_attack_active = _step_active[0]


## Real swing times per step: clip seconds x attack_duration / clip length. Needs the library to exist.
func _build_attack_timings() -> void:
	_step_active.clear()
	_step_combo.clear()
	_step_scale.clear()
	for data in ATTACK_STEPS:
		var length := _anim.get_animation(data["clip"]).length
		var factor := attack_duration / length
		var window: Vector2 = data["active"]
		_step_active.append(window * factor)
		var combo: float = data["combo"]
		_step_combo.append(combo * factor if combo >= 0.0 else -1.0)
		_step_scale.append(length / attack_duration)


func _clip_node(root: AnimationNodeBlendTree, clip: StringName, position: Vector2) -> StringName:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	var node_name := StringName("clip_%s" % clip)
	root.add_node(node_name, node, position)
	return node_name


## input_count Transition whose inputs are fed by one Animation node per clip. Instant by default.
func _clip_transition(root: AnimationNodeBlendTree, node_name: StringName, clips: Array[StringName],
		short_names: Array[String], position: Vector2, scaled: Dictionary = {}) -> AnimationNodeTransition:
	var transition := AnimationNodeTransition.new()
	transition.input_count = clips.size()
	transition.xfade_time = 0.0
	root.add_node(node_name, transition, position)
	for i in clips.size():
		transition.set_input_name(i, short_names[i])
		var source := _clip_node(root, clips[i], position + Vector2(-300, i * 100))
		if scaled.has(clips[i]):
			var scale_name: StringName = scaled[clips[i]]
			root.add_node(scale_name, AnimationNodeTimeScale.new(), position + Vector2(-150, i * 100))
			root.connect_node(scale_name, 0, source)
			source = scale_name
		root.connect_node(node_name, i, source)
	return transition


func _upper_filter(node: AnimationNode, upper_bones: Array[String]) -> void:
	node.filter_enabled = true
	for bone in upper_bones:
		node.set_filter_path(NodePath("%s:%s" % [SKELETON_PATH, bone]), true)


## Combat mode only. BlendTree (output <- life):
##   base (Transition idle/walk[/jump_*]) -> block (Blend2, upper body) -> drink (OneShot, upper body)
##   -> attack (OneShot, upper body, input from attack_pick Transition attack_1..3)
##   -> dodge (OneShot, whole body, input from dodge_pick Transition forward/back/left/right) -> life (alive/dead).
## "Upper body" = spine and all descendants; legs/hips/root keep playing the base clip.
func _build_tree(skeleton: Skeleton3D) -> PackedStringArray:
	var errors := PackedStringArray()
	for bone in [ATTACK_FILTER_ROOT_BONE, "hips", "root", "upperleg.l", "upperleg.r", POTION_HAND_BONE]:
		if skeleton.find_bone(bone) < 0:
			errors.append("Bone '%s' tidak ada di %s" % [bone, SKELETON_PATH])
	if not errors.is_empty():
		return errors
	var spine := skeleton.find_bone(ATTACK_FILTER_ROOT_BONE)
	var upper_bones: Array[String] = []
	for bone in skeleton.get_bone_count():
		var cursor := bone
		while cursor >= 0 and cursor != spine:
			cursor = skeleton.get_bone_parent(cursor)
		if cursor == spine:
			upper_bones.append(skeleton.get_bone_name(bone))
	for excluded in ["root", "hips", "upperleg.l", "upperleg.r"]:
		if upper_bones.has(excluded):
			errors.append("Bone '%s' seharusnya bukan keturunan '%s'" % [excluded, ATTACK_FILTER_ROOT_BONE])
	if not errors.is_empty():
		return errors

	var root := AnimationNodeBlendTree.new()
	var base_clips: Array[StringName] = [&"idle", &"walk", &"run"]
	if jump_enabled:
		base_clips.append_array(JUMP_CLIPS.keys())
	var base_names: Array[String] = []
	for clip in base_clips:
		base_names.append(String(clip))
	_base_node = _clip_transition(root, &"base", base_clips, base_names, Vector2(0, 0),
			{&"walk": &"walk_scale", &"run": &"run_scale"})
	_base_node.xfade_time = 0.15

	var block := AnimationNodeBlend2.new()
	_upper_filter(block, upper_bones)
	root.add_node(&"block", block, Vector2(300, 0))
	root.connect_node(&"block", 0, &"base")
	root.connect_node(&"block", 1, _clip_node(root, &"block", Vector2(0, 300)))

	var drink := AnimationNodeOneShot.new()
	drink.fadein_time = 0.15
	drink.fadeout_time = 0.2
	_upper_filter(drink, upper_bones)
	root.add_node(&"drink", drink, Vector2(600, 0))
	root.connect_node(&"drink", 0, &"block")
	root.connect_node(&"drink", 1, _clip_node(root, &"drink", Vector2(300, 300)))

	var attack := AnimationNodeOneShot.new()
	attack.fadein_time = ATTACK_FADE_IN
	attack.fadeout_time = ATTACK_FADE_OUT
	_attack_node = attack
	_upper_filter(attack, upper_bones)
	root.add_node(&"attack", attack, Vector2(900, 0))
	root.connect_node(&"attack", 0, &"drink")
	var attack_clips: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]
	var attack_names: Array[String] = ["attack_1", "attack_2", "attack_3"]
	_clip_transition(root, &"attack_pick", attack_clips, attack_names, Vector2(600, 400))
	root.add_node(&"attack_scale", AnimationNodeTimeScale.new(), Vector2(750, 400))
	root.connect_node(&"attack_scale", 0, &"attack_pick")
	root.connect_node(&"attack", 1, &"attack_scale")

	var dodge := AnimationNodeOneShot.new()
	dodge.fadein_time = 0.04
	dodge.fadeout_time = DODGE_FADE_OUT
	_dodge_node = dodge
	root.add_node(&"dodge", dodge, Vector2(1200, 0))
	root.connect_node(&"dodge", 0, &"attack")
	var dodge_names: Array[String] = ["dodge_forward", "dodge_back", "dodge_left", "dodge_right"]
	_clip_transition(root, &"dodge_pick", DODGE_CLIPS, dodge_names, Vector2(900, 800))
	root.add_node(&"dodge_scale", AnimationNodeTimeScale.new(), Vector2(1050, 800))
	root.connect_node(&"dodge_scale", 0, &"dodge_pick")
	root.connect_node(&"dodge", 1, &"dodge_scale")

	var life := AnimationNodeTransition.new()
	life.input_count = 2
	life.xfade_time = 0.1
	life.set_input_name(0, "alive")
	life.set_input_name(1, "dead")
	root.add_node(&"life", life, Vector2(1500, 0))
	root.connect_node(&"life", 0, &"dodge")
	root.connect_node(&"life", 1, _clip_node(root, &"death", Vector2(1200, 1100)))
	root.connect_node(&"output", 0, &"life")

	_tree = AnimationTree.new()
	_tree.name = &"AnimationTree"
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(_model)
	_tree.anim_player = _tree.get_path_to(_anim)
	# Animation tree and combat clocks advance in the same physics step.
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_tree.tree_root = root
	_tree.active = true
	_base_state = &"idle"
	_tree.set(PARAM_BASE, "idle")
	_tree.set(PARAM_LIFE, "alive")
	_tree.set(PARAM_ATTACK_PICK, "attack_1")
	_tree.set(PARAM_DODGE_PICK, "dodge_forward")
	errors.append_array(_attach_potion_prop(skeleton))
	return errors


## Potion bottle in the left hand (the sword stays in the right); visible only during the drink's raised phase.
func _attach_potion_prop(skeleton: Skeleton3D) -> PackedStringArray:
	var scene := load(POTION_PROP) as PackedScene
	if scene == null:
		return PackedStringArray(["Gagal load %s" % POTION_PROP])
	var attachment := BoneAttachment3D.new()
	attachment.name = &"PotionAttachment"
	attachment.bone_name = POTION_HAND_BONE
	skeleton.add_child(attachment)
	_bottle = scene.instantiate() as Node3D
	_bottle.name = &"PotionBottle"
	_bottle.transform = DrinkAnimation.bottle_transform()
	_bottle.visible = false
	attachment.add_child(_bottle)
	return PackedStringArray()


## Duplicates only the needed clips (idle/walk, plus jump/combat clips when enabled); source imports stay untouched.
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
			if config.get("strip_root", false):
				var root_track := animation.find_track(NodePath("%s:root" % SKELETON_PATH), Animation.TYPE_POSITION_3D)
				if root_track >= 0:
					animation.remove_track(root_track)
			for track in animation.get_track_count():
				var path := String(animation.track_get_path(track))
				var node_path := NodePath(path.get_slice(":", 0))
				if _model.get_node_or_null(node_path) != skeleton or skeleton.find_bone(path.get_slice(":", 1)) < 0:
					errors.append("%s: track %s tidak cocok dengan Rogue" % [clip_name, path])
			library.add_animation(mode, animation)
		source.free()
	if combat_enabled and errors.is_empty():
		var drink := DrinkAnimation.build(library.get_animation(&"idle"), SKELETON_PATH, errors)
		if drink != null:
			library.add_animation(&"drink", drink)
	if errors.is_empty():
		_anim.add_animation_library(&"", library)
		if combat_enabled:
			errors.append_array(_build_tree(skeleton))
	return errors


## Center of the hurtbox's first CollisionShape3D (the Area3D origin may sit at the feet).
func _hurtbox_center(area: Node) -> Vector3:
	for child in area.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return (area as Node3D).global_position
