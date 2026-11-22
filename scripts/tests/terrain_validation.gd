extends SceneTree
## Throwaway terrain validation harness. Run (from project root):
##   godot --headless --fixed-fps 60 --path . --script res://scripts/tests/terrain_validation.gd -- data
##   godot --headless --fixed-fps 60 --path . --script res://scripts/tests/terrain_validation.gd -- traverse
##   godot --path . --script res://scripts/tests/terrain_validation.gd -- shots     (needs a window/GPU)
## Writes evidence to docs/implementation/evidence/terrain/.

const S := preload("res://scripts/world/island_terrain.gd")
const OUT := "res://docs/implementation/evidence/terrain/"
const PINNED_SEEDS := [101, 202, 303, 404, 505, 606, 707, 808, 909, 1010, 1111, 2222, 3333, 4444, 5555, 6666, 7777, 8888, 9999, 31415]
## Exact seeds from docs/implementation/ACCEPTANCE_CHECKLIST.md (mode `acceptance`).
const ACCEPTANCE_SEEDS := [0, 1, 2, 3, 4, 5, 11, 17, 23, 42, 64, 99, 123, 256, 512, 777, 1024, 2048, 4096, 20261117]

var _log := PackedStringArray()


## Forces every non-baseline layout to be reported invalid, to exercise the bounded retry + fallback path.
class ForcedInvalid:
	extends "res://scripts/world/island_terrain.gd"

	func validate_layout() -> Dictionary:
		var r := super.validate_layout()
		if active_seed != BASELINE_SEED:
			r["valid"] = false
			r["errors"] = ["forced invalid"]
		return r


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var mode := "data"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	_run.call_deferred(mode)


func _p(line: String) -> void:
	print(line)
	_log.append(line)


func _save(name: String) -> void:
	var f := FileAccess.open(OUT + name, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()


func _run(mode: String) -> void:
	match mode:
		"data":
			_data(PINNED_SEEDS, "supplemental pinned seeds")
			_save("data_validation.txt")
		"acceptance":
			_data(ACCEPTANCE_SEEDS, "ACCEPTANCE_CHECKLIST seeds")
			_save("data_validation_acceptance.txt")
		"traverse":
			await _traverse()
			_save("traversal.txt" if OS.get_cmdline_user_args().size() < 2 else "traversal_seed_%s.txt" % OS.get_cmdline_user_args()[1])
		"shots":
			await _shots()
			_save("screenshots.txt")
	quit()


func _hash_state(t: Node) -> Array:
	var routes := []
	for n in t.route_names():
		routes.append(t.get_route_points(n))
	var obs := []
	for o in t.get_obstacles():
		obs.append([o["pos"], o["r"], o["kind"]])
	return [hash(t._h.to_byte_array()), hash(routes), hash(obs)]


func _data(seeds: Array, title: String) -> void:
	_p("== %d %s (procedural=true) ==" % [seeds.size(), title])
	var all_ok := true
	var fallbacks := 0
	var total_ms := 0
	var hashes := {}
	for sd in seeds:
		var t0 := Time.get_ticks_msec()
		var t := S.new()
		t.configure(sd, true)
		var r: Dictionary = t.generate_data()
		var ms := Time.get_ticks_msec() - t0
		total_ms += ms
		var max_slope := 0.0
		for rn in r["routes"]:
			max_slope = maxf(max_slope, r["routes"][rn]["max_slope_deg"])
		var flood_ok := true
		for k in r["flood"]:
			var v = r["flood"][k]
			flood_ok = flood_ok and (v if v is bool else (v["free"] and v["corridor"]))
		_p("seed %d: valid=%s fallback=%s attempts=%d active_seed=%d ms=%d route_max_slope=%.2f relief=%.2f max_h=%.2f obstacles=%d flood_ok=%s errors=%s" % [
			sd, r["valid"], t.used_fallback, t.generation_attempts, t.active_seed, ms, max_slope,
			r["metrics"]["relief_off_route"], r["metrics"]["max_height"], r["metrics"]["obstacle_count"], flood_ok, r["errors"]])
		all_ok = all_ok and r["valid"]
		if t.used_fallback:
			fallbacks += 1
		hashes[hash(t._h.to_byte_array())] = true
		t.free()
	_p("SUMMARY: all_valid=%s fallbacks=%d distinct_heightfields=%d/%d total_ms=%d" % [all_ok, fallbacks, hashes.size(), seeds.size(), total_ms])

	_p("== reproducibility (seed 4242 twice, procedural) ==")
	var a := S.new()
	a.configure(4242, true)
	a.generate_data()
	var b := S.new()
	b.configure(4242, true)
	b.generate_data()
	_p("identical heightfield/routes/obstacles: %s  (A=%s B=%s)" % [_hash_state(a) == _hash_state(b), _hash_state(a), _hash_state(b)])
	_p("== non-procedural ignores the seed value ==")
	var c := S.new()
	c.configure(1, false)
	c.generate_data()
	var d := S.new()
	d.configure(999, false)
	d.generate_data()
	_p("baseline identical for seed 1 vs 999 (procedural=false): %s, active_seed=%d" % [_hash_state(c) == _hash_state(d), c.active_seed])
	_p("== decoration-seed independence (seed 4242) ==")
	var before := _hash_state(a)
	a.set_decoration_seed(777)
	var after := _hash_state(a)
	_p("terrain hash same: %s  routes hash same: %s  obstacles changed: %s  still valid: %s %s" % [
		before[0] == after[0], before[1] == after[1], before[2] != after[2], a.last_report["valid"], a.last_report["errors"]])
	a.set_decoration_seed(a.decoration_seed)
	_p("== different seeds differ ==")
	_p("seed 4242 vs baseline heightfield equal: %s" % (_hash_state(a)[0] == _hash_state(c)[0]))
	_p("== forced invalid layouts (all non-baseline candidates rejected) ==")
	var f := ForcedInvalid.new()
	f.configure(31337, true)
	var t0 := Time.get_ticks_msec()
	var fr: Dictionary = f.generate_data()
	_p("attempts=%d (MAX_ATTEMPTS=%d + 1 fallback) used_fallback=%s final_active_seed=%d final_valid=%s ms=%d attempt_log_seeds=%s" % [
		f.generation_attempts, S.MAX_ATTEMPTS, f.used_fallback, f.active_seed, fr["valid"], Time.get_ticks_msec() - t0,
		f.attempt_log.map(func(e): return [e["seed"], e["valid"]])])


# ---- Traversal ----------------------------------------------------------------------------------------------------
func _build_world(seed_value: int, procedural: bool) -> Dictionary:
	var lab: Node3D = load("res://scenes/tests/melee_lab.tscn").instantiate()
	lab.set_script(null)  # lab HUD script reads the dummies removed below
	root.add_child(lab)
	for n in ["World", "DummyNear", "DummyFar"]:
		var old := lab.get_node_or_null(n)
		if old != null:
			lab.remove_child(old)
			old.queue_free()
	var t := S.new()
	t.configure(seed_value, procedural)
	lab.add_child(t)
	var player = lab.get_node("Player")
	player.jump_enabled = true
	var cam = lab.get_node("Camera3D")
	return {"lab": lab, "terrain": t, "player": player, "cam": cam}


func _place(w: Dictionary, p: Vector2) -> void:
	var t = w["terrain"]
	var pl: CharacterBody3D = w["player"]
	pl.global_position = Vector3(p.x, t.height_at(p.x, p.y) + 0.05, p.y)
	pl.velocity = Vector3.ZERO


func _steer(w: Dictionary, heading: Vector2) -> void:
	# Camera yaw chosen so camera-forward == heading; then plain "move_forward" input, like a player holding W.
	w["cam"].set("_yaw", atan2(-heading.x, -heading.y))
	Input.action_press(&"move_forward", 1.0)


func _walk_route(w: Dictionary, name: StringName, reverse: bool) -> Dictionary:
	var t = w["terrain"]
	var pl: CharacterBody3D = w["player"]
	var pts3: PackedVector3Array = t.get_route_points(name)
	var pts := PackedVector2Array()
	for p in pts3:
		pts.append(Vector2(p.x, p.z))
	if reverse:
		pts.reverse()
	_place(w, pts[0])
	for _i in 30:
		Input.action_release(&"move_forward")
		await physics_frame
	var length := 0.0
	for i in pts.size() - 1:
		length += pts[i].distance_to(pts[i + 1])
	var prog_idx := 0
	var frames := 0
	var max_dev := 0.0
	var max_gap_floor := 0
	var airborne_run := 0
	var min_clear := 1.0e9
	var traveled := 0.0
	var last_pos := Vector2(pl.global_position.x, pl.global_position.z)
	var stall_ref := last_pos
	var stall_frames := 0
	var result := "ok"
	var timeout_frames := int((length / 4.0 + 30.0) * 60.0)
	var end := pts[pts.size() - 1]
	while true:
		await physics_frame
		frames += 1
		var pos := Vector2(pl.global_position.x, pl.global_position.z)
		while prog_idx < pts.size() - 2 and pos.distance_to(pts[prog_idx + 1]) < 6.0:
			prog_idx += 1
		var look := mini(prog_idx + 2, pts.size() - 1)
		var target := pts[look]
		if pos.distance_to(end) < 3.0:
			break
		_steer(w, (target - pos).normalized())
		# metrics (previous physics step result)
		var dev := 1.0e9
		for i in pts.size() - 1:
			dev = minf(dev, S._seg_dist(pos, pts[i], pts[i + 1]))
		max_dev = maxf(max_dev, dev)
		traveled += pos.distance_to(last_pos)
		last_pos = pos
		if not pl.is_on_floor():
			airborne_run += 1
			max_gap_floor = maxi(max_gap_floor, airborne_run)
		else:
			airborne_run = 0
		min_clear = minf(min_clear, pl.global_position.y - t.height_at(pos.x, pos.y))
		if pl.global_position.y < -2.0:
			result = "FELL (y=%.2f)" % pl.global_position.y
			break
		if frames % 180 == 0:
			if pos.distance_to(stall_ref) < 1.0:
				result = "STUCK at (%.1f, %.1f)" % [pos.x, pos.y]
				break
			stall_ref = pos
		if frames > timeout_frames:
			result = "TIMEOUT at (%.1f, %.1f)" % [pos.x, pos.y]
			break
	Input.action_release(&"move_forward")
	var secs := float(frames) / 60.0
	return {"route": name, "reverse": reverse, "result": result, "length": length, "traveled": traveled,
		"sim_seconds": secs, "avg_speed": traveled / maxf(secs, 0.001), "max_centerline_dev": max_dev,
		"max_airborne_frames": max_gap_floor, "min_y_above_ground": min_clear}


func _traverse() -> void:
	var targs := OS.get_cmdline_user_args()
	var w := _build_world(int(targs[1]), true) if targs.size() > 1 else _build_world(S.BASELINE_SEED, false)
	await physics_frame
	await physics_frame
	var t = w["terrain"]
	_p("terrain built: valid=%s seed=%d children=%s" % [t.last_report["valid"], t.active_seed, t.get_children().map(func(c): return c.name)])
	_p("== player physics traversal (baseline layout, melee_lab Player rig, camera-relative W input, no teleport after start) ==")
	var ok_all := true
	for name in t.route_names():
		for rev in [false, true]:
			var t0 := Time.get_ticks_msec()
			var r: Dictionary = await _walk_route(w, name, rev)
			_p("%s%s: %s len=%.0f traveled=%.0f sim=%.1fs avg=%.2fm/s dev=%.2fm airborne_frames_max=%d min_clearance=%.2f wall_ms=%d" % [
				name, " (reverse)" if rev else "", r["result"], r["length"], r["traveled"], r["sim_seconds"], r["avg_speed"],
				r["max_centerline_dev"], r["max_airborne_frames"], r["min_y_above_ground"], Time.get_ticks_msec() - t0])
			ok_all = ok_all and r["result"] == "ok"
	_p("TRAVERSAL SUMMARY: all_ok=%s" % ok_all)
	# Jump behaviour on spawn pad (apex expected v^2/2g = 5.1^2/19.6 = 1.33 m).
	var pl: CharacterBody3D = w["player"]
	_place(w, Vector2(0, 85))
	for _i in 30:
		await physics_frame
	var y0 := pl.global_position.y
	var apex := y0
	Input.action_press(&"jump")
	for i in 90:
		await physics_frame
		if i == 1:
			Input.action_release(&"jump")
		apex = maxf(apex, pl.global_position.y)
	_p("JUMP: start_y=%.3f apex_rise=%.3f (expected ~1.33) landed_on_floor=%s" % [y0, apex - y0, pl.is_on_floor()])
	# Probe collision against the physics world.
	_p("probe_collision: %s" % t.probe_collision())


# ---- Screenshots --------------------------------------------------------------------------------------------------
func _shots() -> void:
	var w := _build_world(S.BASELINE_SEED, false)
	var lab: Node3D = w["lab"]
	var t = w["terrain"]
	var cam: Camera3D = w["cam"]
	cam.set_script(null)
	cam.set_physics_process(false)
	for c in lab.get_children():
		if c is CanvasLayer:
			c.visible = false
	w["player"].visible = true
	# Route overlay (harness only).
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in t.route_names():
		var pts: PackedVector3Array = t.get_route_points(n)
		for i in pts.size() - 1:
			im.surface_add_vertex(pts[i] + Vector3(0, 0.6, 0))
			im.surface_add_vertex(pts[i + 1] + Vector3(0, 0.6, 0))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.9)
	var overlay := MeshInstance3D.new()
	overlay.mesh = im
	overlay.material_override = mat
	lab.add_child(overlay)
	for i in 6:
		await process_frame
	root.size = Vector2i(1280, 960)
	await process_frame
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 270.0
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, 0), Vector3(0, 0, -1)), Vector3(0, 200, 0))
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "overview_topdown_routes.png"))
	overlay.visible = false
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "overview_topdown.png"))
	# Perspective views
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60.0
	var views := {
		"view_spawn_to_hub": [Vector3(0, 14, 105), Vector3(0, 0, 40)],
		"view_island_south": [Vector3(0, 120, 190), Vector3(0, 0, -10)],
		"view_summit_boss_dock": [Vector3(40, 30, -40), Vector3(0, 0, -105)],
		"view_symbol_forest": [Vector3(-30, 18, 35), Vector3(-65, 0, 0)],
		"view_energy_plain": [Vector3(95, 18, 35), Vector3(60, 0, 0)],
	}
	for k in views:
		cam.global_transform = Transform3D(Basis.IDENTITY, views[k][0]).looking_at(views[k][1], Vector3.UP)
		for i in 6:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + k + ".png"))
		_p("saved " + k)
	_p("saved overview_topdown(.png|_routes.png)")
