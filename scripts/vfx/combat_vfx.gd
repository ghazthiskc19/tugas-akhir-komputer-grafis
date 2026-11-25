extends Node3D
## Shared combat VFX hub. One instance lives under the SceneTree root (created lazily by the static helpers) and owns
## fixed pools built once: CPUParticles3D bursts (Kenney particle pack, CC0), flat slash arcs and ground rings
## (own procedural shaders). Nothing is allocated while playing: callers only reposition/restart pooled nodes.
## Compatibility renderer safe: unshaded materials, no lights, no compute.
##
## Usage: const Vfx := preload("res://scripts/vfx/combat_vfx.gd"); Vfx.hit_spark(self, pos, dir, false)

const SCRIPT_PATH := "res://scripts/vfx/combat_vfx.gd"
const HUB_NAME := &"CombatVfxHub"
const TEX := "res://assets/third_party/kenney/particle_pack/"

enum Kind { SPARK, FLASH, GLOW, DUST, DEBRIS, SMOKE, HEAL }

const GOLD := Color(1.0, 0.82, 0.3)
const STEEL := Color(0.5, 0.82, 1.0)
const HURT_RED := Color(1.0, 0.18, 0.1)
const ENEMY_ORANGE := Color(1.0, 0.85, 0.35)
const HEAL_GREEN := Color(0.62, 1.0, 0.78)

## amount / lifetime / size (m) / velocity range / spread (deg) / gravity y / additive / grow (end scale / start scale) /
## pool length / base color / texture / emission radius
const KIND_CFG := {
	Kind.SPARK: {"tex": "star_06", "amount": 12, "life": 0.36, "size": 0.42, "vmin": 3.0, "vmax": 7.0, "spread": 70.0,
		"gravity": -9.0, "add": false, "end": 0.0, "start": 1.0, "pool": 6, "radius": 0.05},
	Kind.FLASH: {"tex": "star_06", "amount": 1, "life": 0.14, "size": 1.9, "vmin": 0.0, "vmax": 0.0, "spread": 0.0,
		"gravity": 0.0, "add": false, "end": 0.2, "start": 1.0, "pool": 6, "radius": 0.0},
	Kind.GLOW: {"tex": "light_01", "amount": 1, "life": 0.22, "size": 2.3, "vmin": 0.0, "vmax": 0.0, "spread": 0.0,
		"gravity": 0.0, "add": false, "end": 0.3, "start": 0.7, "pool": 6, "radius": 0.0},
	Kind.DUST: {"tex": "smoke_04", "amount": 9, "life": 0.65, "size": 0.95, "vmin": 0.8, "vmax": 2.4, "spread": 85.0,
		"gravity": 0.6, "add": false, "end": 1.6, "start": 0.5, "pool": 5, "radius": 0.5},
	Kind.DEBRIS: {"tex": "dirt_01", "amount": 8, "life": 0.6, "size": 0.45, "vmin": 3.0, "vmax": 6.5, "spread": 55.0,
		"gravity": -18.0, "add": false, "end": 0.2, "start": 1.0, "pool": 3, "radius": 0.4},
	Kind.SMOKE: {"tex": "smoke_07", "amount": 6, "life": 0.9, "size": 1.1, "vmin": 0.4, "vmax": 1.3, "spread": 60.0,
		"gravity": 0.9, "add": false, "end": 1.5, "start": 0.6, "pool": 3, "radius": 0.3},
	Kind.HEAL: {"tex": "star_04", "amount": 18, "life": 1.0, "size": 0.55, "vmin": 0.7, "vmax": 1.6, "spread": 20.0,
		"gravity": 1.2, "add": false, "end": 0.0, "start": 1.0, "pool": 2, "radius": 0.55},
}

## Drawn after world transparents (telegraph boxes, rings) so effects stay readable inside them.
const FX_PRIORITY := 40
const SLASH_LIFT_DEG := 18.0
const SLASH_POOL := 6
const RING_POOL := 6
const ARC_SEGMENTS := 28

const SLASH_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float flip = 1.0;
uniform float half_angle = 1.2;
void vertex() {
	float angle = mix(-half_angle, half_angle, UV.x);
	float inner = 1.0 - 0.75 * pow(sin(3.14159265 * UV.x), 0.8);
	float r = mix(inner, 1.0, UV.y);
	VERTEX = vec3(sin(angle) * r, 0.0, cos(angle) * r);
}
void fragment() {
	float t = flip > 0.0 ? UV.x : 1.0 - UV.x;
	float behind = progress * 1.3 - t;
	float trail = clamp(1.0 - behind / 0.6, 0.0, 1.0);
	float mask = step(0.0, behind) * trail * trail;
	float edge = pow(UV.y, 1.6);
	float fade = 1.0 - smoothstep(0.5, 1.0, progress);
	ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.7);
	ALPHA = clamp(mask * fade * (0.35 + 0.9 * edge), 0.0, 1.0) * color.a;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float thickness = 0.2;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float ring = smoothstep(1.0 - thickness - 0.08, 1.0 - thickness, d) * (1.0 - smoothstep(0.93, 1.0, d));
	ALBEDO = color.rgb;
	ALPHA = ring * alpha * color.a;
}
"""


class Timed:
	extends RefCounted
	var node: MeshInstance3D
	var material: ShaderMaterial
	var age := 0.0
	var duration := 0.0
	var active := false
	var radius := 1.0
	var start_thickness := 0.3


var _emitters: Dictionary = {}
var _cursor: Dictionary = {}
var _slashes: Array[Timed] = []
var _rings: Array[Timed] = []
var _slash_next := 0
var _ring_next := 0
var _active_timed := 0


# ----------------------------------------------------------------------------------------------- static API

static var _hub: Node3D


## Null when the hub is not yet in the tree (it joins one frame after the first call) or `from` is outside the tree.
## Owners call it once from _ready so the first real effect is never dropped.
static func hub_for(from: Node) -> Node3D:
	if from == null or not from.is_inside_tree():
		return null
	if is_instance_valid(_hub):
		return _hub if _hub.is_inside_tree() else null
	var created := Node3D.new()
	created.name = HUB_NAME
	created.set_script(load(SCRIPT_PATH))
	created.call(&"build")
	_hub = created
	from.get_tree().root.add_child.call_deferred(created)
	return null


## Particle burst. `dir` is the emission axis (world space), `tint` multiplies the kind's texture, `size_scale` scales the quads.
static func burst(from: Node, kind: int, pos: Vector3, dir := Vector3.UP, tint := Color.WHITE, size_scale := 1.0) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._burst(kind, pos, dir, tint, size_scale)


## Flat crescent swept around +Z of `yaw`. `radius` in metres, `arc_deg` total angle, `roll_deg` tilts the arc plane
## (90 = vertical chop), `flip` reverses the sweep direction.
static func slash(from: Node, pos: Vector3, yaw: float, radius: float, arc_deg: float, tint: Color, duration: float,
		roll_deg := 0.0, flip := false) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._slash(pos, yaw, radius, arc_deg, tint, duration, roll_deg, flip)


## Expanding ground ring (y is the ring height).
static func ring(from: Node, pos: Vector3, radius: float, tint: Color, duration: float, thickness := 0.3) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._ring(pos, radius, tint, duration, thickness)


static func hit_spark(from: Node, pos: Vector3, dir: Vector3, big: bool, tint := GOLD) -> void:
	burst(from, Kind.FLASH, pos, Vector3.UP, tint.lightened(0.4), 1.5 if big else 1.0)
	burst(from, Kind.SPARK, pos, dir, tint, 1.5 if big else 1.0)
	if big:
		burst(from, Kind.SPARK, pos, dir + Vector3.UP, Color.WHITE, 1.2)
		burst(from, Kind.GLOW, pos, Vector3.UP, tint, 1.4)


static func dust_puff(from: Node, pos: Vector3, tint := Color(0.78, 0.72, 0.62, 0.7), size_scale := 1.0) -> void:
	burst(from, Kind.DUST, pos, Vector3.UP, tint, size_scale)


static func ground_impact(from: Node, pos: Vector3, radius: float, tint: Color) -> void:
	ring(from, pos + Vector3(0.0, 0.1, 0.0), radius, tint, 0.4)
	burst(from, Kind.DUST, pos + Vector3(0.0, 0.15, 0.0), Vector3.UP, Color(0.78, 0.72, 0.62, 0.8), radius * 0.45)
	burst(from, Kind.DEBRIS, pos + Vector3(0.0, 0.2, 0.0), Vector3.UP, Color(0.5, 0.46, 0.42), 1.0)
	burst(from, Kind.GLOW, pos + Vector3(0.0, 0.4, 0.0), Vector3.UP, tint, radius * 0.5)


static func poof(from: Node, pos: Vector3, tint := Color(0.7, 0.68, 0.7, 0.8)) -> void:
	burst(from, Kind.SMOKE, pos, Vector3.UP, tint, 1.0)
	burst(from, Kind.DUST, pos, Vector3.UP, tint, 1.2)
	burst(from, Kind.GLOW, pos, Vector3.UP, Color(1.0, 0.9, 0.7), 1.2)
	burst(from, Kind.HEAL, pos, Vector3.UP, Color(0.75, 0.9, 1.0), 1.0)


# ------------------------------------------------------------------------------------------------- instance

func build() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for kind in KIND_CFG:
		_build_pool(kind)
	var arc := _arc_mesh()
	for i in SLASH_POOL:
		_slashes.append(_make_timed(arc, SLASH_SHADER))
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	for i in RING_POOL:
		_rings.append(_make_timed(plane, RING_SHADER))
	set_process(false)


func _process(delta: float) -> void:
	_active_timed = 0
	for item in _slashes:
		if item.active:
			_advance(item, delta, true)
	for item in _rings:
		if item.active:
			_advance(item, delta, false)
	if _active_timed == 0:
		set_process(false)


func _advance(item: Timed, delta: float, is_slash: bool) -> void:
	item.age += delta
	var p := clampf(item.age / item.duration, 0.0, 1.0)
	if p >= 1.0:
		item.active = false
		item.node.visible = false
		return
	_active_timed += 1
	if is_slash:
		item.material.set_shader_parameter(&"progress", p)
	else:
		var eased := 1.0 - pow(1.0 - p, 3.0)
		var r := item.radius * lerpf(0.15, 1.0, eased)
		item.node.scale = Vector3(r, 1.0, r)
		item.material.set_shader_parameter(&"alpha", 1.0 - p * p)
		item.material.set_shader_parameter(&"thickness", lerpf(item.start_thickness, 0.08, p))


func _make_timed(mesh: Mesh, code: String) -> Timed:
	var item := Timed.new()
	var shader := Shader.new()
	shader.code = code
	item.material = ShaderMaterial.new()
	item.material.shader = shader
	item.material.render_priority = FX_PRIORITY
	item.node = MeshInstance3D.new()
	item.node.mesh = mesh
	item.node.material_override = item.material
	item.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.node.top_level = true
	item.node.visible = false
	add_child(item.node)
	return item


func _slash(pos: Vector3, yaw: float, radius: float, arc_deg: float, tint: Color, duration: float,
		roll_deg: float, flip: bool) -> void:
	var item := _slashes[_slash_next]
	_slash_next = (_slash_next + 1) % SLASH_POOL
	# Lift the leading edge so the crescent faces the (above-and-behind) game camera instead of lying edge-on.
	var lift := 0.0 if absf(roll_deg) > 60.0 else -deg_to_rad(SLASH_LIFT_DEG)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift) * Basis(Vector3.BACK, deg_to_rad(roll_deg)) \
		* Basis.from_scale(Vector3(radius, 1.0, radius))
	item.node.global_transform = Transform3D(basis, pos)
	item.node.visible = true
	item.material.set_shader_parameter(&"color", tint)
	item.material.set_shader_parameter(&"flip", -1.0 if flip else 1.0)
	item.material.set_shader_parameter(&"half_angle", deg_to_rad(clampf(arc_deg, 20.0, 340.0)) * 0.5)
	item.material.set_shader_parameter(&"progress", 0.0)
	item.age = 0.0
	item.duration = maxf(duration, 0.05)
	item.active = true
	set_process(true)


func _ring(pos: Vector3, radius: float, tint: Color, duration: float, thickness: float) -> void:
	var item := _rings[_ring_next]
	_ring_next = (_ring_next + 1) % RING_POOL
	item.radius = radius
	item.start_thickness = thickness
	item.node.global_transform = Transform3D(Basis.from_scale(Vector3(radius * 0.15, 1.0, radius * 0.15)), pos)
	item.node.visible = true
	item.material.set_shader_parameter(&"color", tint)
	item.material.set_shader_parameter(&"alpha", 1.0)
	item.material.set_shader_parameter(&"thickness", thickness)
	item.age = 0.0
	item.duration = maxf(duration, 0.05)
	item.active = true
	set_process(true)


func _burst(kind: int, pos: Vector3, dir: Vector3, tint: Color, size_scale: float) -> void:
	var pool: Array = _emitters[kind]
	var index: int = _cursor[kind]
	_cursor[kind] = (index + 1) % pool.size()
	var emitter := pool[index] as CPUParticles3D
	emitter.global_position = pos
	emitter.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	emitter.color = tint
	var cfg: Dictionary = KIND_CFG[kind]
	emitter.scale_amount_min = size_scale * 0.7
	emitter.scale_amount_max = size_scale * 1.15
	emitter.restart()
	emitter.emitting = true
	if int(cfg["amount"]) == 1:
		emitter.angle_min = randf_range(0.0, 360.0)
		emitter.angle_max = emitter.angle_min


func _build_pool(kind: int) -> void:
	var cfg: Dictionary = KIND_CFG[kind]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(cfg["size"])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if cfg["add"]:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.render_priority = FX_PRIORITY
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(TEX + String(cfg["tex"]) + ".png")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.particles_anim_h_frames = 1
	material.particles_anim_v_frames = 1
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	material.no_depth_test = false
	quad.material = material
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.6, Color(1, 1, 1, 0.85))
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, float(cfg["start"])))
	curve.add_point(Vector2(1.0, float(cfg["end"])))
	var list: Array = []
	for i in int(cfg["pool"]):
		var e := CPUParticles3D.new()
		e.amount = int(cfg["amount"])
		e.lifetime = float(cfg["life"])
		e.one_shot = true
		e.explosiveness = 1.0
		e.emitting = false
		e.local_coords = false
		e.mesh = quad
		e.direction = Vector3.UP
		e.spread = float(cfg["spread"])
		e.initial_velocity_min = float(cfg["vmin"])
		e.initial_velocity_max = float(cfg["vmax"])
		e.gravity = Vector3(0.0, float(cfg["gravity"]), 0.0)
		e.color_ramp = ramp
		e.scale_amount_curve = curve
		e.angle_min = 0.0
		e.angle_max = 360.0
		var radius := float(cfg["radius"])
		if radius > 0.0:
			e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			e.emission_sphere_radius = radius
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
		list.append(e)
	_emitters[kind] = list
	_cursor[kind] = 0


## Strip of ARC_SEGMENTS quads; the slash shader's vertex() bends it into a crescent (u along the arc, v inner -> outer).
func _arc_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in ARC_SEGMENTS + 1:
		var u := float(i) / float(ARC_SEGMENTS)
		verts.append(Vector3(u, 0.0, 0.0))
		uvs.append(Vector2(u, 0.0))
		verts.append(Vector3(u, 0.0, 1.0))
		uvs.append(Vector2(u, 1.0))
	for i in ARC_SEGMENTS:
		var a := i * 2
		indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 1.0, 2.0))
	return mesh
