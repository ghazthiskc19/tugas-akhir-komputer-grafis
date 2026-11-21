extends CharacterBody3D
## Configurable enemy. One module, three archetypes ("standard", "heavy", "ranged") whose differences are DATA
## (ARCHETYPES): health, speed, ranges, attack timing, hit volume, stagger rules, projectile and clips.
##
## States: IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE ... ; STAGGER (hurt); RETURN (leash); DEAD.
## Attack contract: all damage goes through player.receive_damage(int) (never Health directly), so block/dodge work.
## The telegraph shows the real hit volume (melee box / projectile lane), clipped by world geometry the same way the
## damage query is clipped, so nothing hits through a wall. Contacts layers: world 1, player 2, hurtbox 4, enemy body 8.

signal defeated(enemy_id: StringName)
signal state_changed(state_name: StringName)

const GENERAL := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_General.glb"
const MOVEMENT := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_MovementBasic.glb"
const MELEE := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_CombatMelee.glb"
const RANGED := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_CombatRanged.glb"
const PROJECTILE_SCRIPT := preload("res://scripts/enemies/enemy_projectile.gd")

const WORLD_MASK := 1
const PLAYER_MASK := 2
const ENEMY_GROUP := &"enemies"
const PLAYER_GROUP := &"player"
const GRAVITY := 20.0
const CHEST_HEIGHT := 1.0
const FEELER_LENGTH := 1.8
const FEELER_ANGLE := 0.7

enum State { IDLE, CHASE, WINDUP, ACTIVE, RECOVERY, STAGGER, RETURN, DEAD }

## Per-archetype data. `clips`: logical name -> [file, clip, loop]. `strike`: fraction of the attack clip
## where the blow starts/ends; the clip is time-mapped so that moment coincides with the ACTIVE phase.
## Strike fractions are estimates from the clip shapes (not measured).
const ARCHETYPES := {
	&"standard": {
		"max_health": 60, "move_speed": 2.6, "turn_rate": 8.0,
		"detect_range": 11.0, "leash_range": 20.0, "attack_range": 1.7, "stop_distance": 1.3,
		"windup": 0.6, "active": 0.15, "recovery": 0.75, "cooldown": 0.8,
		"damage": 12, "hit_width": 1.6, "hit_height": 1.5, "hit_length": 2.0,
		"track_until": 0.6, "windup_turn_rate": 3.0,
		"stagger_time": 0.45, "stagger_interrupts_windup": true, "stagger_interrupts_active": true,
		"stagger_immunity": 0.4,
		"model_scale": 1.0, "walk_anim_speed": 1.2,
		"strike": Vector2(0.35, 0.6),
		"telegraph_windup": Color(1.0, 0.75, 0.1, 0.55), "telegraph_active": Color(1.0, 0.12, 0.05, 0.8),
		"clips": {
			&"idle": [GENERAL, "Idle_A", true], &"walk": [MOVEMENT, "Walking_B", true],
			&"attack": [MELEE, "Melee_1H_Attack_Chop", false], &"hurt": [GENERAL, "Hit_A", false],
			&"death": [GENERAL, "Death_A", false],
		},
	},
	&"heavy": {
		"max_health": 160, "move_speed": 1.7, "turn_rate": 4.0,
		"detect_range": 10.0, "leash_range": 18.0, "attack_range": 2.5, "stop_distance": 1.9,
		"windup": 1.15, "active": 0.2, "recovery": 1.6, "cooldown": 1.2,
		"damage": 32, "hit_width": 2.6, "hit_height": 1.8, "hit_length": 3.0,
		"track_until": 0.45, "windup_turn_rate": 2.0,
		"stagger_time": 0.3, "stagger_interrupts_windup": false, "stagger_interrupts_active": false,
		"stagger_immunity": 0.8,
		"model_scale": 1.25, "walk_anim_speed": 0.8,
		"strike": Vector2(0.45, 0.65),
		"telegraph_windup": Color(1.0, 0.45, 0.0, 0.55), "telegraph_active": Color(0.9, 0.0, 0.0, 0.85),
		"clips": {
			&"idle": [MELEE, "Melee_2H_Idle", true], &"walk": [MOVEMENT, "Walking_A", true],
			&"attack": [MELEE, "Melee_2H_Attack_Chop", false], &"hurt": [GENERAL, "Hit_B", false],
			&"death": [GENERAL, "Death_B", false],
		},
	},
	&"ranged": {
		"max_health": 40, "move_speed": 2.4, "turn_rate": 7.0,
		"detect_range": 15.0, "leash_range": 22.0, "attack_range": 12.0, "stop_distance": 7.0,
		"retreat_range": 4.5, "attack_min": 3.0,
		"windup": 0.9, "active": 0.1, "recovery": 0.8, "cooldown": 1.4,
		"damage": 10, "hit_width": 0.44, "hit_height": 0.44, "hit_length": 22.0,
		"projectile_speed": 13.0, "projectile_lifetime": 1.7, "projectile_radius": 0.22,
		"muzzle_height": 1.3, "muzzle_forward": 0.6,
		"track_until": 0.7, "windup_turn_rate": 5.0,
		"stagger_time": 0.5, "stagger_interrupts_windup": true, "stagger_interrupts_active": true,
		"stagger_immunity": 0.4,
		"model_scale": 1.0, "walk_anim_speed": 1.1,
		"strike": Vector2(0.45, 0.6),
		"telegraph_windup": Color(0.2, 0.75, 1.0, 0.6), "telegraph_active": Color(1.0, 0.2, 0.1, 0.85),
		"clips": {
			&"idle": [GENERAL, "Idle_A", true], &"walk": [MOVEMENT, "Walking_A", true],
			&"attack": [RANGED, "Ranged_1H_Shoot", false], &"hurt": [GENERAL, "Hit_A", false],
			&"death": [GENERAL, "Death_A", false],
		},
	},
}

## Animation resources shared across instances: "file|clip|loop" -> Animation.
static var _clip_cache: Dictionary = {}

@export var enemy_id: StringName = &""
@export var player_path: NodePath
@export_enum("standard", "heavy", "ranged") var archetype: String = "standard"
## Optional per-instance data overrides, e.g. {"max_health": 80}. Keys as in ARCHETYPES.
@export var overrides: Dictionary = {}

var state := State.IDLE
var cfg: Dictionary = {}

var _health: Node
var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _label: Label3D
var _outline: MeshInstance3D
var _fill: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _flash_tween: Tween
var _player: Node3D
var _spawn_xform := Transform3D.IDENTITY
var _state_time := 0.0
var _cooldown := 0.0
var _immunity := 0.0
var _aggro := false
var _last_hp := 0
var _defeated_emitted := false
var _hit_done := false
var _fired := false
var _aim_dir := Vector3.FORWARD
var _clip_len := 1.0
var _hit_shape := BoxShape3D.new()
var _hit_query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _strafe_sign := 1.0
var _strafe_time := 0.0
var _player_lookup_timer := 0.0
var _current_clip: StringName = &""
var _current_speed := 1.0


func _ready() -> void:
	if not ARCHETYPES.has(StringName(archetype)):
		push_error("Enemy %s: archetype '%s' tidak dikenal" % [name, archetype])
		set_physics_process(false)
		return
	cfg = (ARCHETYPES[StringName(archetype)] as Dictionary).duplicate(true)
	cfg.merge(overrides, true)
	if enemy_id == &"":
		enemy_id = StringName(name)
	add_to_group(ENEMY_GROUP)
	_spawn_xform = global_transform
	_health = get_node_or_null("Health")
	_model = get_node_or_null("Model") as Node3D
	_anim = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _health == null or _model == null or _anim == null:
		push_error("Enemy %s: node Health/Model/AnimationPlayer wajib ada" % name)
		set_physics_process(false)
		return
	_health.max_health = int(cfg["max_health"])
	_health.current_health = int(cfg["max_health"])
	_last_hp = _health.current_health
	_health.health_changed.connect(_on_health_changed)
	_health.dead.connect(_on_health_dead)
	_model.scale = Vector3.ONE * float(cfg["model_scale"])
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_error("Enemy %s: Skeleton3D tidak ada di model" % name)
	_label = get_node_or_null("HealthLabel") as Label3D
	_build_library()
	_build_telegraph()
	_build_flash()
	_hit_query.shape = _hit_shape
	_hit_query.collision_mask = PLAYER_MASK
	_hit_query.collide_with_bodies = true
	_hit_query.collide_with_areas = false
	_hit_query.exclude = [get_rid()]
	_ray.collision_mask = WORLD_MASK
	_ray.exclude = [get_rid()]
	_update_label()
	_play_loop(&"idle")


func is_dead() -> bool:
	return state == State.DEAD


func get_state_name() -> StringName:
	return StringName(State.keys()[state].to_lower())


## Restores a LIVING enemy to its spawn: position, HP, state, cooldowns, projectiles. Dead enemies stay dead.
func reset_encounter() -> void:
	if state == State.DEAD or _health.is_dead:
		return
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		if projectile.get("shooter") == self:
			projectile.queue_free()
	global_transform = _spawn_xform
	velocity = Vector3.ZERO
	_health.current_health = _health.max_health
	_last_hp = _health.current_health
	_health.health_changed.emit(_health.current_health, _health.max_health)
	_aggro = false
	_cooldown = 0.0
	_immunity = 0.0
	_hit_done = false
	_fired = false
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_mat.albedo_color.a = 0.0
	_hide_telegraph()
	_current_clip = &""
	_set_state(State.IDLE)
	_play_loop(&"idle")


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_immunity = maxf(_immunity - delta, 0.0)
	_resolve_player(delta)
	var player_alive := _player != null and not _player_is_dead()
	if not player_alive:
		_aggro = false
	match state:
		State.IDLE:
			_tick_idle(delta, player_alive)
		State.CHASE:
			_tick_chase(delta, player_alive)
		State.WINDUP:
			_tick_windup(delta)
		State.ACTIVE:
			_tick_active()
		State.RECOVERY:
			_tick_recovery(delta)
		State.STAGGER:
			_apply_move(Vector3.ZERO, delta, 12.0)
			if _state_time >= float(cfg["stagger_time"]):
				_cooldown = maxf(_cooldown, 0.25)
				_set_state(State.CHASE if _aggro else State.RETURN)
		State.RETURN:
			_tick_return(delta, player_alive)


func _tick_idle(delta: float, player_alive: bool) -> void:
	_apply_move(Vector3.ZERO, delta, 12.0)
	_play_loop(&"idle")
	if player_alive and _can_detect():
		_aggro = true
		_set_state(State.CHASE)


func _tick_return(delta: float, player_alive: bool) -> void:
	var to_spawn := _spawn_xform.origin - global_position
	to_spawn.y = 0.0
	if to_spawn.length() < 0.4:
		_set_state(State.IDLE)
		return
	var dir := to_spawn.normalized()
	_move_toward_dir(dir, float(cfg["move_speed"]), delta)
	# Returning enemies ignore the player until home (leash), except when it is a fresh close detection at spawn.
	if player_alive and _flat_distance_to(_player.global_position) < 2.5 and _player_within_leash():
		_aggro = true
		_set_state(State.CHASE)


func _tick_chase(delta: float, player_alive: bool) -> void:
	if not player_alive or not _player_within_leash() or _flat_distance_to(_spawn_xform.origin) > float(cfg["leash_range"]):
		_aggro = false
		_set_state(State.RETURN)
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)
	var wanted := Vector3.ZERO
	if archetype == "ranged":
		wanted = _ranged_movement(dir, dist, delta)
	elif dist > float(cfg["stop_distance"]):
		wanted = dir
	_face(dir, float(cfg["turn_rate"]), delta)
	if wanted != Vector3.ZERO:
		_move_toward_dir(wanted, float(cfg["move_speed"]), delta)
	else:
		_apply_move(Vector3.ZERO, delta, 12.0)
		_play_loop(&"idle")
	if _cooldown <= 0.0 and _can_start_attack(dir, dist):
		_start_attack()


func _ranged_movement(dir: Vector3, dist: float, delta: float) -> Vector3:
	var retreat := float(cfg["retreat_range"])
	if dist < retreat:
		return -dir
	if dist > float(cfg["stop_distance"]) + 1.5:
		return dir
	# Hold ground and sidestep so the shooter is not a static target.
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = randf_range(1.0, 2.2)
		_strafe_sign = -_strafe_sign
	return dir.cross(Vector3.UP) * _strafe_sign * 0.6


func _can_start_attack(dir: Vector3, dist: float) -> bool:
	if dist > float(cfg["attack_range"]):
		return false
	if archetype == "ranged":
		if dist < float(cfg["attack_min"]) or not _has_los_to_player(_muzzle_position()):
			return false
	elif not _has_los_to_player(global_position + Vector3.UP * CHEST_HEIGHT):
		return false
	return global_basis.z.dot(dir) > 0.9


# ---------------------------------------------------------------- attack phases

func _start_attack() -> void:
	_hit_done = false
	_fired = false
	_aim_dir = _flat_forward()
	_set_state(State.WINDUP)
	_play_attack_pose(0.0)


func _tick_windup(delta: float) -> void:
	var windup := float(cfg["windup"])
	var progress := clampf(_state_time / windup, 0.0, 1.0)
	_apply_move(Vector3.ZERO, delta, 18.0)
	# Tracking stops at track_until: the telegraph then shows the committed lane/box.
	if progress < float(cfg["track_until"]) and _player != null:
		var dir := _player.global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			_face(dir.normalized(), float(cfg["windup_turn_rate"]), delta)
	_aim_dir = _flat_forward()
	_show_telegraph(progress, false)
	_play_attack_pose(progress * float(cfg["strike"].x) * _clip_len)
	if _state_time >= windup:
		_set_state(State.ACTIVE)


func _tick_active() -> void:
	var active := float(cfg["active"])
	var progress := clampf(_state_time / active, 0.0, 1.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_show_telegraph(1.0, true)
	var strike: Vector2 = cfg["strike"]
	_play_attack_pose(lerpf(strike.x, strike.y, progress) * _clip_len)
	if not _hit_done:
		if archetype == "ranged":
			_fire_projectile()
			_hit_done = true
		elif _melee_hit():
			_hit_done = true
	if _state_time >= active:
		_set_state(State.RECOVERY)


func _tick_recovery(delta: float) -> void:
	var recovery := float(cfg["recovery"])
	var progress := clampf(_state_time / recovery, 0.0, 1.0)
	_apply_move(Vector3.ZERO, delta, 18.0)
	_hide_telegraph()
	var strike: Vector2 = cfg["strike"]
	_play_attack_pose(lerpf(strike.y, 1.0, progress) * _clip_len)
	if _state_time >= recovery:
		_cooldown = float(cfg["cooldown"])
		_set_state(State.CHASE if _aggro else State.RETURN)


## One query per swing: box in front of the enemy, clipped by world. Needs a clear chest-to-chest line.
func _melee_hit() -> bool:
	var reach := _clipped_reach(float(cfg["hit_length"]))
	var height := float(cfg["hit_height"])
	_hit_shape.size = Vector3(float(cfg["hit_width"]), height, reach)
	_hit_query.transform = Transform3D(
		global_basis, global_position + _aim_dir * (reach * 0.5) + Vector3.UP * (height * 0.5 + 0.1))
	var hits := get_world_3d().direct_space_state.intersect_shape(_hit_query, 8)
	for hit in hits:
		var target := _find_damageable_player(hit["collider"] as Node)
		if target == null:
			continue
		if not _has_los_to_point(global_position + Vector3.UP * CHEST_HEIGHT, target.global_position + Vector3.UP * CHEST_HEIGHT):
			continue
		target.receive_damage(int(cfg["damage"]))
		return true
	return false


func _fire_projectile() -> void:
	if _fired:
		return
	_fired = true
	var projectile := Node3D.new()
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.set("velocity", _aim_dir * float(cfg["projectile_speed"]))
	projectile.set("damage", int(cfg["damage"]))
	projectile.set("lifetime", float(cfg["projectile_lifetime"]))
	projectile.set("radius", float(cfg["projectile_radius"]))
	projectile.set("shooter", self)
	projectile.set("shooter_rid", get_rid())
	var host := get_parent()
	host.add_child(projectile)
	projectile.global_position = _muzzle_position()


func _muzzle_position() -> Vector3:
	var forward := _flat_forward()
	return global_position + forward * float(cfg.get("muzzle_forward", 0.5)) + Vector3.UP * float(cfg.get("muzzle_height", 1.3))


# ---------------------------------------------------------------- telegraph

func _build_telegraph() -> void:
	_outline_mat = _telegraph_material()
	_fill_mat = _telegraph_material()
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_outline = MeshInstance3D.new()
	_outline.name = "TelegraphOutline"
	_outline.mesh = unit
	_outline.material_override = _outline_mat
	_outline.top_level = true
	_outline.visible = false
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)
	_fill = MeshInstance3D.new()
	_fill.name = "TelegraphFill"
	_fill.mesh = unit
	_fill.material_override = _fill_mat
	_fill.top_level = true
	_fill.visible = false
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)


func _telegraph_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Outline = full hit volume (already clipped by world); fill grows along the facing during wind-up and
## fills completely (brighter, red) while the hit is live.
func _show_telegraph(progress: float, active: bool) -> void:
	var reach := _clipped_reach(float(cfg["hit_length"]), _telegraph_origin())
	var width := float(cfg["hit_width"])
	var height := float(cfg["hit_height"])
	var base := global_position + Vector3.UP * (height * 0.5 + 0.1)
	if archetype == "ranged":
		base = _muzzle_position()
	var forward := _aim_dir
	var xform := Transform3D(Basis.looking_at(forward, Vector3.UP), base + forward * (reach * 0.5))
	var color: Color = cfg["telegraph_active"] if active else cfg["telegraph_windup"]
	_outline.visible = true
	_fill.visible = true
	_outline.global_transform = xform.scaled_local(Vector3(width, height, maxf(reach, 0.05)))
	_outline_mat.albedo_color = Color(color.r, color.g, color.b, 0.18)
	var filled := maxf(reach * progress, 0.02)
	var fill_xform := Transform3D(xform.basis, base + forward * (filled * 0.5))
	_fill.global_transform = fill_xform.scaled_local(Vector3(width * 0.98, height * 0.98, filled))
	_fill_mat.albedo_color = color


func _hide_telegraph() -> void:
	if _outline != null:
		_outline.visible = false
		_fill.visible = false


func _telegraph_origin() -> Vector3:
	if archetype == "ranged":
		return _muzzle_position()
	return global_position + Vector3.UP * CHEST_HEIGHT


## Distance along _aim_dir before world geometry; melee hits and projectile lanes both use this clip.
func _clipped_reach(full: float, origin: Vector3 = Vector3.INF) -> float:
	if origin == Vector3.INF:
		origin = global_position + Vector3.UP * CHEST_HEIGHT
	_ray.from = origin
	_ray.to = origin + _aim_dir * full
	var result := get_world_3d().direct_space_state.intersect_ray(_ray)
	if result.is_empty():
		return full
	return maxf(origin.distance_to(result["position"]) - 0.05, 0.2)


# ---------------------------------------------------------------- movement and avoidance

func _move_toward_dir(dir: Vector3, speed: float, delta: float) -> void:
	var steered := _steer(dir)
	_face_move(steered, delta)
	_apply_move(steered * speed, delta, 10.0)
	_play_loop(&"walk", float(cfg["walk_anim_speed"]))


func _apply_move(horizontal: Vector3, delta: float, accel: float) -> void:
	velocity.x = move_toward(velocity.x, horizontal.x, accel * delta * 4.0)
	velocity.z = move_toward(velocity.z, horizontal.z, accel * delta * 4.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _face(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length() < 0.001:
		return
	var target := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(rate * delta, 0.0, 1.0))


## Walking turns toward travel unless the caller already faces the player (ranged strafing/retreat).
func _face_move(dir: Vector3, delta: float) -> void:
	if archetype == "ranged" and _aggro:
		return
	_face(dir, float(cfg["turn_rate"]), delta)


## Ray feelers (forward, +/-FEELER_ANGLE) against world and other enemies. Pushes the wanted direction along
## the free side; move_and_slide handles actual collision.
func _steer(dir: Vector3) -> Vector3:
	if dir == Vector3.ZERO:
		return dir
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = WORLD_MASK | 8
	query.exclude = [get_rid()]
	var push := Vector3.ZERO
	var blocked_center := false
	for angle in [0.0, FEELER_ANGLE, -FEELER_ANGLE]:
		var feeler: Vector3 = dir.rotated(Vector3.UP, angle)
		query.from = origin
		query.to = origin + feeler * FEELER_LENGTH
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var weight := 1.0 - origin.distance_to(hit["position"]) / FEELER_LENGTH
		var normal: Vector3 = hit["normal"]
		normal.y = 0.0
		if normal.length() < 0.01:
			continue
		push += normal.normalized() * weight
		if angle == 0.0:
			blocked_center = true
			var tangent := normal.normalized().cross(Vector3.UP)
			if tangent.dot(dir) < 0.0:
				tangent = -tangent
			push += tangent * weight * 1.5
	if push == Vector3.ZERO:
		return dir
	var result := dir + push
	result.y = 0.0
	if blocked_center and result.dot(dir) < 0.0:
		result = push
	return result.normalized()


# ---------------------------------------------------------------- perception

func _resolve_player(delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = null
	_player_lookup_timer -= delta
	if _player_lookup_timer > 0.0:
		return
	_player_lookup_timer = 0.5
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D


func _player_is_dead() -> bool:
	return _player.has_method("is_dead") and _player.is_dead()


func _can_detect() -> bool:
	if _flat_distance_to(_player.global_position) > float(cfg["detect_range"]):
		return false
	return _has_los_to_player(global_position + Vector3.UP * CHEST_HEIGHT)


func _player_within_leash() -> bool:
	return _player.global_position.distance_to(_spawn_xform.origin) <= float(cfg["leash_range"])


func _has_los_to_player(from: Vector3) -> bool:
	return _has_los_to_point(from, _player.global_position + Vector3.UP * CHEST_HEIGHT)


func _has_los_to_point(from: Vector3, to: Vector3) -> bool:
	_ray.from = from
	_ray.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _flat_distance_to(point: Vector3) -> float:
	var d := point - global_position
	d.y = 0.0
	return d.length()


func _flat_forward() -> Vector3:
	var f := global_basis.z
	f.y = 0.0
	return f.normalized()


## Walks up from a physics collider to the node exposing receive_damage (the player root).
func _find_damageable_player(collider: Node) -> Node3D:
	var node := collider
	while node != null:
		if node.has_method("receive_damage"):
			return node as Node3D
		node = node.get_parent()
	return null


# ---------------------------------------------------------------- damage reactions

func _on_health_changed(current: int, maximum: int) -> void:
	var took_damage := current < _last_hp
	_last_hp = current
	_update_label()
	if not took_damage or current <= 0 or state == State.DEAD:
		return
	_flash()
	# Being hit wakes the enemy; leash still applies.
	if not _aggro and _player != null and not _player_is_dead():
		_aggro = true
		if state == State.IDLE or state == State.RETURN:
			_set_state(State.CHASE)
	if _immunity > 0.0:
		return
	match state:
		State.WINDUP:
			if not cfg["stagger_interrupts_windup"]:
				return
		State.ACTIVE:
			if not cfg["stagger_interrupts_active"]:
				return
		State.STAGGER:
			return
	_hide_telegraph()
	_immunity = float(cfg["stagger_time"]) + float(cfg["stagger_immunity"])
	_set_state(State.STAGGER)
	var hurt := _anim.get_animation(&"hurt")
	_current_clip = &"hurt"
	_anim.play(&"hurt", 0.05, hurt.length / maxf(float(cfg["stagger_time"]), 0.05))


func _on_health_dead() -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	_hide_telegraph()
	velocity = Vector3.ZERO
	_aggro = false
	_disable_collisions()
	_current_clip = &"death"
	_anim.play(&"death", 0.1, 1.0)
	_update_label()
	if not _defeated_emitted:
		_defeated_emitted = true
		defeated.emit(enemy_id)


func _disable_collisions() -> void:
	# Deferred: the kill usually happens inside the player's physics query callback.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for shape in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("collision_layer", 0)


func _build_flash() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _flash_mat


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_mat.albedo_color = Color(1, 1, 1, 0.55)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.15)


func _update_label() -> void:
	if _label != null:
		_label.text = "KO" if _health.is_dead else "%s %d/%d" % [archetype.to_upper(), _health.current_health, _health.max_health]


# ---------------------------------------------------------------- state + animation

func _set_state(next: State) -> void:
	if state == State.DEAD and next != State.DEAD:
		return
	state = next
	_state_time = 0.0
	state_changed.emit(get_state_name())


func _play_loop(clip: StringName, speed := 1.0) -> void:
	if _current_clip == clip and is_equal_approx(_current_speed, speed):
		return
	_current_clip = clip
	_current_speed = speed
	_anim.play(clip, 0.15, speed)


## The attack clip is driven by phase time (windup/strike/recovery) rather than free-running, so the visible
## blow lands exactly in the ACTIVE phase.
func _play_attack_pose(clip_time: float) -> void:
	if _current_clip != &"attack":
		_current_clip = &"attack"
		_anim.play(&"attack", 0.0, 0.0)
	_anim.seek(clip_time, true)


func _build_library() -> void:
	var library := AnimationLibrary.new()
	var clips: Dictionary = cfg["clips"]
	for logical: StringName in clips:
		var spec: Array = clips[logical]
		var animation := _load_clip(spec[0], spec[1], spec[2])
		if animation == null:
			continue
		library.add_animation(logical, animation)
	for required in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
		if not library.has_animation(required):
			push_error("Enemy %s: klip '%s' gagal dibuat; archetype %s tidak dapat dimainkan" % [name, required, archetype])
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", library)
	_anim.root_node = _anim.get_path_to(_model)
	if library.has_animation(&"attack"):
		_clip_len = library.get_animation(&"attack").length


func _load_clip(file: String, clip: String, loop: bool) -> Animation:
	var key := "%s|%s|%s" % [file, clip, loop]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var scene := load(file) as PackedScene
	if scene == null:
		push_error("Enemy %s: gagal load %s" % [name, file])
		return null
	var source := scene.instantiate()
	var animation: Animation = null
	var players := source.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		push_error("Enemy %s: klip %s tidak ada di %s" % [name, clip, file])
	else:
		animation = (players[0] as AnimationPlayer).get_animation(clip).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		_validate_tracks(animation, clip)
		_clip_cache[key] = animation
	source.free()
	return animation


func _validate_tracks(animation: Animation, clip: String) -> void:
	if _skeleton == null:
		return
	for track in animation.get_track_count():
		var path := String(animation.track_get_path(track))
		var node_path := NodePath(path.get_slice(":", 0))
		if _model.get_node_or_null(node_path) != _skeleton or _skeleton.find_bone(path.get_slice(":", 1)) < 0:
			push_warning("Enemy %s: klip %s track %s tidak cocok dengan rig model" % [name, clip, path])
			return
