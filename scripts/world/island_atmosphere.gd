extends Node3D
## Island 1 presentation layer: sky, light, fog, shoreline data for the sea shader, drifting clouds and motes, foliage
## sway and a light detail texture on the terrain. Visual only: no collision, no gameplay state, deterministic per seed.
##
## Usage (parent, AFTER the terrain exists):
##   var atmosphere := preload("res://scripts/world/island_atmosphere.gd").new()
##   parent.add_child(atmosphere)
##   atmosphere.build(parent, terrain)

const FOLIAGE_SHADER := "res://shaders/island/foliage_sway.gdshader"
const TERRAIN_SHADER := "res://shaders/island/island_terrain.gdshader"
const STONE_SHADER := "res://shaders/island/island_stone.gdshader"
const SHORE_RES := 256
const SHORE_RANGE := 6.0
const MOTE_COUNT := 90
const SKY_SHADER := "res://shaders/island/island_sky.gdshader"
const CANOPY_SHADER := "res://shaders/island/canopy_blob.gdshader"
const FOG_COLOR := Color(0.72, 0.81, 0.86)

var _noise_tex: Texture2D


## `rig` = the node that owns WorldEnvironment/KeyLight/Camera3D (the game root).
func build(rig: Node, terrain: Node3D) -> void:
	_build_environment(rig)
	_build_sun(rig)
	var camera := rig.get_node_or_null(^"Camera3D") as Camera3D
	if camera != null:
		camera.far = 420.0
	_build_shore(terrain)
	_detail_terrain(terrain)
	_sway_foliage(terrain)
	_build_canopy_clusters(terrain)
	_stone_decoration(rig, terrain)
	_build_motes(rig)


# ---- Sky / fog / grade -----------------------------------------------------------------------------------------------
func _build_environment(rig: Node) -> void:
	var holder := rig.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if holder == null:
		holder = WorldEnvironment.new()
		holder.name = "WorldEnvironment"
		rig.add_child(holder)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER) as Shader
	sky_mat.set_shader_parameter("horizon_color", FOG_COLOR)
	sky_mat.set_shader_parameter("ground_color", FOG_COLOR)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	# A fresh Environment: the rig's sub-resource is shared by every scene that inherits the lab.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Flat cool-neutral fill (sky-derived ambient is a strong blue in Compatibility and greys the sand and foliage).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.93, 1.0)
	env.ambient_light_energy = 0.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.95
	# Depth fog: combat range (< ~35 m) stays clear, the island dissolves into the haze by ~130 m. fog_density
	# scales the depth-mode result; 1.0 is set explicitly rather than relying on the engine default.
	# The sky shader's horizon uses the same colour, so far terrain/sea and sky share one seam.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 35.0
	env.fog_depth_end = 130.0
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	holder.environment = env


func _build_sun(rig: Node) -> void:
	var sun := rig.get_node_or_null(^"KeyLight") as DirectionalLight3D
	if sun == null:
		return
	# Warm low sun: long readable shadows, cool fill from the sky ambient.
	sun.rotation_degrees = Vector3(-40.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_blend_splits = true


# ---- Shoreline -------------------------------------------------------------------------------------------------------
## Bakes terrain height above the water line into an R8 texture; the sea shader draws depth tint, wash line and foam.
func _build_shore(terrain: Node3D) -> void:
	var sea := terrain.get_node_or_null(^"Sea") as MeshInstance3D
	if sea == null or not (sea.material_override is ShaderMaterial):
		return
	var half: float = terrain.HALF
	var water_y: float = terrain.WATER_Y
	var data := PackedByteArray()
	data.resize(SHORE_RES * SHORE_RES)
	for j in SHORE_RES:
		var z := -half + (float(j) + 0.5) / float(SHORE_RES) * 2.0 * half
		for i in SHORE_RES:
			var x := -half + (float(i) + 0.5) / float(SHORE_RES) * 2.0 * half
			var d: float = terrain.height_at(x, z) - water_y
			data[j * SHORE_RES + i] = int(clampf(d / SHORE_RANGE * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(SHORE_RES, SHORE_RES, false, Image.FORMAT_R8, data)
	var mat := sea.material_override as ShaderMaterial
	mat.set_shader_parameter("shore_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("shore_half_extent", half)
	mat.set_shader_parameter("shore_range", SHORE_RANGE)


# ---- Terrain / foliage -----------------------------------------------------------------------------------------------
## Shared seamless value-noise texture (built synchronously so the first frame is already textured).
func _noise_texture() -> Texture2D:
	if _noise_tex != null:
		return _noise_tex
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	noise.seed = 1019
	var img := noise.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_L8)
	img.adjust_bcs(1.0, 1.35, 1.0)
	img.generate_mipmaps()
	_noise_tex = ImageTexture.create_from_image(img)
	return _noise_tex


## Replaces the flat vertex-colour ground material with the stylised terrain shader (same mesh, same draw call):
## vertex colour stays the base, so biome, shore, route and pad painting from the terrain data is preserved.
func _detail_terrain(terrain: Node3D) -> void:
	var mesh_node := terrain.get_node_or_null(^"Terrain/TerrainMesh") as MeshInstance3D
	if mesh_node == null or not ResourceLoader.exists(TERRAIN_SHADER):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load(TERRAIN_SHADER) as Shader
	mat.set_shader_parameter("noise_tex", _noise_texture())
	mat.set_shader_parameter("water_y", float(terrain.WATER_Y))
	mesh_node.mesh.surface_set_material(0, mat)


## Moss/dirt stone look for rocks and ruin pieces (walls, rubble, barriers), one ShaderMaterial per source texture.
## Sweeps the whole rig: terrain decoration (MultiMesh rocks, scene instances) and the objective modules' loose pieces.
## Puzzle pillars, columns, torches, floor tiles and the wooden dock keep their own materials (puzzles recolour them).
func _stone_decoration(rig: Node, terrain: Node3D) -> void:
	if not ResourceLoader.exists(STONE_SHADER):
		return
	var shader := load(STONE_SHADER) as Shader
	var cache := {}
	var deco := terrain.get_node_or_null(^"Decoration")
	for n in rig.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.material_override != null:
			continue
		var mesh: Mesh = null
		if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		elif g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		if mesh == null or mesh.get_surface_count() < 1:
			continue
		var mname := mesh.resource_name
		var stone := mname.begins_with("Rock_") or mname.begins_with("wall") or mname.begins_with("rubble") \
			or mname.begins_with("barrier")
		if not stone and deco != null and deco.is_ancestor_of(g):
			stone = mname.begins_with("pillar") or mname.begins_with("column")
		if not stone:
			continue
		var src := mesh.surface_get_material(0) as StandardMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var key: Texture2D = src.albedo_texture
		if not cache.has(key):
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("albedo_tex", key)
			sm.set_shader_parameter("noise_tex", _noise_texture())
			cache[key] = sm
		g.material_override = cache[key]

## Wind sway for trees and bushes. They are MultiMeshes sharing one palette material, so one ShaderMaterial per class
## (tall / low) is applied as material_override: zero extra draw calls.
func _sway_foliage(terrain: Node3D) -> void:
	var deco := terrain.get_node_or_null(^"Decoration")
	if deco == null or not ResourceLoader.exists(FOLIAGE_SHADER):
		return
	var shader := load(FOLIAGE_SHADER) as Shader
	var tall: ShaderMaterial = null
	var low: ShaderMaterial = null
	for child in deco.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var mesh := mmi.multimesh.mesh
		var is_tree := mesh.resource_name.begins_with("Tree_")
		var is_bush := mesh.resource_name.begins_with("Bush_")
		if not (is_tree or is_bush) or mesh.get_surface_count() != 1:
			continue
		var src := mesh.surface_get_material(0) as StandardMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		if is_tree:
			if tall == null:
				tall = _foliage_material(shader, src.albedo_texture, 0.2, 0.11)
			mmi.material_override = tall
		else:
			if low == null:
				low = _foliage_material(shader, src.albedo_texture, 1.4, 0.035)
			mmi.material_override = low


func _foliage_material(shader: Shader, texture: Texture2D, inv_height: float, amplitude: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_tex", texture)
	mat.set_shader_parameter("inv_height", inv_height)
	mat.set_shader_parameter("amplitude", amplitude)
	return mat

## Grouped canopies: a few low-poly leaf clumps around the crown of existing trees (placement, collision and tree
## seed untouched; clump offsets use their own deterministic RNG). One extra MultiMesh, no shadows.
func _build_canopy_clusters(terrain: Node3D) -> void:
	var deco := terrain.get_node_or_null(^"Decoration")
	if deco == null or not ResourceLoader.exists(CANOPY_SHADER):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.get("active_seed")) * 131 + 17
	var xforms: Array[Transform3D] = []
	for child in deco.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		if not mmi.multimesh.mesh.resource_name.begins_with("Tree_"):
			continue
		var box := mmi.multimesh.mesh.get_aabb()
		var count := mmi.multimesh.visible_instance_count
		if count < 0:
			count = mmi.multimesh.instance_count
		for i in count:
			var t := mmi.global_transform * mmi.multimesh.get_instance_transform(i)
			if rng.randf() > 0.65:
				continue
			var to_local_xform := global_transform.affine_inverse()
			var blobs := 1 + int(rng.randf() < 0.5) + int(rng.randf() < 0.25)
			for b in blobs:
				var ang := rng.randf() * TAU
				var reach := box.size.x * rng.randf_range(0.18, 0.34)
				var local := Vector3(cos(ang) * reach, box.end.y * rng.randf_range(0.62, 0.9), sin(ang) * reach)
				var r := box.size.x * rng.randf_range(0.16, 0.26)
				var bas := Basis.from_scale(Vector3(r, r * rng.randf_range(0.7, 0.95), r)).rotated(Vector3.UP, rng.randf() * TAU)
				# Tree-local clump placed through the full instance transform (scale, rotation), then into this node's space.
				xforms.append(to_local_xform * (t * Transform3D(bas, local)))
	if xforms.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var mat := ShaderMaterial.new()
	mat.shader = load(CANOPY_SHADER) as Shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = "CanopyClusters"
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)



## Pollen / dust motes that follow the camera but stay in world space, so movement reads as depth.
func _build_motes(rig: Node) -> void:
	var cam := rig.get_node_or_null(^"Camera3D") as Camera3D
	if cam == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = Color(1.0, 0.96, 0.78, 0.55)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.disable_fog = true
	quad.material = qm
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18.0, 4.0, 18.0)
	pm.direction = Vector3(1.0, 0.15, 0.3)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.0, 0.03, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var p := GPUParticles3D.new()
	p.name = "AmbientMotes"
	p.amount = MOTE_COUNT
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-24, -8, -24), Vector3(48, 16, 48))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 1.5, 0.0)
	cam.add_child(p)
