extends RefCounted
## Character look shared by the player, the ancient guards and (materials only) the Gatekeeper.
## Ancient guards: weathered stone body + glowing teal rune core, applied per instance on top of the shared KayKit rigs
## (the player Rogue uses the same GLB, so nothing here may touch imported resources). Body meshes get NEW per-surface
## override materials (toon ramp + faction rim + inverted-hull outline + death dissolve); the shared mesh/material
## resources and every weapon stay untouched. The existing white flash overlay (material_overlay) draws on top unchanged.
## Rune glow is state driven (idle dim, windup rising, strike flash, stagger flicker, death fade) from the enemy's own
## state_changed signal and windup getter: purely visual, never changes gameplay state or attack timing.
## Silhouette stays archetype-specific: the standard guard keeps its sword, heavy gets bulkier stone pauldrons on the
## Barbarian rig, ranged gets a back rune-ring on the Ranger rig.

const TOON_SHADER := preload("res://shaders/characters/toon_character.gdshader")
const OUTLINE_SHADER := preload("res://shaders/characters/character_outline.gdshader")
const GLOW_SHADER := preload("res://shaders/characters/rune_glow.gdshader")
const HALO_SHADER := preload("res://shaders/characters/rune_halo.gdshader")
const Vfx := preload("res://scripts/vfx/combat_vfx.gd")

const TEAL := Color(0.15, 0.95, 0.85)
const RIM_GUARD := Color(0.35, 0.95, 0.9)
const RIM_PLAYER := Color(1.0, 0.78, 0.38)
const RIM_BOSS := Color(1.0, 0.45, 0.15)
const OUTLINE_GUARD := Color(0.03, 0.07, 0.08)
const OUTLINE_PLAYER := Color(0.09, 0.05, 0.03)
const OUTLINE_BOSS := Color(0.06, 0.03, 0.02)
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

const RUNE_IDLE := 0.55
const RUNE_CHASE := 0.85
const DEATH_HOLD := 0.9
const DEATH_DISSOLVE := 1.1

static var _halo_texture: Texture2D


## Per-instance look state: owns the tween that moves rune energy / rim / dissolve. Kept alive through model metadata.
class Driver:
	extends RefCounted
	var model: Node3D
	var toons: Array[ShaderMaterial] = []
	var outline: ShaderMaterial
	var glow: ShaderMaterial
	var halos: Array[ShaderMaterial] = []
	var tween: Tween
	var energy := RUNE_IDLE

	func set_energy(value: float) -> void:
		energy = value
		if glow != null:
			glow.set_shader_parameter(&"energy", value)
		for halo in halos:
			halo.set_shader_parameter(&"energy", value)
		var rim := lerpf(0.45, 1.7, clampf((value - RUNE_IDLE) / 3.0, 0.0, 1.0))
		for toon in toons:
			toon.set_shader_parameter(&"rim_energy", rim)

	func set_dissolve(value: float) -> void:
		for toon in toons:
			toon.set_shader_parameter(&"dissolve", value)
		if outline != null:
			outline.set_shader_parameter(&"dissolve", value)
		if glow != null:
			glow.set_shader_parameter(&"dissolve", value)
		for halo in halos:
			halo.set_shader_parameter(&"dissolve", value)

	func on_state(state: StringName) -> void:
		if not is_instance_valid(model) or not model.is_inside_tree():
			return
		if tween != null:
			tween.kill()
		tween = model.create_tween()
		var enemy := model.get_parent()
		match state:
			&"windup":
				var windup := 0.6
				if enemy != null and enemy.has_method(&"get_attack_windup"):
					windup = maxf(float(enemy.call(&"get_attack_windup")), 0.15)
				tween.tween_method(set_energy, RUNE_CHASE, 3.2, windup).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			&"active":
				tween.tween_method(set_energy, 4.2, 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			&"recovery":
				tween.tween_method(set_energy, maxf(energy, 1.0), RUNE_IDLE, 0.5)
			&"stagger":
				tween.tween_method(set_energy, 0.15, RUNE_CHASE, 0.45).set_ease(Tween.EASE_OUT)
			&"chase":
				tween.tween_method(set_energy, energy, RUNE_CHASE, 0.25)
			&"dead":
				tween.tween_method(set_energy, energy, 0.0, 0.5)
				tween.tween_interval(maxf(DEATH_HOLD - 0.5, 0.0))
				tween.tween_callback(burn_embers)
				tween.tween_method(set_dissolve, 0.0, 1.25, DEATH_DISSOLVE)
				tween.tween_callback(func() -> void: model.visible = false)
			_:
				tween.tween_method(set_energy, energy, RUNE_IDLE, 0.3)

	func burn_embers() -> void:
		var enemy := model.get_parent() as Node3D
		if enemy != null:
			Vfx.embers(enemy, enemy.global_position + Vector3(0.0, 0.4, 0.0))


## `model` is the enemy's Model instance; `skeleton` its Skeleton3D (may be null: then only the stone pass runs).
static func apply(model: Node3D, skeleton: Skeleton3D, archetype: String) -> void:
	var driver := Driver.new()
	driver.model = model
	driver.outline = make_outline(OUTLINE_GUARD, 0.012)
	_stone_pass(model, driver)
	if skeleton == null:
		return
	# Vary idle breathing without consuming the gameplay RNG.
	var phase := float(model.get_instance_id() % 997) / 997.0 * TAU
	driver.glow = ShaderMaterial.new()
	driver.glow.shader = GLOW_SHADER
	driver.glow.set_shader_parameter(&"color", TEAL)
	driver.glow.set_shader_parameter(&"phase", phase)
	var glow := driver.glow
	match archetype:
		"heavy":
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.24, 0.24, 0.06), glow), Vector3(0, 0.1, 0.36), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.36, 0.06, 0.05), glow), Vector3(0, 0.34, 0.5))
			var shoulder := make_toon(null, Color.WHITE, 0.0, RIM_GUARD, null)
			shoulder.set_shader_parameter(&"albedo_color", Color(0.5, 0.48, 0.44))
			driver.toons.append(shoulder)
			_attach(skeleton, "chest", "PauldronLeft", _box(Vector3(0.4, 0.26, 0.46), shoulder), Vector3(0.42, 0.2, 0))
			_attach(skeleton, "chest", "PauldronRight", _box(Vector3(0.4, 0.26, 0.46), shoulder), Vector3(-0.42, 0.2, 0))
			_halo(driver, skeleton, "chest", "RuneCoreHalo", 0.95, Vector3(0, 0.1, 0.4), phase)
			_halo(driver, skeleton, "head", "RuneEyesHalo", 0.6, Vector3(0, 0.34, 0.52), phase)
		"ranged":
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.14, 0.14, 0.05), glow), Vector3(0, 0.1, 0.33), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.28, 0.05, 0.05), glow), Vector3(0, 0.34, 0.5))
			_attach(skeleton, "chest", "RuneRing", _torus(0.26, 0.4, glow), Vector3(0, 0.22, -0.35), Vector3(90, 0, 0))
			_halo(driver, skeleton, "chest", "RuneCoreHalo", 0.7, Vector3(0, 0.1, 0.37), phase)
			_halo(driver, skeleton, "head", "RuneEyesHalo", 0.5, Vector3(0, 0.34, 0.52), phase)
		_:
			_attach(skeleton, "chest", "RuneCore", _box(Vector3(0.17, 0.17, 0.05), glow), Vector3(0, 0.1, 0.34), Vector3(0, 0, 45))
			_attach(skeleton, "head", "RuneEyes", _box(Vector3(0.3, 0.05, 0.05), glow), Vector3(0, 0.34, 0.5))
			_halo(driver, skeleton, "chest", "RuneCoreHalo", 0.75, Vector3(0, 0.1, 0.38), phase)
			_halo(driver, skeleton, "head", "RuneEyesHalo", 0.5, Vector3(0, 0.34, 0.52), phase)
	driver.set_energy(RUNE_IDLE)
	model.set_meta(&"look_driver", driver)
	var enemy := model.get_parent()
	if enemy != null and enemy.has_signal(&"state_changed"):
		enemy.connect(&"state_changed", driver.on_state)


## Player Rogue: keeps the KayKit palette colours, adds the toon ramp, warm-gold rim, outline and a gentle cape flutter.
## Only body parts directly under the skeleton are touched (weapon and potion hang under bone attachments).
static func apply_player(model: Node3D) -> void:
	var outline := make_outline(OUTLINE_PLAYER, 0.011)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.get_parent() is Skeleton3D:
			continue
		var is_cape := String(mesh_instance.name).ends_with("_Cape")
		var piece_outline := outline if _outline_part(String(mesh_instance.name)) else null
		if is_cape:
			piece_outline = make_outline(OUTLINE_PLAYER, 0.011)
			piece_outline.set_shader_parameter(&"sway", 0.03)
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var toon := make_toon(source, Color.WHITE, 0.0, RIM_PLAYER, piece_outline)
			toon.set_shader_parameter(&"rim_energy", 0.7)
			if is_cape:
				toon.set_shader_parameter(&"sway", 0.03)
			mesh_instance.set_surface_override_material(surface, toon)


## Spend the extra pass on the large silhouette pieces only. Extremities retain the same ramp/rim but do not
## multiply arm/leg submesh draw calls in Compatibility's depth/light passes.
static func _outline_part(part: String) -> bool:
	return part.ends_with("_Head") or part.ends_with("_Body") or part.ends_with("_Cape")


static func make_outline(color: Color, width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"width", width)
	return material


## Toon material over a source palette material; `outline` becomes its next_pass.
static func make_toon(source: BaseMaterial3D, tone: Color, stone_mix: float, rim: Color, outline: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter(&"palette", source.albedo_texture if source != null else null)
	material.set_shader_parameter(&"albedo_color", source.albedo_color if source != null else Color.WHITE)
	material.set_shader_parameter(&"tone", tone)
	material.set_shader_parameter(&"stone_mix", stone_mix)
	material.set_shader_parameter(&"rim_color", rim)
	material.next_pass = outline
	return material


## Weapons hang under a BoneAttachment3D named "WeaponSlot" inside the skeleton, so find_children("Model") reaches them:
## without this exemption they were repainted in the same stone tone as the guard body and camouflaged against it.
static func _is_weapon(node: Node, model: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != model:
		if parent.name == &"WeaponSlot":
			return true
		parent = parent.get_parent()
	return false


static func _stone_pass(model: Node3D, driver: Driver) -> void:
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
			# Keeps the KayKit palette's luminance (face, belts, straps stay readable) but replaces its hues with one stone tone.
			var stone := make_toon(source, tone, 1.0, RIM_GUARD, driver.outline if _outline_part(String(mesh_instance.name)) else null)
			driver.toons.append(stone)
			mesh_instance.set_surface_override_material(surface, stone)


static func _halo(driver: Driver, skeleton: Skeleton3D, bone: String, part: String, size: float, offset: Vector3, phase: float) -> void:
	var halo := ShaderMaterial.new()
	halo.shader = HALO_SHADER
	halo.set_shader_parameter(&"color", TEAL)
	halo.set_shader_parameter(&"phase", phase)
	driver.halos.append(halo)
	if _halo_texture == null:
		var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_halo_texture = ImageTexture.create_from_image(image)
	var slot := BoneAttachment3D.new()
	slot.name = "Guard" + part
	slot.bone_name = bone
	skeleton.add_child(slot)
	# Sprite3D deliberately avoids the enemy's MeshInstance3D white-flash overlay pass: applying a solid overlay
	# to a halo quad would flash a large white rectangle instead of just the character silhouette.
	var sprite := Sprite3D.new()
	sprite.name = part
	sprite.texture = _halo_texture
	sprite.pixel_size = size
	sprite.material_override = halo
	sprite.position = offset
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.extra_cull_margin = 2.0
	slot.add_child(sprite)



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
