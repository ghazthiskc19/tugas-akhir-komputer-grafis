extends RefCounted
## Single source of truth for where everything on the island sits: objective modules, spawn/camp, checkpoints,
## potions, enemy packs, pads, route control points, dock and biome centres.
##
## `baseline()` is the fixed layout (the accepted coordinates, also the proven fallback). `generate(seed)` builds a
## seed-dependent layout by bounded rejection sampling; it returns {} when no attempt passed (caller retries with another
## seed or falls back to baseline). Layouts are plain Dictionaries so consumers never read coordinate constants:
##   procedural: bool, seed: int
##   anchors: Dictionary StringName -> Vector3 (y = 0): spawn symbol energy summit boss dock_start dock_end
##            foothill_checkpoint boss_checkpoint viewpoint + one anchor per encounter pad
##   encounters: Array[{id: StringName, archetype: "standard"|"heavy"|"ranged", position: Vector3, pad: StringName}]
##   potions: Array[{id: StringName, position: Vector3}]      camp: Vector3
##   pads: StringName -> [center Vector2, radius_x, radius_z, blend, coast_margin, (&"rect")]
##   routes: StringName -> Array of [Vector2 control, fixed: bool]      edges: [[from, to, route], ...]
##   enc_pads: Array[StringName] (anchor == pad name), enc_dirs: StringName -> Vector2 (route tangent at the pad)
##   footprints: StringName -> Rect2 (module AABBs: symbol energy summit boss), biome_centers: StringName -> Vector2
##   summit_exit: Vector3 (summit local x 1.5 z -24), boss_entrance: Vector3 (boss local z +18)
##   swapped: bool (symbol on the east, energy on the west; modules are never mirrored, only their world slots swap)
## foothill_checkpoint / boss_checkpoint anchors equal the module-authored checkpoints: summit local (-4, 18) and boss
## local (-10, 12.5) (summit_route.gd `_build_foot`, gatekeeper_encounter.gd `_build_checkpoint`); modules are unrotated.
## Objective modules are axis aligned; the dock always leaves the boss pad toward -Z.

const OBJECTIVE_ANCHORS := {
	&"spawn": Vector3(0, 0, 85),
	&"symbol": Vector3(-65, 0, 0),
	&"energy": Vector3(60, 0, 0),
	&"summit": Vector3(0, 0, -50),
	&"boss": Vector3(0, 0, -100),
}
## [center(x,z), radius_x, radius_z, blend_width, coast_margin]; rect pads are flat out to the module AABB + 2 m.
const PAD_DEFS := {
	&"spawn": [Vector2(0, 85), 15.0, 15.0, 14.0, 14.0],
	&"symbol": [Vector2(-65, 0), 26.0, 26.0, 16.0, 14.0],
	&"energy": [Vector2(60, 0), 26.0, 26.0, 16.0, 14.0],
	&"summit": [Vector2(0, -50), 30.0, 26.0, 14.0, 14.0, &"rect"],
	&"boss": [Vector2(0, -97.5), 23.5, 22.0, 5.0, 0.0, &"rect"],
	&"encounter_standard": [Vector2(0, 48), 10.0, 10.0, 12.0, 12.0],
	&"encounter_heavy": [Vector2(0, 25), 10.0, 10.0, 12.0, 12.0],
	&"encounter_ranged": [Vector2(0, 5), 10.0, 10.0, 12.0, 12.0],
	&"foothill_checkpoint": [Vector2(-4, -32), 6.0, 6.0, 8.0, 12.0],
	&"boss_checkpoint": [Vector2(-10, -87.5), 5.0, 5.0, 6.0, 8.0],
	&"viewpoint": [Vector2(-84, -42), 6.0, 6.0, 10.0, 12.0],
}
## Ordered control points; `true` = fixed (never jittered by the terrain). Walkable, no jump gaps.
const ROUTE_DEFS := {
	&"spawn_symbol": [[Vector2(0, 85), true], [Vector2(-30, 62), false], [Vector2(-58, 30), false], [Vector2(-65, 0), true]],
	&"spawn_energy": [[Vector2(0, 85), true], [Vector2(30, 62), false], [Vector2(56, 30), false], [Vector2(60, 0), true]],
	&"spawn_summit": [[Vector2(0, 85), true], [Vector2(0, 48), true], [Vector2(0, 25), true], [Vector2(0, 5), true], [Vector2(0, -21), true], [Vector2(0, -50), true]],
	&"symbol_summit": [[Vector2(-65, 0), true], [Vector2(-60, -26), false], [Vector2(-38, -46), false], [Vector2(0, -50), true]],
	&"energy_summit": [[Vector2(60, 0), true], [Vector2(52, -28), false], [Vector2(36, -46), false], [Vector2(0, -50), true]],
	&"summit_boss": [[Vector2(1.5, -50), true], [Vector2(1.5, -62), true], [Vector2(1.5, -74), true], [Vector2(1.5, -80), true], [Vector2(0, -100), true]],
	&"energy_boss": [[Vector2(60, 0), true], [Vector2(70, -40), false], [Vector2(50, -82), false], [Vector2(26, -98), false], [Vector2(0, -100), true]],
	&"viewpoint_spur": [[Vector2(-65, 0), true], [Vector2(-80, -20), false], [Vector2(-84, -42), true]],
}
const ROUTE_GRAPH_EDGES := [
	[&"spawn", &"symbol", &"spawn_symbol"], [&"spawn", &"energy", &"spawn_energy"],
	[&"spawn", &"summit", &"spawn_summit"], [&"symbol", &"summit", &"symbol_summit"],
	[&"energy", &"summit", &"energy_summit"], [&"summit", &"boss", &"summit_boss"],
	[&"energy", &"boss", &"energy_boss"], [&"symbol", &"viewpoint", &"viewpoint_spur"],
]
const EXTRA_ANCHORS := {
	&"foothill_checkpoint": Vector3(-4, 0, -32),
	&"boss_checkpoint": Vector3(-10, 0, -87.5),
	&"encounter_standard": Vector3(0, 0, 48),
	&"encounter_heavy": Vector3(0, 0, 25),
	&"encounter_ranged": Vector3(0, 0, 5),
	&"viewpoint": Vector3(-84, 0, -42),
	&"dock_start": Vector3(0, 0, -106),
	&"dock_end": Vector3(0, 0, -122),
}
const SUMMIT_FOOT_LOCAL := Vector2(-4.0, 18.0)
const BOSS_CHECKPOINT_LOCAL := Vector2(-10.0, 12.5)
const SUMMIT_FOOTPRINT := Rect2(-28.0, -74.0, 56.0, 48.0)
const BOSS_FOOTPRINT := Rect2(-21.0, -117.0, 42.0, 34.0)
const SYMBOL_HALF := Vector2(12.0, 12.0)
const ENERGY_HALF := Vector2(9.0, 7.0)
const ENCOUNTER_PADS: Array[StringName] = [&"encounter_standard", &"encounter_heavy", &"encounter_ranged", &"encounter_4", &"encounter_5"]
const ENCOUNTER_PAD_RADIUS := 10.0

## Per pack: [member id suffix, archetype, local offset]; all offsets stay inside the 10 m flat encounter pad.
const PACKS := [
	[["guard", "standard", Vector2(0, 0)], ["flanker", "standard", Vector2(-4, -2)], ["archer", "ranged", Vector2(4, -5)]],
	[["heavy", "heavy", Vector2(0, 0)], ["flanker", "standard", Vector2(4, 2)], ["archer", "ranged", Vector2(-4, -2)]],
	[["ranged", "ranged", Vector2(0, 0)], ["guard", "standard", Vector2(-4, 3)], ["flanker", "standard", Vector2(4, -2)]],
	[["heavy", "heavy", Vector2(0, 0)], ["archer", "ranged", Vector2(-4, 3)], ["guard", "standard", Vector2(4, -2)]],
	[["guard", "standard", Vector2(0, 0)], ["archer", "ranged", Vector2(4, 3)], ["archer_b", "ranged", Vector2(-4, -2)]],
]
const BASELINE_ENCOUNTERS := [
	[&"grassland_guard", "standard", Vector3(0, 0, 48), &"encounter_standard"],
	[&"grassland_flanker", "standard", Vector3(-4, 0, 46), &"encounter_standard"],
	[&"grassland_archer", "ranged", Vector3(4, 0, 43), &"encounter_standard"],
	[&"grassland_heavy", "heavy", Vector3(0, 0, 25), &"encounter_heavy"],
	[&"midland_flanker", "standard", Vector3(4, 0, 27), &"encounter_heavy"],
	[&"midland_archer", "ranged", Vector3(-4, 0, 23), &"encounter_heavy"],
	[&"crossroads_ranged", "ranged", Vector3(0, 0, 5), &"encounter_ranged"],
	[&"crossroads_guard", "standard", Vector3(-4, 0, 8), &"encounter_ranged"],
	[&"crossroads_flanker", "standard", Vector3(4, 0, 3), &"encounter_ranged"],
]
const BASELINE_POTIONS := [Vector3(3, 0, 83), Vector3(-48, 0, 0), Vector3(44, 0, 0)]
const BASELINE_CAMP := Vector3(-3, 0, 83)


# ---- Geometry helpers (shared with the terrain) --------------------------------------------------------------------
## Signed distance (m) from (x, z) to a pad's flat edge; negative inside.
static func pad_dist(d: Array, x: float, z: float) -> float:
	var c: Vector2 = d[0]
	if d.size() > 5:  # axis-aligned rectangle, d[1]/d[2] are half extents (exact signed distance)
		var q := Vector2(absf(x - c.x) - float(d[1]), absf(z - c.y) - float(d[2]))
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	var dn := Vector2((x - c.x) / float(d[1]), (z - c.y) / float(d[2])).length()
	return (dn - 1.0) * minf(float(d[1]), float(d[2]))


static func rect_gap(a: Rect2, b: Rect2) -> float:
	var gx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var gz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(gx, gz).length()


static func catmull(pts: Array) -> PackedVector2Array:
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


# ---- Fixed layout ---------------------------------------------------------------------------------------------------
static func baseline() -> Dictionary:
	var anchors := {}
	for name: StringName in OBJECTIVE_ANCHORS:
		anchors[name] = OBJECTIVE_ANCHORS[name]
	for name: StringName in EXTRA_ANCHORS:
		anchors[name] = EXTRA_ANCHORS[name]
	var encounters: Array = []
	for e in BASELINE_ENCOUNTERS:
		encounters.append({"id": e[0], "archetype": e[1], "position": e[2], "pad": e[3]})
	var potions: Array = []
	for i in BASELINE_POTIONS.size():
		potions.append({"id": StringName("island_potion_%d" % i), "position": BASELINE_POTIONS[i]})
	var enc_pads: Array[StringName] = [&"encounter_standard", &"encounter_heavy", &"encounter_ranged"]
	var enc_dirs := {}
	for p in enc_pads:
		enc_dirs[p] = Vector2(0, 1)
	return {
		"procedural": false, "seed": 0, "swapped": false, "anchors": anchors, "encounters": encounters, "potions": potions,
		"camp": BASELINE_CAMP, "pads": PAD_DEFS.duplicate(true), "routes": ROUTE_DEFS.duplicate(true),
		"edges": ROUTE_GRAPH_EDGES.duplicate(true), "enc_pads": enc_pads, "enc_dirs": enc_dirs,
		"footprints": {
			&"symbol": Rect2(-65.0 - SYMBOL_HALF.x, -SYMBOL_HALF.y, SYMBOL_HALF.x * 2.0, SYMBOL_HALF.y * 2.0),
			&"energy": Rect2(60.0 - ENERGY_HALF.x, -ENERGY_HALF.y, ENERGY_HALF.x * 2.0, ENERGY_HALF.y * 2.0),
			&"summit": SUMMIT_FOOTPRINT, &"boss": BOSS_FOOTPRINT,
		},
		"biome_centers": {
			&"grassland": Vector2(0, 70), &"forest": Vector2(-70, 10), &"ruins_plain": Vector2(68, 5), &"rocky_highlands": Vector2(0, -75),
		},
		"summit_exit": Vector3(1.5, 0, -74), "boss_entrance": Vector3(0, 0, -82),
	}


# ---- Seeded layout --------------------------------------------------------------------------------------------------
## Whether a seed puts the symbol puzzle on the east and the energy puzzle on the west (decided once per seed, not per attempt).
static func seed_swaps_sides(seed_value: int) -> bool:
	var side_rng := RandomNumberGenerator.new()
	side_rng.seed = seed_value ^ 0x5DE5A1D
	return side_rng.randi() % 2 == 1


## Deterministic for a seed and side. `swapped` comes from the caller (see `seed_swaps_sides`) so retries keep the same side.
## Returns {} if the bounded sampling found no layout that passes `strict_errors`.
static func generate(seed_value: int, swapped: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt in 64:
		var l := _try_generate(rng, swapped)
		if l.is_empty():
			continue
		l["procedural"] = true
		l["seed"] = seed_value
		l["sampling_attempts"] = attempt + 1
		if validate(l).is_empty():
			return l
	return {}


static func _rect_pad(center: Vector2, half: Vector2, blend: float, coast: float) -> Array:
	return [center, half.x, half.y, blend, coast, &"rect"]


static func _line_ctrl(a: Vector2, b: Vector2, f: float, lateral: float) -> Vector2:
	var d := (b - a).normalized()
	return a.lerp(b, f) + Vector2(-d.y, d.x) * lateral


static func _spacing_ok(pts: Array, min_d: float) -> bool:
	for i in pts.size() - 1:
		if (pts[i] as Vector2).distance_to(pts[i + 1]) < min_d:
			return false
	return true


static func _fix(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append([p, true])
	return out


## `swapped`: symbol on the east / energy on the west. Module-local axes are never mirrored; only world slots and routes move.
static func _try_generate(rng: RandomNumberGenerator, swapped: bool) -> Dictionary:
	var sym_side := 1.0 if swapped else -1.0  # world x sign of the symbol puzzle; the energy puzzle takes the opposite side
	var spawn := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(80.0, 88.0))
	var summit := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-50.0, -38.0))
	var boss := Vector2(clampf(summit.x + rng.randf_range(-12.0, 12.0), -24.0, 24.0), rng.randf_range(-101.5, -98.5))
	var symbol := Vector2(sym_side * rng.randf_range(60.0, 78.0), rng.randf_range(-22.0, 22.0))
	var energy := Vector2(-sym_side * rng.randf_range(60.0, 78.0), rng.randf_range(-22.0, 22.0))
	var summit_fp := Rect2(summit.x - 28.0, summit.y - 24.0, 56.0, 48.0)
	var boss_fp := Rect2(boss.x - 21.0, boss.y - 17.0, 42.0, 34.0)
	if rect_gap(summit_fp, boss_fp) < 10.0:
		return {}
	var pads := {
		&"spawn": [spawn, 15.0, 15.0, 14.0, 14.0],
		&"symbol": [symbol, 26.0, 26.0, 16.0, 14.0],
		&"energy": [energy, 26.0, 26.0, 16.0, 14.0],
		&"summit": _rect_pad(summit, Vector2(30.0, 26.0), 14.0, 14.0),
		&"boss": _rect_pad(boss + Vector2(0, 2.5), Vector2(23.5, 22.0), 5.0, 0.0),
	}
	# Module pads keep a clear gap (summit/boss may touch by design: their footprints are already 10 m apart).
	var modules: Array[StringName] = [&"spawn", &"symbol", &"energy"]
	for m in modules:
		for o: StringName in [&"summit", &"boss", &"spawn", &"symbol", &"energy"]:
			if o == m:
				continue
			var d: Array = pads[o]
			var other: Array = pads[m]
			# circle pad vs any pad: centre distance to the other pad's edge minus this pad's radius
			if pad_dist(d, (other[0] as Vector2).x, (other[0] as Vector2).y) < float(other[1]) + 6.0:
				return {}
	# Viewpoint: coastal spur out of the symbol pad, toward the outer coast on the symbol's side.
	var view := Vector2(sym_side * rng.randf_range(76.0, 88.0), rng.randf_range(-62.0, -30.0))
	var view_dist := view.distance_to(symbol)
	if view_dist < 40.0 or view_dist > 64.0:
		return {}
	pads[&"viewpoint"] = [view, 6.0, 6.0, 10.0, 12.0]
	# Checkpoints sit exactly on the module-authored shrines (modules are unrotated, origin = anchor).
	var boss_cp := boss + BOSS_CHECKPOINT_LOCAL
	pads[&"boss_checkpoint"] = [boss_cp, 5.0, 5.0, 6.0, 8.0]
	# Main route spawn -> foothill lane -> summit with three encounter pads on fixed control points.
	var fore := summit + SUMMIT_FOOT_LOCAL
	var lane := summit + Vector2(1.5, SUMMIT_FOOT_LOCAL.y)
	pads[&"foothill_checkpoint"] = [fore, 6.0, 6.0, 8.0, 12.0]
	var main_ctrl: Array[Vector2] = [spawn]
	for f in [rng.randf_range(0.34, 0.38), rng.randf_range(0.55, 0.59), rng.randf_range(0.74, 0.78)]:
		main_ctrl.append(_line_ctrl(spawn, lane, f, rng.randf_range(-10.0, 10.0)))
	main_ctrl.append(lane)
	main_ctrl.append(summit)
	if not _spacing_ok(main_ctrl, 18.0):
		return {}
	var group_count := 3 + rng.randi() % 3
	var enc_pads: Array[StringName] = []
	var enc_pos: Array[Vector2] = []
	var enc_dirs := {}
	for i in 3:
		enc_pads.append(ENCOUNTER_PADS[i])
		enc_pos.append(main_ctrl[i + 1])
		enc_dirs[ENCOUNTER_PADS[i]] = (main_ctrl[i + 2] - main_ctrl[i]).normalized()
	# Side routes from the spawn; the optional 4th/5th pack sits on the first control of each.
	var sym_a := _line_ctrl(spawn, symbol, rng.randf_range(0.42, 0.48), rng.randf_range(-8.0, 8.0))
	var sym_b := _line_ctrl(spawn, symbol, rng.randf_range(0.74, 0.82), rng.randf_range(-8.0, 8.0))
	var en_a := _line_ctrl(spawn, energy, rng.randf_range(0.42, 0.48), rng.randf_range(-8.0, 8.0))
	var en_b := _line_ctrl(spawn, energy, rng.randf_range(0.74, 0.82), rng.randf_range(-8.0, 8.0))
	var sym_ctrl: Array = [spawn, sym_a, sym_b, symbol]
	var en_ctrl: Array = [spawn, en_a, en_b, energy]
	if not _spacing_ok(sym_ctrl, 18.0) or not _spacing_ok(en_ctrl, 18.0):
		return {}
	if group_count >= 4:
		enc_pads.append(ENCOUNTER_PADS[3])
		enc_pos.append(sym_a)
		enc_dirs[ENCOUNTER_PADS[3]] = (sym_b - spawn).normalized()
	if group_count >= 5:
		enc_pads.append(ENCOUNTER_PADS[4])
		enc_pos.append(en_a)
		enc_dirs[ENCOUNTER_PADS[4]] = (en_b - spawn).normalized()
	for i in enc_pads.size():
		pads[enc_pads[i]] = [enc_pos[i], ENCOUNTER_PAD_RADIUS, ENCOUNTER_PAD_RADIUS, 12.0, 12.0]
	# Summit approaches: the symbol/energy routes arrive on the summit side facing their (possibly swapped) puzzle.
	var arrive_sym := summit + Vector2(sym_side * 38.0 + rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 6.0))
	var arrive_en := summit + Vector2(-sym_side * 36.0 + rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 6.0))
	var sym_sum: Array = [symbol, _line_ctrl(symbol, arrive_sym, rng.randf_range(0.45, 0.55), rng.randf_range(-9.0, 9.0)), arrive_sym, summit]
	var en_sum: Array = [energy, _line_ctrl(energy, arrive_en, rng.randf_range(0.45, 0.55), rng.randf_range(-9.0, 9.0)), arrive_en, summit]
	var view_mid := _line_ctrl(symbol, view, 0.5, rng.randf_range(-6.0, 6.0))
	var view_ctrl: Array = [symbol, view_mid, view]
	var summit_exit := summit + Vector2(1.5, -24.0)
	var boss_entry := boss + Vector2(0.0, 18.0)
	var sb_ctrl: Array = [summit + Vector2(1.5, 0.0), summit + Vector2(1.5, -12.0), summit_exit, summit + Vector2(1.5, -30.0)]
	if (sb_ctrl[3] as Vector2).y - boss_entry.y >= 6.0:
		sb_ctrl.append(boss_entry)
	sb_ctrl.append(boss)
	var en_side := -sym_side
	var eb_ctrl: Array = [energy,
		Vector2(energy.x + en_side * rng.randf_range(4.0, 12.0), lerpf(energy.y, boss.y, rng.randf_range(0.36, 0.44))),
		Vector2(boss.x + en_side * rng.randf_range(40.0, 52.0), boss.y + rng.randf_range(14.0, 22.0)),
		boss + Vector2(en_side * rng.randf_range(24.0, 28.0), rng.randf_range(0.0, 4.0)), boss]
	if not _spacing_ok(sym_sum, 14.0) or not _spacing_ok(en_sum, 14.0) or not _spacing_ok(eb_ctrl, 14.0) or not _spacing_ok(view_ctrl, 14.0):
		return {}
	var routes := {
		&"spawn_symbol": _fix(sym_ctrl), &"spawn_energy": _fix(en_ctrl), &"spawn_summit": _fix(main_ctrl.slice(0, main_ctrl.size())),
		&"symbol_summit": _fix(sym_sum), &"energy_summit": _fix(en_sum), &"summit_boss": _fix(sb_ctrl),
		&"energy_boss": _fix(eb_ctrl), &"viewpoint_spur": _fix(view_ctrl),
	}
	var anchors := {
		&"spawn": _v3(spawn), &"symbol": _v3(symbol), &"energy": _v3(energy), &"summit": _v3(summit), &"boss": _v3(boss),
		&"dock_start": _v3(boss + Vector2(0, -6)), &"dock_end": _v3(boss + Vector2(0, -22)),
		&"foothill_checkpoint": _v3(fore), &"boss_checkpoint": _v3(boss_cp), &"viewpoint": _v3(view),
	}
	for i in enc_pads.size():
		anchors[enc_pads[i]] = _v3(enc_pos[i])
	var encounters: Array = []
	for g in enc_pads.size():
		for m in PACKS[g]:
			var off: Vector2 = m[2]
			encounters.append({
				"id": StringName("pack%d_%s" % [g, m[0]]), "archetype": m[1],
				"position": _v3(enc_pos[g] + off), "pad": enc_pads[g],
			})
	var potions: Array = [
		{"id": &"island_potion_0", "position": _v3(spawn + Vector2(3, -2))},
		{"id": &"island_potion_1", "position": _v3(symbol + Vector2(-sym_side * 17.0, rng.randf_range(-3.0, 3.0)))},
		{"id": &"island_potion_2", "position": _v3(energy + Vector2(sym_side * 16.0, rng.randf_range(-3.0, 3.0)))},
	]
	var l := {
		"swapped": swapped, "anchors": anchors, "encounters": encounters, "potions": potions, "camp": _v3(spawn + Vector2(-3, -2)),
		"pads": pads, "routes": routes, "edges": ROUTE_GRAPH_EDGES.duplicate(true), "enc_pads": enc_pads, "enc_dirs": enc_dirs,
		"footprints": {
			&"symbol": Rect2(symbol - SYMBOL_HALF, SYMBOL_HALF * 2.0), &"energy": Rect2(energy - ENERGY_HALF, ENERGY_HALF * 2.0),
			&"summit": summit_fp, &"boss": boss_fp,
		},
		"biome_centers": {
			&"grassland": spawn + Vector2(0, -15), &"forest": symbol + Vector2(sym_side * 5.0, 10), &"ruins_plain": energy + Vector2(-sym_side * 8.0, 5),
			&"rocky_highlands": (summit + boss) * 0.5,
		},
		"summit_exit": _v3(summit_exit), "boss_entrance": _v3(boss_entry),
	}
	return l if _strict_errors(l).is_empty() else {}


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


## Sampling-only margins (stricter than `validate`, which the fixed layout also satisfies).
static func _strict_errors(l: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var pads: Dictionary = l["pads"]
	var enc_pads: Array = l["enc_pads"]
	var enc_pad_set := {}
	for p in enc_pads:
		enc_pad_set[p] = true
	# Encounter pads: gap to every other pad (module pads 8 m, others 6 m) and to each other (centres 30 m).
	for e: StringName in enc_pads:
		var c: Vector2 = (pads[e] as Array)[0]
		for o: StringName in pads:
			if o == e:
				continue
			var gap := 6.0 if o == &"spawn" else (8.0 if (o == &"symbol" or o == &"energy" or o == &"summit" or o == &"boss") else 4.0)
			if enc_pad_set.has(o):
				if c.distance_to((pads[o] as Array)[0]) < 20.0:
					errors.append("encounter pads %s/%s too close" % [e, o])
			elif pad_dist(pads[o], c.x, c.y) < ENCOUNTER_PAD_RADIUS + gap:
				errors.append("encounter pad %s too close to %s" % [e, o])
	# Small pads (checkpoints, viewpoint) clear of the module pads other than their own parent.
	for s: StringName in [&"viewpoint", &"boss_checkpoint", &"foothill_checkpoint"]:
		var sd: Array = pads[s]
		var sc: Vector2 = sd[0]
		for o: StringName in [&"spawn", &"symbol", &"energy", &"summit", &"boss"]:
			if (s == &"viewpoint" and o == &"symbol") or (s == &"boss_checkpoint" and o == &"boss") or (s == &"foothill_checkpoint" and o == &"summit"):
				continue
			if pad_dist(pads[o], sc.x, sc.y) < float(sd[1]) + 6.0:
				errors.append("%s too close to pad %s" % [s, o])
	# Routes keep 6 m from every pad they do not own (endpoints, their own encounter/checkpoint pads).
	var own := {}
	for e: Array in l["edges"]:
		own[e[2]] = {e[0]: true, e[1]: true}
		if e[0] == &"boss" or e[1] == &"boss":
			own[e[2]][&"boss_checkpoint"] = true
	for i in enc_pads.size():
		var rname: StringName = &"spawn_summit" if i < 3 else (&"spawn_symbol" if i == 3 else &"spawn_energy")
		own[rname][enc_pads[i]] = true
	own[&"spawn_summit"][&"foothill_checkpoint"] = true
	var routes: Dictionary = l["routes"]
	for r: StringName in routes:
		var ctrl: Array = []
		for c in routes[r]:
			ctrl.append(c[0])
		var line := catmull(ctrl)
		for o: StringName in pads:
			if own[r].has(o):
				continue
			var d: Array = pads[o]
			for p in line:
				if pad_dist(d, p.x, p.y) < 6.0:
					errors.append("route %s passes through pad %s" % [r, o])
					break
	return errors


## Invariants every layout (fixed or seeded) must satisfy. Empty array = valid.
static func validate(l: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["anchors", "encounters", "potions", "camp", "pads", "routes", "edges", "enc_pads", "footprints", "biome_centers"]:
		if not l.has(key):
			errors.append("layout missing %s" % key)
	if not errors.is_empty():
		return errors
	var anchors: Dictionary = l["anchors"]
	var pads: Dictionary = l["pads"]
	for name: StringName in [&"spawn", &"symbol", &"energy", &"summit", &"boss", &"dock_start", &"dock_end", &"foothill_checkpoint", &"boss_checkpoint", &"viewpoint"]:
		if not anchors.has(name):
			errors.append("missing anchor %s" % name)
	if not errors.is_empty():
		return errors
	for name: StringName in anchors:
		var a: Vector3 = anchors[name]
		if absf(a.x) > 100.0 or absf(a.z) > 124.0:
			errors.append("anchor %s out of bounds %s" % [name, a])
	# Checkpoint anchors are the authored module-local shrine offsets; side routes follow the actual puzzle sides.
	var su: Vector3 = anchors[&"summit"]
	var bo: Vector3 = anchors[&"boss"]
	var fc: Vector3 = anchors[&"foothill_checkpoint"]
	var bc: Vector3 = anchors[&"boss_checkpoint"]
	if not (is_equal_approx(fc.x, su.x + SUMMIT_FOOT_LOCAL.x) and is_equal_approx(fc.z, su.z + SUMMIT_FOOT_LOCAL.y)):
		errors.append("foothill_checkpoint %s is not the summit module's authored checkpoint" % fc)
	if not (is_equal_approx(bc.x, bo.x + BOSS_CHECKPOINT_LOCAL.x) and is_equal_approx(bc.z, bo.z + BOSS_CHECKPOINT_LOCAL.y)):
		errors.append("boss_checkpoint %s is not the boss arena's authored checkpoint" % bc)
	var sy: Vector3 = anchors[&"symbol"]
	var ep: Vector3 = anchors[&"energy"]
	var vp: Vector3 = anchors[&"viewpoint"]
	if sy.x * ep.x >= 0.0 or sy.x * vp.x <= 0.0:
		errors.append("symbol/energy must sit on opposite sides with the viewpoint on the symbol side")
	if bool(l.get("swapped", false)) != (sy.x > 0.0):
		errors.append("layout 'swapped' flag disagrees with the symbol side")
	for pair: Array in [[&"symbol_summit", sy], [&"energy_summit", ep], [&"viewpoint_spur", sy]]:
		var first: Vector2 = ((l["routes"] as Dictionary)[pair[0]] as Array)[0][0]
		if not first.is_equal_approx(Vector2(pair[1].x, pair[1].z)):
			errors.append("route %s does not start at its puzzle" % pair[0])
	var eb: Array = (l["routes"] as Dictionary)[&"energy_boss"]
	var eb_pre: Vector2 = eb[eb.size() - 2][0]
	if not (eb[0][0] as Vector2).is_equal_approx(Vector2(ep.x, ep.z)) or (eb_pre.x - bo.x) * ep.x <= 0.0:
		errors.append("energy_boss must leave the energy puzzle and enter the boss from the energy side")
	for name: StringName in pads:
		var d: Array = pads[name]
		var c: Vector2 = d[0]
		if absf(c.x) + float(d[1]) > 110.0 or absf(c.y) + float(d[2]) > 124.5:
			errors.append("pad %s leaves the island square" % name)
	var routes: Dictionary = l["routes"]
	for e: Array in l["edges"]:
		if not routes.has(e[2]) or not pads.has(e[0]) or not pads.has(e[1]):
			errors.append("edge %s references missing route/pad" % [e])
	# Module footprints: no overlap, summit/boss keep >= 8 m, axis aligned dock leaving -Z from the boss pad.
	var fp: Dictionary = l["footprints"]
	var names: Array = fp.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var gap := rect_gap(fp[names[i]], fp[names[j]])
			var need := 8.0 if (names[i] == &"summit" and names[j] == &"boss") or (names[i] == &"boss" and names[j] == &"summit") else 1.0
			if gap < need:
				errors.append("footprints %s/%s gap %.1f < %.1f" % [names[i], names[j], gap, need])
	var boss: Vector3 = anchors[&"boss"]
	var ds: Vector3 = anchors[&"dock_start"]
	var de: Vector3 = anchors[&"dock_end"]
	if not (is_equal_approx(ds.x, boss.x) and is_equal_approx(de.x, boss.x) and is_equal_approx(ds.z, boss.z - 6.0) and is_equal_approx(de.z, boss.z - 22.0)):
		errors.append("dock must leave the boss pad toward -Z")
	# Encounter pads vs puzzle (module) pads; every member inside its pad; unique stable ids.
	var ids := {}
	for en: Dictionary in l["encounters"]:
		if ids.has(en["id"]):
			errors.append("duplicate encounter id %s" % en["id"])
		ids[en["id"]] = true
		var pd: Array = pads.get(en["pad"], [])
		if pd.is_empty():
			errors.append("encounter %s has no pad" % en["id"])
			continue
		var p: Vector3 = en["position"]
		if pad_dist(pd, p.x, p.z) > -1.0:
			errors.append("encounter %s outside its pad" % en["id"])
		for o: StringName in [&"spawn", &"symbol", &"energy", &"summit", &"boss"]:
			if pad_dist(pads[o], p.x, p.z) < 2.0:
				errors.append("encounter %s inside puzzle pad %s" % [en["id"], o])
	var groups := (l["enc_pads"] as Array).size()
	if groups < 3 or groups > 5:
		errors.append("encounter group count %d outside 3..5" % groups)
	var pids := {}
	for po: Dictionary in l["potions"]:
		if pids.has(po["id"]):
			errors.append("duplicate potion id %s" % po["id"])
		pids[po["id"]] = true
	if not (l["camp"] as Vector3).is_finite():
		errors.append("camp invalid")
	return errors
