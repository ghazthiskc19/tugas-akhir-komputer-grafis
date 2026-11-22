extends Node3D
## Stylized 250 x 250 m island: deterministic seeded terrain mesh + real trimesh collision, coast, biomes,
## structural routes/pads at the shared anchors, an independent decoration stream and layout validation.
##
## Usage (no class_name on purpose; use preload):
##   var terrain := preload("res://scripts/world/island_terrain.gd").new()
##   terrain.configure(seed, procedural)      # BEFORE add_child (or call again later -> rebuilds)
##   add_child(terrain)                       # _ready builds data + nodes
## Data only (no scene tree needed, no nodes): configure(...); generate_data(); validate_layout().
##
## Order of generation: (1) structure stream (coast wobble, route jitter, hill noise) -> routes + pads + heightfield,
## validated with bounded retries and a proven fallback; (2) decoration stream (decoration_seed, independent of the
## structure stream) places trees/rocks/bushes/ruins only where they do not touch routes or pads.
## Everything is in this node's local space; anchors are fixed for every seed.

signal generated(report: Dictionary)

# ---- Contract constants -------------------------------------------------------------------------------------------
const BASELINE_SEED := 20261122
const MAX_ATTEMPTS := 4
const HALF := 125.0
const CELL := 1.25
const N := 201  # vertices per side (250 / 1.25 + 1)
const WATER_Y := -0.9
const OUT_OF_BOUNDS_H := -12.0
const WORLD_LAYER := 1  # terrain, decoration, dock and boundary collision all live on layer 1

const OBJECTIVE_ANCHORS := {
	&"spawn": Vector3(0, 0, 85),
	&"symbol": Vector3(-65, 0, 0),
	&"energy": Vector3(60, 0, 0),
	&"summit": Vector3(0, 0, -65),
	&"boss": Vector3(0, 0, -100),
}
## Flat pads (height exactly 0). [center(x,z), radius_x, radius_z, blend_width, coast_margin]
const PAD_DEFS := {
	&"spawn": [Vector2(0, 85), 15.0, 15.0, 14.0, 14.0],
	&"symbol": [Vector2(-65, 0), 26.0, 26.0, 16.0, 14.0],
	&"energy": [Vector2(60, 0), 26.0, 26.0, 16.0, 14.0],
	&"summit": [Vector2(0, -65), 28.0, 24.0, 20.0, 14.0],
	&"boss": [Vector2(0, -100), 28.0, 15.0, 5.0, 4.0],
	&"encounter_standard": [Vector2(0, 48), 10.0, 10.0, 12.0, 12.0],
	&"encounter_heavy": [Vector2(0, 25), 10.0, 10.0, 12.0, 12.0],
	&"encounter_ranged": [Vector2(0, 5), 10.0, 10.0, 12.0, 12.0],
	&"foothill_checkpoint": [Vector2(0, -36), 6.0, 6.0, 8.0, 12.0],
	&"boss_checkpoint": [Vector2(-22, -97), 5.0, 5.0, 6.0, 8.0],
	&"viewpoint": [Vector2(-84, -42), 6.0, 6.0, 10.0, 12.0],
}
## Routes: ordered control points; `true` = fixed (never jittered). Walkable, no jump gaps (jump_links is empty).
const ROUTE_DEFS := {
	&"spawn_symbol": [[Vector2(0, 85), true], [Vector2(-30, 62), false], [Vector2(-58, 30), false], [Vector2(-65, 0), true]],
	&"spawn_energy": [[Vector2(0, 85), true], [Vector2(30, 62), false], [Vector2(56, 30), false], [Vector2(60, 0), true]],
	&"spawn_summit": [[Vector2(0, 85), true], [Vector2(0, 48), true], [Vector2(0, 25), true], [Vector2(0, 5), true], [Vector2(0, -36), true], [Vector2(0, -65), true]],
	&"symbol_summit": [[Vector2(-65, 0), true], [Vector2(-60, -32), false], [Vector2(-34, -56), false], [Vector2(0, -65), true]],
	&"energy_summit": [[Vector2(60, 0), true], [Vector2(52, -34), false], [Vector2(32, -56), false], [Vector2(0, -65), true]],
	&"summit_boss": [[Vector2(0, -65), true], [Vector2(0, -100), true]],
	&"energy_boss": [[Vector2(60, 0), true], [Vector2(70, -40), false], [Vector2(50, -82), false], [Vector2(26, -98), false], [Vector2(0, -100), true]],
	&"viewpoint_spur": [[Vector2(-65, 0), true], [Vector2(-80, -20), false], [Vector2(-84, -42), true]],
}
## Boss checkpoint is a spur from boss pad; it lies inside the boss pad's flat blend so no route is needed.
const ROUTE_GRAPH_EDGES := [
	[&"spawn", &"symbol", &"spawn_symbol"], [&"spawn", &"energy", &"spawn_energy"],
	[&"spawn", &"summit", &"spawn_summit"], [&"symbol", &"summit", &"symbol_summit"],
	[&"energy", &"summit", &"energy_summit"], [&"summit", &"boss", &"summit_boss"],
	[&"energy", &"boss", &"energy_boss"], [&"symbol", &"viewpoint", &"viewpoint_spur"],
]
const EXTRA_ANCHORS := {
	&"foothill_checkpoint": Vector3(0, 0, -36),
	&"boss_checkpoint": Vector3(-22, 0, -97),
	&"encounter_standard": Vector3(0, 0, 48),
	&"encounter_heavy": Vector3(0, 0, 25),
	&"encounter_ranged": Vector3(0, 0, 5),
	&"viewpoint": Vector3(-84, 0, -42),
	&"dock_start": Vector3(0, 0, -106),
	&"dock_end": Vector3(0, 0, -122),
}

# Traversal limits (player: base 6 / sprint 9 m/s, jump 5.1 m/s with g 9.8 -> apex 1.33 m, floor angle 45 deg).
const ROUTE_HALF_WIDTH := 5.5            # fully flattened path half-width (path is 11 m wide)
const ROUTE_BLEND := 16.0
const ROUTE_CLEAR_HALF_WIDTH := 6.0      # no solid decoration within this distance of a route centerline (minus radius)
const PAD_SOLID_MARGIN := 3.0            # no solid decoration within this distance of a pad edge (minus radius)
const ROUTE_MAX_SLOPE_DEG := 14.0        # centerline, 1 m spacing
const ROUTE_EDGE_MAX_SLOPE_DEG := 20.0   # lateral +-4.5 m lines
const ROUTE_MIN_HEIGHT := -0.2
const PAD_FLAT_TOLERANCE := 0.02
const MIN_ANCHOR_SHORE := 8.0            # land-field distance (m) anchors must have from the shoreline
const WALK_SLOPE_DEG := 35.0             # free flood-fill slope limit
const CORRIDOR_SLOPE_DEG := 20.0         # route-only flood-fill slope limit
const MAX_JUMP_GAP := 3.0                # documented allowed jump link (none are generated)
const MIN_RELIEF := 3.0                  # off-route terrain must vary at least this much (not a fake flat plane)
const MAX_HEIGHT := 16.0

const FOREST := "res://assets/third_party/kaykit/forest_nature/"
const DUNGEON := "res://assets/third_party/kaykit/dungeon/"
const WATER_SHADER := "res://shaders/island/island_water.gdshader"

const TREE_FOREST: Array[String] = ["Tree_1_A", "Tree_1_B", "Tree_2_A", "Tree_2_B", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B"]
const TREE_OPEN: Array[String] = ["Tree_1_C", "Tree_2_C", "Tree_3_C"]
const TREE_BARE: Array[String] = ["Tree_Bare_1_A", "Tree_Bare_1_B", "Tree_Bare_2_A", "Tree_Bare_2_B"]
const BUSHES: Array[String] = ["Bush_1_A", "Bush_2_A", "Bush_3_A", "Bush_4_A", "Bush_1_C", "Bush_2_C"]
const ROCKS_BIG: Array[String] = ["Rock_1_A", "Rock_1_D", "Rock_1_G", "Rock_3_A", "Rock_3_D", "Rock_3_H"]
const RUIN_PIECES := {
	"pillar": [0.75, 4.0], "column": [0.35, 1.4], "wall_broken": [2.0, 4.0], "wall": [2.0, 4.0],
	"rubble_large": [4.0, 2.0], "wall_arched": [2.0, 4.0], "barrier_column": [2.0, 1.4],
}

# ---- Public state -------------------------------------------------------------------------------------------------
var requested_seed := BASELINE_SEED
var procedural := false
## Seed actually used for the structure stream (== BASELINE_SEED when not procedural or when fallback was needed).
var active_seed := BASELINE_SEED
var decoration_seed := 0
var used_fallback := false
var generation_attempts := 0
var attempt_log: Array[Dictionary] = []
var anchor_positions: Dictionary = {}
var last_report: Dictionary = {}
var jump_links: Array = []  # intentionally empty: every route is continuous ground

# ---- Internal -----------------------------------------------------------------------------------------------------
var _configured := false
var _data_ready := false
var _nodes_built := false
var _h := PackedFloat32Array()
var _s := PackedFloat32Array()
var _route_d := PackedFloat32Array()
var _colors := PackedColorArray()
var _routes: Dictionary = {}  # StringName -> PackedVector2Array (about 4 m spacing)
var _obstacles: Array[Dictionary] = []  # {pos:Vector2, r:float, kind:StringName}
var _instances: Dictionary = {}  # model path -> Array[Transform3D]
var _ruin_nodes: Array[Dictionary] = []  # {path, xform}
var _relief := 0.0
var _max_h := 0.0
var _noise_hill: FastNoiseLite
var _noise_ridge: FastNoiseLite
var _noise_coast: FastNoiseLite
var _noise_road: FastNoiseLite
var _noise_detail: FastNoiseLite
var _jitter_rng := RandomNumberGenerator.new()


# ---- Entry points -------------------------------------------------------------------------------------------------
func configure(seed_value: int, procedural_enabled: bool = false) -> void:
	requested_seed = seed_value
	procedural = procedural_enabled
	_configured = true
	_data_ready = false
	if _nodes_built:
		_clear_nodes()
		generate_data()
		_build_nodes()


func _ready() -> void:
	if not _configured:
		configure(BASELINE_SEED, false)
	if not _data_ready:
		generate_data()
	if not _nodes_built:
		_build_nodes()
	generated.emit(last_report)


## Pure data generation (no nodes, no scene tree): structure with bounded retries/fallback, then decoration.
func generate_data() -> Dictionary:
	if not _configured:
		configure(BASELINE_SEED, false)
	_rebuild_anchor_positions()
	used_fallback = false
	attempt_log.clear()
	generation_attempts = 0
	var base_seed := requested_seed if procedural else BASELINE_SEED
	var ok := false
	var attempts := MAX_ATTEMPTS if procedural else 1
	for k in attempts:
		generation_attempts += 1
		active_seed = base_seed if k == 0 else _mix(base_seed, 1000 + k)
		_generate_structure(active_seed)
		var r := validate_layout()
		attempt_log.append({"seed": active_seed, "valid": r["valid"], "errors": r["errors"]})
		if r["valid"]:
			ok = true
			break
	if not ok:
		used_fallback = procedural
		if procedural:
			generation_attempts += 1
			active_seed = BASELINE_SEED
			_generate_structure(active_seed)
			var fr := validate_layout()
			attempt_log.append({"seed": active_seed, "valid": fr["valid"], "errors": fr["errors"]})
	decoration_seed = _mix(active_seed, 0xDEC0)
	_place_decoration()
	_data_ready = true
	last_report = validate_layout()
	return last_report


## Re-places decoration only (terrain/routes untouched). Same decoration seed => identical result.
func set_decoration_seed(value: int) -> void:
	decoration_seed = value
	if _data_ready:
		_place_decoration()
		last_report = validate_layout()
		if _nodes_built:
			_rebuild_decoration_nodes()


# ---- Queries ------------------------------------------------------------------------------------------------------
## Height of the real collision surface (same triangulation as the mesh). OUT_OF_BOUNDS_H outside the 250 m square.
func height_at(x: float, z: float) -> float:
	var gx := (x + HALF) / CELL
	var gz := (z + HALF) / CELL
	if gx < 0.0 or gz < 0.0 or gx >= float(N - 1) or gz >= float(N - 1):
		return OUT_OF_BOUNDS_H
	var i := int(gx)
	var j := int(gz)
	var u := gx - float(i)
	var v := gz - float(j)
	var k := j * N + i
	var h00 := _h[k]
	var h10 := _h[k + 1]
	var h01 := _h[k + N]
	var h11 := _h[k + N + 1]
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


func normal_at(x: float, z: float) -> Vector3:
	var dx := height_at(x + 0.6, z) - height_at(x - 0.6, z)
	var dz := height_at(x, z + 0.6) - height_at(x, z - 0.6)
	return Vector3(-dx, 1.2, -dz).normalized()


func slope_deg_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


## Distance (m) from the shoreline-ish land field; > 2 is dry land, water level lies near 2.
func land_depth_at(x: float, z: float) -> float:
	var gx := clampi(roundi((x + HALF) / CELL), 0, N - 1)
	var gz := clampi(roundi((z + HALF) / CELL), 0, N - 1)
	return _s[gz * N + gx]


func is_dry_at(x: float, z: float) -> bool:
	return height_at(x, z) > WATER_Y + 0.3


func get_pad_def(pad: StringName) -> Dictionary:
	var d: Array = PAD_DEFS[pad]
	return {"center": d[0], "radius_x": d[1], "radius_z": d[2], "blend": d[3]}


## Metres beyond the pad edge (negative inside). Minimum over all pads.
func pad_distance(x: float, z: float) -> float:
	var best := 1.0e9
	for name: StringName in PAD_DEFS:
		best = minf(best, _pad_dist_one(PAD_DEFS[name], x, z))
	return best


func route_names() -> Array:
	return _routes.keys()


## Centerline of a route in local space (Y = terrain height), ~4 m point spacing.
func get_route_points(route: StringName) -> PackedVector3Array:
	var out := PackedVector3Array()
	var pts: PackedVector2Array = _routes.get(route, PackedVector2Array())
	for p in pts:
		out.append(Vector3(p.x, height_at(p.x, p.y), p.y))
	return out


func route_distance(x: float, z: float) -> float:
	var best := 1.0e9
	var p := Vector2(x, z)
	for name: StringName in _routes:
		var pts: PackedVector2Array = _routes[name]
		for i in range(pts.size() - 1):
			best = minf(best, _seg_dist(p, pts[i], pts[i + 1]))
	return best


func get_obstacles() -> Array[Dictionary]:
	return _obstacles


func get_spawn_position() -> Vector3:
	return anchor_positions[&"spawn"]


func biome_at(x: float, z: float) -> StringName:
	if land_depth_at(x, z) < 7.0:
		return &"beach"
	var w := _biome_weights(x, z)
	var names: Array[StringName] = [&"grassland", &"forest", &"ruins_plain", &"rocky_highlands"]
	var best := 0
	for i in 4:
		if w[i] > w[best]:
			best = i
	return names[best]


## HUD compass hook. position is global when inside the tree, otherwise local.
func get_compass_targets() -> Array:
	var out: Array = []
	var defs := [
		[&"spawn", "Titik Awal", "Grassland"], [&"symbol", "Pilar Simbol", "Forest"],
		[&"energy", "Jalur Energi", "Ruins Plain"], [&"summit", "Puncak", "Rocky Highlands"],
		[&"boss", "Gerbang Pulau", "Dermaga"], [&"viewpoint", "Titik Pandang", "Coast"],
	]
	for d in defs:
		var p: Vector3 = anchor_positions[d[0]]
		out.append({"label": d[1], "position": to_global(p) if is_inside_tree() else p, "region": d[2]})
	return out


# ---- Validation ---------------------------------------------------------------------------------------------------
## Real checks on the generated surface: pad flatness, per-route slope/step/gap/dryness on the centerline and
## lateral lines, obstacle clearance on routes and pads, route-graph reachability, and flood-fill traversal over the
## height field with slope limits and decoration obstacles (corridor-only, free, and per-artifact order independence).
func validate_layout() -> Dictionary:
	var errors: Array[String] = []
	var rep := {
		"valid": false, "errors": errors, "seed": active_seed, "requested_seed": requested_seed,
		"procedural": procedural, "used_fallback": used_fallback, "attempts": generation_attempts,
		"pads": {}, "routes": {}, "graph_reachable": {}, "flood": {}, "metrics": {},
	}
	if _h.size() != N * N:
		errors.append("heightfield not generated")
		return rep
	# Anchors
	for name: StringName in OBJECTIVE_ANCHORS:
		var a: Vector3 = OBJECTIVE_ANCHORS[name]
		if absf(height_at(a.x, a.z)) > PAD_FLAT_TOLERANCE:
			errors.append("anchor %s not on y=0 (%.3f)" % [name, height_at(a.x, a.z)])
		if land_depth_at(a.x, a.z) < MIN_ANCHOR_SHORE:
			errors.append("anchor %s too close to shore" % name)
	# Pads
	for name: StringName in PAD_DEFS:
		var d: Array = PAD_DEFS[name]
		var c: Vector2 = d[0]
		var max_dev := 0.0
		for ring in [0.0, 0.5, 0.9]:
			for s in 16:
				var ang := TAU * float(s) / 16.0
				var px: float = c.x + cos(ang) * float(d[1]) * ring
				var pz: float = c.y + sin(ang) * float(d[2]) * ring
				max_dev = maxf(max_dev, absf(height_at(px, pz)))
		var blocked := 0
		for o in _obstacles:
			if _pad_dist_one(d, o["pos"].x, o["pos"].y) < float(o["r"]) + PAD_SOLID_MARGIN:
				blocked += 1
		rep["pads"][name] = {"max_height_dev": max_dev, "flat_radius_x": d[1], "flat_radius_z": d[2], "obstacles_in_clearance": blocked}
		if max_dev > PAD_FLAT_TOLERANCE:
			errors.append("pad %s not flat (dev %.3f)" % [name, max_dev])
		if blocked > 0:
			errors.append("pad %s has %d obstacles inside clearance" % [name, blocked])
	# Routes
	var route_ok := {}
	for name: StringName in _routes:
		var r := _validate_route(name)
		rep["routes"][name] = r
		route_ok[name] = r["ok"]
		if not r["ok"]:
			errors.append("route %s invalid: %s" % [name, r["reason"]])
	# Graph reachability from spawn
	var reached := {&"spawn": true}
	var changed := true
	while changed:
		changed = false
		for e in ROUTE_GRAPH_EDGES:
			if route_ok.get(e[2], false):
				if reached.has(e[0]) and not reached.has(e[1]):
					reached[e[1]] = true
					changed = true
				elif reached.has(e[1]) and not reached.has(e[0]):
					reached[e[0]] = true
					changed = true
	for name: StringName in [&"symbol", &"energy", &"summit", &"boss", &"viewpoint"]:
		rep["graph_reachable"][name] = reached.has(name)
		if not reached.has(name):
			errors.append("graph: %s unreachable from spawn" % name)
	# Flood fill traversal
	_validate_flood(rep, errors)
	# Obstacle vs route clearance (exact, independent of placement filter)
	var route_viol := 0
	for o in _obstacles:
		var dd := route_distance(o["pos"].x, o["pos"].y)
		if dd - float(o["r"]) < ROUTE_CLEAR_HALF_WIDTH - 0.01:
			route_viol += 1
	rep["metrics"]["route_clearance_violations"] = route_viol
	if route_viol > 0:
		errors.append("%d obstacles inside route clearance" % route_viol)
	rep["metrics"]["obstacle_count"] = _obstacles.size()
	rep["metrics"]["relief_off_route"] = _relief
	rep["metrics"]["max_height"] = _max_h
	if _relief < MIN_RELIEF:
		errors.append("terrain too flat off-route (%.2f)" % _relief)
	if _max_h > MAX_HEIGHT:
		errors.append("terrain too high (%.2f)" % _max_h)
	# Dock hand-off
	var ds: Vector3 = EXTRA_ANCHORS[&"dock_start"]
	var de: Vector3 = EXTRA_ANCHORS[&"dock_end"]
	rep["metrics"]["dock_start_ground"] = height_at(ds.x, ds.z)
	rep["metrics"]["dock_end_ground"] = height_at(de.x, de.z)
	if absf(height_at(ds.x, ds.z)) > 0.1:
		errors.append("dock start not level with boss pad")
	if height_at(de.x, de.z) > WATER_Y:
		errors.append("dock end not over water")
	rep["valid"] = errors.is_empty()
	return rep


func _validate_route(name: StringName) -> Dictionary:
	var pts: PackedVector2Array = _routes[name]
	var line := _resample(pts, 1.0)
	var max_slope := 0.0
	var max_edge_slope := 0.0
	var min_h := 1.0e9
	var gap_run := 0.0
	var max_gap := 0.0
	var reason := ""
	var length := 0.0
	for off in [-4.5, 0.0, 4.5]:
		var prev := Vector3.INF
		for i in line.size():
			var dir: Vector2
			if i < line.size() - 1:
				dir = (line[i + 1] - line[i]).normalized()
			else:
				dir = (line[i] - line[i - 1]).normalized()
			var p: Vector2 = line[i] + Vector2(-dir.y, dir.x) * off
			var h := height_at(p.x, p.y)
			min_h = minf(min_h, h)
			if off == 0.0:
				if h < ROUTE_MIN_HEIGHT:
					gap_run += 1.0
					max_gap = maxf(max_gap, gap_run)
				else:
					gap_run = 0.0
			if prev != Vector3.INF:
				var run := Vector2(p.x - prev.x, p.y - prev.z).length()
				if run > 0.05:
					var sl := rad_to_deg(atan(absf(h - prev.y) / run))
					if off == 0.0:
						max_slope = maxf(max_slope, sl)
					else:
						max_edge_slope = maxf(max_edge_slope, sl)
			prev = Vector3(p.x, h, p.y)
	length = float(line.size() - 1)
	if min_h < ROUTE_MIN_HEIGHT:
		reason += "wet/low (%.2f) " % min_h
	if max_slope > ROUTE_MAX_SLOPE_DEG:
		reason += "slope %.1f " % max_slope
	if max_edge_slope > ROUTE_EDGE_MAX_SLOPE_DEG:
		reason += "edge slope %.1f " % max_edge_slope
	if max_gap > 0.0:
		reason += "gap %.1f " % max_gap
	return {"ok": reason == "", "reason": reason, "length": length, "max_slope_deg": max_slope,
		"max_edge_slope_deg": max_edge_slope, "min_height": min_h, "max_gap_m": max_gap}


func _validate_flood(rep: Dictionary, errors: Array[String]) -> void:
	var M := 101
	var step := 2.5
	var origin := -HALF
	var droute := PackedFloat32Array()
	droute.resize(M * M)
	var hh := PackedFloat32Array()
	hh.resize(M * M)
	var padmask := {}
	for name: StringName in PAD_DEFS:
		padmask[name] = PackedByteArray()
		padmask[name].resize(M * M)
	var blocked := PackedByteArray()
	blocked.resize(M * M)
	for j in M:
		for i in M:
			var k := j * M + i
			var x := origin + float(i) * step
			var z := origin + float(j) * step
			hh[k] = height_at(x, z)
			droute[k] = _route_d[(j * 2) * N + i * 2]
			for name: StringName in PAD_DEFS:
				if _pad_dist_one(PAD_DEFS[name], x, z) <= 0.0:
					padmask[name][k] = 1
	for o in _obstacles:
		var p: Vector2 = o["pos"]
		var rr: float = float(o["r"]) + 0.6
		var i0 := clampi(int((p.x - rr - origin) / step), 0, M - 1)
		var i1 := clampi(int((p.x + rr - origin) / step) + 1, 0, M - 1)
		var j0 := clampi(int((p.y - rr - origin) / step), 0, M - 1)
		var j1 := clampi(int((p.y + rr - origin) / step) + 1, 0, M - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var q := Vector2(origin + float(i) * step, origin + float(j) * step)
				if q.distance_to(p) <= rr:
					blocked[j * M + i] = 1
	var spawn_cell := _cell_of(_anchor2(&"spawn"), M, step)
	var tan_free := tan(deg_to_rad(WALK_SLOPE_DEG))
	var tan_corr := tan(deg_to_rad(CORRIDOR_SLOPE_DEG))
	# Free traversal
	var v_free := _flood(M, step, hh, blocked, droute, padmask, spawn_cell, tan_free, false, [])
	var v_corr := _flood(M, step, hh, blocked, droute, padmask, spawn_cell, tan_corr, true, [])
	var targets := [&"symbol", &"energy", &"summit", &"boss", &"viewpoint", &"foothill_checkpoint", &"boss_checkpoint", &"encounter_standard", &"encounter_heavy", &"encounter_ranged"]
	for t: StringName in targets:
		var c := _cell_of(_anchor2(t), M, step)
		var f_ok: bool = v_free[c] == 1
		var c_ok: bool = v_corr[c] == 1
		rep["flood"][t] = {"free": f_ok, "corridor": c_ok}
		if not f_ok:
			errors.append("flood(free): %s unreachable" % t)
		if not c_ok:
			errors.append("flood(corridor): %s unreachable" % t)
	# Artifact order independence: reach each artifact pad without passing through the other two pads.
	var arts := [&"symbol", &"energy", &"summit"]
	for t: StringName in arts:
		var others := []
		for o in arts:
			if o != t:
				others.append(o)
		var v := _flood(M, step, hh, blocked, droute, padmask, spawn_cell, tan_corr, true, others)
		var ok: bool = v[_cell_of(_anchor2(t), M, step)] == 1
		rep["flood"]["%s_without_others" % t] = ok
		if not ok:
			errors.append("artifact %s requires passing another artifact pad" % t)


func _anchor2(name: StringName) -> Vector2:
	var a: Vector3 = anchor_positions[name]
	return Vector2(a.x, a.z)


func _cell_of(p: Vector2, M: int, step: float) -> int:
	var i := clampi(roundi((p.x + HALF) / step), 0, M - 1)
	var j := clampi(roundi((p.y + HALF) / step), 0, M - 1)
	return j * M + i


func _flood(M: int, step: float, hh: PackedFloat32Array, blocked: PackedByteArray, droute: PackedFloat32Array,
		padmask: Dictionary, start: int, max_tan: float, corridor: bool, avoid_pads: Array) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(M * M)
	var allowed := PackedByteArray()
	allowed.resize(M * M)
	for k in M * M:
		var ok := blocked[k] == 0 and hh[k] > ROUTE_MIN_HEIGHT - 0.15
		if ok and corridor:
			var in_pad := false
			for name: StringName in padmask:
				if padmask[name][k] == 1:
					in_pad = true
					break
			ok = in_pad or droute[k] <= ROUTE_HALF_WIDTH
		if ok:
			for name: StringName in avoid_pads:
				if padmask[name][k] == 1:
					ok = false
					break
		allowed[k] = 1 if ok else 0
	allowed[start] = 1
	var queue: Array[int] = [start]
	seen[start] = 1
	var head := 0
	while head < queue.size():
		var k: int = queue[head]
		head += 1
		var ci := k % M
		var cj := k / M
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ni := ci + di
				var nj := cj + dj
				if ni < 0 or nj < 0 or ni >= M or nj >= M:
					continue
				var n := nj * M + ni
				if seen[n] == 1 or allowed[n] == 0:
					continue
				var run := step * (1.4142 if (di != 0 and dj != 0) else 1.0)
				if absf(hh[n] - hh[k]) / run > max_tan:
					continue
				seen[n] = 1
				queue.append(n)
	return seen


# ---- Structure ----------------------------------------------------------------------------------------------------
func _rebuild_anchor_positions() -> void:
	anchor_positions = {}
	for name: StringName in OBJECTIVE_ANCHORS:
		anchor_positions[name] = OBJECTIVE_ANCHORS[name]
	for name: StringName in EXTRA_ANCHORS:
		anchor_positions[name] = EXTRA_ANCHORS[name]


func _make_noise(seed_value: int, freq: float, octaves: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value & 0x7FFFFFFF
	n.noise_type = kind
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


func _generate_structure(seed_value: int) -> void:
	_noise_hill = _make_noise(_mix(seed_value, 1), 0.011, 4)
	_noise_ridge = _make_noise(_mix(seed_value, 2), 0.02, 3, FastNoiseLite.TYPE_PERLIN)
	_noise_coast = _make_noise(_mix(seed_value, 3), 0.018, 3)
	_noise_road = _make_noise(_mix(seed_value, 4), 0.016, 2)
	_noise_detail = _make_noise(_mix(seed_value, 5), 0.09, 2)
	_jitter_rng.seed = _mix(seed_value, 6)
	_obstacles.clear()
	_instances.clear()
	_ruin_nodes.clear()
	_build_routes()
	_build_fields()


func _build_routes() -> void:
	_routes.clear()
	for name: StringName in ROUTE_DEFS:
		var ctrl: Array = ROUTE_DEFS[name]
		var pts: Array[Vector2] = []
		for c in ctrl:
			var p: Vector2 = c[0]
			if not c[1]:
				# Jitter stays inside a disc; routes keep ~25 m control spacing so they cannot fold back.
				var ang := _jitter_rng.randf() * TAU
				var rad := _jitter_rng.randf_range(0.0, 9.0)
				p += Vector2(cos(ang), sin(ang)) * rad
			pts.append(p)
		_routes[name] = _catmull(pts)


func _catmull(pts: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var subdiv := maxi(2, ceili(p1.distance_to(p2) / 4.0))
		for s in subdiv:
			var t := float(s) / float(subdiv)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


func _build_fields() -> void:
	var cnt := N * N
	_route_d.resize(cnt)
	_route_d.fill(99.0)
	var cap := ROUTE_BLEND + 4.0
	for name: StringName in _routes:
		var pts: PackedVector2Array = _routes[name]
		for si in range(pts.size() - 1):
			var a := pts[si]
			var b := pts[si + 1]
			var i0 := clampi(int((minf(a.x, b.x) - cap + HALF) / CELL), 0, N - 1)
			var i1 := clampi(int((maxf(a.x, b.x) + cap + HALF) / CELL) + 1, 0, N - 1)
			var j0 := clampi(int((minf(a.y, b.y) - cap + HALF) / CELL), 0, N - 1)
			var j1 := clampi(int((maxf(a.y, b.y) + cap + HALF) / CELL) + 1, 0, N - 1)
			for j in range(j0, j1 + 1):
				var z := -HALF + float(j) * CELL
				for i in range(i0, i1 + 1):
					var d := _seg_dist(Vector2(-HALF + float(i) * CELL, z), a, b)
					var k := j * N + i
					if d < _route_d[k]:
						_route_d[k] = d
	_s.resize(cnt)
	_h.resize(cnt)
	_colors.resize(cnt)
	var min_relief := 1.0e9
	var max_relief := -1.0e9
	_max_h = -1.0e9
	for j in N:
		var z := -HALF + float(j) * CELL
		for i in N:
			var x := -HALF + float(i) * CELL
			var k := j * N + i
			var s := _land_field(x, z, _route_d[k])
			_s[k] = s
			var w := _biome_weights(x, z)
			var amp := 1.8 * w.x + 3.0 * w.y + 2.2 * w.z + 7.0 * w.w
			var hl := _noise_hill.get_noise_2d(x, z) * 0.5 + 0.5
			var rg := 1.0 - absf(_noise_ridge.get_noise_2d(x, z))
			var hills := amp * hl + 5.0 * w.w * rg * rg + 0.35 * _noise_detail.get_noise_2d(x, z)
			var h := _coast_profile(s) + hills * smoothstep(8.0, 28.0, s)
			var pd := 1.0e9
			var wp := 0.0
			for name: StringName in PAD_DEFS:
				var d: Array = PAD_DEFS[name]
				var dp := _pad_dist_one(d, x, z)
				pd = minf(pd, dp)
				wp = maxf(wp, 1.0 - smoothstep(0.0, float(d[3]), dp))
			var road := (0.25 + 1.3 * (_noise_road.get_noise_2d(x, z) * 0.5 + 0.5)) * smoothstep(0.0, 18.0, pd)
			var wr := 1.0 - smoothstep(ROUTE_HALF_WIDTH, ROUTE_BLEND, _route_d[k])
			var free_h := h
			h = lerpf(h, road, wr)
			h = lerpf(h, 0.0, wp)
			_h[k] = h
			if s > 10.0:
				_max_h = maxf(_max_h, h)
				if wr < 0.01 and wp < 0.01:
					min_relief = minf(min_relief, free_h)
					max_relief = maxf(max_relief, free_h)
	_relief = max_relief - min_relief if max_relief > min_relief else 0.0
	_paint_colors()


func _land_field(x: float, z: float, route_d: float) -> float:
	# Rounded-box island silhouette with noisy coast, unioned with disks around every pad and a corridor around routes
	# so the structure can never be cut by the sea.
	var q := Vector2(absf(x) - (92.0 - 42.0), absf(z) - (104.0 - 42.0))
	var sd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 42.0
	var s := -sd + _noise_coast.get_noise_2d(x, z) * 9.0
	for name: StringName in PAD_DEFS:
		var d: Array = PAD_DEFS[name]
		var c: Vector2 = d[0]
		var dn := Vector2((x - c.x) / float(d[1]), (z - c.y) / float(d[2])).length()
		s = maxf(s, float(d[4]) + (1.0 - dn) * minf(float(d[1]), float(d[2])))
	return maxf(s, 16.0 - route_d)


func _coast_profile(s: float) -> float:
	if s >= -6.0:
		return -3.0 + 3.6 * smoothstep(-6.0, 8.0, s)
	return maxf(-3.0 - (-6.0 - s) * 1.5, -12.0)


func _biome_weights(x: float, z: float) -> Vector4:
	# x grassland, y forest, z ruins plain, w rocky highlands
	var g := exp(-pow(Vector2(x, z - 70.0).length() / 52.0, 2.0))
	var f := exp(-pow(Vector2(x + 70.0, z - 10.0).length() / 48.0, 2.0))
	var p := exp(-pow(Vector2(x - 68.0, z - 5.0).length() / 45.0, 2.0))
	var hh := exp(-pow(Vector2(x * 0.8, z + 75.0).length() / 52.0, 2.0))
	var sum := g + f + p + hh + 0.0001
	return Vector4(g / sum, f / sum, p / sum, hh / sum)


func _pad_dist_one(d: Array, x: float, z: float) -> float:
	var c: Vector2 = d[0]
	var dn := Vector2((x - c.x) / float(d[1]), (z - c.y) / float(d[2])).length()
	return (dn - 1.0) * minf(float(d[1]), float(d[2]))


func _paint_colors() -> void:
	var grass := Color(0.38, 0.64, 0.27)
	var forest := Color(0.2, 0.44, 0.22)
	var plain := Color(0.55, 0.64, 0.3)
	var rock := Color(0.5, 0.47, 0.43)
	var sand := Color(0.87, 0.79, 0.56)
	var dirt := Color(0.63, 0.5, 0.33)
	var paving := Color(0.68, 0.62, 0.5)
	for j in N:
		var z := -HALF + float(j) * CELL
		for i in N:
			var x := -HALF + float(i) * CELL
			var k := j * N + i
			var w := _biome_weights(x, z)
			var c := grass * w.x + forest * w.y + plain * w.z + rock * w.w
			var s := _s[k]
			var h := _h[k]
			c = c.lerp(sand, 1.0 - smoothstep(3.0, 9.0, s))
			if h < WATER_Y + 0.3:
				c = c.lerp(Color(0.55, 0.5, 0.38), 0.6)
			var slope := 1.0 - normal_at_grid(i, j).y
			c = c.lerp(rock * 0.9, smoothstep(0.12, 0.3, slope))
			var wr := 1.0 - smoothstep(ROUTE_HALF_WIDTH - 1.5, ROUTE_HALF_WIDTH + 1.5, _route_d[k])
			c = c.lerp(dirt, wr * 0.85)
			var pd := pad_distance(x, z)
			c = c.lerp(paving, 1.0 - smoothstep(-2.0, 1.0, pd))
			var dn := _noise_detail.get_noise_2d(x, z) * 0.07
			_colors[k] = Color(clampf(c.r + dn, 0.0, 1.0), clampf(c.g + dn, 0.0, 1.0), clampf(c.b + dn, 0.0, 1.0))


func normal_at_grid(i: int, j: int) -> Vector3:
	var il := maxi(i - 1, 0)
	var ir := mini(i + 1, N - 1)
	var jl := maxi(j - 1, 0)
	var jr := mini(j + 1, N - 1)
	var dx := _h[j * N + ir] - _h[j * N + il]
	var dz := _h[jr * N + i] - _h[jl * N + i]
	return Vector3(-dx / (CELL * float(ir - il)), 1.0, -dz / (CELL * float(jr - jl))).normalized()


# ---- Decoration (independent stream) ------------------------------------------------------------------------------
func _place_decoration() -> void:
	_obstacles.clear()
	_instances.clear()
	_ruin_nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var occupied := {}
	# Ruin clusters first (landmarks), then trail markers, trees, rocks, bushes.
	_place_ruins(rng)
	_place_cover_rocks(rng, occupied)
	_place_trail_markers(rng, occupied)
	_place_trees(rng, occupied)
	_place_scatter_rocks(rng, occupied)
	_place_bushes(rng, occupied)


func _clear_for(p: Vector2, r: float, route_margin: float, pad_margin: float, min_depth: float, min_ny: float) -> bool:
	if absf(p.x) > HALF - 6.0 or absf(p.y) > HALF - 6.0:
		return false
	var gi := clampi(roundi((p.x + HALF) / CELL), 0, N - 1)
	var gj := clampi(roundi((p.y + HALF) / CELL), 0, N - 1)
	if _s[gj * N + gi] < min_depth:
		return false
	if _route_d[gj * N + gi] - 0.9 < r + route_margin:
		return false
	if pad_distance(p.x, p.y) < r + pad_margin:
		return false
	var dock_dx := absf(p.x)
	if dock_dx < 8.0 + r and p.y < -102.0:
		return false
	return normal_at(p.x, p.y).y >= min_ny


func _cell_free(occupied: Dictionary, p: Vector2, size: float) -> bool:
	var key := Vector2i(floori(p.x / size), floori(p.y / size))
	if occupied.has(key):
		return false
	occupied[key] = true
	return true


func _add_instance(path: String, p: Vector2, scale: float, yaw: float, tilt: float = 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt).scaled(Vector3.ONE * scale), Vector3(p.x, height_at(p.x, p.y) - 0.05, p.y))
	if not _instances.has(path):
		_instances[path] = []
	_instances[path].append(xf)


func _place_trees(rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var placed := 0
	for _try in 5000:
		if placed >= 420:
			break
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		var scale := rng.randf_range(1.5, 2.1)
		var yaw := rng.randf() * TAU
		var pick := rng.randf()
		var accept := rng.randf()
		var biome := biome_at(p.x, p.y)
		var density := 0.0
		var pool: Array[String] = TREE_FOREST
		match biome:
			&"forest":
				density = 0.85
			&"grassland":
				density = 0.1
				pool = TREE_OPEN
			&"ruins_plain":
				density = 0.12
				pool = TREE_OPEN
			&"rocky_highlands":
				density = 0.2
				pool = TREE_BARE
		if accept > density:
			continue
		var r := 0.3 * scale
		if not _clear_for(p, r, ROUTE_CLEAR_HALF_WIDTH + 0.8, PAD_SOLID_MARGIN + 2.0, 12.0, 0.88):
			continue
		if not _cell_free(occupied, p, 4.0):
			continue
		var model := pool[int(pick * float(pool.size())) % pool.size()]
		_add_instance(FOREST + model + "_Color1.gltf", p, scale, yaw)
		_obstacles.append({"pos": p, "r": r, "kind": &"tree", "h": 4.0 * scale})
		placed += 1


func _place_scatter_rocks(rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var placed := 0
	for _try in 1500:
		if placed >= 120:
			break
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		var biome := biome_at(p.x, p.y)
		var prob := 0.55 if biome == &"rocky_highlands" else (0.2 if biome != &"beach" else 0.12)
		var scale := rng.randf_range(3.0, 6.0)
		var model := ROCKS_BIG[rng.randi() % ROCKS_BIG.size()]
		var yaw := rng.randf() * TAU
		if rng.randf() > prob:
			continue
		var r := 0.28 * scale
		if not _clear_for(p, r, ROUTE_CLEAR_HALF_WIDTH + 0.8, PAD_SOLID_MARGIN + 2.0, 5.0, 0.8):
			continue
		if not _cell_free(occupied, p, 5.0):
			continue
		_add_instance(FOREST + model + "_Color1.gltf", p, scale, yaw)
		_obstacles.append({"pos": p, "r": r, "kind": &"rock", "h": 0.5 * scale})
		placed += 1


func _place_bushes(rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var placed := 0
	for _try in 4000:
		if placed >= 360:
			break
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		var biome := biome_at(p.x, p.y)
		var prob := 0.5 if biome == &"forest" else (0.3 if biome == &"grassland" or biome == &"ruins_plain" else 0.05)
		var scale := rng.randf_range(3.0, 5.0)
		var model := BUSHES[rng.randi() % BUSHES.size()]
		var yaw := rng.randf() * TAU
		if rng.randf() > prob:
			continue
		# Bushes are non-solid (no collision) but still stay off pads and the route surface.
		if not _clear_for(p, 0.4, ROUTE_HALF_WIDTH + 1.0, 1.5, 9.0, 0.8):
			continue
		if not _cell_free(occupied, p, 2.5):
			continue
		_add_instance(FOREST + model + "_Color1.gltf", p, scale, yaw)
		placed += 1


func _place_trail_markers(rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	# Rock pairs at the path margin so the route reads from the gameplay camera.
	for name: StringName in _routes:
		var line := _resample(_routes[name], 16.0)
		for i in range(1, line.size() - 1):
			var dir: Vector2 = (line[i + 1] - line[i - 1]).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var p: Vector2 = line[i] + nrm * side * rng.randf_range(8.0, 10.0)
			var scale := rng.randf_range(2.5, 4.0)
			var model := ROCKS_BIG[rng.randi() % ROCKS_BIG.size()]
			var yaw := rng.randf() * TAU
			var r := 0.28 * scale
			if not _clear_for(p, r, ROUTE_CLEAR_HALF_WIDTH + 0.5, PAD_SOLID_MARGIN + 1.0, 6.0, 0.85):
				continue
			if not _cell_free(occupied, p, 5.0):
				continue
			_add_instance(FOREST + model + "_Color1.gltf", p, scale, yaw)
			_obstacles.append({"pos": p, "r": r, "kind": &"rock", "h": 0.5 * scale})


func _place_cover_rocks(rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	# Side cover beside the centre-route encounter pads (15 m off the centreline): outside the 6 m clearance
	# corridor and outside every pad, so they give ranged-fight cover without blocking the path.
	for e: StringName in [&"encounter_standard", &"encounter_heavy", &"encounter_ranged"]:
		var c: Vector3 = anchor_positions[e]
		for side in [-1.0, 1.0]:
			for dz in [-3.5, 3.5]:
				var p := Vector2(c.x + 15.0 * side, c.z + dz)
				var scale := rng.randf_range(3.2, 4.2)
				var model := ROCKS_BIG[rng.randi() % ROCKS_BIG.size()]
				var yaw := rng.randf() * TAU
				var r := 0.28 * scale
				if not _clear_for(p, r, ROUTE_CLEAR_HALF_WIDTH + 0.5, PAD_SOLID_MARGIN + 0.5, 6.0, 0.8):
					continue
				if not _cell_free(occupied, p, 5.0):
					continue
				_add_instance(FOREST + model + "_Color1.gltf", p, scale, yaw)
				_obstacles.append({"pos": p, "r": r, "kind": &"rock", "h": 0.5 * scale})


func _place_ruins(rng: RandomNumberGenerator) -> void:
	var sites: Array[Vector2] = []
	var pieces: Array = RUIN_PIECES.keys()
	for _try in 1200:
		if sites.size() >= 8:
			break
		var c := Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-100.0, 100.0))
		var biome := biome_at(c.x, c.y)
		if biome != &"ruins_plain" and biome != &"rocky_highlands" and biome != &"forest":
			continue
		var ok := true
		for s in sites:
			if s.distance_to(c) < 45.0:
				ok = false
				break
		if not ok:
			continue
		var gi := clampi(roundi((c.x + HALF) / CELL), 0, N - 1)
		var gj := clampi(roundi((c.y + HALF) / CELL), 0, N - 1)
		var rd := _route_d[gj * N + gi]
		if rd < 14.0 or rd > 34.0 or pad_distance(c.x, c.y) < 14.0 or _s[gj * N + gi] < 16.0:
			continue
		if normal_at(c.x, c.y).y < 0.96:
			continue
		sites.append(c)
		var count := rng.randi_range(4, 7)
		for _k in count:
			var ang := rng.randf() * TAU
			var p := c + Vector2(cos(ang), sin(ang)) * rng.randf_range(0.0, 7.0)
			var name: String = pieces[rng.randi() % pieces.size()]
			var def: Array = RUIN_PIECES[name]
			var r := float(def[0])
			var yaw := rng.randf() * TAU
			if not _clear_for(p, r, ROUTE_CLEAR_HALF_WIDTH + 1.0, PAD_SOLID_MARGIN + 3.0, 12.0, 0.93):
				continue
			var overlap := false
			for o in _obstacles:
				if o["pos"].distance_to(p) < float(o["r"]) + r:
					overlap = true
					break
			if overlap:
				continue
			_obstacles.append({"pos": p, "r": r, "kind": &"ruin", "h": float(def[1]), "piece": name, "yaw": yaw})
			var y := height_at(p.x, p.y) - 0.05
			_ruin_nodes.append({"path": DUNGEON + name + ".gltf", "xform": Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))})


# ---- Node construction --------------------------------------------------------------------------------------------
func _build_nodes() -> void:
	_nodes_built = true
	_build_terrain_node()
	_build_sea()
	_build_boundary()
	_build_dock()
	_build_anchor_markers()
	_rebuild_decoration_nodes()


func _clear_nodes() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_nodes_built = false


func _build_terrain_node() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(N * N)
	norms.resize(N * N)
	for j in N:
		for i in N:
			var k := j * N + i
			verts[k] = Vector3(-HALF + float(i) * CELL, _h[k], -HALF + float(j) * CELL)
			norms[k] = normal_at_grid(i, j)
	var idx := PackedInt32Array()
	idx.resize((N - 1) * (N - 1) * 6)
	var w := 0
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			var b := a + 1
			var c := a + N
			var d := c + 1
			# Same triangulation as height_at(): (a,b,c) and (b,d,c); clockwise seen from above = front face.
			idx[w] = a
			idx[w + 1] = b
			idx[w + 2] = c
			idx[w + 3] = b
			idx[w + 4] = d
			idx[w + 5] = c
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "TerrainCollision"
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ResourceLoader.exists(WATER_SHADER):
		plane.subdivide_width = 120
		plane.subdivide_depth = 120
		var sm := ShaderMaterial.new()
		sm.shader = load(WATER_SHADER)
		mi.material_override = sm
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.55, 0.78, 0.72)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.25
		mi.material_override = m
	mi.mesh = plane
	add_child(mi)


func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var defs := [[Vector3(0, 0, -HALF - 2.0), Vector3(2 * HALF + 8.0, 60, 4)], [Vector3(0, 0, HALF + 2.0), Vector3(2 * HALF + 8.0, 60, 4)],
		[Vector3(-HALF - 2.0, 0, 0), Vector3(4, 60, 2 * HALF)], [Vector3(HALF + 2.0, 0, 0), Vector3(4, 60, 2 * HALF)]]
	for d in defs:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d[1]
		cs.shape = bs
		cs.position = d[0]
		body.add_child(cs)
	add_child(body)


func _build_dock() -> void:
	var dock := Node3D.new()
	dock.name = "Dock"
	add_child(dock)
	var tile: PackedScene = load(DUNGEON + "floor_wood_large.gltf")
	var col: PackedScene = load(DUNGEON + "column.gltf")
	var body := StaticBody3D.new()
	body.name = "DockCollision"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	dock.add_child(body)
	# 2 x 4 tiles of 4 m: x -4..4, z -106..-122, walking surface y = 0.03 (3 cm above the pad).
	for tz in 4:
		for tx in 2:
			var n: Node3D = tile.instantiate()
			n.position = Vector3(-2.0 + 4.0 * float(tx), -0.02, -108.0 - 4.0 * float(tz))
			dock.add_child(n)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(8.0, 0.6, 16.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.03 - 0.3, -114.0)
	body.add_child(cs)
	for tz in 3:
		for side in [-1.0, 1.0]:
			var post: Node3D = col.instantiate()
			post.position = Vector3(4.3 * side, -1.35, -108.0 - 6.0 * float(tz))
			post.scale = Vector3(1.3, 1.3, 1.3)
			dock.add_child(post)


func _build_anchor_markers() -> void:
	var root := Node3D.new()
	root.name = "Anchors"
	add_child(root)
	for name: StringName in anchor_positions:
		var m := Marker3D.new()
		m.name = String(name)
		m.position = anchor_positions[name]
		root.add_child(m)


func _rebuild_decoration_nodes() -> void:
	for n in ["Decoration", "DecorationCollision"]:
		var old := get_node_or_null(n)
		if old != null:
			remove_child(old)
			old.queue_free()
	var deco := Node3D.new()
	deco.name = "Decoration"
	add_child(deco)
	for path: String in _instances:
		var xfs: Array = _instances[path]
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := mi as MeshInstance3D
			var local := _relative_transform(mesh_node, inst)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh_node.mesh
			mm.instance_count = xfs.size()
			for q in xfs.size():
				mm.set_instance_transform(q, xfs[q] * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			deco.add_child(mmi)
		inst.free()
	for r in _ruin_nodes:
		var rs: PackedScene = load(r["path"])
		var rn: Node3D = rs.instantiate()
		rn.transform = r["xform"]
		deco.add_child(rn)
	var body := StaticBody3D.new()
	body.name = "DecorationCollision"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	add_child(body)
	for o in _obstacles:
		var p: Vector2 = o["pos"]
		var y := height_at(p.x, p.y)
		var h: float = o["h"]
		var cs := CollisionShape3D.new()
		if o["kind"] == &"ruin" and (o["piece"] == "wall" or o["piece"] == "wall_broken" or o["piece"] == "wall_arched" or o["piece"] == "barrier_column"):
			var bs := BoxShape3D.new()
			bs.size = Vector3(4.0, h, 1.0)
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, o["yaw"]), Vector3(p.x, y + h * 0.5, p.y))
		elif o["kind"] == &"ruin" and o["piece"] == "rubble_large":
			var bs := BoxShape3D.new()
			bs.size = Vector3(7.0, h, 2.6)
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, o["yaw"]), Vector3(p.x, y + h * 0.5, p.y))
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(o["r"])
			cyl.height = h
			cs.shape = cyl
			cs.position = Vector3(p.x, y + h * 0.5, p.y)
		body.add_child(cs)


func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# ---- Physics probe ------------------------------------------------------------------------------------------------
## Call after at least one physics frame in the tree. Raycasts layer-1 collision at pads/route samples and compares
## with height_at(). Returns {checked, missed, max_error}.
func probe_collision() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var pts: Array[Vector2] = []
	for name: StringName in anchor_positions:
		pts.append(Vector2(anchor_positions[name].x, anchor_positions[name].z))
	for name: StringName in _routes:
		for p in _resample(_routes[name], 12.0):
			pts.append(p)
	var missed := 0
	var max_err := 0.0
	for p in pts:
		var from := to_global(Vector3(p.x, 40.0, p.y))
		var to := to_global(Vector3(p.x, -30.0, p.y))
		var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			missed += 1
			continue
		var local_y: float = to_local(hit["position"]).y
		var ground := height_at(p.x, p.y)
		# Dock tiles sit 3 cm above the boss pad; solids are excluded by the route/pad clearance.
		max_err = maxf(max_err, absf(local_y - ground))
	return {"checked": pts.size(), "missed": missed, "max_error": max_err}


# ---- Helpers ------------------------------------------------------------------------------------------------------
static func _mix(a: int, b: int) -> int:
	var x: int = a + b * 0x1E3779B97F4A7C15
	x = (x ^ (x >> 30)) * 0x3F58476D1CE4E5B9
	x = (x ^ (x >> 27)) * 0x14D049BB133111EB
	x = x ^ (x >> 31)
	return x & 0x7FFFFFFF


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	var carry := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var pos := spacing - carry
		while pos <= seg:
			out.append(a.lerp(b, pos / seg))
			pos += spacing
		carry = seg - (pos - spacing)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.01:
		out.append(pts[pts.size() - 1])
	return out
