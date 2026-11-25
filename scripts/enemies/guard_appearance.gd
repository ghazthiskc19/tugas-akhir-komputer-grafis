extends RefCounted
## Ancient-guard look for enemy instances: weathered stone body + glowing teal rune core. Applied per instance on top of the
## shared KayKit rigs (the player Rogue uses the same GLB, so nothing here may touch imported resources). Body meshes get
## NEW per-surface override materials; the shared mesh/material resources and every weapon stay untouched.
## Silhouette stays archetype-specific: the standard guard keeps its sword, heavy gets bulkier stone pauldrons on the
## Barbarian rig, ranged gets a back rune-ring on the Ranger rig.

const TEAL := Color(0.15, 0.95, 0.85)
const STONE_TONES := {
	"Body": Color(0.62, 0.58, 0.5),
	"Head": Color(0.74, 0.69, 0.6),
	"ArmLeft": Color(0.56, 0.54, 0.5),
	"ArmRight": Color(0.56, 0.54, 0.5),
	"LegLeft": Color(0.48, 0.47, 0.45),
	"LegRight": Color(0.48, 0.47, 0.45),
}
## Capes/hats/quivers read as moss-stained slabs rather than cloth.
const CLOTH_TONE := Color(0.52, 0.55, 0.5)

static var _shader: Shader
static var _glow_mat: StandardMaterial3D
static var _pauldron_mat: StandardMaterial3D



## `model` is the enemy's Model instance; `skeleton` its Skeleton3D (may be null: then only the stone pass runs).
static func apply(model: Node3D, skeleton: Skeleton3D, archetype: String) -> void:
	_stone_pass(model)
	if skeleton == null:
		return
	var glow := _glow()
	match archetype:
		"heavy":
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.24, 0.24, 0.06), glow), Vector3(0, 0.1, 0.36), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.36, 0.06, 0.05), glow), Vector3(0, 0.34, 0.5))
			_attach(skeleton, "chest", "PauldronLeft", _box(Vector3(0.4, 0.26, 0.46), _pauldron()), Vector3(0.42, 0.2, 0))
			_attach(skeleton, "chest", "PauldronRight", _box(Vector3(0.4, 0.26, 0.46), _pauldron()), Vector3(-0.42, 0.2, 0))
		"ranged":
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.14, 0.14, 0.05), glow), Vector3(0, 0.1, 0.33), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.28, 0.05, 0.05), glow), Vector3(0, 0.34, 0.5))
			_attach(skeleton, "chest", "RuneRing", _torus(0.26, 0.4, glow), Vector3(0, 0.22, -0.35), Vector3(90, 0, 0))
		_:
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.17, 0.17, 0.05), glow), Vector3(0, 0.1, 0.34), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.3, 0.05, 0.05), glow), Vector3(0, 0.34, 0.5))


## Weapons hang under a BoneAttachment3D named "WeaponSlot" inside the skeleton, so find_children("Model") reaches them:
## without this exemption they were repainted in the same stone tone as the guard body and camouflaged against it.
static func _is_weapon(node: Node, model: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != model:
		if parent.name == &"WeaponSlot":
			return true
		parent = parent.get_parent()
	return false


static func _stone_pass(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or _is_weapon(mesh_instance, model):
			continue
		var tone := CLOTH_TONE
		for part: String in STONE_TONES:
			if String(mesh_instance.name).ends_with("_" + part):
				tone = STONE_TONES[part]
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var stone := ShaderMaterial.new()
			stone.shader = _stone_shader()
			stone.set_shader_parameter("palette", source.albedo_texture if source != null else null)
			stone.set_shader_parameter("tone", tone)
			mesh_instance.set_surface_override_material(surface, stone)


## Keeps the KayKit palette's luminance (face, belts, straps stay readable) but replaces its hues with one stone tone,
## fully rough and non-metallic.
static func _stone_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform vec4 tone : source_color;
void fragment() {
	float luma = dot(texture(palette, UV).rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = tone.rgb * (0.7 + 0.7 * luma);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.15;
}
"""
	return _shader


static func _glow() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = TEAL
		_glow_mat.emission_enabled = true
		_glow_mat.emission = TEAL
		_glow_mat.emission_energy_multiplier = 2.2
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _glow_mat


static func _pauldron() -> StandardMaterial3D:
	if _pauldron_mat == null:
		_pauldron_mat = StandardMaterial3D.new()
		_pauldron_mat.albedo_color = Color(0.5, 0.48, 0.44)
		_pauldron_mat.roughness = 1.0
	return _pauldron_mat


static func _sphere(radius: float, material: Material) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	return mesh


static func _box(size: Vector3, material: Material) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


static func _torus(inner: float, outer: float, material: Material) -> Mesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 6
	mesh.material = material
	return mesh


static func _attach(skeleton: Skeleton3D, bone: String, part: String, mesh: Mesh, offset: Vector3, euler_degrees := Vector3.ZERO) -> void:
	if skeleton.find_bone(bone) < 0:
		push_warning("GuardAppearance: bone %s tidak ada" % bone)
		return
	var slot := BoneAttachment3D.new()
	slot.name = "Guard" + part
	slot.bone_name = bone
	skeleton.add_child(slot)
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.position = offset
	instance.rotation_degrees = euler_degrees
	# Skinned GLB meshes can sit outside the skeleton-space AABB; keep attachments from being culled.
	instance.extra_cull_margin = 2.0
	slot.add_child(instance)
