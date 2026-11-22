extends RefCounted
## Shared helpers for the objective modules (symbol pillars, energy path, summit route): primitive builders with
## world collision (layer 1), licensed KayKit/Kenney model placement, sound, and the compass hook.
## Use via `const Kit := preload("res://scripts/objectives/objective_kit.gd")`.

const WORLD_LAYER := 1
## Enemy bodies live on layer 8 and collide with it; the player (mask 1) ignores it. Used for enemy-only guards.
const ENEMY_ONLY_LAYER := 8

const DUNGEON := "res://assets/third_party/kaykit/dungeon/%s.gltf"
const NATURE := "res://assets/third_party/kaykit/forest_nature/%s.gltf"
const CRYSTAL := "res://assets/third_party/polypizza/crystal_ipoly3d.glb"
const INTERACTABLE := preload("res://scripts/objectives/objective_interactable.gd")

const SFX_GEM := "res://assets/third_party/audio/rpg_sfx_rubberduck/item_gem_02.ogg"
const SFX_STONE := "res://assets/third_party/audio/rpg_sfx_rubberduck/item_stone_02.ogg"
const SFX_STONES := "res://assets/third_party/audio/rpg_sfx_rubberduck/stones_02.ogg"
const SFX_LOCK := "res://assets/third_party/audio/rpg_sfx_rubberduck/lock_02.ogg"
const SFX_SPELL := "res://assets/third_party/audio/rpg_sfx_rubberduck/spell_02.ogg"
const SFX_ERROR := "res://assets/third_party/kenney/interface_sounds/error_004.ogg"
const SFX_CONFIRM := "res://assets/third_party/kenney/interface_sounds/confirmation_003.ogg"
const SFX_TICK := "res://assets/third_party/kenney/interface_sounds/tick_002.ogg"

static var _model_cache: Dictionary = {}


static func material(color: Color, emission := 0.0, alpha := 1.0, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = roughness
	mat.metallic_specular = 0.0
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


static func set_glow(mat: StandardMaterial3D, color: Color, energy: float) -> void:
	mat.albedo_color = Color(color.r, color.g, color.b, mat.albedo_color.a)
	mat.emission_enabled = energy > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = energy


## Visual-only box.
static func box_mesh(parent: Node, node_name: String, center: Vector3, size: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = center
	inst.rotation_degrees.y = yaw_deg
	parent.add_child(inst)
	return inst


## Static box with collision (layer 1 by default) and an optional visible mesh.
static func box_body(parent: Node, node_name: String, center: Vector3, size: Vector3, mat: Material = null, yaw_deg := 0.0, layer := WORLD_LAYER) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees.y = yaw_deg
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	if mat != null:
		var mesh := BoxMesh.new()
		mesh.size = size
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		body.add_child(inst)
	parent.add_child(body)
	return body


static func cylinder_body(parent: Node, node_name: String, center: Vector3, radius: float, height: float, mat: Material = null, layer := WORLD_LAYER) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	if mat != null:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 20
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		body.add_child(inst)
	parent.add_child(body)
	return body


## Walkable slab whose TOP surface runs from `bottom` to `top` (both are surface points on the centre line).
static func ramp(parent: Node, node_name: String, bottom: Vector3, top: Vector3, width: float, thickness: float, mat: Material, extra_length := 0.0) -> StaticBody3D:
	var dir := (top - bottom).normalized()
	var side := Vector3.UP.cross(dir).normalized()
	var normal := dir.cross(side)
	var length := bottom.distance_to(top) + extra_length
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var center := (bottom + top) * 0.5 - normal * thickness * 0.5
	body.transform = Transform3D(Basis(side, normal, dir), center)
	var size := Vector3(width, thickness, length)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	if mat != null:
		var mesh := BoxMesh.new()
		mesh.size = size
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		body.add_child(inst)
	parent.add_child(body)
	return body


## Instances a licensed model; null when the file is missing. `path` is a full res:// path.
static func model(parent: Node, path: String, pos: Vector3, yaw_deg := 0.0, scale := Vector3.ONE) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = _model_cache.get(path)
	if scene == null:
		scene = load(path) as PackedScene
		_model_cache[path] = scene
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return null
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = scale
	parent.add_child(inst)
	return inst


static func dungeon(parent: Node, asset: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	return model(parent, DUNGEON % asset, pos, yaw_deg, Vector3.ONE * scale)


static func nature(parent: Node, asset: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	return model(parent, NATURE % asset, pos, yaw_deg, Vector3.ONE * scale)


## Floor tiles (visual only) tiling the rectangle [x0,x1]x[z0,z1] at surface height `top`.
static func tile_floor(parent: Node, x0: float, x1: float, z0: float, z1: float, top: float, variant := "floor_tile_large") -> void:
	var nx := maxi(1, ceili((x1 - x0) / 4.0))
	var nz := maxi(1, ceili((z1 - z0) / 4.0))
	var sx := (x1 - x0) / (4.0 * nx)
	var sz := (z1 - z0) / (4.0 * nz)
	var holder := Node3D.new()
	holder.name = "Tiles_%d_%d" % [int(x0), int(z0)]
	parent.add_child(holder)
	for ix in nx:
		for iz in nz:
			var asset := variant
			if variant == "floor_tile_large" and (ix * 7 + iz * 3) % 5 == 0:
				asset = "floor_tile_large_rocks"
			var tile := model(holder, DUNGEON % asset, Vector3(x0 + (ix + 0.5) * 4.0 * sx, top - 0.045, z0 + (iz + 0.5) * 4.0 * sz), 0.0, Vector3(sx, 1.0, sz))
			if tile != null:
				tile.name = "Tile_%d_%d" % [ix, iz]


static func label(parent: Node, text: String, pos: Vector3, size_px := 40, pixel := 0.006, color := Color(0.95, 0.92, 0.8), billboard := false) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = size_px
	lab.pixel_size = pixel
	lab.modulate = color
	lab.outline_size = 10
	lab.outline_modulate = Color(0.05, 0.05, 0.08)
	if billboard:
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(lab)
	return lab


## Creates an objective interactable (extends the shared interactable base; group `interactable`).
static func interactable(parent: Node, node_name: String, pos: Vector3, prompt: String, focus_height := 0.8) -> Node3D:
	var item: Node3D = INTERACTABLE.new()
	item.name = node_name
	item.position = pos
	item.prompt_text = prompt
	item.focus_height = focus_height
	parent.add_child(item)
	return item


static func play(parent: Node3D, path: String, volume_db := 0.0) -> void:
	if parent == null or not parent.is_inside_tree() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 14.0
	player.max_distance = 60.0
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Registers a `compass_target` marker (read by the presentation HUD): metas label, region, hint, done.
static func compass_marker(parent: Node3D, marker_name: String, pos: Vector3, label_text: String, region: String, hint: String) -> Node3D:
	var marker := Node3D.new()
	marker.name = marker_name
	marker.position = pos
	marker.add_to_group(&"compass_target")
	marker.set_meta(&"label", label_text)
	marker.set_meta(&"region", region)
	marker.set_meta(&"hint", hint)
	marker.set_meta(&"done", false)
	parent.add_child(marker)
	return marker


## Locates the session: the explicit one, else the `session` group.
static func resolve_session(tree: SceneTree, explicit: Node) -> Node:
	if explicit != null and is_instance_valid(explicit):
		return explicit
	return tree.get_first_node_in_group(&"session")


static func is_progress(session: Node, key: StringName) -> bool:
	return session != null and bool(session.puzzle_progress.get(key, false))


static func mark_progress(session: Node, key: StringName) -> void:
	if session == null:
		return
	session.puzzle_progress[key] = true
	session.status_changed.emit()
