extends Node3D
## Visual-only landmarks, directional signposts, short lore placards and route accents for the island.
##
## Usage (parent, AFTER terrain and objective modules exist; instantiate as a SIBLING of the terrain):
##   var marks := preload("res://scripts/world/island_landmarks.gd").new()
##   add_child(marks)
##   marks.build(terrain)
##
## Everything is derived from terrain.layout (anchor name -> Vector3, falls back to terrain.anchor_positions),
## terrain.height_at and terrain.get_route_points, so moved anchors move the content with them.
## Nothing here has collision, nothing runs per frame, and every spot is validated to stay off routes, module
## footprints, checkpoints, encounter pads and the shoreline. Spots that cannot be validated are simply skipped.

const Kit := preload("res://scripts/objectives/objective_kit.gd")

const ROUTES: Array[StringName] = [
	&"spawn_symbol", &"spawn_energy", &"spawn_summit", &"symbol_summit",
	&"energy_summit", &"summit_boss", &"energy_boss", &"viewpoint_spur",
]
## Module footprints (layout["footprints"]) are kept clear of decoration, plus margin.
const MODULE_KEYS: Array[StringName] = [&"symbol", &"energy", &"summit", &"boss"]
const PYLON_MAX_DIST := 35.0   # boss gate pylons must stay this close to the boss entrance
## Points kept clear of decoration: anchor -> radius.
const AVOID_RADIUS := {
	&"spawn": 4.0, &"foothill_checkpoint": 5.0, &"boss_checkpoint": 5.0, &"encounter_standard": 7.0,
	&"encounter_heavy": 7.0, &"encounter_ranged": 7.0, &"dock_start": 6.0, &"dock_end": 6.0,
}
const REQUIRED_ANCHORS: Array[StringName] = [&"spawn", &"symbol", &"energy", &"summit", &"boss", &"viewpoint", &"dock_start"]
const ROUTE_CLEARANCE := 7.5   # route half width is 5.5; keep landmarks and accents beyond it
const SIGN_RANGE := 45.0
const TITLE_RANGE := 70.0
const LORE_RANGE := 16.0

## name -> world-local position of everything placed (for inspection/tests).
var placed: Dictionary = {}

var _t: Node3D
var _anchors: Dictionary = {}
var _routes: Dictionary = {}          # StringName -> PackedVector3Array (raw, as returned by terrain)
var _keep: Array[Rect2] = []
var _avoid: Array[Vector3] = []       # (x, z, radius)
var _used: Array[Vector3] = []        # (x, z, radius)
var _m: Dictionary = {}
var _gate_pt := Vector3.ZERO             # layout boss_entrance (boss local z + 18)
var _limit := Vector3.ZERO            # (x, z, radius): when radius > 0, _ok rejects spots outside it


## Contract violations and unplaceable mandatory content (empty after a clean build).
var errors: Array[String] = []


## Returns true when the layout contract is satisfied and every mandatory landmark was placed.
func build(terrain: Node3D) -> bool:
	for c in get_children():
		c.queue_free()
	placed.clear()
	errors.clear()
	_used.clear()
	_keep.clear()
	_avoid.clear()
	_routes.clear()
	_t = terrain
	if is_inside_tree() and terrain.is_inside_tree():
		global_transform = terrain.global_transform
	else:
		transform = terrain.transform
	if not _load_layout():
		return false
	_make_materials()
	_landmark_pass()
	_accent_pass()
	return errors.is_empty()


# ---- Layout ----------------------------------------------------------------------------------------------------------
func _load_layout() -> bool:
	var src: Variant = _t.get("layout")
	_anchors.clear()
	if not (src is Dictionary) or not ((src as Dictionary).get("anchors") is Dictionary) or ((src as Dictionary)["anchors"] as Dictionary).is_empty():
		_fail("terrain.layout[\"anchors\"] hilang atau kosong (kontrak wajib)")
		return false
	var raw: Dictionary = (src as Dictionary)["anchors"]
	for k in raw:
		var v: Vector3 = raw[k]
		_anchors[StringName(k)] = Vector3(v.x, _t.height_at(v.x, v.z), v.z)
	for a: StringName in REQUIRED_ANCHORS:
		if not _anchors.has(a):
			_fail("terrain.layout tidak memiliki anchor '%s'" % a)
	for r in ROUTES:
		var pts: PackedVector3Array = _t.get_route_points(r)
		if pts.size() >= 2:
			_routes[r] = pts
		else:
			_fail("terrain.get_route_points('%s') kosong" % r)
	if not errors.is_empty():
		return false
	var fp: Variant = (src as Dictionary).get("footprints")
	for k: StringName in MODULE_KEYS:
		if fp is Dictionary and (fp as Dictionary).get(k) is Rect2:
			_keep.append((fp as Dictionary)[k])
		else:
			_fail("terrain.layout[\"footprints\"] tidak memiliki '%s' (kontrak wajib)" % k)
	var entrance: Variant = (src as Dictionary).get("boss_entrance")
	if not (entrance is Vector3):
		_fail("terrain.layout[\"boss_entrance\"] hilang (kontrak wajib)")
	else:
		_gate_pt = entrance
	if not errors.is_empty():
		return false
	for k: StringName in AVOID_RADIUS:
		if _anchors.has(k):
			var a: Vector3 = _anchors[k]
			_avoid.append(Vector3(a.x, a.z, AVOID_RADIUS[k]))
	return true


func _make_materials() -> void:
	_m = {
		"wood": Kit.material(Color(0.42, 0.28, 0.16)),
		"plank": Kit.material(Color(0.74, 0.58, 0.36)),
		"stone": Kit.material(Color(0.52, 0.52, 0.5)),
		"dark": Kit.material(Color(0.2, 0.2, 0.24)),
		"rock": Kit.material(Color(0.42, 0.44, 0.5)),
		"snow": Kit.material(Color(0.9, 0.93, 0.96)),
		"amber": Kit.material(Color(1.0, 0.7, 0.28), 1.6),
		"cyan": Kit.material(Color(0.3, 0.9, 1.0), 1.8),
		"red": Kit.material(Color(1.0, 0.25, 0.2), 1.6),
		"flag": Kit.material(Color(0.15, 0.7, 0.75)),
		"cloth": Kit.material(Color(0.6, 0.12, 0.12)),
	}
	var acc := Kit.material(Color.WHITE)
	acc.vertex_color_use_as_albedo = true
	_m["accent"] = acc


# ---- Geometry helpers ------------------------------------------------------------------------------------------------
func _node(parent: Node, node_name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


func _box(parent: Node, center: Vector3, size: Vector3, mat: String, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var inst := Kit.box_mesh(parent, "Box", center, size, _m[mat])
	inst.rotation_degrees = rot_deg
	return inst


func _cyl(parent: Node, center: Vector3, r_top: float, r_bot: float, h: float, mat: String, seg := 8, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = seg
	mesh.rings = 1
	var inst := MeshInstance3D.new()
	inst.name = "Cyl"
	inst.mesh = mesh
	inst.material_override = _m[mat]
	inst.position = center
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	return inst


func _label(parent: Node, text: String, pos: Vector3, size_px: int, pixel: float, color: Color, billboard: bool, view_range: float, outline := 10) -> Label3D:
	var lab := Kit.label(parent, text, pos, size_px, pixel, color, billboard)
	lab.outline_size = outline
	lab.double_sided = false
	lab.visibility_range_end = view_range
	lab.visibility_range_end_margin = 5.0
	lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return lab


func _light(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 35.0
	l.distance_fade_length = 15.0
	parent.add_child(l)


static func _yaw_facing(d: Vector3) -> float:
	return atan2(d.x, d.z)


# ---- Route / placement queries ---------------------------------------------------------------------------------------
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Route points ordered so that the last point is nearest to `target`. Empty when the route is not in the layout.
func _oriented(route: StringName, target: StringName) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if _routes.has(route):
		pts = _routes[route]
	else:
		return pts
	if _anchors.has(target):
		var tp: Vector3 = _anchors[target]
		if _flat(pts[0]).distance_to(_flat(tp)) < _flat(pts[pts.size() - 1]).distance_to(_flat(tp)):
			var rev := PackedVector3Array()
			for i in range(pts.size() - 1, -1, -1):
				rev.append(pts[i])
			pts = rev
	return pts


## Position and horizontal tangent at arc length `dist` from the start of `pts`.
func _sample(pts: PackedVector3Array, dist: float) -> Dictionary:
	var acc := 0.0
	for i in range(pts.size() - 1):
		var seg := _flat(pts[i + 1] - pts[i])
		var l := seg.length()
		if l < 0.001:
			continue
		if acc + l >= dist or i == pts.size() - 2:
			var f := clampf((dist - acc) / l, 0.0, 1.0)
			return {"pos": pts[i].lerp(pts[i + 1], f), "dir": seg / l}
		acc += l
	return {"pos": pts[0], "dir": Vector3.FORWARD}


## First point walking back from the module end that is outside every module footprint (+ margin).
func _approach(pts: PackedVector3Array, margin := 5.0) -> Dictionary:
	if pts.size() < 2:
		return {}
	var i := pts.size() - 1
	while i > 0 and _in_keep(pts[i], margin):
		i -= 1
	var j := mini(i + 1, pts.size() - 1)
	var d := _flat(pts[j] - pts[maxi(j - 1, 0)])
	if d.length() < 0.001:
		d = Vector3.FORWARD
	return {"pos": pts[i], "dir": d.normalized(), "i": i}


func _route_dir(pts: PackedVector3Array, from: Vector3, target: StringName, look := 18.0) -> Vector3:
	var best := 0
	var best_d := INF
	for i in pts.size():
		var d := _flat(pts[i]).distance_squared_to(_flat(from))
		if d < best_d:
			best_d = d
			best = i
	var acc := 0.0
	var idx := best
	while idx < pts.size() - 1 and acc < look:
		acc += _flat(pts[idx + 1] - pts[idx]).length()
		idx += 1
	var dir := _flat(pts[idx] - from) if pts.size() > 0 else Vector3.ZERO
	if dir.length() < 2.0 and _anchors.has(target):
		dir = _flat(_anchors[target] - from)
	return dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD


func _route_dist(p: Vector3) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for r: StringName in _routes:
		var pts: PackedVector3Array = _routes[r]
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var ab := Vector2(pts[i + 1].x, pts[i + 1].z) - a
			var l2 := ab.length_squared()
			var f := 0.0 if l2 < 0.0001 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
			best = minf(best, q.distance_to(a + ab * f))
	return best


func _in_keep(p: Vector3, margin: float) -> bool:
	for r in _keep:
		if r.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _ok(p: Vector3, radius: float, min_route := ROUTE_CLEARANCE) -> bool:
	var h: float = _t.height_at(p.x, p.z)
	if h < -0.15 or _in_keep(p, radius + 3.0) or not _in_limit(p):
		return false
	var lo := h
	var hi := h
	for k in 4:
		var a := k * PI * 0.5
		var near: float = _t.height_at(p.x + cos(a) * (radius + 1.0), p.z + sin(a) * (radius + 1.0))
		var far: float = _t.height_at(p.x + cos(a) * (radius + 6.0), p.z + sin(a) * (radius + 6.0))
		if far < -0.3:
			return false
		lo = minf(lo, near)
		hi = maxf(hi, near)
	if hi - lo > 1.3:
		return false
	for v in _avoid:
		if Vector2(v.x, v.y).distance_to(Vector2(p.x, p.z)) < v.z + radius:
			return false
	for v in _used:
		if Vector2(v.x, v.y).distance_to(Vector2(p.x, p.z)) < v.z + radius:
			return false
	if min_route > 0.0 and _route_dist(p) < min_route + radius * 0.5:
		return false
	return true


## Searches lateral offsets (both sides, nearest first) around `base`, with small shifts along `dir`.
## Returns the grounded position or null; reserves the spot on success.
func _spot(base: Vector3, dir: Vector3, radius: float, r0: float, r1: float, prefer := 1.0, min_route := ROUTE_CLEARANCE, wide := false) -> Variant:
	var side := Vector3.UP.cross(dir).normalized()
	var shifts: Array[float] = [0.0, -6.0, 6.0, -12.0, 12.0, -18.0, 18.0]
	if wide:
		shifts.append_array([-24.0, 24.0, -30.0, 30.0, -38.0, 38.0, -46.0, 46.0])
	for shift: float in shifts:
		var dist := r0
		while dist <= r1:
			for s: float in [prefer, -prefer]:
				var p := base + dir * shift + side * s * dist
				p.y = _t.height_at(p.x, p.z)
				if _ok(p, radius, min_route):
					_used.append(Vector3(p.x, p.z, radius))
					return p
			dist += 1.5
	return null


## Mandatory content: wider second search, then a reported failure (never silent).
func _spot_must(what: String, base: Vector3, dir: Vector3, radius: float, r0: float, r1: float, prefer := 1.0) -> Variant:
	var p: Variant = _spot(base, dir, radius, r0, r1, prefer)
	if p == null:
		p = _spot(base, dir, radius, r0, r1 + 12.0, prefer)
	if p == null:
		p = _spot(base, dir, radius, r0, r1 + 24.0, prefer, ROUTE_CLEARANCE, true)
	if p == null:
		_fail("%s: tidak ada titik aman di sisi rute (margin %.1f m)" % [what, ROUTE_CLEARANCE])
	return p


func _fail(msg: String) -> void:
	errors.append(msg)
	push_warning("island_landmarks: " + msg)


func _in_limit(p: Vector3) -> bool:
	return _limit.z <= 0.0 or Vector2(_limit.x, _limit.y).distance_to(Vector2(p.x, p.z)) <= _limit.z


## Decorative (non-colliding) gate at the boss entrance, just outside the boss footprint: pylons flank the route at
## +-x (local), widest first. Returns {pos, half} or {} when no ground is safe within PYLON_MAX_DIST.
func _boss_gate_fallback() -> Dictionary:
	for half: float in [12.0, 9.0, 7.0]:
		var c := Vector3(_gate_pt.x, 0.0, _gate_pt.z)
		c.y = _t.height_at(c.x, c.z)
		var good := true
		for sx: float in [-half, half]:
			var x: float = c.x + sx
			var h: float = _t.height_at(x, c.z)
			if h < -0.15 or _in_keep(Vector3(x, h, c.z), 0.0) or _t.height_at(x, c.z + 3.0) < -0.3:
				good = false
		if good and c.y >= -0.15:
			return {"pos": c, "half": half}
	return {}


func _reserve_free(p: Vector3, radius: float) -> void:
	_used.append(Vector3(p.x, p.z, radius))


# ---- Landmark pass ---------------------------------------------------------------------------------------------------
func _landmark_pass() -> void:
	if not _anchors.has(&"spawn"):
		return
	_spawn_group()
	_module_group(&"symbol", &"spawn_symbol", "totem", "Hutan Simbol",
		"Ukiran di tiang tua\nmengingat urutan batu.",
		[["Pilar Simbol", &"symbol", &"spawn_symbol"], ["Titik Pandang", &"viewpoint", &"viewpoint_spur"], ["Puncak", &"summit", &"symbol_summit"]])
	_module_group(&"energy", &"spawn_energy", "obelisk", "Dataran Reruntuhan",
		"Cahaya biru masih\nmengalir di batu ini.",
		[["Jalur Energi", &"energy", &"spawn_energy"], ["Puncak", &"summit", &"energy_summit"]])
	_module_group(&"summit", &"spawn_summit", "spire", "Dataran Tinggi",
		"Udara menipis.\nPuncak membuka jalan.",
		[["Puncak", &"summit", &"spawn_summit"], ["Gerbang Pulau", &"boss", &"summit_boss"]])
	_module_group(&"boss", &"energy_boss", "pylons", "Gerbang Pulau",
		"Penjaga gerbang\nmenunggu di dermaga.",
		[["Gerbang Pulau", &"boss", &"energy_boss"], ["Dermaga", &"dock_start", &"energy_boss"]])
	_viewpoint_group()


func _spawn_group() -> void:
	var pts := _oriented(&"spawn_summit", &"summit")
	if pts.size() < 2:
		_fail("Signpost_Spawn: rute spawn_summit tidak tersedia")
		return
	var s := _sample(pts, 12.0)
	var sign_pos: Variant = _spot_must("Signpost_Spawn", s["pos"], s["dir"], 1.5, 8.0, 12.0)
	if sign_pos != null:
		_signpost("Signpost_Spawn", sign_pos, [
			["Pilar Simbol", &"symbol", &"spawn_symbol"], ["Jalur Energi", &"energy", &"spawn_energy"],
			["Puncak", &"summit", &"spawn_summit"]])
	var gate_base: Dictionary = _sample(pts, 22.0)
	var gate_pos: Variant = _spot_must("Landmark_Gapura", gate_base["pos"], gate_base["dir"], 4.0, 12.0, 17.0, -1.0)
	if gate_pos != null:
		var root := _node(self, "Landmark_Gapura", gate_pos, _yaw_facing(-gate_base["dir"]))
		_gate(root, "Padang Rumput")
		placed["gapura"] = gate_pos
	var lore_pos: Variant = _spot_must("Lore_Spawn", s["pos"], s["dir"], 1.2, 9.0, 14.0, -1.0)
	if lore_pos != null:
		_placard("Lore_Spawn", lore_pos, -s["dir"], "Tiga kunci tersebar di pulau.\nIkuti papan penunjuk.")


func _module_group(module: StringName, route: StringName, kind: String, title: String, lore: String, entries: Array) -> void:
	if not _anchors.has(module):
		return
	var pts := _oriented(route, module)
	var ap := _approach(pts)
	if ap.is_empty():
		_fail("Landmark_%s: rute %s tidak tersedia" % [kind, route])
		return
	var pos: Vector3 = ap["pos"]
	var dir: Vector3 = ap["dir"]
	var face := -dir
	var is_gate := kind == "pylons"
	if is_gate:
		_limit = Vector3(_gate_pt.x, _gate_pt.z, PYLON_MAX_DIST)
	var lm_pos: Variant = _spot(pos, dir, 4.5, 10.0, 16.0)
	if lm_pos == null:
		lm_pos = _spot(pos, dir, 4.5, 10.0, 28.0)
	var back := 1
	while lm_pos == null and back <= 12:
		var bi := maxi(int(ap["i"]) - back * 3, 0)
		var bd := _flat(pts[mini(bi + 1, pts.size() - 1)] - pts[bi])
		if bd.length() > 0.001:
			lm_pos = _spot(pts[bi], bd.normalized(), 4.5, 10.0, 16.0)
		back += 1
	_limit = Vector3.ZERO
	var half := 3.0
	if lm_pos == null and is_gate:
		# Decorative gate at the boss entrance margin (just outside the footprint), pylons flanking the route.
		var g := _boss_gate_fallback()
		if not g.is_empty():
			lm_pos = g["pos"]
			half = g["half"]
			face = Vector3(0, 0, 1)
	if lm_pos == null and not is_gate:
		lm_pos = _spot_must("Landmark_" + kind, pos, dir, 4.5, 10.0, 16.0)
	if lm_pos == null:
		if is_gate:
			_fail("Landmark_pylons: tidak ada titik aman dalam %.0f m dari pintu boss" % PYLON_MAX_DIST)
	else:
		var root := _node(self, "Landmark_" + kind.capitalize(), lm_pos, _yaw_facing(face))
		match kind:
			"totem": _totem(root, title)
			"obelisk": _obelisk(root, title)
			"spire": _spire(root, title)
			"pylons": _pylons(root, title, half)
		placed[kind] = lm_pos
	var sign_pos: Variant = _spot_must("Signpost_" + String(module), pos, dir, 1.5, 8.0, 12.0, -1.0 if lm_pos != null and _side_of(pos, dir, lm_pos) > 0.0 else 1.0)
	if sign_pos != null:
		_signpost("Signpost_" + String(module), sign_pos, entries)
	var lore_pos: Variant = _spot_must("Lore_" + String(module), pos + dir * 8.0, dir, 1.2, 8.5, 13.0)
	if lore_pos != null:
		_placard("Lore_" + String(module), lore_pos, face, lore)


func _side_of(base: Vector3, dir: Vector3, p: Vector3) -> float:
	return Vector3.UP.cross(dir).dot(_flat(p - base))


func _viewpoint_group() -> void:
	if not _anchors.has(&"viewpoint"):
		return
	var a: Vector3 = _anchors[&"viewpoint"]
	var out := _flat(a)
	out = out.normalized() if out.length() > 1.0 else Vector3.RIGHT
	var side := Vector3.UP.cross(out).normalized()
	var flag_p := a + out * 3.2
	flag_p.y = _t.height_at(flag_p.x, flag_p.z)
	if _ok(flag_p, 0.6, 0.0):
		_reserve_free(flag_p, 0.6)
		var root := _node(self, "Landmark_Bendera", flag_p, _yaw_facing(out))
		_flagpole(root, "Titik Pandang")
		placed["bendera"] = flag_p
	else:
		_fail("Landmark_Bendera: tidak ada titik aman di viewpoint")
	var bench_p := a + side * 3.4
	bench_p.y = _t.height_at(bench_p.x, bench_p.z)
	if _ok(bench_p, 1.2, 0.0):
		_reserve_free(bench_p, 1.2)
		var bench := _node(self, "Bangku", bench_p, _yaw_facing(out))
		_box(bench, Vector3(0, 0.42, 0), Vector3(1.6, 0.12, 0.5), "wood")
		_box(bench, Vector3(-0.65, 0.2, 0), Vector3(0.12, 0.4, 0.4), "wood")
		_box(bench, Vector3(0.65, 0.2, 0), Vector3(0.12, 0.4, 0.4), "wood")
	var lore_p := a - side * 3.4
	lore_p.y = _t.height_at(lore_p.x, lore_p.z)
	if _ok(lore_p, 1.0, 0.0):
		_reserve_free(lore_p, 1.0)
		_placard("Lore_Viewpoint", lore_p, -out, "Dari tepi ini, seluruh\npulau terlihat.")


# ---- Landmark silhouettes --------------------------------------------------------------------------------------------
func _title(root: Node3D, text: String, y: float, color: Color) -> void:
	_label(root, text, Vector3(0, y, 0), 56, 0.008, color, true, TITLE_RANGE)


## Grassland: open wooden gate.
func _gate(root: Node3D, title: String) -> void:
	for sx: float in [-2.4, 2.4]:
		_box(root, Vector3(sx, 1.7, 0), Vector3(0.4, 3.6, 0.4), "wood")
		_box(root, Vector3(sx, 0.1, 0), Vector3(0.8, 0.3, 0.8), "stone")
	_box(root, Vector3(0, 3.55, 0), Vector3(5.8, 0.4, 0.45), "wood")
	_box(root, Vector3(0, 3.95, 0), Vector3(3.6, 0.3, 0.4), "wood", Vector3(0, 0, 0))
	_box(root, Vector3(-1.2, 3.3, 0), Vector3(0.12, 0.9, 0.12), "wood", Vector3(0, 0, 45))
	_box(root, Vector3(1.2, 3.3, 0), Vector3(0.12, 0.9, 0.12), "wood", Vector3(0, 0, -45))
	_box(root, Vector3(0, 2.75, 0), Vector3(0.9, 0.4, 0.06), "cloth")
	_title(root, title, 5.2, Color(0.95, 0.95, 0.75))


## Forest: stacked carved totem with glowing glyphs.
func _totem(root: Node3D, title: String) -> void:
	_box(root, Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 1.4), "stone")
	for i in 4:
		var y := 1.2 + i * 1.15
		var seg := _node(root, "Seg%d" % i, Vector3(0, y, 0), deg_to_rad(i * 24.0))
		_box(seg, Vector3.ZERO, Vector3(0.9 - i * 0.05, 1.05, 0.9 - i * 0.05), "wood")
		_box(seg, Vector3(0, 0, 0.46 - i * 0.025), Vector3(0.34, 0.34, 0.05), "amber")
	_box(root, Vector3(0, 5.9, 0), Vector3(2.6, 0.35, 0.5), "wood")
	_box(root, Vector3(0, 6.35, 0), Vector3(0.5, 0.6, 0.5), "wood", Vector3(0, 45, 0))
	_light(root, Vector3(0, 3.2, 1.4), Color(1.0, 0.72, 0.4), 0.6, 8.0)
	_title(root, title, 7.6, Color(1.0, 0.88, 0.6))


## Ruins plain: broken obelisk with a floating cap and energy rings.
func _obelisk(root: Node3D, title: String) -> void:
	_box(root, Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4), "stone", Vector3(0, 45, 0))
	_cyl(root, Vector3(0, 2.7, 0), 0.4, 0.95, 4.6, "stone", 4, Vector3(0, 45, 0))
	for y: float in [1.6, 2.6, 3.6]:
		var r := 0.95 - (y - 0.4) / 4.6 * 0.55 + 0.03
		_cyl(root, Vector3(0, y, 0), r, r, 0.07, "cyan", 4, Vector3(0, 45, 0))
	_cyl(root, Vector3(0, 6.0, 0), 0.0, 0.5, 1.1, "cyan", 4, Vector3(0, 45, 0))
	_cyl(root, Vector3(-2.2, 0.5, 1.4), 0.4, 0.55, 1.0, "stone", 4, Vector3(8, 20, 70))
	_box(root, Vector3(2.0, 0.3, -1.0), Vector3(1.2, 0.6, 0.9), "stone", Vector3(0, 30, 6))
	_light(root, Vector3(0, 4.4, 0), Color(0.4, 0.9, 1.0), 0.7, 9.0)
	_title(root, title, 7.6, Color(0.65, 0.95, 1.0))


## Rocky highlands: jagged rock spire with a snow tip.
func _spire(root: Node3D, title: String) -> void:
	var defs := [[Vector3(0, 0, 0), 1.7, 8.0, 3.0], [Vector3(2.0, 0, 0.8), 1.2, 5.2, -5.0], [Vector3(-1.8, 0, -0.6), 1.3, 4.4, 6.0], [Vector3(0.6, 0, -2.0), 0.9, 3.2, -8.0]]
	for d in defs:
		var p: Vector3 = d[0]
		var h: float = d[2]
		_cyl(root, p + Vector3(0, h * 0.5 - 0.4, 0), 0.0, d[1], h, "rock", 5, Vector3(0, 0, d[3]))
	_cyl(root, Vector3(0.18, 7.35, 0), 0.0, 0.42, 1.3, "snow", 5, Vector3(0, 0, 3.0))
	_title(root, title, 9.6, Color(0.85, 0.9, 1.0))


## Boss approach: twin dark pylons with red crowns and a hanging banner.
func _pylons(root: Node3D, title: String, half := 3.0) -> void:
	for sx: float in [-half, half]:
		_box(root, Vector3(sx, 0.4, 0), Vector3(1.8, 0.8, 1.8), "dark")
		_box(root, Vector3(sx, 3.2, 0), Vector3(1.0, 5.2, 1.0), "dark")
		_box(root, Vector3(sx, 5.95, 0), Vector3(1.4, 0.3, 1.4), "red")
		_box(root, Vector3(sx, 6.4, 0), Vector3(0.5, 0.6, 0.5), "red", Vector3(0, 45, 0))
		_light(root, Vector3(sx, 6.8, 0.6), Color(1.0, 0.3, 0.2), 0.8, 9.0)
	_box(root, Vector3(0, 5.2, 0), Vector3(1.6, 1.6, 0.06), "cloth")
	_box(root, Vector3(0, 6.1, 0), Vector3(half * 2.0 - 1.0, 0.12, 0.12), "wood")
	_title(root, title, 8.3, Color(1.0, 0.6, 0.5))


func _flagpole(root: Node3D, title: String) -> void:
	_cyl(root, Vector3(0, 2.4, 0), 0.07, 0.1, 4.8, "wood", 6)
	_box(root, Vector3(0.7, 4.2, 0), Vector3(1.4, 0.8, 0.04), "flag")
	_box(root, Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), "stone")
	_title(root, title, 5.6, Color(0.7, 1.0, 0.95))


# ---- Signposts and placards ------------------------------------------------------------------------------------------
## entries: [label, target anchor, route name]. Board directions come from the named route toward the target.
func _signpost(node_name: String, pos: Vector3, entries: Array) -> void:
	var root := _node(self, node_name, pos)
	_box(root, Vector3(0, 1.55, 0), Vector3(0.22, 3.3, 0.22), "wood")
	_box(root, Vector3(0, 0.12, 0), Vector3(0.8, 0.3, 0.8), "stone")
	var shown := 0
	for e in entries:
		var target: StringName = e[1]
		if not _anchors.has(target):
			_fail("%s: anchor target '%s' tidak ada" % [node_name, target])
			continue
		var pts := _oriented(e[2], target)
		var tp: Vector3 = _anchors[target]
		var d := _route_dir(pts, pos, target) if pts.size() >= 2 else _flat(tp - pos).normalized()
		var meters := int(round(_flat(tp - pos).length() / 5.0) * 5.0)
		var board := _node(root, "Board_" + String(target), Vector3(0, 2.95 - shown * 0.62, 0), atan2(-d.z, d.x))
		_box(board, Vector3(1.55, 0, 0), Vector3(2.9, 0.5, 0.07), "plank")
		_box(board, Vector3(3.05, 0, 0), Vector3(0.36, 0.36, 0.07), "plank", Vector3(0, 0, 45))
		var txt := "%s  %d m" % [e[0], meters]
		var ink := Color(0.14, 0.08, 0.03)
		var front := _label(board, txt + " >", Vector3(1.45, 0, 0.045), 36, 0.0055, ink, false, SIGN_RANGE, 0)
		front.double_sided = false
		var back := _label(board, "< " + txt, Vector3(1.65, 0, -0.045), 36, 0.0055, ink, false, SIGN_RANGE, 0)
		back.rotation.y = PI
		shown += 1
	placed[node_name] = pos


func _placard(node_name: String, pos: Vector3, face: Vector3, text: String) -> void:
	var root := _node(self, node_name, pos, _yaw_facing(face))
	_box(root, Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), "wood")
	var board := _node(root, "Board", Vector3(0, 1.2, 0.04))
	board.rotation_degrees.x = -18.0
	_box(board, Vector3.ZERO, Vector3(1.7, 0.75, 0.06), "plank")
	_label(board, text, Vector3(0, 0, 0.04), 30, 0.0045, Color(0.14, 0.08, 0.03), false, LORE_RANGE, 0)
	placed[node_name] = pos


# ---- Route accents ---------------------------------------------------------------------------------------------------
func _biome_tint(p: Vector3) -> Color:
	var b: StringName = _t.biome_at(p.x, p.z) if _t.has_method("biome_at") else &""
	match b:
		&"grassland": return Color(0.58, 0.6, 0.46)
		&"forest": return Color(0.42, 0.5, 0.42)
		&"ruins_plain": return Color(0.66, 0.6, 0.5)
		&"rocky_highlands": return Color(0.5, 0.52, 0.58)
		&"beach": return Color(0.76, 0.7, 0.56)
	return Color(0.55, 0.55, 0.52)


## Small non-colliding waypoint stones and glowing poles beside the routes, alternating sides.
func _accent_pass() -> void:
	var stones: Array[Transform3D] = []
	var stone_cols: Array[Color] = []
	var poles: Array[Transform3D] = []
	var n := 0
	for r: StringName in ROUTES:
		if not _routes.has(r):
			continue
		var pts: PackedVector3Array = _routes[r]
		var total := 0.0
		for i in range(pts.size() - 1):
			total += _flat(pts[i + 1] - pts[i]).length()
		var dist := 16.0
		var flip := 1.0
		while dist < total - 12.0:
			var s := _sample(pts, dist)
			var dir: Vector3 = s["dir"]
			var side := Vector3.UP.cross(dir).normalized()
			var p: Vector3 = s["pos"] + side * flip * (ROUTE_CLEARANCE + 1.3)
			p.y = _t.height_at(p.x, p.z)
			if _ok(p, 0.6):
				_reserve_free(p, 0.6)
				var yaw := float(n * 53 % 360) * PI / 180.0
				if n % 2 == 0:
					stones.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.3, 0)))
					stone_cols.append(_biome_tint(p))
				else:
					poles.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.6, 0)))
				n += 1
			flip = -flip
			dist += 22.0
	_multimesh("AccentStones", _make_box(Vector3(0.55, 0.7, 0.45)), _m["accent"], stones, stone_cols)
	var pole_cols: Array[Color] = []
	for _i in poles.size():
		pole_cols.append(Color(0.45, 0.3, 0.18))
	_multimesh("AccentPoles", _make_cyl(0.07, 1.3), _m["accent"], poles, pole_cols)
	var caps: Array[Transform3D] = []
	var cap_cols: Array[Color] = []
	for t in poles:
		caps.append(Transform3D(t.basis, t.origin + Vector3(0, 0.75, 0)))
		cap_cols.append(Color(1.0, 0.75, 0.35))
	_multimesh("AccentCaps", _make_box(Vector3(0.2, 0.2, 0.2)), _m["amber"], caps, cap_cols)


func _make_box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _make_cyl(radius: float, h: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.2
	mesh.height = h
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


func _multimesh(node_name: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = mat
	inst.visibility_range_end = 90.0
	inst.visibility_range_end_margin = 10.0
	add_child(inst)
