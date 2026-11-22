extends Node3D
## Static + dynamic dressing of the Gatekeeper arena (built in code, local space of the encounter root).
## Layout (local metres, +Z south = access, -Z north = dock): plaza x +/-18, z -15..+15; south entrance gap +/-5.5 (sealed
## by an energy barrier during the fight); north gate opening +/-4.5 (two sliding slabs + energy seal) leading to a dock
## corridor z -16.5..-27. Interactables: three artifact sockets (V arc) and the activation altar. All collision is layer 1.

signal gate_opened
signal dock_entered(body: Node3D)

const CONSOLE := preload("res://scripts/boss/gate_console.gd")
const HALF_X := 18.0
const HALF_Z := 15.0
const ENTRANCE_HALF := 5.5
const GATE_HALF := 4.5
const WALL_H := 7.0
const GATE_H := 5.8
const DOCK_END := -27.0
const RETRY_POINT := Vector3(0.0, 0.1, 13.5)
const ALTAR_POS := Vector3(0.0, 0.0, 5.5)
const SOCKETS := [
	{"id": &"forest_artifact", "name": "Artefak Hutan", "label": "Simbol", "pos": Vector3(-6.0, 0.0, 11.5), "color": Color(0.35, 1.0, 0.45)},
	{"id": &"summit_artifact", "name": "Artefak Puncak", "label": "Puncak", "pos": Vector3(0.0, 0.0, 9.0), "color": Color(1.0, 0.85, 0.35)},
	{"id": &"energy_artifact", "name": "Artefak Energi", "label": "Energi", "pos": Vector3(6.0, 0.0, 11.5), "color": Color(0.35, 0.8, 1.0)},
]

var consoles: Dictionary = {}
var altar: Node3D
var gate_body: StaticBody3D
var barrier_body: StaticBody3D

var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _rune_mat: StandardMaterial3D
var _seal_mat: StandardMaterial3D
var _barrier_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _door_l: Node3D
var _door_r: Node3D
var _seal: MeshInstance3D
var _barrier: MeshInstance3D
var _altar_core: MeshInstance3D
var _altar_core_mat: StandardMaterial3D
var _altar_light: OmniLight3D
var _socket_visuals: Dictionary = {}
var _socket_labels: Dictionary = {}
var _altar_label: Label3D
var _rune_energy := 0.4
var _rune_color := Color(0.3, 0.85, 1.0)
var _seal_color := Color(1.0, 0.2, 0.15)
var _time := 0.0
var _gate_open := false


func build(encounter: Node) -> void:
	_stone = _std(Color(0.43, 0.41, 0.38), 0.95)
	_dark = _std(Color(0.26, 0.25, 0.25), 0.95)
	_rune_mat = _glow(Color(0.3, 0.85, 1.0), 0.4)
	_seal_mat = _glow(_seal_color, 1.5)
	_seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_seal_mat.albedo_color.a = 0.55
	_seal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_barrier_mat = _glow(Color(0.3, 0.85, 1.0), 1.6)
	_barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_barrier_mat.albedo_color.a = 0.0
	_barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_floor()
	_build_walls()
	_build_gate()
	_build_barrier()
	_build_dock()
	_build_pylons()
	_build_altar(encounter)
	for data: Dictionary in SOCKETS:
		_build_socket(data, encounter)
	var retry := Marker3D.new()
	retry.name = &"RetryPoint"
	retry.position = RETRY_POINT
	add_child(retry)
	set_rune(_rune_color, _rune_energy)


func _process(delta: float) -> void:
	_time += delta
	if _seal != null and _seal.visible:
		_seal_mat.albedo_color.a = 0.45 + 0.12 * sin(_time * 3.0)
		_seal_mat.emission_energy_multiplier = 1.4 + 0.5 * sin(_time * 3.0)
	if _altar_core != null:
		_altar_core.rotate_y(delta * 1.2)
		_altar_core.position.y = 1.9 + sin(_time * 1.8) * 0.1


func set_barrier(closed: bool) -> void:
	for shape in barrier_body.get_children():
		if shape is CollisionShape3D:
			shape.set_deferred(&"disabled", not closed)
	_barrier.visible = true
	var tween := create_tween()
	tween.tween_property(_barrier_mat, "albedo_color:a", 0.42 if closed else 0.0, 0.45)
	if not closed:
		tween.tween_callback(func(): _barrier.visible = false)


func is_gate_open() -> bool:
	return _gate_open


## Slides the slabs into the walls, dissolves the seal and removes the gate collision.
func open_gate(duration := 3.0) -> void:
	if _gate_open:
		return
	_gate_open = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_seal_mat, "emission_energy_multiplier", 0.0, 1.0)
	tween.tween_property(_seal_mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_property(_door_l, "position:x", -GATE_HALF * 1.5 - 2.25, duration).set_delay(0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_door_r, "position:x", GATE_HALF * 1.5 + 2.25, duration).set_delay(0.7).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(_finish_gate_open)


func set_rune(color: Color, energy: float) -> void:
	_rune_color = color
	_rune_energy = energy
	_rune_mat.albedo_color = color
	_rune_mat.emission = color
	_rune_mat.emission_energy_multiplier = energy
	for light in _lights:
		light.light_color = color
		light.light_energy = clampf(energy * 0.35, 0.0, 3.0)
	_barrier_mat.emission = color
	_barrier_mat.albedo_color = Color(color.r, color.g, color.b, _barrier_mat.albedo_color.a)


func set_seal_active(active: bool) -> void:
	_seal.visible = active


func set_socket_installed(id: StringName, installed: bool, animate := true) -> void:
	var visual: Dictionary = _socket_visuals.get(id, {})
	if visual.is_empty():
		return
	(visual["shard"] as Node3D).visible = installed
	(visual["light"] as OmniLight3D).visible = installed
	(visual["beam"] as Node3D).visible = installed
	if installed and animate:
		var shard := visual["shard"] as Node3D
		shard.scale = Vector3.ONE * 0.1
		create_tween().tween_property(shard, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var burst := visual["burst"] as CPUParticles3D
		burst.restart()
		burst.emitting = true


func set_socket_text(id: StringName, text: String) -> void:
	var label := _socket_labels.get(id) as Label3D
	if label != null:
		label.text = text


func set_altar_state(ready: bool, text: String) -> void:
	_altar_label.text = text
	var color := Color(0.3, 0.85, 1.0) if ready else Color(0.25, 0.2, 0.2)
	_altar_core_mat.albedo_color = color
	_altar_core_mat.emission = color
	_altar_core_mat.emission_energy_multiplier = 2.6 if ready else 0.15
	_altar_light.light_energy = 1.6 if ready else 0.0


func set_altar_visible(shown: bool) -> void:
	altar.visible = shown
	_altar_label.visible = shown
	if not shown:
		altar.remove_from_group(&"interactable")
	elif not altar.is_in_group(&"interactable"):
		altar.add_to_group(&"interactable")


func retry_point_global() -> Vector3:
	return to_global(RETRY_POINT)


# ---------------------------------------------------------------- construction

func _finish_gate_open() -> void:
	for shape in gate_body.get_children():
		if shape is CollisionShape3D:
			(shape as CollisionShape3D).disabled = true
	_seal.visible = false
	gate_opened.emit()


func _build_floor() -> void:
	_box(self, &"FloorCollision", Vector3(HALF_X * 2 + 3.0, 1.0, HALF_Z * 2 + 3.0), Vector3(0, -0.5, 0), null, true)
	_box(self, &"ApproachCollision", Vector3(14.0, 1.0, 8.0), Vector3(0, -0.5, HALF_Z + 5.5), null, true)
	_box(self, &"DockCollision", Vector3(13.0, 1.0, 12.0), Vector3(0, -0.5, -21.5), null, true)
	_box(self, &"PlazaVisual", Vector3(HALF_X * 2, 0.1, HALF_Z * 2), Vector3(0, -0.038, 0), _stone, false)
	var ring := MeshInstance3D.new()
	ring.name = &"RuneRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 12.4
	torus.outer_radius = 13.0
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _rune_mat
	ring.scale = Vector3(1.0, 0.02, 1.0)
	ring.position = Vector3(0, 0.02, -1.0)
	add_child(ring)
	var inner := MeshInstance3D.new()
	inner.name = &"RuneInner"
	var t2 := TorusMesh.new()
	t2.inner_radius = 3.9
	t2.outer_radius = 4.2
	t2.rings = 32
	t2.ring_segments = 4
	inner.mesh = t2
	inner.material_override = _rune_mat
	inner.scale = Vector3(1.0, 0.02, 1.0)
	inner.position = Vector3(0, 0.02, -5.0)
	add_child(inner)


func _build_walls() -> void:
	var t := 1.5
	_box(self, &"WallWest", Vector3(t, WALL_H, HALF_Z * 2 + 3.0), Vector3(-HALF_X - t * 0.5, WALL_H * 0.5, 0), _dark, true)
	_box(self, &"WallEast", Vector3(t, WALL_H, HALF_Z * 2 + 3.0), Vector3(HALF_X + t * 0.5, WALL_H * 0.5, 0), _dark, true)
	var north_w := HALF_X + t - GATE_HALF
	_box(self, &"WallNorthWest", Vector3(north_w, WALL_H, t), Vector3(-(GATE_HALF + north_w * 0.5), WALL_H * 0.5, -HALF_Z - t * 0.5), _dark, true)
	_box(self, &"WallNorthEast", Vector3(north_w, WALL_H, t), Vector3(GATE_HALF + north_w * 0.5, WALL_H * 0.5, -HALF_Z - t * 0.5), _dark, true)
	_box(self, &"GateLintel", Vector3(GATE_HALF * 2, WALL_H - GATE_H, t), Vector3(0, GATE_H + (WALL_H - GATE_H) * 0.5, -HALF_Z - t * 0.5), _dark, true)
	var south_w := HALF_X + t - ENTRANCE_HALF
	_box(self, &"WallSouthWest", Vector3(south_w, WALL_H, t), Vector3(-(ENTRANCE_HALF + south_w * 0.5), WALL_H * 0.5, HALF_Z + t * 0.5), _dark, true)
	_box(self, &"WallSouthEast", Vector3(south_w, WALL_H, t), Vector3(ENTRANCE_HALF + south_w * 0.5, WALL_H * 0.5, HALF_Z + t * 0.5), _dark, true)
	# Entrance posts.
	for sx in [-1.0, 1.0]:
		_box(self, &"EntrancePost", Vector3(1.4, 4.2, 1.4), Vector3(sx * (ENTRANCE_HALF + 0.2), 2.1, HALF_Z + 0.75), _stone, false)


func _build_gate() -> void:
	var z := -HALF_Z - 0.75
	gate_body = _box(self, &"GateBody", Vector3(GATE_HALF * 2, GATE_H, 1.4), Vector3(0, GATE_H * 0.5, z), null, true) as StaticBody3D
	_door_l = _box(self, &"GateDoorL", Vector3(GATE_HALF, GATE_H, 1.2), Vector3(-GATE_HALF * 0.5, GATE_H * 0.5, z), _stone, false)
	_door_r = _box(self, &"GateDoorR", Vector3(GATE_HALF, GATE_H, 1.2), Vector3(GATE_HALF * 0.5, GATE_H * 0.5, z), _stone, false)
	for door in [_door_l, _door_r]:
		for i in 3:
			_box(door, &"Rune", Vector3(0.5, 0.5, 0.1), Vector3(0, 1.2 + i * 1.5, 0.62), _rune_mat, false)
	_seal = MeshInstance3D.new()
	_seal.name = &"GateSeal"
	var quad := QuadMesh.new()
	quad.size = Vector2(GATE_HALF * 2, GATE_H)
	_seal.mesh = quad
	_seal.material_override = _seal_mat
	_seal.position = Vector3(0, GATE_H * 0.5, z + 0.7)
	add_child(_seal)


func _build_barrier() -> void:
	barrier_body = StaticBody3D.new()
	barrier_body.name = &"ArenaBarrier"
	barrier_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(ENTRANCE_HALF * 2 + 0.6, WALL_H, 0.6)
	shape.disabled = true
	shape.position = Vector3(0, WALL_H * 0.5, HALF_Z + 0.75)
	barrier_body.add_child(shape)
	add_child(barrier_body)
	_barrier = MeshInstance3D.new()
	_barrier.name = &"BarrierEnergy"
	var quad := QuadMesh.new()
	quad.size = Vector2(ENTRANCE_HALF * 2, 6.0)
	_barrier.mesh = quad
	_barrier.material_override = _barrier_mat
	_barrier.position = Vector3(0, 3.0, HALF_Z + 0.75)
	_barrier.visible = false
	add_child(_barrier)


func _build_dock() -> void:
	_box(self, &"DockVisual", Vector3(12.0, 0.1, 11.0), Vector3(0, -0.038, -22.0), _dark, false)
	for sx in [-1.0, 1.0]:
		_box(self, &"DockWall", Vector3(1.0, 4.0, 12.0), Vector3(sx * 6.5, 2.0, -21.5), _dark, true)
	_box(self, &"DockEndStop", Vector3(14.0, 4.0, 0.6), Vector3(0, 2.0, DOCK_END - 0.3), null, true)
	# Exit arch.
	for sx in [-1.0, 1.0]:
		_box(self, &"ArchPost", Vector3(0.9, 5.0, 0.9), Vector3(sx * 4.0, 2.5, DOCK_END + 1.0), _stone, false)
		_box(self, &"ArchRune", Vector3(0.25, 3.5, 0.2), Vector3(sx * 4.0, 2.5, DOCK_END + 1.55), _rune_mat, false)
	_box(self, &"ArchBeam", Vector3(9.0, 0.8, 0.9), Vector3(0, 5.0, DOCK_END + 1.0), _stone, false)
	var trigger := Area3D.new()
	trigger.name = &"DockTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10.0, 4.0, 3.0)
	shape.position = Vector3(0, 2.0, -21.0)
	trigger.add_child(shape)
	add_child(trigger)
	trigger.body_entered.connect(func(body: Node3D): dock_entered.emit(body))


func _build_pylons() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pos := Vector3(sx * (HALF_X - 1.8), 0, sz * (HALF_Z - 2.5) - 0.0)
			_box(self, &"PylonBase", Vector3(1.3, 3.4, 1.3), pos + Vector3(0, 1.7, 0), _stone, true)
			var crystal := MeshInstance3D.new()
			crystal.name = &"PylonCrystal"
			var prism := PrismMesh.new()
			prism.size = Vector3(0.9, 1.5, 0.9)
			crystal.mesh = prism
			crystal.material_override = _rune_mat
			crystal.position = pos + Vector3(0, 4.2, 0)
			add_child(crystal)
			var light := OmniLight3D.new()
			light.omni_range = 9.0
			light.position = pos + Vector3(0, 4.3, 0)
			add_child(light)
			_lights.append(light)


func _build_altar(encounter: Node) -> void:
	var node := CONSOLE.new()
	node.name = &"ActivationAltar"
	node.role = &"altar"
	node.focus_height = 1.2
	node.encounter = encounter
	node.position = ALTAR_POS
	altar = node
	add_child(altar)
	_cyl(altar, Vector3.ZERO, 1.3, 1.0, _dark, true)
	_cyl(altar, Vector3(0, 1.0, 0), 1.0, 0.12, _stone, false)
	_altar_core_mat = _glow(Color(0.3, 0.85, 1.0), 0.15)
	_altar_core = MeshInstance3D.new()
	_altar_core.name = &"AltarCore"
	var gem := SphereMesh.new()
	gem.radius = 0.45
	gem.height = 1.1
	gem.radial_segments = 6
	gem.rings = 3
	_altar_core.mesh = gem
	_altar_core.material_override = _altar_core_mat
	_altar_core.position = Vector3(0, 1.9, 0)
	altar.add_child(_altar_core)
	_altar_light = OmniLight3D.new()
	_altar_light.omni_range = 7.0
	_altar_light.light_color = Color(0.3, 0.85, 1.0)
	_altar_light.position = Vector3(0, 1.9, 0)
	altar.add_child(_altar_light)
	_altar_label = _label(altar, Vector3(0, 3.0, 0))


func _build_socket(data: Dictionary, encounter: Node) -> void:
	var id: StringName = data["id"]
	var color: Color = data["color"]
	var console := CONSOLE.new()
	console.name = StringName("Socket_%s" % id)
	console.role = &"socket"
	console.artifact_id = id
	console.display_name = data["name"]
	console.focus_height = 1.2
	console.encounter = encounter
	console.position = data["pos"]
	add_child(console)
	consoles[id] = console
	_cyl(console, Vector3.ZERO, 0.62, 0.9, _dark, true)
	var hollow := _cyl(console, Vector3(0, 0.9, 0), 0.42, 0.06, _std(Color(0.08, 0.08, 0.09), 1.0), false)
	hollow.name = &"Hollow"
	var glow := _glow(color, 0.5)
	var rim := _cyl(console, Vector3(0, 0.88, 0), 0.5, 0.04, glow, false)
	rim.name = &"SlotGlow"
	var shard := Node3D.new()
	shard.name = &"InstalledShard"
	shard.position = Vector3(0, 1.55, 0)
	console.add_child(shard)
	var shard_mat := _glow(color, 2.2)
	for flip in [1.0, -1.0]:
		var part := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.4, 0.6, 0.4)
		part.mesh = prism
		part.material_override = shard_mat
		part.position = Vector3(0, 0.3 * flip, 0)
		part.rotation.z = 0.0 if flip > 0 else PI
		shard.add_child(part)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 5.0
	light.position = Vector3(0, 1.55, 0)
	console.add_child(light)
	var beam := _beam(console, Vector3(0, 1.55, 0), ALTAR_POS - console.position + Vector3(0, 1.9, 0), color)
	var burst := CPUParticles3D.new()
	burst.name = &"InstallBurst"
	burst.amount = 28
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 1.0
	burst.lifetime = 0.9
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3(0, -4.0, 0)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.09, 0.09, 0.09)
	burst.mesh = spark
	burst.material_override = _glow(color, 3.0)
	burst.position = Vector3(0, 1.4, 0)
	console.add_child(burst)
	_socket_visuals[id] = {"shard": shard, "light": light, "beam": beam, "burst": burst}
	_socket_labels[id] = _label(console, Vector3(0, 2.6, 0))
	set_socket_installed(id, false, false)


func _beam(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	beam.name = &"Beam"
	var cylinder := CylinderMesh.new()
	var dir := to - from
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = dir.length()
	cylinder.radial_segments = 6
	beam.mesh = cylinder
	beam.material_override = _glow(color, 2.0)
	beam.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5), from + dir * 0.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	return beam


func _label(parent: Node3D, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.007
	label.font_size = 44
	label.outline_size = 12
	label.modulate = Color(0.9, 0.95, 1.0)
	label.no_depth_test = true
	label.position = pos
	parent.add_child(label)
	return label


# ---------------------------------------------------------------- primitives

func _std(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## Box with optional material/visual and optional layer-1 collider. Returns the StaticBody3D when it collides, otherwise the MeshInstance3D.
func _box(parent: Node, node_name: StringName, size: Vector3, pos: Vector3, mat: Material, collide: bool) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		root = body
		if mat != null:
			var mesh := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = size
			mesh.mesh = box_mesh
			mesh.material_override = mat
			body.add_child(mesh)
	else:
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		mesh.material_override = mat
		root = mesh
	root.name = node_name
	root.position = pos
	parent.add_child(root)
	return root


func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, collide: bool) -> Node3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 10
	mesh.mesh = cylinder
	mesh.material_override = mat
	mesh.position = pos + Vector3(0, height * 0.5, 0)
	parent.add_child(mesh)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = radius
		cyl_shape.height = height
		shape.shape = cyl_shape
		body.add_child(shape)
		mesh.add_child(body)
	return mesh
