class_name MouseWorldAim
extends Node
## I08 mouse aiming: cursor ray -> world point -> model heading + marker. Aim only, no attack.
## Needs GroundPlayer.external_facing = true. Rotates only the model node ($Rogue), never the body.
## Camera must expose is_orbiting() -> bool; heading freezes and marker hides while it is true.

const MARKER_COLOR := Color("#930031")
const RAY_LENGTH := 1000.0
const MIN_PLANE_DENOM := 0.0001
const MIN_AIM_DISTANCE := 0.3

@export var player_path: NodePath
@export var camera_path: NodePath
@export var debug_label_path: NodePath
@export var turn_rate := 14.0
## Fallback distance cap for the ground-plane point when the ray misses.
@export var max_aim_distance := 50.0
## Explicit policy: the model keeps facing the cursor in the air too (heading never depends on grounded).
@export var face_while_airborne := true
@export var marker_normal_offset := 0.03

var _player: CharacterBody3D
var _camera: Camera3D
var _model: Node3D
var _debug_label: Label
var _marker: Node3D
var _query := PhysicsRayQueryParameters3D.new()
var _focused := true
var _heading := 0.0 # yaw, atan2(dx, dz); last valid direction
## Last resolved aim point (world). Valid when has_target; has_surface_hit tells physics hit vs ground-plane fallback.
var target_position := Vector3.ZERO
var has_target := false
var has_surface_hit := false
var _source := "none"


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	_camera = get_node_or_null(camera_path) as Camera3D
	var errors := PackedStringArray()
	if _player == null:
		errors.append("player_path tidak menunjuk CharacterBody3D: '%s'" % player_path)
	elif _player.get_node_or_null("Rogue") as Node3D == null:
		errors.append("Node Rogue tidak ada di Player")
	if _camera == null:
		errors.append("camera_path tidak menunjuk Camera3D: '%s'" % camera_path)
	elif not _camera.has_method(&"is_orbiting"):
		errors.append("Kamera tidak punya is_orbiting() -> bool")
	if not errors.is_empty():
		push_error("Setup MouseWorldAim gagal:\n" + "\n".join(errors))
		set_physics_process(false)
		return
	_model = _player.get_node("Rogue") as Node3D
	_debug_label = get_node_or_null(debug_label_path) as Label
	_heading = _player.global_rotation.y + _model.rotation.y
	_query.collision_mask = 1
	_query.exclude = [_player.get_rid()]
	_build_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true


func _physics_process(delta: float) -> void:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	var orbiting: bool = _camera.call(&"is_orbiting")
	var active := _focused and not orbiting and viewport.get_visible_rect().has_point(mouse)
	if not active:
		_marker.visible = false
		has_target = false
		has_surface_hit = false
		_update_debug("beku" if _focused else "fokus hilang")
		return

	_resolve_target(mouse)
	if has_target:
		var to_point := target_position - _player.global_position
		to_point.y = 0.0
		if to_point.length() >= MIN_AIM_DISTANCE:
			_heading = atan2(to_point.x, to_point.z)
	# else: ray parallel/behind -> keep last valid heading, never zero or flip.

	if face_while_airborne or _player.is_on_floor():
		_model.global_rotation.y = lerp_angle(_model.global_rotation.y, _heading, 1.0 - exp(-turn_rate * delta))
	_update_debug(_source)


## Fills target_position/has_target/has_surface_hit/_source. Order: physics hit, then ground-plane fallback at the feet height.
func _resolve_target(mouse: Vector2) -> void:
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	_query.from = origin
	_query.to = origin + direction * RAY_LENGTH
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		target_position = hit["position"]
		_set_marker(target_position, hit["normal"])
		has_target = true
		has_surface_hit = true
		_source = "hit"
		return

	# Plane y = feet: t = (feet - origin.y) / direction.y. Needs a downward ray and t >= 0 (plane not behind the camera).
	var feet := _player.global_position.y
	if direction.y < -MIN_PLANE_DENOM and origin.y >= feet:
		var point := origin + direction * ((feet - origin.y) / direction.y)
		var offset := Vector3(point.x - _player.global_position.x, 0.0, point.z - _player.global_position.z)
		if offset.length() > max_aim_distance:
			offset = offset.normalized() * max_aim_distance
		target_position = Vector3(_player.global_position.x + offset.x, feet, _player.global_position.z + offset.z)
		_set_marker(target_position, Vector3.UP)
		has_target = true
		has_surface_hit = false
		_source = "bidang"
		return

	has_target = false
	has_surface_hit = false
	_marker.visible = false
	_source = "tak valid"


func _build_marker() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = MARKER_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.material = material
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.34
	ring.material = material
	_marker = Node3D.new()
	_marker.name = "AimMarker"
	_marker.top_level = true
	_marker.visible = false
	for mesh: Mesh in [sphere, ring]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(instance)
	# World-space sibling of the player, not a child (no inherited movement/rotation); no collision body.
	_player.get_parent().add_child.call_deferred(_marker)


func _set_marker(point: Vector3, normal: Vector3) -> void:
	_marker.visible = true
	var up := normal.normalized()
	_marker.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), point + up * marker_normal_offset)


func _update_debug(state: String) -> void:
	if _debug_label == null:
		return
	if has_target:
		_debug_label.text = "Bidik: %s • elevasi %+.2f m • arah %d°" % [
			state, target_position.y - _player.global_position.y, wrapi(int(rad_to_deg(_heading)), 0, 360)]
	else:
		_debug_label.text = "Bidik: %s" % state
