extends Node3D
## Exploration 03 - Jalur Menuju Puncak (Rocky Highlands). Climbable route with REAL elevation, built from solid blocks
## and walkable slopes (all <= 22 degrees): foot checkpoint -> west ramp (R1) -> cliff ledge (L1) -> ramp (R2) -> ledge (L2)
## -> ONE proven 3 m jump gap -> guardian courtyard (melee + ranged, cover rocks) -> final ramp (R4) -> summit altar with
## the artifact (no kill prerequisite: a cover-lined side corridor bypasses the courtyard) -> viewpoint, rest checkpoint
## and a lever that extends a persistent bridge shortcut from the summit down to the foot area.
##
## Module-local layout (anchor at origin on flat ground y=0, entry from +z; footprint x +/-25, z +/-22, max height 8.2):
##   Foot area y=0, z 4..22.   Checkpoint "summit_foot" (-4,0,18).   Foot enemy summit_melee_foot (10,0,9) (>20 m from the bridge foot/R1).
##   MAIN GROUND LANE for the island route: x 0..3 (centre x=1.5), free from z=+22 to z=-22 (canyon between L2 and the courtyard,
##   then under the raised R4 deck, clearance >= 3.98 m). Never blocked by supports/rocks.
##   R1: (-19,0,4) -> (-19,2.4,-4) w5.   L1: x[-24,-14] z[-10,-4] top 2.4.   R2: (-14,2.4,-7) -> (-6,4.2,-7) w3.4.
##   L2: x[-6,0] z[-10,-4] top 4.2.   Gap: x 0..3 (3 m).   Courtyard: x[3,25] z[-20,-4] top 4.6.
##   R4: (3,4.6,-16) -> (-10,8.2,-16) w4.   Summit: x[-25,-10] z[-22,-11] top 8.2.   Altar (-18,8.2,-17).
##   Bridge (closed until the lever): (-11.5,8.2,-11) -> (-11.5,0,10) w3, lever at (-13.2,8.2,-12.3).
##
## Interface: setup(player, session) AFTER the module has its final transform (enemies snapshot their spawn then),
## is_shortcut_open(), open_shortcut(), get_artifact(), get_enemies(), get_route_waypoints(), validate_route(),
## signals shortcut_opened / viewpoint_used. Session keys: puzzle_progress[&"summit_shortcut"], artifact id
## &"summit_artifact", enemy ids summit_melee_foot / summit_melee_guard / summit_ranged_guard,
## checkpoints &"summit_foot" and &"summit_top".

const Kit := preload("res://scripts/objectives/objective_kit.gd")

signal shortcut_opened
signal viewpoint_used

const SHORTCUT_KEY := &"summit_shortcut"
const ARTIFACT_ID := &"summit_artifact"
const ARTIFACT_SCENE := preload("res://scenes/world/artifact_pickup.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/world/checkpoint.tscn")
const STANDARD_SCENE := preload("res://scenes/enemies/standard_melee.tscn")
const RANGED_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")

const TOP_L1 := 2.4
const TOP_L2 := 4.2
const TOP_COURT := 4.6
const TOP_SUMMIT := 8.2
const GAP_X0 := 0.0
const GAP_X1 := 3.0
const MAIN_LANE_X0 := 0.0
const MAIN_LANE_X1 := 3.0
const MAIN_LANE_X := 1.5

const BRIDGE_START := Vector3(-11.5, 8.2, -11.0)
const BRIDGE_END := Vector3(-11.5, 0.0, 10.0)
const BRIDGE_SEGMENTS := 10
const BRIDGE_WIDTH := 3.0

const ENEMIES: Array[Dictionary] = [
	{"id": &"summit_melee_foot", "scene": "standard", "pos": Vector3(10, 0, 9)},
	{"id": &"summit_melee_guard", "scene": "standard", "pos": Vector3(19, 4.6, -10.5)},
	{"id": &"summit_ranged_guard", "scene": "ranged", "pos": Vector3(22.5, 4.6, -17)},
]

var _player: Node3D
var _session: Node
var _built := false
var _bridge_open := false
var _bridge_segments: Array[Array] = []
var _bridge_gate: StaticBody3D
var _lever_handle: Node3D
var _lever_label: Label3D
var _artifact: Node3D
var _compass: Node3D
var _enemies: Array[Node] = []
var _enemy_root: Node3D
var _view_label: Label3D

var _rock_mat: StandardMaterial3D
var _cliff_mat: StandardMaterial3D
var _path_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func setup(player: Node3D, session: Node = null) -> void:
	_player = player
	_session = Kit.resolve_session(get_tree(), session)
	if _session != null and not _session.status_changed.is_connected(_refresh_compass):
		_session.status_changed.connect(_refresh_compass)
	_spawn_enemies()
	if Kit.is_progress(_session, SHORTCUT_KEY) and not _bridge_open:
		_set_bridge_open(false)
	_refresh_compass()


func is_shortcut_open() -> bool:
	return _bridge_open


func get_artifact() -> Node3D:
	return _artifact


func get_enemies() -> Array[Node]:
	return _enemies


## Opens the bridge (what the summit lever does). False if already open.
func open_shortcut() -> bool:
	if _bridge_open:
		return false
	Kit.mark_progress(_session, SHORTCUT_KEY)
	_set_bridge_open(true)
	return true


## Walkable centre-line waypoints (module-local) from the entry to the altar, then the lever. For runtime bots/tests.
func get_route_waypoints() -> Array[Vector3]:
	return [
		Vector3(0, 0, 20), Vector3(-4, 0, 16), Vector3(-19, 0, 6), Vector3(-19, TOP_L1, -4.5), Vector3(-17, TOP_L1, -7),
		Vector3(-14, TOP_L1, -7), Vector3(-6, TOP_L2, -7), Vector3(-1.5, TOP_L2, -7),
		Vector3(4.5, TOP_COURT, -7), Vector3(4.5, TOP_COURT, -12), Vector3(4.5, TOP_COURT, -16),
		Vector3(3, TOP_COURT, -16), Vector3(-10, TOP_SUMMIT, -16), Vector3(-16, TOP_SUMMIT, -16.8),
	]


func get_lever_position() -> Vector3:
	return Vector3(-13.2, TOP_SUMMIT, -12.3)


## Proof data for the route: jump gaps (flight time/reach at walking speed vs. width), slope angles, extents.
func validate_route() -> Dictionary:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var jump_speed := 5.1
	var walk_speed := 6.0
	if _player != null and is_instance_valid(_player):
		var jv: Variant = _player.get(&"jump_velocity")
		if jv != null:
			jump_speed = float(jv)
		var bs: Variant = _player.get(&"base_speed")
		if bs != null:
			walk_speed = float(bs)
	var gap_rise := TOP_COURT - TOP_L2
	var gap_width := GAP_X1 - GAP_X0
	var apex := jump_speed * jump_speed / (2.0 * gravity)
	var gaps: Array[Dictionary] = []
	var discriminant := jump_speed * jump_speed - 2.0 * gravity * gap_rise
	var flight := (jump_speed + sqrt(maxf(discriminant, 0.0))) / gravity if discriminant > 0.0 else 0.0
	var reach := flight * walk_speed
	# The capsule centre must travel the gap plus a 0.9 m allowance for edge clearance/radius.
	gaps.append({
		"name": "gap_L2_courtyard", "width": gap_width, "rise": gap_rise, "apex": apex, "flight_time": flight,
		"reach_walking": reach, "margin": reach - (gap_width + 0.9), "ok": discriminant > 0.0 and reach > gap_width + 0.9 and gap_rise < apex,
	})
	var slopes: Array[Dictionary] = []
	for spec in [
		["R1", Vector3(-19, 0, 4), Vector3(-19, TOP_L1, -4)], ["R2", Vector3(-14, TOP_L1, -7), Vector3(-6, TOP_L2, -7)],
		["R4", Vector3(3, TOP_COURT, -16), Vector3(-10, TOP_SUMMIT, -16)], ["Bridge", BRIDGE_START, BRIDGE_END],
	]:
		var a: Vector3 = spec[1]
		var b: Vector3 = spec[2]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		var degrees := rad_to_deg(atan2(absf(b.y - a.y), run))
		slopes.append({"name": spec[0], "degrees": degrees, "ok": degrees <= 25.0})
	var all_ok := true
	for gap in gaps:
		all_ok = all_ok and bool(gap["ok"])
	for slope in slopes:
		all_ok = all_ok and bool(slope["ok"])
	var lane_deck_low := TOP_COURT - 0.65
	var lane := {"x_min": MAIN_LANE_X0, "x_max": MAIN_LANE_X1, "width": MAIN_LANE_X1 - MAIN_LANE_X0, "clearance_under_ramp_R4": lane_deck_low, "ok": lane_deck_low >= 3.0}
	return {
		"gaps": gaps, "slopes": slopes, "lane": lane, "max_height": TOP_SUMMIT, "footprint": Rect2(-25, -22, 50, 44),
		"ok": all_ok and bool(lane["ok"]) and TOP_SUMMIT <= 10.0,
	}


# ------------------------------------------------------------------ bridge / lever / viewpoint

func _set_bridge_open(animate: bool) -> void:
	_bridge_open = true
	if _bridge_gate != null:
		_bridge_gate.set_deferred(&"collision_layer", 0)
		_bridge_gate.hide()
	if _lever_handle != null:
		if animate:
			create_tween().tween_property(_lever_handle, "rotation_degrees:x", -50.0, 0.4)
		else:
			_lever_handle.rotation_degrees.x = -50.0
	if _lever_label != null:
		_lever_label.text = "JEMBATAN TERBUKA"
		_lever_label.modulate = Color(0.6, 1.0, 0.7)
	if animate:
		Kit.play(self, Kit.SFX_LOCK)
		Kit.play(self, Kit.SFX_STONE)
	var tween: Tween = create_tween() if animate else null
	for index in _bridge_segments.size():
		if animate:
			tween.tween_interval(0.12)
			tween.tween_callback(_show_segment.bind(index))
		else:
			_show_segment(index)
	if animate:
		tween.tween_callback(_play_confirm)
	shortcut_opened.emit()


func _play_confirm() -> void:
	Kit.play(self, Kit.SFX_CONFIRM)


func _show_segment(index: int) -> void:
	for body in _bridge_segments[index]:
		var solid := body as StaticBody3D
		solid.show()
		solid.collision_layer = Kit.WORLD_LAYER


func _use_lever(_p: Node) -> bool:
	return open_shortcut()


func _use_viewpoint(_p: Node) -> bool:
	Kit.play(self, Kit.SFX_TICK)
	_view_label.text = "Dermaga & gerbang boss di utara, hutan dan reruntuhan di barat-timur."
	viewpoint_used.emit()
	return true


func _refresh_compass() -> void:
	if _compass == null:
		return
	_compass.set_meta(&"done", _session != null and _session.is_collected(ARTIFACT_ID))
	_compass.set_meta(&"hint", "Daki lereng barat, lompati celah, lewati pelataran penjaga; artefak di altar puncak")


# ------------------------------------------------------------------ enemies

func _spawn_enemies() -> void:
	if _enemy_root != null:
		return
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)
	for spec in ENEMIES:
		var id: StringName = spec["id"]
		if _session != null and _session.killed_enemy_ids.has(id):
			continue
		var scene: PackedScene = STANDARD_SCENE if spec["scene"] == "standard" else RANGED_SCENE
		var enemy := scene.instantiate() as CharacterBody3D
		enemy.name = String(id)
		enemy.set(&"enemy_id", id)
		enemy.position = spec["pos"]
		_enemy_root.add_child(enemy)
		if _player != null:
			enemy.set(&"player_path", enemy.get_path_to(_player))
		if _session != null:
			_session.register_enemy(enemy)
		_enemies.append(enemy)


# ------------------------------------------------------------------ construction

func _build() -> void:
	if _built:
		return
	_built = true
	_rock_mat = Kit.material(Color(0.46, 0.46, 0.43))
	_cliff_mat = Kit.material(Color(0.38, 0.38, 0.36))
	_path_mat = Kit.material(Color(0.62, 0.53, 0.37))
	_wood_mat = Kit.material(Color(0.5, 0.36, 0.2))
	_build_blocks()
	_build_ramps()
	_build_courtyard()
	_build_summit()
	_build_bridge()
	_build_foot()
	_build_decor()
	_compass = Kit.compass_marker(self, "CompassMarker", Vector3(-18, TOP_SUMMIT + 1.0, -17), "Puncak", "Rocky Highlands", "")


func _block(node_name: String, x0: float, x1: float, z0: float, z1: float, top: float) -> void:
	var center := Vector3((x0 + x1) * 0.5, top * 0.5, (z0 + z1) * 0.5)
	Kit.box_body(self, node_name, center, Vector3(x1 - x0, top, z1 - z0), _cliff_mat)
	Kit.tile_floor(self, x0 + 0.2, x1 - 0.2, z0 + 0.2, z1 - 0.2, top)


func _build_blocks() -> void:
	_block("LedgeL1", -24.0, -14.0, -10.0, -4.0, TOP_L1)
	_block("LedgeL2", -6.0, GAP_X0, -10.0, -4.0, TOP_L2)
	_block("Courtyard", GAP_X1, 25.0, -20.0, -4.0, TOP_COURT)
	_block("Summit", -25.0, -10.0, -22.0, -11.0, TOP_SUMMIT)


func _fill_under(bottom: Vector3, top: Vector3, width: float, segments: int, open_x := Vector2(1.0, -1.0)) -> void:
	for i in segments:
		var p0 := bottom.lerp(top, float(i) / segments)
		var p1 := bottom.lerp(top, float(i + 1) / segments)
		var low := minf(p0.y, p1.y) - 0.8
		if low < 0.2:
			continue
		# Keep a ground underpass open: no support under the part of the deck that spans open_x (x min, x max).
		if open_x.x <= open_x.y and maxf(p0.x, p1.x) > open_x.x and minf(p0.x, p1.x) < open_x.y:
			continue
		var mid := (p0 + p1) * 0.5
		var along_x := absf(p1.x - p0.x) > absf(p1.z - p0.z)
		var span := maxf(absf(p1.x - p0.x), absf(p1.z - p0.z)) + 0.02
		var size := Vector3(span, low, width - 0.2) if along_x else Vector3(width - 0.2, low, span)
		Kit.box_body(self, "Support_%d" % i, Vector3(mid.x, low * 0.5, mid.z), size, _cliff_mat)


func _ramp(node_name: String, bottom: Vector3, top: Vector3, width: float, open_x := Vector2(1.0, -1.0)) -> void:
	Kit.ramp(self, node_name, bottom, top, width, 0.6, _path_mat)
	_fill_under(bottom, top, width, 8, open_x)


func _build_ramps() -> void:
	_ramp("RampR1", Vector3(-19, 0, 4), Vector3(-19, TOP_L1, -4), 5.0)
	_ramp("RampR2", Vector3(-14, TOP_L1, -7), Vector3(-6, TOP_L2, -7), 3.4)
	_ramp("RampR4", Vector3(3, TOP_COURT, -16), Vector3(-10, TOP_SUMMIT, -16), 4.0, Vector2(MAIN_LANE_X0 - 0.2, MAIN_LANE_X1))


func _rock(pos: Vector3, scale: float, yaw: float, collide := true, kind := "Rock_3_A_Color1") -> void:
	Kit.nature(self, kind, pos + Vector3(0, 0.465 * scale, 0), yaw, scale)
	if collide:
		Kit.box_body(self, "RockCollision", pos + Vector3(0, 0.43 * scale, 0), Vector3(0.85 * scale, 0.8 * scale, 0.75 * scale), null, yaw)


func _guard(node_name: String, center: Vector3, size: Vector3) -> void:
	Kit.box_body(self, node_name, center, size, null, 0.0, Kit.ENEMY_ONLY_LAYER)


func _build_courtyard() -> void:
	# Cover wall between the bypass corridor (x 3..7) and the arena, with gaps so both can be reached.
	_rock(Vector3(8.8, TOP_COURT, -7.4), 3.4, 20.0)
	_rock(Vector3(8.8, TOP_COURT, -11.6), 3.4, 100.0, true, "Rock_3_C_Color1")
	_rock(Vector3(8.8, TOP_COURT, -15.8), 3.4, 200.0)
	# Arena cover.
	_rock(Vector3(15.0, TOP_COURT, -8.0), 3.0, 10.0, true, "Rock_3_D_Color1")
	_rock(Vector3(19.0, TOP_COURT, -15.0), 3.0, 70.0)
	_rock(Vector3(13.5, TOP_COURT, -16.5), 2.5, 150.0, true, "Rock_3_C_Color1")
	_rock(Vector3(22.0, TOP_COURT, -8.5), 2.5, 40.0, true, "Rock_3_D_Color1")
	# Ruined walls and torches giving the courtyard an identity and a second layer of cover.
	for spec in [[Vector3(15.5, TOP_COURT, -12.5), 90.0], [Vector3(20.0, TOP_COURT, -5.0), 0.0]]:
		var wall_pos: Vector3 = spec[0]
		var wall_yaw: float = spec[1]
		Kit.dungeon(self, "wall_broken", wall_pos, wall_yaw)
		Kit.box_body(self, "WallCollision", wall_pos + Vector3(0, 1.25, 0), Vector3(3.8, 2.5, 0.9), null, wall_yaw)
	for pos in [Vector3(11.0, TOP_COURT, -4.6), Vector3(24.0, TOP_COURT, -19.0)]:
		Kit.dungeon(self, "pillar", pos, 0.0, 0.8)
		Kit.cylinder_body(self, "PillarCollision", pos + Vector3(0, 1.6, 0), 0.5, 3.2)
	Kit.dungeon(self, "rubble_large", Vector3(23.5, TOP_COURT, -13.0), 270.0, 0.6)
	# Enemy-only guards on the courtyard edges (layer 8: enemies collide, the player does not).
	var y := TOP_COURT + 1.0
	_guard("GuardSouth", Vector3(14.0, y, -4.3), Vector3(22.0, 2.0, 0.6))
	_guard("GuardEast", Vector3(24.7, y, -12.0), Vector3(0.6, 2.0, 16.0))
	_guard("GuardNorth", Vector3(14.0, y, -19.7), Vector3(22.0, 2.0, 0.6))
	_guard("GuardWestLow", Vector3(3.3, y, -7.0), Vector3(0.6, 2.0, 6.0))
	_guard("GuardWestMid", Vector3(3.3, y, -12.0), Vector3(0.6, 2.0, 4.0))
	_guard("GuardWestHigh", Vector3(3.3, y, -19.0), Vector3(0.6, 2.0, 2.0))
	# Clue: torches line the bypass corridor toward the final ramp.
	for z in [-7.0, -12.0]:
		Kit.dungeon(self, "torch_lit", Vector3(3.6, TOP_COURT + 0.4, z))
	Kit.label(self, "JALUR SAMPING", Vector3(5.0, TOP_COURT + 0.05, -11.0), 40, 0.012, Color(1.0, 0.9, 0.55)).rotation_degrees.x = -90.0
	Kit.label(self, "PELATARAN PENJAGA", Vector3(15.0, TOP_COURT + 0.05, -4.8), 40, 0.012, Color(1.0, 0.6, 0.4)).rotation_degrees.x = -90.0


func _rail_line(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var pieces := maxi(1, int(round(length / 4.0)))
	var piece_len := length / pieces
	var dir := (b - a).normalized()
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	for i in pieces:
		var center := a + dir * (piece_len * (i + 0.5))
		var model := Kit.dungeon(self, "barrier", center, yaw, piece_len / 4.0)
		if model != null:
			model.name = "Barrier"
		Kit.box_body(self, "RailCollision", center + Vector3(0, 0.55, 0), Vector3(piece_len, 1.1, 0.5), null, yaw)


func _build_summit() -> void:
	var top := TOP_SUMMIT
	# Rails: north, west, south (up to the bridge gate) and the east edge on both sides of the ramp opening.
	_rail_line(Vector3(-25, top, -21.7), Vector3(-10, top, -21.7))
	_rail_line(Vector3(-24.7, top, -21.7), Vector3(-24.7, top, -11.3))
	_rail_line(Vector3(-24.7, top, -11.3), Vector3(-13.2, top, -11.3))
	_rail_line(Vector3(-10.3, top, -21.7), Vector3(-10.3, top, -18.0))
	_rail_line(Vector3(-10.3, top, -14.0), Vector3(-10.3, top, -11.3))
	# Altar with the artifact (no seal: reaching it is the only requirement).
	var altar := Vector3(-18, top, -17)
	var stone := Kit.material(Color(0.5, 0.53, 0.48))
	Kit.cylinder_body(self, "AltarDais", altar + Vector3(0, 0.2, 0), 1.7, 0.4, stone)
	_artifact = ARTIFACT_SCENE.instantiate() as Node3D
	_artifact.set(&"pickup_id", ARTIFACT_ID)
	_artifact.set(&"display_name", "Artefak Puncak")
	_artifact.name = "ArtifactPickup"
	_artifact.position = altar + Vector3(0, 0.4, 0)
	add_child(_artifact)
	for dz in [-2.6, 2.6]:
		var column_pos: Vector3 = altar + Vector3(0.0, 0, dz)
		Kit.dungeon(self, "pillar", column_pos, 0.0, 0.8)
		Kit.cylinder_body(self, "PillarCollision", column_pos + Vector3(0, 1.6, 0), 0.5, 3.2)
	for dz in [-1.4, 1.4]:
		Kit.dungeon(self, "torch_lit", altar + Vector3(-1.9, 0.4, dz))
	Kit.label(self, "ALTAR PUNCAK", altar + Vector3(0, 3.4, 0), 40, 0.01, Color(1.0, 0.9, 0.55), true)
	# Rest checkpoint.
	var rest := CHECKPOINT_SCENE.instantiate() as Node3D
	rest.set(&"checkpoint_id", &"summit_top")
	rest.name = "CheckpointTop"
	rest.position = Vector3(-14.0, top, -19.5)
	add_child(rest)
	Kit.label(self, "AREA ISTIRAHAT", Vector3(-14.0, top + 2.6, -19.5), 30, 0.008, Color(0.6, 1.0, 0.8), true)
	# Viewpoint nook at the north-west corner.
	var view := Vector3(-22.3, top, -19.6)
	Kit.cylinder_body(self, "ViewBase", view + Vector3(0, 0.25, 0), 0.5, 0.5, stone)
	var scope := Kit.box_mesh(self, "Telescope", view + Vector3(0, 1.0, 0), Vector3(0.22, 0.22, 1.2), Kit.material(Color(0.45, 0.35, 0.2)), 40.0)
	scope.rotation_degrees.x = 18.0
	Kit.dungeon(self, "barrier_column", view + Vector3(1.6, 0, 1.2), 90.0, 0.5)
	Kit.label(self, "TITIK PANDANG", view + Vector3(0, 2.4, 0), 36, 0.008, Color(0.7, 0.95, 1.0), true)
	_view_label = Kit.label(self, "", view + Vector3(0, 2.0, 0), 24, 0.006, Color(0.9, 0.95, 0.8), true)
	var look := Kit.interactable(self, "Interact_Viewpoint", view + Vector3(0.9, 0, 0.6), "Lihat pemandangan pulau", 1.0)
	look.interact_callable = _use_viewpoint
	# Bridge lever + gate.
	var lever_pos := get_lever_position()
	Kit.cylinder_body(self, "LeverBase", lever_pos + Vector3(0, 0.45, 0), 0.4, 0.9, stone)
	_lever_handle = Node3D.new()
	_lever_handle.name = "LeverHandle"
	_lever_handle.position = lever_pos + Vector3(0, 1.0, 0)
	_lever_handle.rotation_degrees.x = 40.0
	add_child(_lever_handle)
	Kit.box_mesh(_lever_handle, "Bar", Vector3(0, 0.5, 0), Vector3(0.12, 1.0, 0.12), Kit.material(Color(0.45, 0.35, 0.2)))
	Kit.box_mesh(_lever_handle, "Knob", Vector3(0, 1.05, 0), Vector3(0.28, 0.28, 0.28), Kit.material(Color(0.9, 0.7, 0.2), 0.8))
	_lever_label = Kit.label(self, "TUAS JEMBATAN (SHORTCUT)", lever_pos + Vector3(0, 2.3, 0), 30, 0.008, Color(1.0, 0.85, 0.5), true)
	var lever := Kit.interactable(self, "Interact_Lever", lever_pos + Vector3(0.9, 0, 0.0), "Tarik tuas: turunkan jembatan shortcut", 1.0)
	lever.enabled_callable = func(_p: Node) -> bool: return not _bridge_open
	lever.interact_callable = _use_lever
	_bridge_gate = Kit.box_body(self, "BridgeGate", Vector3(-11.5, top + 0.55, -11.3), Vector3(3.2, 1.1, 0.5), null)
	var gate_model := Kit.dungeon(_bridge_gate, "barrier", Vector3.ZERO, 0.0, 0.8)
	if gate_model != null:
		gate_model.position = Vector3(0.0, -0.55, 0.0)


func _bridge_point(t: float) -> Vector3:
	return BRIDGE_START.lerp(BRIDGE_END, t)


func _build_bridge() -> void:
	for i in BRIDGE_SEGMENTS:
		var a := _bridge_point(float(i) / BRIDGE_SEGMENTS)
		var b := _bridge_point(float(i + 1) / BRIDGE_SEGMENTS)
		var parts: Array = []
		var deck := Kit.ramp(self, "BridgeDeck_%d" % i, a, b, BRIDGE_WIDTH, 0.45, _wood_mat, 0.06)
		parts.append(deck)
		# The last two segments (deck < 1.6 m above ground) get no rails: a rail tip would wedge into the ground and snag the exit.
		for side in [-1.0, 1.0]:
			if i >= BRIDGE_SEGMENTS - 2:
				continue
			var offset := Vector3(side * (BRIDGE_WIDTH * 0.5 - 0.08), 1.0, 0.0)
			parts.append(Kit.ramp(self, "BridgeRail_%d_%d" % [i, int(side)], a + offset, b + offset, 0.16, 1.0, _wood_mat, 0.06))
		for body in parts:
			(body as StaticBody3D).hide()
			(body as StaticBody3D).collision_layer = 0
		_bridge_segments.append(parts)
	# Piers where the deck is high enough to need them.
	for z in [-2.0, 4.5]:
		var t: float = (z - BRIDGE_START.z) / (BRIDGE_END.z - BRIDGE_START.z)
		var height := _bridge_point(t).y - 0.6
		if height > 0.3:
			Kit.box_body(self, "Pier_%d" % int(z), Vector3(BRIDGE_START.x, height * 0.5, z), Vector3(1.2, height, 1.2), _cliff_mat)
	# Enemy-only side guards: ground enemies cannot walk under the raised deck (they would chase a player standing above them
	# forever, unable to hit through the slab). They reach the deck only via its ground-level south end, i.e. on the player's level.
	Kit.box_body(self, "GuardBridgeWest", Vector3(BRIDGE_START.x - 1.8, 1.0, -0.25), Vector3(0.3, 2.0, 9.5), null, 0.0, Kit.ENEMY_ONLY_LAYER)
	Kit.box_body(self, "GuardBridgeEast", Vector3(BRIDGE_START.x + 1.8, 1.0, -0.25), Vector3(0.3, 2.0, 9.5), null, 0.0, Kit.ENEMY_ONLY_LAYER)
	Kit.label(self, "SHORTCUT", Vector3(BRIDGE_END.x, 0.05, BRIDGE_END.z + 1.5), 40, 0.012, Color(1.0, 0.85, 0.5)).rotation_degrees.x = -90.0


func _build_foot() -> void:
	var cp := CHECKPOINT_SCENE.instantiate() as Node3D
	cp.set(&"checkpoint_id", &"summit_foot")
	cp.name = "CheckpointFoot"
	cp.position = Vector3(-4, 0, 18)
	add_child(cp)
	Kit.label(self, "KAKI BUKIT - CHECKPOINT", Vector3(-4, 3.0, 18), 30, 0.008, Color(0.6, 1.0, 0.8), true)
	Kit.label(self, "JALUR UTAMA PULAU", Vector3(MAIN_LANE_X, 0.05, 12.0), 40, 0.012, Color(1.0, 0.9, 0.55)).rotation_degrees.x = -90.0
	Kit.label(self, "JALUR UTAMA PULAU", Vector3(MAIN_LANE_X, 0.05, -12.0), 40, 0.012, Color(1.0, 0.9, 0.55)).rotation_degrees.x = -90.0
	# Entry sign pointing at the climb, with torches lining the west ramp.
	var sign_root := Node3D.new()
	sign_root.name = "RouteSign"
	sign_root.position = Vector3(-13.0, 0, 8.0)
	sign_root.rotation_degrees.y = 30.0
	add_child(sign_root)
	var stone := Kit.material(Color(0.5, 0.55, 0.46))
	var dark := Kit.material(Color(0.22, 0.24, 0.22))
	Kit.box_body(sign_root, "Slab", Vector3(0, 1.0, 0), Vector3(3.0, 2.0, 0.4), stone)
	Kit.box_mesh(sign_root, "Panel", Vector3(0, 1.05, 0.22), Vector3(2.6, 1.6, 0.04), dark)
	Kit.label(sign_root, "JALUR MENUJU PUNCAK", Vector3(0, 1.6, 0.26), 34, 0.006, Color(1.0, 0.9, 0.55))
	Kit.label(sign_root, "Daki lereng barat <-\nLompat celah, lewati pelataran.\nShortcut dibuka dari puncak.", Vector3(0, 0.95, 0.26), 22, 0.0055, Color(0.9, 0.95, 0.85))
	for z in [3.0, -1.0]:
		for x in [-21.2, -16.8]:
			Kit.dungeon(self, "torch_lit", Vector3(x, 0.4 + maxf(0.0, (4.0 - z) * 0.3), z))
	Kit.dungeon(self, "barrier_column", Vector3(-22.5, 0, 6), 90.0, 0.6)
	Kit.dungeon(self, "barrier_column", Vector3(-15.5, 0, 6), 90.0, 0.6)


func _build_decor() -> void:
	# Rocks hugging the cliff faces and foot (with collision so the player cannot clip into them).
	for spec in [
		[Vector3(-3.0, 0, -3.4), 2.4], [Vector3(-5.0, 0, -3.0), 1.8], [Vector3(9.0, 0, -3.2), 2.8],
		[Vector3(15.0, 0, -3.0), 2.4], [Vector3(21.0, 0, -3.2), 2.8], [Vector3(-9.0, 0, -9.2), 2.0],
	]:
		var pos: Vector3 = spec[0]
		_rock(pos, spec[1], pos.x * 23.0, true, "Rock_3_B_Color1")
	for pos in [Vector3(-23, 0, 14), Vector3(-15, 0, 19), Vector3(22, 0, 12), Vector3(24, 0, 19), Vector3(14, 0, 8), Vector3(-5, 0, 20)]:
		Kit.nature(self, "Tree_1_B_Color1", pos, pos.x * 7.0)
		Kit.cylinder_body(self, "TrunkCollision", pos + Vector3(0, 2.0, 0), 0.45, 4.0)
	for pos in [Vector3(12.0, 0, 14.0), Vector3(-2.0, 0, 6.0), Vector3(-17.0, 0, 11.0)]:
		Kit.nature(self, "Rock_1_A_Color1", pos, pos.x * 5.0, 2.0)
