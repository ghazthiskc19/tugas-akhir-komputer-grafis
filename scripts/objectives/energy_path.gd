extends Node3D
## Puzzle 02 - Jalur Energi. Three rotatable stone panels (straight / elbow) route energy from the source crystal to the
## altar. One E press turns a panel 90 degrees clockwise (seen from above). Flow lights only the VALID PREFIX of the chain
## (source -> panel 1 -> ... ); the seal over the altar artifact opens only when the whole chain reaches the altar.
##
## Module-local layout (4 m cells, grid col 0..3 / row 1..2, cell centre = ((col-1.5)*4, 0, (row-1.5)*4)):
##   Source crystal cell (0,2) emits EAST.  Panel1 (1,2) straight.  Panel2 (2,2) elbow.  Panel3 (2,1) elbow.
##   Altar cell (3,1) accepts from its WEST side.  Footprint x +/-9, z +/-7; flat ground y=0; panels are walkable inlays.
## Side encoding: 0=N(-z) 1=E(+x) 2=S(+z) 3=W(-x). Orientation o = number of clockwise quarter turns from the base:
##   straight base = N-S (period 2), elbow base = N-E. Initial orientations [0,1,2]; solutions [1|3, 3, 1] (validated).
##
## Interface: setup(player, session), is_solved(), is_rotating(), get_orientations(), get_panel_kinds(),
## get_panel_interactable(i), rotate_panel(i) -> bool, trace(orientations) -> Dictionary,
## validate_orientations() -> Dictionary (all 64 combos), signals solved / panel_rotated / flow_changed.
## Session keys: puzzle_progress[&"energy_path"] (solved), artifact pickup id &"energy_artifact".

const Kit := preload("res://scripts/objectives/objective_kit.gd")

signal solved
signal panel_rotated(index: int, orientation: int)
signal flow_changed(prefix: int, reaches_altar: bool)

const SOLVED_KEY := &"energy_path"
const ARTIFACT_ID := &"energy_artifact"
const ARTIFACT_SCENE := preload("res://scenes/world/artifact_pickup.tscn")

const N := 0
const E := 1
const S := 2
const W := 3
const DIR_CELL: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_VEC: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
const DIR_YAW: Array[float] = [0.0, -90.0, 180.0, 90.0]

const CELL_SIZE := 4.0
const SOURCE_CELL := Vector2i(0, 2)
const SOURCE_OUT := E
const ALTAR_CELL := Vector2i(3, 1)
const ALTAR_IN := W
const PANEL_CELLS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1)]
const PANEL_KINDS: Array[String] = ["straight", "elbow", "elbow"]
const INITIAL_ORIENTATIONS: Array[int] = [0, 1, 2]
const ROTATE_TIME := 0.22

const COLOR_OFF := Color(0.16, 0.2, 0.26)
const COLOR_ON := Color(0.3, 0.95, 1.0)

var _player: Node3D
var _session: Node
var _solved := false
var _rotating := 0
var _panels: Array[Dictionary] = []
var _seal_body: StaticBody3D
var _seal_mat: StandardMaterial3D
var _altar_stub_mat: StandardMaterial3D
var _flow_label: Label3D
var _artifact: Node3D
var _compass: Node3D
var _crystal: Node3D
var _time := 0.0
var _built := false


func _ready() -> void:
	_build()


func setup(player: Node3D, session: Node = null) -> void:
	_player = player
	_session = Kit.resolve_session(get_tree(), session)
	if _session != null and not _session.status_changed.is_connected(_refresh_compass):
		_session.status_changed.connect(_refresh_compass)
	if Kit.is_progress(_session, SOLVED_KEY) and not _solved:
		_solved = true
		var solution := _find_solutions()[0] as Array
		for i in _panels.size():
			_set_panel_orientation(_panels[i], int(solution[i]))
		_refresh_flow()
		_open_seal(false)
	_refresh_compass()


func is_solved() -> bool:
	return _solved


func is_rotating() -> bool:
	return _rotating > 0


func get_orientations() -> Array[int]:
	var result: Array[int] = []
	for panel in _panels:
		result.append(int(panel["orient"]))
	return result


func get_panel_kinds() -> Array[String]:
	return PANEL_KINDS.duplicate()


func get_panel_interactable(index: int) -> Node3D:
	return _panels[index]["item"] as Node3D


func get_artifact() -> Node3D:
	return _artifact


func get_seal_body() -> StaticBody3D:
	return _seal_body


## Rotates panel `index` by one quarter turn. False while any panel is turning, after the puzzle is solved, or
## for a bad index (reentry guard, identical to pressing E).
func rotate_panel(index: int) -> bool:
	if index < 0 or index >= _panels.size() or _solved or _rotating > 0:
		return false
	var panel := _panels[index]
	_rotating += 1
	panel["orient"] = (int(panel["orient"]) + 1) % 4
	panel["turns"] = int(panel["turns"]) + 1
	var rotor: Node3D = panel["rotor"]
	var tween := create_tween()
	tween.tween_property(rotor, "rotation_degrees:y", -90.0 * float(panel["turns"]), ROTATE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_rotation_done.bind(index))
	Kit.play(self, Kit.SFX_STONES)
	return true


# ------------------------------------------------------------------ logic (pure)

## Sides (two ints) a panel of `kind` exposes at orientation `orient`.
static func sides_of(kind: String, orient: int) -> Array[int]:
	var base: Array[int] = [N, E]
	if kind == "straight":
		base = [N, S]
	return [(base[0] + orient) % 4, (base[1] + orient) % 4]


## Follows the energy from the source. Returns {powered: Array[bool], entries: Array[int], exits: Array[int],
## prefix: int (number of consecutively powered panels), solved: bool (reaches the altar through its input side)}.
static func trace(orientations: Array) -> Dictionary:
	var powered: Array[bool] = [false, false, false]
	var entries: Array[int] = [-1, -1, -1]
	var exits: Array[int] = [-1, -1, -1]
	var cell := SOURCE_CELL
	var dir := SOURCE_OUT
	var prefix := 0
	var reached := false
	for _step in 6:
		cell += DIR_CELL[dir]
		var entry := (dir + 2) % 4
		if cell == ALTAR_CELL:
			reached = entry == ALTAR_IN
			break
		var index := PANEL_CELLS.find(cell)
		if index < 0:
			break
		var sides := sides_of(PANEL_KINDS[index], int(orientations[index]))
		if not sides.has(entry):
			break
		powered[index] = true
		entries[index] = entry
		var out: int = sides[0] if sides[1] == entry else sides[1]
		exits[index] = out
		dir = out
		prefix += 1
	return {"powered": powered, "entries": entries, "exits": exits, "prefix": prefix, "solved": reached}


static func _find_solutions() -> Array:
	var found: Array = []
	for a in 4:
		for b in 4:
			for c in 4:
				if trace([a, b, c])["solved"]:
					found.append([a, b, c])
	return found


## Checks all 4*4*4 = 64 orientation combinations: the initial layout must be unsolved yet solvable. Returns
## {total, solving: Array of [o1,o2,o3], initial, initial_solved, min_presses, valid}.
func validate_orientations() -> Dictionary:
	var solutions := _find_solutions()
	var min_presses := 999
	for solution in solutions:
		var presses := 0
		for i in 3:
			presses += (int(solution[i]) - INITIAL_ORIENTATIONS[i] + 4) % 4
		min_presses = mini(min_presses, presses)
	var initial_solved: bool = trace(INITIAL_ORIENTATIONS)["solved"]
	return {
		"total": 64, "solving": solutions, "initial": INITIAL_ORIENTATIONS.duplicate(),
		"initial_solved": initial_solved, "min_presses": min_presses,
		"valid": not solutions.is_empty() and not initial_solved and min_presses > 0,
	}


# ------------------------------------------------------------------ flow / state

func _on_rotation_done(index: int) -> void:
	_rotating = maxi(0, _rotating - 1)
	panel_rotated.emit(index, int(_panels[index]["orient"]))
	if _rotating > 0:
		return
	var result := _refresh_flow()
	if bool(result["solved"]) and not _solved:
		_solved = true
		Kit.mark_progress(_session, SOLVED_KEY)
		_open_seal(true)
		solved.emit()


func _set_panel_orientation(panel: Dictionary, orient: int) -> void:
	panel["orient"] = orient
	panel["turns"] = orient
	(panel["rotor"] as Node3D).rotation_degrees.y = -90.0 * float(orient)


func _refresh_flow() -> Dictionary:
	var result := trace(get_orientations())
	for index in _panels.size():
		var panel := _panels[index]
		var on: bool = result["powered"][index]
		var orient: int = panel["orient"]
		Kit.set_glow(panel["hub_mat"], COLOR_ON if on else COLOR_OFF, 2.2 if on else 0.0)
		for half in panel["halves"]:
			var world_side := (int(half["side"]) + orient) % 4
			var is_in: bool = on and world_side == int(result["entries"][index])
			var is_out: bool = on and world_side == int(result["exits"][index])
			Kit.set_glow(half["mat"], COLOR_ON if (is_in or is_out) else COLOR_OFF, 2.2 if (is_in or is_out) else 0.0)
			(half["chev_in"] as Node3D).visible = is_in
			(half["chev_out"] as Node3D).visible = is_out
	Kit.set_glow(_altar_stub_mat, COLOR_ON if result["solved"] else COLOR_OFF, 2.2 if result["solved"] else 0.0)
	if _flow_label != null:
		_flow_label.text = "Aliran energi: %d/%d panel%s" % [result["prefix"], _panels.size(), " - TERSAMBUNG" if result["solved"] else ""]
		_flow_label.modulate = Color(0.5, 1.0, 0.7) if result["solved"] else Color(0.75, 0.9, 1.0)
	flow_changed.emit(int(result["prefix"]), bool(result["solved"]))
	return result


func _open_seal(animate: bool) -> void:
	if _seal_body == null:
		return
	_seal_body.set_deferred(&"collision_layer", 0)
	if animate:
		Kit.play(self, Kit.SFX_SPELL)
		Kit.play(self, Kit.SFX_LOCK)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_seal_mat, "albedo_color:a", 0.0, 1.0)
		tween.tween_property(_seal_body, "scale", Vector3(1.2, 0.05, 1.2), 1.0)
		tween.chain().tween_callback(_seal_body.queue_free)
	else:
		_seal_body.queue_free()
	_seal_body = null


func _refresh_compass() -> void:
	if _compass == null:
		return
	_compass.set_meta(&"done", _session != null and _session.is_collected(ARTIFACT_ID))
	_compass.set_meta(&"hint", "Segel terbuka - ambil artefak di altar" if _solved else "Putar tiga panel batu (E) hingga energi dari kristal mengalir ke altar")


func _process(delta: float) -> void:
	_time += delta
	if _crystal != null:
		_crystal.rotation.y = _time * 0.9
		_crystal.position.y = 1.0 + sin(_time * 2.0) * 0.06


# ------------------------------------------------------------------ construction

static func cell_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - 1.5) * CELL_SIZE, 0.0, (cell.y - 1.5) * CELL_SIZE)


func _build() -> void:
	if _built:
		return
	_built = true
	_build_decor()
	_build_source()
	_build_altar()
	for index in PANEL_CELLS.size():
		_build_panel(index)
	_build_board()
	_refresh_flow()
	_compass = Kit.compass_marker(self, "CompassMarker", cell_position(ALTAR_CELL) + Vector3(0, 1.0, 0), "Jalur Energi", "Hutan", "")


func _strip(parent: Node, node_name: String, side: int, from_d: float, to_d: float, mat: Material, y := 0.16) -> MeshInstance3D:
	var length := to_d - from_d
	var mid := (to_d + from_d) * 0.5
	var size := Vector3(0.46, 0.05, length) if side % 2 == 0 else Vector3(length, 0.05, 0.46)
	return Kit.box_mesh(parent, node_name, DIR_VEC[side] * mid + Vector3(0, y, 0), size, mat)


func _chevron(parent: Node, node_name: String, side: int, distance: float, y: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = DIR_VEC[side] * distance + Vector3(0, y, 0)
	pivot.rotation_degrees.y = DIR_YAW[side]
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.42, 0.5, 0.04)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.rotation_degrees.x = -90.0
	pivot.add_child(inst)
	pivot.visible = false
	parent.add_child(pivot)
	return pivot


func _build_panel(index: int) -> void:
	var kind: String = PANEL_KINDS[index]
	var root := Node3D.new()
	root.name = "Panel%d" % (index + 1)
	root.position = cell_position(PANEL_CELLS[index])
	add_child(root)
	var dark := Kit.material(Color(0.3, 0.32, 0.3))
	var light := Kit.material(Color(0.56, 0.58, 0.52))
	Kit.box_mesh(root, "Plinth", Vector3(0, 0.05, 0), Vector3(3.9, 0.1, 3.9), dark)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 0.1, 0)
	root.add_child(rotor)
	Kit.box_mesh(rotor, "Slab", Vector3(0, 0.05, 0), Vector3(3.5, 0.1, 3.5), light)
	var hub_mat := Kit.material(COLOR_OFF)
	Kit.box_mesh(rotor, "Hub", Vector3(0, 0.12, 0), Vector3(0.6, 0.06, 0.6), hub_mat)
	var chev_mat := Kit.material(Color(0.9, 1.0, 1.0), 2.5)
	var halves: Array[Dictionary] = []
	var local_sides: Array[int] = [N, E]
	if kind == "straight":
		local_sides = [N, S]
	for side in local_sides:
		var mat := Kit.material(COLOR_OFF)
		_strip(rotor, "Strip_%d" % side, side, 0.0, 1.75, mat, 0.12)
		var chev_in := _chevron(rotor, "ChevIn_%d" % side, (side + 2) % 4, 1.05, 0.2, chev_mat)
		var chev_out := _chevron(rotor, "ChevOut_%d" % side, side, 1.05, 0.2, chev_mat)
		# chev_in sits on the same half-strip but points toward the hub, so flip it onto the strip position.
		chev_in.position = DIR_VEC[side] * 1.05 + Vector3(0, 0.2, 0)
		halves.append({"side": side, "mat": mat, "chev_in": chev_in, "chev_out": chev_out})
	var kind_name := "LURUS" if kind == "straight" else "SIKU"
	Kit.label(root, "%d %s" % [index + 1, kind_name], Vector3(0, 0.95, 0), 36, 0.008, Color(0.8, 0.95, 1.0), true)
	var item := Kit.interactable(self, "Interact_Panel%d" % (index + 1), root.position + Vector3(0, 0.1, 0), "Putar panel %d (%s) 90°" % [index + 1, kind_name.to_lower()], 0.3)
	var panel := {"index": index, "kind": kind, "orient": 0, "turns": 0, "rotor": rotor, "halves": halves, "hub_mat": hub_mat, "item": item}
	item.enabled_callable = func(_p: Node) -> bool: return not _solved and _rotating == 0
	item.interact_callable = func(_p: Node) -> bool: return rotate_panel(index)
	_panels.append(panel)
	_set_panel_orientation(panel, INITIAL_ORIENTATIONS[index])


func _build_source() -> void:
	var pos := cell_position(SOURCE_CELL)
	var dark := Kit.material(Color(0.3, 0.32, 0.3))
	var stone := Kit.material(Color(0.5, 0.53, 0.48))
	Kit.box_mesh(self, "SourcePlinth", pos + Vector3(0, 0.05, 0), Vector3(3.9, 0.1, 3.9), dark)
	var lit := Kit.material(COLOR_ON, 2.2)
	_strip(self, "SourceStub", E, -0.8, 2.0, lit, 0.12).position += pos
	var chevron_mat := Kit.material(Color(0.9, 1.0, 1.0), 2.5)
	var chev := _chevron(self, "SourceChevron", E, 1.2, 0.2, chevron_mat)
	chev.position += pos
	chev.visible = true
	var pedestal_pos := pos + Vector3(-0.8, 0, 0)
	Kit.cylinder_body(self, "SourcePedestal", pedestal_pos + Vector3(0, 0.4, 0), 0.8, 0.8, stone)
	_crystal = Node3D.new()
	_crystal.name = "Crystal"
	_crystal.position = pedestal_pos + Vector3(0, 1.0, 0)
	add_child(_crystal)
	var glow_mat := Kit.material(COLOR_ON, 2.5, 0.7)
	# Measured with node transforms (glb root scale 100): 1.88 x 13.9 x 1.92 m, base at y=-3.39 at scale 1 -> 0.13 gives ~1.8 m tall.
	var model := Kit.model(_crystal, Kit.CRYSTAL, Vector3(0, 0.44, 0), 0.0, Vector3.ONE * 0.13)
	if model == null:
		var fallback := MeshInstance3D.new()
		fallback.mesh = PrismMesh.new()
		fallback.material_override = glow_mat
		_crystal.add_child(fallback)
	_crystal.position = pedestal_pos + Vector3(0, 1.0, 0)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.1
	beam_mesh.bottom_radius = 0.18
	beam_mesh.height = 7.0
	beam.mesh = beam_mesh
	beam.material_override = Kit.material(COLOR_ON, 2.0, 0.28)
	beam.position = pedestal_pos + Vector3(0, 4.3, 0)
	add_child(beam)
	var omni := OmniLight3D.new()
	omni.light_color = COLOR_ON
	omni.light_energy = 2.0
	omni.omni_range = 7.0
	omni.position = pedestal_pos + Vector3(0, 1.6, 0)
	add_child(omni)
	Kit.label(self, "KRISTAL SUMBER", pedestal_pos + Vector3(0, 2.7, 0), 36, 0.008, Color(0.6, 1.0, 1.0), true)


func _build_altar() -> void:
	var pos := cell_position(ALTAR_CELL)
	var dark := Kit.material(Color(0.3, 0.32, 0.3))
	var stone := Kit.material(Color(0.5, 0.53, 0.48))
	Kit.box_mesh(self, "AltarPlinth", pos + Vector3(0, 0.05, 0), Vector3(3.9, 0.1, 3.9), dark)
	_altar_stub_mat = Kit.material(COLOR_OFF)
	_strip(self, "AltarStub", W, 0.8, 2.0, _altar_stub_mat, 0.12).position += pos
	var altar_pos := pos + Vector3(0.7, 0, 0)
	Kit.cylinder_body(self, "AltarDais", altar_pos + Vector3(0, 0.2, 0), 1.4, 0.4, stone)
	_artifact = ARTIFACT_SCENE.instantiate() as Node3D
	_artifact.set(&"pickup_id", ARTIFACT_ID)
	_artifact.set(&"display_name", "Artefak Energi")
	_artifact.name = "ArtifactPickup"
	_artifact.position = altar_pos + Vector3(0, 0.4, 0)
	add_child(_artifact)
	_seal_mat = Kit.material(Color(0.3, 0.7, 1.0), 1.4, 0.38)
	_seal_body = Kit.cylinder_body(self, "Seal", altar_pos + Vector3(0, 0.4 + 1.3, 0), 1.0, 2.6, _seal_mat)
	Kit.label(self, "ALTAR", altar_pos + Vector3(0, 3.4, 0), 40, 0.01, Color(1.0, 0.9, 0.55), true)
	_flow_label = Kit.label(self, "", altar_pos + Vector3(0, 3.9, 0), 32, 0.008, Color(0.75, 0.9, 1.0), true)
	_flow_label.name = "FlowLabel"
	for side in [-1.0, 1.0]:
		var column_pos := altar_pos + Vector3(0.3, 0, side * 2.6)
		Kit.dungeon(self, "pillar", column_pos, 0.0, 0.8)
		Kit.cylinder_body(self, "PillarCollision", column_pos + Vector3(0, 1.6, 0), 0.5, 3.2)
		Kit.dungeon(self, "torch_lit", altar_pos + Vector3(1.0, 0.4, side * 1.2))


func _build_decor() -> void:
	for pos in [Vector3(-9, 0, -5), Vector3(0, 0, -6.5), Vector3(9, 0, 4.5), Vector3(2, 0, 7)]:
		Kit.dungeon(self, "wall_broken", pos, 0.0 if absf(pos.z) > 5.0 else 90.0)
		var yaw := 0.0 if absf(pos.z) > 5.0 else 90.0
		Kit.box_body(self, "WallCollision", pos + Vector3(0, 1.25, 0), Vector3(3.8, 2.5, 0.9), null, yaw)
	for pos in [Vector3(-12, 0, -8), Vector3(-12, 0, 8), Vector3(12, 0, -8), Vector3(12, 0, 9), Vector3(-4, 0, -9), Vector3(6, 0, -9)]:
		Kit.nature(self, "Tree_2_A_Color1", pos, pos.x * 11.0)
		Kit.cylinder_body(self, "TrunkCollision", pos + Vector3(0, 2.0, 0), 0.45, 4.0)
	for pos in [Vector3(-8, 0, 5.5), Vector3(8.5, 0, -6), Vector3(-1, 0, 6.5)]:
		Kit.nature(self, "Rock_3_B_Color1", pos, pos.x * 31.0, 1.6)
	Kit.dungeon(self, "rubble_half", Vector3(10, 0, 0.5), 200.0, 0.6)


func _build_board() -> void:
	var board := Node3D.new()
	board.name = "Board"
	board.position = Vector3(-10.5, 0, 6.5)
	board.rotation_degrees.y = -45.0
	add_child(board)
	var stone := Kit.material(Color(0.5, 0.55, 0.46))
	var dark := Kit.material(Color(0.22, 0.24, 0.22))
	Kit.box_body(board, "Slab", Vector3(0, 1.1, 0), Vector3(3.4, 2.2, 0.4), stone)
	Kit.box_mesh(board, "Panel", Vector3(0, 1.15, 0.22), Vector3(3.0, 1.8, 0.04), dark)
	Kit.label(board, "JALUR ENERGI", Vector3(0, 1.85, 0.26), 40, 0.006, Color(1.0, 0.9, 0.55))
	Kit.label(board, "Putar 3 panel batu (E) agar energi\nmengalir dari Kristal ke Altar.\nUkiran LURUS atau SIKU; panah putih\n= arah aliran, garis biru = tersambung.", Vector3(0, 1.2, 0.26), 24, 0.0055, Color(0.85, 0.95, 1.0))
	Kit.label(board, "Tidak ada hukuman - coba sesukamu.", Vector3(0, 0.55, 0.26), 22, 0.005, Color(0.7, 0.8, 0.7))
	for side in [-1.0, 1.0]:
		Kit.box_mesh(board, "TorchStub", Vector3(side * 2.1, 0.5, 0.0), Vector3(0.3, 1.0, 0.3), stone)
		Kit.dungeon(board, "torch_lit", Vector3(side * 2.1, 1.35, 0.0))
