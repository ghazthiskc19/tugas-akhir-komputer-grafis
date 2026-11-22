extends Node3D
## Ground telegraph of ONE boss attack zone. The polygon given to set_zone() (world XZ) is the same polygon that
## contains_circle() tests, so what is drawn is exactly the damage area (the caller already clipped it by world geometry).
## Visual: faint full-area outline, a fill that grows with the wind-up progress, and a bright rim.

enum Fill { RADIAL, LANE }

const GROUND_Y := 0.035
const RIM_WIDTH := 0.16
const PLAYER_RADIUS := 0.35

var polygon := PackedVector2Array()

var _outline: MeshInstance3D
var _fill: MeshInstance3D
var _rim: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _fill_mode := Fill.RADIAL
var _color := Color(1.0, 0.7, 0.1)
var _shown := false


func _ready() -> void:
	add_to_group(&"boss_telegraph")
	_outline_mat = _material(10)
	_fill_mat = _material(11)
	_rim_mat = _material(12)
	_outline = _instance(&"Outline", _outline_mat)
	_fill = _instance(&"Fill", _fill_mat)
	_rim = _instance(&"Rim", _rim_mat)
	_apply_color(_color, 0.5)
	clear()


func is_shown() -> bool:
	return _shown


## `poly` is the damage polygon in world XZ; `origin`/`yaw` define the frame the fill grows in (origin = growth centre,
## yaw = forward = Vector3(sin yaw, 0, cos yaw)).
func set_zone(poly: PackedVector2Array, origin: Vector3, yaw: float, mode: int) -> void:
	polygon = poly
	_fill_mode = mode as Fill
	var local := PackedVector2Array()
	var rotation_back := Basis(Vector3.UP, -yaw)
	for p in poly:
		var v := rotation_back * Vector3(p.x - origin.x, 0.0, p.y - origin.z)
		local.append(Vector2(v.x, v.z))
	var area := _fan(local)
	_outline.mesh = area
	_fill.mesh = area
	_rim.mesh = _rim_strip(local)
	var xform := Transform3D(Basis(Vector3.UP, yaw), Vector3(origin.x, GROUND_Y, origin.z))
	_outline.global_transform = xform
	_fill.global_transform = xform
	_rim.global_transform = xform
	_shown = true
	_outline.visible = true
	_fill.visible = true
	_rim.visible = true


## 0..1 growth of the fill (radial: from the origin outward; lane: along forward).
func set_progress(progress: float) -> void:
	if not _shown:
		return
	var p := clampf(progress, 0.02, 1.0)
	var basis := _outline.global_transform.basis
	var scale_vec := Vector3(p, 1.0, p) if _fill_mode == Fill.RADIAL else Vector3(1.0, 1.0, p)
	_fill.global_transform = Transform3D(basis.orthonormalized() * Basis.from_scale(scale_vec), _outline.global_position)


func set_color(color: Color, fill_alpha := 0.5) -> void:
	_color = color
	_apply_color(color, fill_alpha)


func clear() -> void:
	_shown = false
	polygon = PackedVector2Array()
	for node in [_outline, _fill, _rim]:
		if node != null:
			node.visible = false


## True when any of five sample points of the player's body circle lies inside the polygon.
func contains_circle(position: Vector3, radius := PLAYER_RADIUS) -> bool:
	if polygon.size() < 3:
		return false
	var c := Vector2(position.x, position.z)
	for offset in [Vector2.ZERO, Vector2(radius, 0.0), Vector2(-radius, 0.0), Vector2(0.0, radius), Vector2(0.0, -radius)]:
		if Geometry2D.is_point_in_polygon(c + offset, polygon):
			return true
	return false


func _apply_color(color: Color, fill_alpha: float) -> void:
	if _fill_mat == null:
		return
	_outline_mat.albedo_color = Color(color.r, color.g, color.b, 0.16)
	_fill_mat.albedo_color = Color(color.r, color.g, color.b, fill_alpha)
	_rim_mat.albedo_color = Color(minf(color.r + 0.25, 1.0), minf(color.g + 0.25, 1.0), minf(color.b + 0.25, 1.0), 0.95)


func _material(priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = priority
	return mat


func _instance(node_name: StringName, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.material_override = mat
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


static func _fan(points: PackedVector2Array) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	for p in points:
		vertices.append(Vector3(p.x, 0.0, p.y))
	var indices := PackedInt32Array()
	for i in points.size():
		indices.append_array([0, 1 + i, 1 + (i + 1) % points.size()])
	return _mesh(vertices, indices)


static func _rim_strip(points: PackedVector2Array) -> ArrayMesh:
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= maxf(points.size(), 1.0)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var edge := b - a
		if edge.length() < 0.01:
			continue
		var normal := Vector2(-edge.y, edge.x).normalized()
		if normal.dot(centroid - a) < 0.0:
			normal = -normal
		var base := vertices.size()
		for q in [a, b, b + normal * RIM_WIDTH, a + normal * RIM_WIDTH]:
			vertices.append(Vector3(q.x, 0.004, q.y))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return _mesh(vertices, indices)


static func _mesh(vertices: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if vertices.size() >= 3 and indices.size() >= 3:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
