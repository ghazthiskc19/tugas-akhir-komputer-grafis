extends Node3D
## Island 1 presentation layer: sky, light, fog, shoreline data for the sea shader, drifting clouds and motes, foliage
## sway and a light detail texture on the terrain. Visual only: no collision, no gameplay state, deterministic per seed.
##
## Usage (parent, AFTER the terrain exists):
##   var atmosphere := preload("res://scripts/world/island_atmosphere.gd").new()
##   parent.add_child(atmosphere)
##   atmosphere.build(parent, terrain)

const FOLIAGE_SHADER := "res://shaders/island/foliage_sway.gdshader"
const SHORE_RES := 256
const SHORE_RANGE := 6.0
const CLOUD_COUNT := 14
const MOTE_COUNT := 90

var _clouds: Node3D


## `rig` = the node that owns WorldEnvironment/KeyLight/Camera3D (the game root).
func build(rig: Node, terrain: Node3D) -> void:
	_build_environment(rig)
	_build_sun(rig)
	_build_shore(terrain)
	_detail_terrain(terrain)
	_sway_foliage(terrain)
	_build_clouds(terrain)
	_build_motes(rig)


func _process(delta: float) -> void:
	if _clouds != null:
		_clouds.rotation.y += delta * 0.004


# ---- Sky / fog / grade -----------------------------------------------------------------------------------------------
func _build_environment(rig: Node) -> void:
	var holder := rig.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if holder == null:
		holder = WorldEnvironment.new()
		holder.name = "WorldEnvironment"
		rig.add_child(holder)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.27, 0.5, 0.84)
	sky_mat.sky_horizon_color = Color(0.78, 0.87, 0.94)
	sky_mat.sky_curve = 0.14
	sky_mat.ground_horizon_color = Color(0.74, 0.76, 0.68)
	sky_mat.ground_bottom_color = Color(0.5, 0.46, 0.34)
	sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.12
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
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.74, 0.85, 0.93)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
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
## Breaks up the flat vertex-colour ground with a world-space triplanar value noise (no extra draw call).
func _detail_terrain(terrain: Node3D) -> void:
	var mesh_node := terrain.get_node_or_null(^"Terrain/TerrainMesh") as MeshInstance3D
	if mesh_node == null:
		return
	var mat := mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
	if mat == null:
		return
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.seed = 1019
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.88, 0.88, 0.88))
	ramp.set_color(1, Color(1.04, 1.04, 1.04))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	mat.albedo_texture = tex
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.06


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


# ---- Ambient motion --------------------------------------------------------------------------------------------------
## Flat low-poly clouds on a slowly turning ring around the island (one MultiMesh, unshaded, no shadows).
func _build_clouds(terrain: Node3D) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.disable_fog = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.get("active_seed")) * 31 + 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = CLOUD_COUNT * 3
	var k := 0
	for c in CLOUD_COUNT:
		var ang := rng.randf() * TAU
		var radius := rng.randf_range(150.0, 330.0)
		var centre := Vector3(cos(ang) * radius, rng.randf_range(85.0, 120.0), sin(ang) * radius)
		var size := rng.randf_range(16.0, 30.0)
		for puff in 3:
			var off := Vector3(float(puff - 1) * size * 0.9, rng.randf_range(-1.5, 1.5), rng.randf_range(-4.0, 4.0))
			var s := size * (1.0 if puff == 1 else rng.randf_range(0.6, 0.8))
			var basis := Basis.from_scale(Vector3(s * 1.6, s * 0.32, s * 0.9)).rotated(Vector3.UP, ang)
			mm.set_instance_transform(k, Transform3D(basis, centre + off.rotated(Vector3.UP, ang)))
			k += 1
	var inst := MultiMeshInstance3D.new()
	inst.name = "Clouds"
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 400.0
	add_child(inst)
	_clouds = inst


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
