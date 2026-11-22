extends Node3D
## Puzzle 01 - Pilar Simbol. Four pillars with distinct SHAPES (sphere, cube, triangle pyramid, ring); a stone relief
## (always visible) shows the activation order. Correct order opens the seal over the artifact; a wrong pillar resets
## the chain without penalty. Module-local layout: artifact/seal at the origin, pillars on a 6.5 m ring, relief stele
## at the south-east entrance (+x,+z). Flat ground y=0, footprint within +/-12 m. No enemies live in this module.
##
## Interface: setup(player, session), is_solved(), get_solution(), get_progress(), reset_sequence(),
## get_pillar_interactable(symbol_id), signals solved / sequence_failed / pillar_activated.
## Session keys: puzzle_progress[&"symbol_pillars"] (solved), artifact pickup id &"forest_artifact".

const Kit := preload("res://scripts/objectives/objective_kit.gd")

signal solved
signal sequence_failed
signal pillar_activated(symbol_id: int, step: int)

const SOLVED_KEY := &"symbol_pillars"
const ARTIFACT_ID := &"forest_artifact"
const ARTIFACT_SCENE := preload("res://scenes/world/artifact_pickup.tscn")
const SYMBOL_NAMES: Array[String] = ["Lingkaran", "Kotak", "Segitiga", "Cincin"]
const SYMBOL_COLORS: Array[Color] = [
	Color(1.0, 0.6, 0.2), Color(0.35, 0.7, 1.0), Color(0.55, 0.95, 0.4), Color(0.95, 0.45, 0.95),
]
## Where each symbol's pillar stands (index = symbol id).
const PILLAR_POSITIONS: Array[Vector3] = [
	Vector3(-4.6, 0.0, -4.6), Vector3(4.6, 0.0, -4.6), Vector3(4.6, 0.0, 4.6), Vector3(-4.6, 0.0, 4.6),
]
const STELE_POSITION := Vector3(8.2, 0.0, 8.2)
const STELE_YAW := 45.0
const SEAL_RADIUS := 1.35
const SEAL_HEIGHT := 3.2

## Correct activation order as symbol ids (0 Lingkaran, 1 Kotak, 2 Segitiga, 3 Cincin).
@export var solution: Array[int] = [2, 0, 3, 1]

var _player: Node3D
var _session: Node
var _solved := false
var _progress: Array[int] = []
var _pillars: Array[Dictionary] = []
var _lamps: Array[MeshInstance3D] = []
var _lamp_mat_off: StandardMaterial3D
var _lamp_mat_on: StandardMaterial3D
var _seal_body: StaticBody3D
var _seal_mat: StandardMaterial3D
var _seal_label: Label3D
var _status_label: Label3D
var _artifact: Node3D
var _compass: Node3D
var _spin := 0.0
var _built := false


func _ready() -> void:
	_build()


## Called by the island assembler after add_child. `session` may be null (the `session` group is used then).
func setup(player: Node3D, session: Node = null) -> void:
	_player = player
	_session = Kit.resolve_session(get_tree(), session)
	if _session != null and not _session.status_changed.is_connected(_refresh_compass):
		_session.status_changed.connect(_refresh_compass)
	if Kit.is_progress(_session, SOLVED_KEY) and not _solved:
		_solved = true
		_apply_solved(false)
	_refresh_compass()


func is_solved() -> bool:
	return _solved


func get_solution() -> Array[int]:
	return solution.duplicate()


func get_progress() -> Array[int]:
	return _progress.duplicate()


func get_artifact() -> Node3D:
	return _artifact


func get_seal_body() -> StaticBody3D:
	return _seal_body


func get_pillar_interactable(symbol_id: int) -> Node3D:
	return _pillars[symbol_id]["item"] as Node3D


func get_relief_interactable() -> Node3D:
	return get_node_or_null(^"Stele/ReliefInteract") as Node3D


## Clears the current chain (also what a wrong pillar does). No penalty of any kind.
func reset_sequence() -> void:
	_progress.clear()
	for pillar in _pillars:
		_set_pillar_lit(pillar, false)
	_update_lamps()


# ------------------------------------------------------------------ interaction

func _can_press(_player: Node, pillar: Dictionary) -> bool:
	return not _solved and not bool(pillar["lit"])


func _press(pillar: Dictionary) -> bool:
	if _solved or bool(pillar["lit"]):
		return false
	var symbol_id: int = pillar["symbol"]
	if symbol_id == solution[_progress.size()]:
		_progress.append(symbol_id)
		_set_pillar_lit(pillar, true)
		Kit.play(self, Kit.SFX_GEM)
		_update_lamps()
		_say("Simbol %d/%d benar" % [_progress.size(), solution.size()], SYMBOL_COLORS[symbol_id])
		pillar_activated.emit(symbol_id, _progress.size())
		if _progress.size() == solution.size():
			_solve()
		return true
	_fail(pillar)
	return true


func _fail(pillar: Dictionary) -> void:
	reset_sequence()
	var mat: StandardMaterial3D = pillar["mat"]
	Kit.set_glow(mat, Color(1.0, 0.15, 0.1), 3.0)
	var light: OmniLight3D = pillar["light"]
	light.light_color = Color(1.0, 0.15, 0.1)
	light.light_energy = 2.0
	Kit.play(self, Kit.SFX_ERROR)
	_say("Urutan salah - ulangi dari awal. Periksa relief.", Color(1.0, 0.4, 0.3))
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_clear_flash.bind(pillar))
	sequence_failed.emit()


func _clear_flash(pillar: Dictionary) -> void:
	if not bool(pillar["lit"]):
		_set_pillar_lit(pillar, false)


func _solve() -> void:
	_solved = true
	Kit.mark_progress(_session, SOLVED_KEY)
	_apply_solved(true)
	solved.emit()


func _apply_solved(animate: bool) -> void:
	for pillar in _pillars:
		_set_pillar_lit(pillar, true)
	_progress.assign(solution)
	_update_lamps()
	if _seal_body != null:
		_seal_body.set_deferred(&"collision_layer", 0)
	_seal_label.text = "SEGEL TERBUKA"
	_seal_label.modulate = Color(0.6, 1.0, 0.7)
	if animate:
		Kit.play(self, Kit.SFX_SPELL)
		Kit.play(self, Kit.SFX_LOCK)
		_say("Segel terbuka! Ambil artefak di tengah.", Color(0.6, 1.0, 0.7))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_seal_mat, "albedo_color:a", 0.0, 1.0)
		tween.tween_property(_seal_body, "scale", Vector3(1.2, 0.05, 1.2), 1.0)
		tween.chain().tween_callback(_seal_body.queue_free)
	else:
		_seal_body.queue_free()
		_say("Segel terbuka", Color(0.6, 1.0, 0.7))
	_seal_body = null


func _set_pillar_lit(pillar: Dictionary, lit: bool) -> void:
	pillar["lit"] = lit
	var color: Color = SYMBOL_COLORS[int(pillar["symbol"])]
	var mat: StandardMaterial3D = pillar["mat"]
	var light: OmniLight3D = pillar["light"]
	if lit:
		Kit.set_glow(mat, color, 2.6)
		light.light_color = color
		light.light_energy = 1.8
	else:
		Kit.set_glow(mat, color.lerp(Color(0.35, 0.36, 0.4), 0.7), 0.0)
		light.light_energy = 0.0


func _update_lamps() -> void:
	for i in _lamps.size():
		_lamps[i].material_override = _lamp_mat_on if i < _progress.size() else _lamp_mat_off


func _say(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.modulate = color


func _refresh_compass() -> void:
	if _compass == null:
		return
	var collected: bool = _session != null and _session.is_collected(ARTIFACT_ID)
	_compass.set_meta(&"done", collected)
	_compass.set_meta(&"hint", "Segel terbuka - ambil artefak di tengah reruntuhan" if _solved else "Baca relief batu di pintu masuk, lalu aktifkan keempat pilar sesuai urutannya")


func _process(delta: float) -> void:
	_spin += delta
	for pillar in _pillars:
		(pillar["symbol_node"] as Node3D).rotation.y = _spin * 0.8


# ------------------------------------------------------------------ construction

func _build() -> void:
	if _built:
		return
	_built = true
	_lamp_mat_off = Kit.material(Color(0.25, 0.25, 0.28))
	_lamp_mat_on = Kit.material(Color(1.0, 0.85, 0.3), 3.0)
	_build_floor_and_ruins()
	_build_seal_and_artifact()
	for symbol_id in 4:
		_build_pillar(symbol_id)
	_build_stele()
	_compass = Kit.compass_marker(self, "CompassMarker", Vector3(0, 1.0, 0), "Pilar Simbol", "Reruntuhan", "")


func _build_floor_and_ruins() -> void:
	Kit.tile_floor(self, -10.0, 12.0, -10.0, 12.0, 0.0)
	for spec in [
		[Vector3(-6, 0, -11), 0.0], [Vector3(2, 0, -11), 0.0],
		[Vector3(-11, 0, -4), 90.0], [Vector3(-11, 0, 4), 90.0],
	]:
		var pos: Vector3 = spec[0]
		var yaw: float = spec[1]
		Kit.dungeon(self, "wall_broken", pos, yaw)
		Kit.box_body(self, "WallCollision", pos + Vector3(0, 1.25, 0), Vector3(3.8, 2.5, 0.9), null, yaw)
	for pos in [Vector3(-10.5, 0, -10.5), Vector3(10.5, 0, -10.5), Vector3(-10.5, 0, 10.5)]:
		Kit.dungeon(self, "pillar", pos, 0.0, 1.0)
		Kit.cylinder_body(self, "PillarCollision", pos + Vector3(0, 2.0, 0), 0.6, 4.0)
	Kit.dungeon(self, "rubble_half", Vector3(-9.5, 0, 8), 160.0)
	Kit.dungeon(self, "rubble_large", Vector3(10, 0, -7), 70.0, 0.7)
	for pos in [Vector3(-14, 0, -8), Vector3(-14, 0, 6), Vector3(13, 0, -12), Vector3(14, 0, 2)]:
		Kit.nature(self, "Tree_1_A_Color1", pos, pos.x * 13.0)
		Kit.cylinder_body(self, "TrunkCollision", pos + Vector3(0, 2.0, 0), 0.45, 4.0)
	for pos in [Vector3(-8.5, 0, -8.5), Vector3(11.5, 0, 5)]:
		Kit.nature(self, "Rock_3_A_Color1", pos, pos.z * 17.0, 2.0)


func _build_seal_and_artifact() -> void:
	_artifact = ARTIFACT_SCENE.instantiate() as Node3D
	_artifact.set(&"pickup_id", ARTIFACT_ID)
	_artifact.set(&"display_name", "Artefak Simbol")
	_artifact.name = "ArtifactPickup"
	add_child(_artifact)
	_seal_mat = Kit.material(Color(0.55, 0.35, 1.0), 1.6, 0.38)
	_seal_body = Kit.cylinder_body(self, "Seal", Vector3(0, SEAL_HEIGHT * 0.5, 0), SEAL_RADIUS, SEAL_HEIGHT, _seal_mat)
	_seal_label = Kit.label(self, "SEGEL TERKUNCI", Vector3(0, SEAL_HEIGHT + 0.6, 0), 44, 0.008, Color(0.8, 0.65, 1.0), true)
	_seal_label.name = "SealLabel"
	_status_label = Kit.label(self, "Aktifkan pilar sesuai urutan relief", Vector3(0, SEAL_HEIGHT + 1.2, 0), 36, 0.008, Color(0.95, 0.92, 0.8), true)
	_status_label.name = "StatusLabel"


func _make_symbol_mesh(symbol_id: int, size: float) -> Mesh:
	match symbol_id:
		0:
			var sphere := SphereMesh.new()
			sphere.radius = 0.38 * size
			sphere.height = 0.76 * size
			return sphere
		1:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * 0.64 * size
			return cube
		2:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5 * size
			cone.height = 0.9 * size
			cone.radial_segments = 3
			return cone
		_:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.2 * size
			ring.outer_radius = 0.44 * size
			return ring


func _build_pillar(symbol_id: int) -> void:
	var pos: Vector3 = PILLAR_POSITIONS[symbol_id]
	var root := Node3D.new()
	root.name = "Pillar_%s" % SYMBOL_NAMES[symbol_id]
	root.position = pos
	add_child(root)
	Kit.dungeon(root, "column", Vector3.ZERO, 0.0, 1.5)
	Kit.cylinder_body(root, "Collision", Vector3(0, 1.05, 0), 0.55, 2.1)
	var base_color: Color = SYMBOL_COLORS[symbol_id]
	var ring_mat := Kit.material(base_color.lerp(Color(0.3, 0.3, 0.32), 0.6))
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.95
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.08
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	var mat := Kit.material(base_color.lerp(Color(0.35, 0.36, 0.4), 0.7))
	var symbol_node := Node3D.new()
	symbol_node.name = "SymbolSpin"
	symbol_node.position = Vector3(0, 2.75, 0)
	root.add_child(symbol_node)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Symbol"
	mesh_node.mesh = _make_symbol_mesh(symbol_id, 1.0)
	mesh_node.material_override = mat
	if symbol_id == 3:
		mesh_node.rotation_degrees.x = 70.0
	symbol_node.add_child(mesh_node)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position = Vector3(0, 2.75, 0)
	light.omni_range = 5.0
	light.light_energy = 0.0
	root.add_child(light)
	Kit.label(root, SYMBOL_NAMES[symbol_id], Vector3(0, 3.55, 0), 32, 0.006, base_color.lerp(Color.WHITE, 0.4), true)
	var toward := (-pos).normalized()
	var item := Kit.interactable(self, "Interact_%s" % SYMBOL_NAMES[symbol_id], pos + toward * 1.15, "Aktifkan Pilar %s" % SYMBOL_NAMES[symbol_id], 1.0)
	var pillar := {"symbol": symbol_id, "lit": false, "mat": mat, "light": light, "item": item, "symbol_node": symbol_node}
	item.enabled_callable = _can_press.bind(pillar)
	item.interact_callable = func(_p: Node) -> bool: return _press(pillar)
	_pillars.append(pillar)


func _build_stele() -> void:
	var stele := Node3D.new()
	stele.name = "Stele"
	stele.position = STELE_POSITION
	stele.rotation_degrees.y = STELE_YAW
	add_child(stele)
	var stone := Kit.material(Color(0.5, 0.55, 0.46))
	var dark := Kit.material(Color(0.22, 0.24, 0.22))
	Kit.box_body(stele, "Slab", Vector3(0, 1.25, 0), Vector3(3.6, 2.5, 0.5), stone)
	Kit.box_mesh(stele, "Cap", Vector3(0, 2.55, 0), Vector3(3.9, 0.2, 0.7), stone)
	Kit.box_mesh(stele, "Panel", Vector3(0, 1.45, 0.26), Vector3(3.2, 1.55, 0.04), dark)
	Kit.label(stele, "URUTAN AKTIVASI PILAR", Vector3(0, 2.15, 0.3), 36, 0.006, Color(1.0, 0.9, 0.55))
	var count := solution.size()
	for i in count:
		var symbol_id: int = solution[i]
		var x := (i - (count - 1) * 0.5) * 0.8
		var holder := Node3D.new()
		holder.position = Vector3(x, 1.55, 0.4)
		stele.add_child(holder)
		var mesh_node := MeshInstance3D.new()
		mesh_node.mesh = _make_symbol_mesh(symbol_id, 0.75)
		mesh_node.material_override = Kit.material(SYMBOL_COLORS[symbol_id], 0.9)
		if symbol_id == 3:
			mesh_node.rotation_degrees.x = 90.0
		holder.add_child(mesh_node)
		Kit.label(stele, str(i + 1), Vector3(x, 1.98, 0.3), 36, 0.006, Color.WHITE)
		Kit.label(stele, SYMBOL_NAMES[symbol_id], Vector3(x, 1.08, 0.3), 24, 0.005, Color(0.85, 0.85, 0.8))
		var lamp := MeshInstance3D.new()
		var lamp_mesh := SphereMesh.new()
		lamp_mesh.radius = 0.09
		lamp_mesh.height = 0.18
		lamp.mesh = lamp_mesh
		lamp.material_override = _lamp_mat_off
		lamp.position = Vector3(x, 0.78, 0.3)
		stele.add_child(lamp)
		_lamps.append(lamp)
	for side in [-1.0, 1.0]:
		Kit.box_mesh(stele, "TorchStub", Vector3(side * 2.2, 0.5, 0.0), Vector3(0.3, 1.0, 0.3), stone)
		Kit.dungeon(stele, "torch_lit", Vector3(side * 2.2, 1.35, 0.0))
	var names: PackedStringArray = []
	for symbol_id in solution:
		names.append(SYMBOL_NAMES[symbol_id])
	var read := Kit.interactable(stele, "ReliefInteract", Vector3(0, 0.0, 1.3), "Baca relief: " + " > ".join(names), 1.4)
	read.interact_callable = func(_p: Node) -> bool:
		Kit.play(self, Kit.SFX_TICK)
		_say("Urutan: " + " > ".join(names), Color(1.0, 0.9, 0.55))
		return true
