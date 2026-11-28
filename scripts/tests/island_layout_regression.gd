extends SceneTree
## Data-only layout regression (no scene tree needed):
##   godot --headless --path . --script res://scripts/tests/island_layout_regression.gd
const T := preload("res://scripts/world/island_terrain.gd")
const L := preload("res://scripts/world/island_layout.gd")
const P := preload("res://scripts/world/central_passage.gd")
const SEEDS := [0, 1, 2, 3, 5, 11, 17, 23, 42, 64, 99, 123, 256, 777, 1024, 20261117]

var failures := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)


func _init() -> void:
	var base := L.baseline()
	check(L.validate(base).is_empty(), "baseline layout valid: %s" % [L.validate(base)])
	var seen := {}
	for s in SEEDS:
		var l := L.generate(s, L.seed_swaps_sides(s))
		check(not l.is_empty(), "seed %d generates a layout" % s)
		if l.is_empty():
			continue
		check(L.generate(s, L.seed_swaps_sides(s))["anchors"] == l["anchors"], "seed %d deterministic" % s)
		seen[str(l["anchors"][&"symbol"]) + str(l["anchors"][&"summit"]) + str(l["anchors"][&"boss"])] = true
		check(l["anchors"][&"dock_end"].z < l["anchors"][&"boss"].z, "seed %d dock leaves toward -Z" % s)
		var n := (l["enc_pads"] as Array).size()
		check(n >= 3 and n <= 5, "seed %d has 3..5 encounter groups (%d)" % [s, n])
		var kinds := {}
		for e in l["encounters"]:
			kinds[e["archetype"]] = true
		check(kinds.size() == 3, "seed %d mixes standard/heavy/ranged" % s)
	check(seen.size() >= SEEDS.size() - 2, "layouts genuinely differ across seeds (%d distinct)" % seen.size())
	# Full terrain validity (heightfield, routes, flood, dock) for a few seeds.
	for s in [42, 777, 20261117]:
		var t: Node3D = T.new()
		t.configure(s, true)
		var rep: Dictionary = t.generate_data()
		check(rep["valid"], "terrain seed %d valid (fallback %s): %s" % [s, t.used_fallback, rep["errors"]])
		check(not t.used_fallback, "terrain seed %d used its own layout (attempts %d)" % [s, t.generation_attempts])
		_check_side(s, t)
		t.free()
	# Consumer seam: the rendered side must match seed_swaps_sides(requested seed), including after retries.
	check(L.seed_swaps_sides(42) and not L.seed_swaps_sides(777), "pinned seeds: 42 swapped, 777 not")
	for s in [42, 777, 7]:
		var t2: Node3D = T.new()
		t2.configure(s, true)
		t2.generate_data()
		_check_side(s, t2)
		print("seed %d: swapped=%s symbol.x=%.1f fallback=%s" % [s, t2.layout["swapped"], t2.layout["anchors"][&"symbol"].x, t2.used_fallback])
		t2.free()
	_check_passage()
	print("island_layout_regression: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


## Central causeway: walls + sealed gate must exist for the baseline and procedural layouts, and the flood-fill proof must show no
## side-stepping (closed passage is a sealed pocket), a working doorway, a free mouth and reachable branches.
func _check_passage() -> void:
	var cases: Array = [[20261122, false], [42, true], [7, true], [777, true], [20261117, true], [1, true], [99, true]]
	for c: Array in cases:
		var t: Node3D = T.new()
		t.configure(c[0], c[1])
		t.generate_data()
		var plan: Dictionary = P.plan(t)
		check(bool(plan["ok"]), "passage plan seed %d procedural %s: %s" % [c[0], c[1], plan["errors"]])
		if bool(plan["ok"]):
			var v: Dictionary = P.verify_topology(t, plan)
			check(v["sealed"] and v["opens"] and v["mouth_free"] and v["branches"], "passage topology seed %d: %s" % [c[0], v])
			print("passage seed %d: run %d samples, interior cells %d" % [c[0], (plan["left"] as Array).size(), v["interior_cells"]])
		t.free()




func _check_side(s: int, t: Node3D) -> void:
	if t.used_fallback:
		return
	var want := L.seed_swaps_sides(s)
	check(t.layout["swapped"] == want, "terrain seed %d swapped=%s, expected %s" % [s, t.layout["swapped"], want])
	check((t.layout["anchors"][&"symbol"].x > 0.0) == want, "terrain seed %d symbol x=%.1f on wrong side (swapped %s)" % [s, t.layout["anchors"][&"symbol"].x, want])
