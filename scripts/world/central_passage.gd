extends Node3D
## Central ancient causeway: the straight spawn -> summit route is a walled stone passage whose north end is a sealed gate.
##
## Ground topology, not a door in open grass: two continuous rock walls (4.6 m above the highest local ground, far above the
## 1.3 m jump apex) run on both sides of the central route from a south mouth next to the spawn to the summit foot, and a cross
## wall closes the north end. The only things in the cross wall are a doorway plugged by a stone seal slab and two glowing artifact
## sockets. Walking around the passage just leads onto the symbol / energy branch routes, so the branches stay the way north until
## the seal breaks; once both branch artifacts are collected the slab sinks and the causeway is a free shortcut both ways.
## Entry from the spawn is always free and the walls never touch the side routes, so the way back to the spawn is never cut.
##
## State is derived: open <=> session.is_collected(forest_artifact) and is_collected(energy_artifact). Nothing is saved on its own,
## so Continue / respawn / boss retry reopen it from the persisted collected ids (no animation on build). No enemy kill is needed.
##
## Everything is built from the terrain's final central route centre line (get_route_points), so every seed / the baseline gets the
## same structure. `plan()` is data only (no tree); `verify_topology()` flood-fills the walls to prove the passage is sealed.

const Kit := preload("res://scripts/objectives/objective_kit.gd")

signal opened

const ROUTE := &"spawn_summit"
const REQUIREMENTS: Array[StringName] = [&"forest_artifact", &"energy_artifact"]
const REQUIREMENT_LABELS := {&"forest_artifact": "Artefak Hutan", &"energy_artifact": "Artefak Energi"}
const REQUIREMENT_COLORS := {&"forest_artifact": Color(0.35, 1.0, 0.45), &"energy_artifact": Color(0.35, 0.8, 1.0)}
const SFX_OPEN := [Kit.SFX_LOCK, Kit.SFX_STONE]

const INNER_MIN := 8.0           ## narrowest wall offset on the inside of a bend
const WALL_ROUTE_CLEAR := 7.5    ## wall centre line vs the central route itself (half width 5.5 + wall half 1.3 + margin)
const HALF_SPAN := 13.0          ## wall centre line offset from the route centre line (inner clear half width ~11.7 m)
const WALL_THICK := 2.6
const WALL_ABOVE := 4.6          ## wall top above the highest ground along the segment (player jump apex is ~1.3 m)
const WALL_BELOW := 3.0          ## sunk below the lowest ground so slopes never leave a gap underneath
const SAMPLE_STEP := 4.0
const MIN_START_ARC := 22.0      ## mouth is at least this far (route arclength) from the spawn
const MIN_RUN := 36.0            ## shortest acceptable walled stretch
const OTHER_ROUTE_CLEAR := 8.5   ## wall centre line vs every other route centre line (route half width 5.5 + wall half 1.3 + margin)
const PAD_CLEAR := 1.5
const FOOTPRINT_MARGIN := 4.0
const DOOR_HALF := 3.0
const DOOR_DEPTH := 2.0
const WORLD_LAYER := 1
const WATER_CUT := -1.0          ## wall samples must sit on land at least this high
const FLOOD_STEP := 1.5

var _terrain: Node3D
var _session: Node
var _plan: Dictionary = {}
var _open := false
var _initialized := false
var _door: StaticBody3D
var _door_height := 0.0
var _label: Label3D
var _socket_mats: Dictionary = {}
var _stone_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D


# ------------------------------------------------------------------ public interface

func build(terrain_node: Node3D, session_node: Node, deco_seed: int = 0) -> void:
	_terrain = terrain_node
	_session = session_node
	_plan = plan(terrain_node)
	if not bool(_plan.get("ok", false)):
		push_warning("central_passage: %s" % [_plan.get("errors", [])])
	if _plan.get("gate_center") == null:
		return
	_stone_mat = Kit.material(Color(0.47, 0.44, 0.39), 0.0, 1.0, 1.0)
	_cap_mat = Kit.material(Color(0.36, 0.38, 0.3), 0.0, 1.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = deco_seed ^ 0x6A7E
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var left: Array = _plan["left"]
	var right: Array = _plan["right"]
	for s in 2:
		var side: Array = left if s == 0 else right
		for i in side.size() - 1:
			_wall(walls, side[i], side[i + 1], "Wall_%d_%d" % [s, i])
	_decorate(walls, left, rng)
	_decorate(walls, right, rng)
	_build_gate()
	if _session != null and not _session.status_changed.is_connected(_refresh):
		_session.status_changed.connect(_refresh)
	_refresh()
	_initialized = true


func is_open() -> bool:
	return _open


func get_plan() -> Dictionary:
	return _plan


func get_door() -> StaticBody3D:
	return _door


## World position of the doorway centre on the ground and the passage direction (south -> north).
func get_gate_center() -> Vector3:
	var g: Vector2 = _plan["gate_center"]
	return Vector3(g.x, _terrain.height_at(g.x, g.y), g.y)


static func requirements_met(session: Node) -> bool:
	if session == null:
		return false
	for id in REQUIREMENTS:
		if not session.is_collected(id):
			return false
	return true


# ------------------------------------------------------------------ plan (data only)

## Wall lines and gate placement along the central route. {ok, errors, left, right, gate_center, gate_tangent, route(points
## mouth..gate), mouth_left, mouth_right}. Walls start where both flanks are clear of every other route / pad (never crossing the
## side routes) and run to the last sample before the summit footprint.
static func plan(terrain: Node3D) -> Dictionary:
	var errors: Array[String] = []
	var raw: PackedVector3Array = terrain.get_route_points(ROUTE)
	var line := PackedVector2Array()
	for p in raw:
		line.append(Vector2(p.x, p.z))
	var pts := _resample(line, SAMPLE_STEP)
	var out := {"ok": false, "errors": errors, "left": [], "right": [], "route": []}
	if pts.size() < 6:
		errors.append("central route too short")
		return out
	var keep: Rect2 = ((terrain.layout["footprints"] as Dictionary)[&"summit"] as Rect2).grow(FOOTPRINT_MARGIN)
	var gate_i := -1
	for i in pts.size():
		if keep.has_point(pts[i]):
			gate_i = i - 1
			break
	if gate_i < 2:
		errors.append("central route never reaches the summit footprint")
		return out
	var own: Dictionary = {&"summit": true, &"foothill_checkpoint": true}
	for p: StringName in (terrain.layout["enc_pads"] as Array).slice(0, 3):
		own[p] = true
	var others: Array = []
	for r: StringName in terrain.route_names():
		if r != ROUTE:
			others.append(terrain.get_route_points(r))
	var n := gate_i + 1
	# Inner side of a bend is pulled in (offset <= 0.75 x local radius, never below INNER_MIN) so the wall can never fold over the
	# route; limits take the minimum over +-3 samples so the wall line stays smooth.
	var raw_l: Array[float] = []
	var raw_r: Array[float] = []
	for i in n:
		var lim := HALF_SPAN
		var turn := 0.0
		if i > 0 and i < pts.size() - 1:
			var a := pts[i - 1]
			var b := pts[i]
			var c := pts[i + 1]
			turn = (b - a).cross(c - b)
			if absf(turn) > 0.0001:
				var radius := a.distance_to(b) * b.distance_to(c) * a.distance_to(c) / (2.0 * absf(turn))
				lim = clampf(radius * 0.75, INNER_MIN, HALF_SPAN)
		raw_l.append(lim if turn > 0.0 else HALF_SPAN)
		raw_r.append(lim if turn < 0.0 else HALF_SPAN)
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	var clear: Array[bool] = []
	for i in n:
		var off_l := HALF_SPAN
		var off_r := HALF_SPAN
		for k in range(maxi(i - 3, 0), mini(i + 4, n)):
			off_l = minf(off_l, raw_l[k])
			off_r = minf(off_r, raw_r[k])
		var t := _tangent(pts, i)
		var nrm := Vector2(-t.y, t.x)
		var l := pts[i] + nrm * off_l
		var r := pts[i] - nrm * off_r
		left.append(l)
		right.append(r)
		clear.append(_flank_clear(terrain, l, others, own) and _flank_clear(terrain, r, others, own))
	var min_i := ceili(MIN_START_ARC / SAMPLE_STEP)
	var start := gate_i
	while start > 0 and clear[start - 1]:
		start -= 1
	start = maxi(start, min_i)
	if not clear[gate_i]:
		errors.append("gate flanks are not clear")
	if (gate_i - start) * SAMPLE_STEP < MIN_RUN:
		errors.append("clear central stretch %.0f m is shorter than %.0f m" % [(gate_i - start) * SAMPLE_STEP, MIN_RUN])
	var central := PackedVector2Array(pts)
	var bent := false
	for i in range(start, gate_i + 1):
		for q: Vector2 in [left[i], right[i]]:
			for j in range(maxi(start - 4, 0), mini(gate_i + 5, central.size())):
				if absi(j - i) > 2 and q.distance_to(central[j]) < WALL_ROUTE_CLEAR:
					bent = true
	if bent:
		errors.append("central route bends too tightly for the passage walls")
	var gate_t := _tangent(pts, gate_i)
	out["left"] = left.slice(start, gate_i + 1)
	out["right"] = right.slice(start, gate_i + 1)
	out["route"] = Array(pts.slice(start, gate_i + 1))
	out["mouth_left"] = left[start]
	out["mouth_right"] = right[start]
	out["gate_center"] = pts[gate_i]
	out["gate_tangent"] = gate_t
	out["ok"] = errors.is_empty()
	return out


static func _tangent(pts: PackedVector2Array, i: int) -> Vector2:
	return (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()


static func _flank_clear(terrain: Node3D, p: Vector2, others: Array, own: Dictionary) -> bool:
	if terrain.height_at(p.x, p.y) < WATER_CUT:
		return false
	for route: PackedVector3Array in others:
		for i in route.size() - 1:
			var a := Vector2(route[i].x, route[i].z)
			var b := Vector2(route[i + 1].x, route[i + 1].z)
			if _seg_dist(p, a, b) < OTHER_ROUTE_CLEAR:
				return false
	for pad: StringName in terrain.pad_names():
		if own.has(pad):
			continue
		if terrain.pad_distance_to(pad, p.x, p.y) < PAD_CLEAR:
			return false
	return true


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0))


static func _resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	out.append(pts[0])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var seg := pts[i + 1] - a
		var seg_len := seg.length()
		var d := spacing - carry
		while d <= seg_len:
			out.append(a + seg * (d / seg_len))
			d += spacing
		carry = seg_len - (d - spacing)
	return out


# ------------------------------------------------------------------ build

## Solid wall between two world XZ points (overlapped by 0.6 m at both ends so bends never leave a gap).
func _wall(parent: Node3D, a: Vector2, b: Vector2, node_name: String, thick := WALL_THICK) -> StaticBody3D:
	var d := b - a
	var length := d.length() + 1.2
	var dir := d.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var lo := 1.0e9
	var hi := -1.0e9
	var steps := maxi(2, ceili(d.length() / 1.0))
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		for off in [-2.0, 0.0, 2.0]:
			var q: Vector2 = p + nrm * off
			var h: float = _terrain.height_at(q.x, q.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var bottom := lo - WALL_BELOW
	var top := hi + WALL_ABOVE
	var mid := (a + b) * 0.5
	var yaw := rad_to_deg(atan2(-d.y, d.x))
	var size := Vector3(length, top - bottom, thick)
	var body := Kit.box_body(parent, node_name, Vector3(mid.x, (top + bottom) * 0.5, mid.y), size, _stone_mat, yaw)
	Kit.box_mesh(body, "Cap", Vector3(0, size.y * 0.5 + 0.2, 0), Vector3(length + 0.1, 0.5, thick + 0.5), _cap_mat)
	return body


## Visual-only boulders leaning on both faces so the wall reads as natural rock, not a fence.
func _decorate(parent: Node3D, side: Array, rng: RandomNumberGenerator) -> void:
	var models := ["Rock_1_A_Color1", "Rock_3_A_Color1", "Rock_1_D_Color1", "Rock_3_D_Color1"]
	var face := 1.0
	for i in range(1, side.size() - 1, 2):
		var a: Vector2 = side[i - 1]
		var b: Vector2 = side[i + 1]
		var nrm := Vector2(-(b - a).y, (b - a).x).normalized()
		var p: Vector2 = (side[i] as Vector2) + nrm * face * (WALL_THICK * 0.5 + 0.4)
		face = -face
		var rock := Kit.nature(parent, models[rng.randi() % models.size()], Vector3(p.x, _terrain.height_at(p.x, p.y) - 0.3, p.y), rng.randf() * 360.0, rng.randf_range(3.2, 4.6))
		if rock != null:
			rock.name = "Boulder_%d" % i


func _build_gate() -> void:
	var g: Vector2 = _plan["gate_center"]
	var t: Vector2 = _plan["gate_tangent"]
	var nrm := Vector2(-t.y, t.x)
	var left: Array = _plan["left"]
	var right: Array = _plan["right"]
	var gate := Node3D.new()
	gate.name = "Gate"
	add_child(gate)
	var l: Vector2 = left[left.size() - 1]
	var r: Vector2 = right[right.size() - 1]
	var door_l := g + nrm * DOOR_HALF
	var door_r := g - nrm * DOOR_HALF
	_wall(gate, l, door_l, "CrossWall_L")
	_wall(gate, door_r, r, "CrossWall_R")
	# Door slab: spans the doorway up to the wall top and sinks into the ground when the seal breaks.
	var lo := 1.0e9
	var hi := -1.0e9
	for s in 7:
		var p := door_l.lerp(door_r, float(s) / 6.0)
		for off in [-1.0, 0.0, 1.0]:
			var q: Vector2 = p + t * float(off)
			var h: float = _terrain.height_at(q.x, q.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var bottom := lo - WALL_BELOW
	var top := hi + WALL_ABOVE
	_door_height = top - bottom
	var yaw := rad_to_deg(atan2(-nrm.y, nrm.x))
	var slab_mat := Kit.material(Color(0.3, 0.32, 0.36), 0.0, 1.0, 1.0)
	_door = Kit.box_body(gate, "SealSlab", Vector3(g.x, (top + bottom) * 0.5, g.y), Vector3(DOOR_HALF * 2.0 + 0.8, _door_height, DOOR_DEPTH), slab_mat, yaw)
	# One socket gem per branch artifact on both faces of the cross wall, flanking the doorway.
	var side_sign := 1.0
	for id in REQUIREMENTS:
		var mat := Kit.material(Color(0.35, 0.35, 0.38), 0.0)
		_socket_mats[id] = mat
		for face in [-1.0, 1.0]:
			var c: Vector2 = g + nrm * (DOOR_HALF + 1.6) * side_sign + t * face * (WALL_THICK * 0.5 + 0.15)
			var gy: float = _terrain.height_at(c.x, c.y) + 2.4
			Kit.box_mesh(gate, "Socket_%s_%d" % [id, int(face)], Vector3(c.x, gy, c.y), Vector3(1.0, 1.5, 0.35), mat, yaw)
		side_sign = -side_sign
	_label = Kit.label(gate, "", Vector3(g.x, hi + WALL_ABOVE + 1.6, g.y), 44, 0.012, Color(0.95, 0.92, 0.8), true)


# ------------------------------------------------------------------ state

func _refresh() -> void:
	var met := requirements_met(_session)
	var lines := PackedStringArray()
	for id in REQUIREMENTS:
		var have: bool = _session != null and _session.is_collected(id)
		lines.append("%s %s" % [REQUIREMENT_LABELS[id], "[x]" if have else "[ ]"])
		var mat: StandardMaterial3D = _socket_mats.get(id)
		if mat != null:
			if have:
				Kit.set_glow(mat, REQUIREMENT_COLORS[id], 2.2)
			else:
				Kit.set_glow(mat, Color(0.35, 0.35, 0.38), 0.0)
	if _label != null:
		_label.text = ("Gerbang Kuno Terbuka" if met else "Gerbang Kuno Tersegel\n%s" % "\n".join(lines))
		_label.modulate = Color(0.6, 1.0, 0.7) if met else Color(0.95, 0.92, 0.8)
	if met and not _open:
		_set_open(_initialized and is_inside_tree())


func _set_open(animate: bool) -> void:
	_open = true
	if _door != null:
		_door.set_deferred(&"collision_layer", 0)
		if animate:
			var tween := create_tween()
			tween.tween_property(_door, "position:y", _door.position.y - _door_height - 0.5, 1.4).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(_door.hide)
			for path: String in SFX_OPEN:
				Kit.play(self, path)
		else:
			_door.position.y -= _door_height + 0.5
			_door.hide()
	opened.emit()



# ------------------------------------------------------------------ topology proof

## Grid flood fill over the island with the wall footprints stamped as obstacles (slopes ignored = most permissive walkers).
## {sealed: closed passage + capped mouth reaches neither the summit foot nor the spawn, opens: with the door open the same
## flood reaches the far side, mouth_free: the open mouth reaches the spawn, branches: symbol / energy / summit anchors stay
## reachable from the spawn with the door closed, interior_cells, errors}.
static func verify_topology(terrain: Node3D, plan_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var res := {"sealed": false, "opens": false, "mouth_free": false, "branches": false, "interior_cells": 0, "errors": errors}
	if not bool(plan_data.get("ok", false)):
		errors.append("plan not ok: %s" % [plan_data.get("errors")])
		return res
	var half := WALL_THICK * 0.5 + 0.4
	var left: Array = plan_data["left"]
	var right: Array = plan_data["right"]
	var g: Vector2 = plan_data["gate_center"]
	var t: Vector2 = plan_data["gate_tangent"]
	var nrm := Vector2(-t.y, t.x)
	var walls: Array = []
	for side: Array in [left, right]:
		for i in side.size() - 1:
			walls.append([side[i], side[i + 1]])
	walls.append([left[left.size() - 1], g + nrm * DOOR_HALF])
	walls.append([g - nrm * DOOR_HALF, right[right.size() - 1]])
	var door := [g + nrm * DOOR_HALF, g - nrm * DOOR_HALF]
	var mouth := [plan_data["mouth_left"], plan_data["mouth_right"]]
	var m := int(ceil(250.0 / FLOOD_STEP)) + 1
	var base := PackedByteArray()
	base.resize(m * m)
	for j in m:
		for i in m:
			var p := Vector2(-125.0 + float(i) * FLOOD_STEP, -125.0 + float(j) * FLOOD_STEP)
			if terrain.height_at(p.x, p.y) < -2.0:
				base[j * m + i] = 1
	for w in walls:
		_stamp(base, m, w[0], w[1], half)
	var route: Array = plan_data["route"]
	var interior: Vector2 = route[route.size() / 2]
	var beyond := g + t * 8.0
	var spawn := _anchor(terrain, &"spawn")
	var foot := _anchor(terrain, &"foothill_checkpoint")
	# 1. Door closed, mouth capped: the passage interior must stay a sealed pocket.
	var closed := base.duplicate()
	_stamp(closed, m, door[0], door[1], half)
	_stamp(closed, m, mouth[0], mouth[1], half)
	var pocket := _flood(closed, m, interior)
	res["interior_cells"] = _count(pocket)
	var leaks := pocket[_cell(m, beyond)] == 1 or pocket[_cell(m, foot)] == 1 or pocket[_cell(m, spawn)] == 1
	res["sealed"] = not leaks and pocket[_cell(m, interior)] == 1
	if leaks:
		errors.append("closed passage leaks (beyond %s, foot %s, spawn %s)" % [pocket[_cell(m, beyond)], pocket[_cell(m, foot)], pocket[_cell(m, spawn)]])
	# 2. Door open, mouth capped: the far side becomes reachable only through the doorway.
	var opened_cap := base.duplicate()
	_stamp(opened_cap, m, mouth[0], mouth[1], half)
	var through := _flood(opened_cap, m, interior)
	res["opens"] = through[_cell(m, beyond)] == 1
	if not res["opens"]:
		errors.append("open doorway does not connect the passage to the far side")
	# 3. Door closed, mouth open: the spawn side connects and every branch stays reachable.
	var door_closed := base.duplicate()
	_stamp(door_closed, m, door[0], door[1], half)
	var from_spawn := _flood(door_closed, m, spawn)
	res["mouth_free"] = from_spawn[_cell(m, interior)] == 1
	if not res["mouth_free"]:
		errors.append("spawn cannot enter the passage mouth")
	var branches := true
	for a: StringName in [&"symbol", &"energy", &"summit", &"boss", &"viewpoint"]:
		if from_spawn[_cell(m, _anchor(terrain, a))] != 1:
			branches = false
			errors.append("anchor %s unreachable from the spawn with the door closed" % a)
	res["branches"] = branches
	return res


static func _anchor(terrain: Node3D, name: StringName) -> Vector2:
	var a: Vector3 = terrain.anchor_positions[name]
	return Vector2(a.x, a.z)


static func _cell(m: int, p: Vector2) -> int:
	var i := clampi(roundi((p.x + 125.0) / FLOOD_STEP), 0, m - 1)
	var j := clampi(roundi((p.y + 125.0) / FLOOD_STEP), 0, m - 1)
	return j * m + i


static func _stamp(grid: PackedByteArray, m: int, a: Vector2, b: Vector2, half: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(half, half)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(half, half)
	var i0 := clampi(floori((lo.x + 125.0) / FLOOD_STEP), 0, m - 1)
	var i1 := clampi(ceili((hi.x + 125.0) / FLOOD_STEP), 0, m - 1)
	var j0 := clampi(floori((lo.y + 125.0) / FLOOD_STEP), 0, m - 1)
	var j1 := clampi(ceili((hi.y + 125.0) / FLOOD_STEP), 0, m - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(-125.0 + float(i) * FLOOD_STEP, -125.0 + float(j) * FLOOD_STEP)
			if _seg_dist(p, a, b) <= half:
				grid[j * m + i] = 1


static func _flood(blocked: PackedByteArray, m: int, start: Vector2) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(m * m)
	var s := _cell(m, start)
	blocked[s] = 0
	seen[s] = 1
	var queue: Array[int] = [s]
	var head := 0
	while head < queue.size():
		var k: int = queue[head]
		head += 1
		var ci := k % m
		var cj := k / m
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ni := ci + di
				var nj := cj + dj
				if (di == 0 and dj == 0) or ni < 0 or nj < 0 or ni >= m or nj >= m:
					continue
				var n := nj * m + ni
				if seen[n] == 1 or blocked[n] == 1:
					continue
				seen[n] = 1
				queue.append(n)
	return seen


static func _count(grid: PackedByteArray) -> int:
	var n := 0
	for v in grid:
		n += v
	return n
