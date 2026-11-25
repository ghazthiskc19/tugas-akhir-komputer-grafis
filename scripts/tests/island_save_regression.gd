extends SceneTree
## Save persistence regression (island_save.gd + SessionProgress export/import).
## Run: C:/Godot/godot.exe --headless --path . --script res://scripts/tests/island_save_regression.gd
## Exit 0 = all checks passed. Uses a private save path; the real user save is never touched.

const IslandSave := preload("res://scripts/world/island_save.gd")
const SessionScript := preload("res://scripts/world/session_progress.gd")
const TEST_PATH := "user://island_save_regression.json"

var _checks := 0
var _failures := 0
var _suites_done := 0
## A script error aborts a suite function silently (exit stays 0), so every suite must reach its end marker.
const EXPECTED_SUITES := 4
const MIN_CHECKS := 80


func _initialize() -> void:
	var original_path := IslandSave.save_path
	IslandSave.save_path = TEST_PATH
	IslandSave.clear_save()
	_test_roundtrip()
	_test_malformed_transaction()
	_test_prior_save_and_corruption()
	_test_killed_enemy_applied()
	IslandSave.clear_save()
	IslandSave.save_path = original_path
	check(_suites_done == EXPECTED_SUITES, "all %d suites completed (got %d)" % [EXPECTED_SUITES, _suites_done])
	check(_checks >= MIN_CHECKS, "check count floor %d (got %d)" % [MIN_CHECKS, _checks])
	print("island_save_regression: %d checks, %d failures, %d suites" % [_checks, _failures, _suites_done])
	quit(1 if _failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _boss_session() -> Node:
	var s: Node = SessionScript.new()
	s.checkpoint_id = &"boss_checkpoint"
	s.checkpoint_transform = Transform3D(Basis.from_euler(Vector3(0, 0.7, 0)), Vector3(12.5, 3.25, -40.0))
	s.collected_ids[&"forest_artifact"] = &"artifact"
	s.collected_ids[&"island_potion_0"] = &"potion"
	s.killed_enemy_ids[&"wolf_1"] = true
	s.killed_enemy_ids[&"golem_2"] = true
	s.puzzle_progress = {
		&"symbol_pillars": true,
		&"gatekeeper_sockets": {&"forest_artifact": true, &"energy_artifact": true},
		&"gatekeeper_started": true,
		&"gatekeeper_snapshot": {"hp": 70, "stamina": 45.5, "potions": 5},
	}
	return s


func _root(session_state: Dictionary) -> Dictionary:
	return {"version": 1, "island_seed": 9007199254740993, "procedural": true, "session": session_state,
		"player": {"hp": 70, "stamina": 45.5, "potions": 5}}


func _test_roundtrip() -> void:
	var src := _boss_session()
	check(IslandSave.write_save(_root(src.export_state())) == OK, "write ok")
	check(IslandSave.has_save(), "has_save after write")
	var root := IslandSave.read_save()
	check(root.get("island_seed") == 9007199254740993, "large seed survives disk as int")
	check(root.get("procedural") == true, "procedural flag")
	var dst: Node = SessionScript.new()
	check(dst.import_state(root["session"]), "import of disk data")
	check(dst.checkpoint_id == &"boss_checkpoint", "checkpoint id")
	check(dst.checkpoint_transform.is_equal_approx(src.checkpoint_transform), "checkpoint transform")
	check(dst.collected_ids == src.collected_ids, "collected ids")
	check(dst.killed_enemy_ids.has(&"wolf_1") and dst.killed_enemy_ids.size() == 2, "killed ids")
	check(dst.puzzle_progress.get(&"symbol_pillars") == true, "puzzle flag")
	var sockets: Dictionary = dst.puzzle_progress[&"gatekeeper_sockets"]
	check(sockets.has(&"forest_artifact") and sockets.has(&"energy_artifact") and not sockets.has(&"summit_artifact"), "partial sockets")
	var snap: Dictionary = dst.get_boss_snapshot()
	check(snap == {"hp": 70, "stamina": 45.5, "potions": 5}, "boss snapshot exact: %s" % [snap])
	check(typeof(snap["hp"]) == TYPE_INT and typeof(snap["potions"]) == TYPE_INT, "snapshot ints are ints")
	check(dst.is_boss_retry_pending(), "boss retry pending after reload")
	dst.puzzle_progress[&"gatekeeper_defeated"] = true
	dst.puzzle_progress.erase(&"gatekeeper_snapshot")
	var won: Dictionary = dst.export_state()
	check(not IslandSave.decode_session(won).is_empty(), "defeated state without snapshot is valid")
	src.free()
	dst.free()
	_suites_done += 1


func _test_malformed_transaction() -> void:
	var good_src := _boss_session()
	var good: Dictionary = good_src.export_state()
	good_src.free()
	var target := _boss_session()
	target.checkpoint_id = &"foothill_checkpoint"
	var before: Dictionary = target.export_state()
	var cases := {}
	cases["bad transform"] = _mutate(good, func(d): d["checkpoint_transform"] = [1, 2, 3])
	cases["nan transform"] = _mutate(good, func(d): d["checkpoint_transform"] = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, INF, 0])
	cases["degenerate basis"] = _mutate(good, func(d): d["checkpoint_transform"] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	cases["bad collected kind"] = _mutate(good, func(d): d["collected"]["x"] = "sword")
	cases["killed not strings"] = _mutate(good, func(d): d["killed"] = [1, 2])
	cases["unknown puzzle key"] = _mutate(good, func(d): d["puzzle_progress"]["mystery"] = true)
	cases["flag not bool"] = _mutate(good, func(d): d["puzzle_progress"]["symbol_pillars"] = "yes")
	cases["started without snapshot"] = _mutate(good, func(d): d["puzzle_progress"].erase("gatekeeper_snapshot"))
	cases["snapshot hp zero"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_snapshot"]["hp"] = 0)
	cases["snapshot string stamina"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_snapshot"]["stamina"] = "full")
	cases["snapshot extra field"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_snapshot"]["x"] = 1)
	cases["snapshot after defeat"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_defeated"] = true)
	cases["socket false"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_sockets"]["forest_artifact"] = false)
	cases["socket unknown id"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_sockets"]["rock"] = true)
	cases["sockets not dict"] = _mutate(good, func(d): d["puzzle_progress"]["gatekeeper_sockets"] = [true])
	cases["missing killed"] = _mutate(good, func(d): d.erase("killed"))
	for label in cases:
		check(not target.import_state(cases[label]), "rejects: " + label)
		check(target.export_state() == before, "state untouched after reject: " + label)
		check(IslandSave.write_save(_root(cases[label])) == ERR_INVALID_DATA, "write refuses: " + label)
	target.free()
	_suites_done += 1


func _mutate(src: Dictionary, fn: Callable) -> Dictionary:
	var d := src.duplicate(true)
	fn.call(d)
	return d


func _test_prior_save_and_corruption() -> void:
	IslandSave.clear_save()
	check(not IslandSave.has_save(), "no save after clear")
	var session := _boss_session()
	var good_root := _root(session.export_state())
	check(IslandSave.write_save(good_root) == OK, "first write")
	var first := IslandSave.read_save()

	var bad := _root(session.export_state())
	bad["player"]["hp"] = -5
	check(IslandSave.write_save(bad) != OK, "invalid write fails")
	check(IslandSave.read_save() == first, "invalid write preserved previous save")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "no tmp left after failed write")

	var changed := _root(session.export_state())
	changed["island_seed"] = 77
	check(IslandSave.write_save(changed) == OK, "overwrite ok")
	check(IslandSave.read_save()["island_seed"] == 77, "overwrite replaced save")
	check(not FileAccess.file_exists(TEST_PATH + ".bak"), "no backup left after success")

	_raw_write(TEST_PATH, "{\"version\":1,\"island_seed\":\"5\",")
	check(not IslandSave.has_save() and IslandSave.read_save().is_empty(), "truncated json is invalid")
	_raw_write(TEST_PATH, "[1,2,3]")
	check(not IslandSave.has_save(), "non-dictionary json is invalid")
	_raw_write(TEST_PATH, JSON.stringify({"version": 99, "island_seed": "1", "procedural": true,
		"session": session.export_state(), "player": {"hp": 1, "stamina": 0, "potions": 0}}))
	check(not IslandSave.has_save(), "wrong version is invalid")
	_raw_write(TEST_PATH, "x".repeat(IslandSave.MAX_BYTES + 1))
	check(not IslandSave.has_save(), "oversized file is invalid")

	# Interrupted replacement: corrupt main + valid backup -> backup is recovered.
	var out := first.duplicate()
	out["island_seed"] = str(first["island_seed"])
	_raw_write(TEST_PATH, "garbage")
	_raw_write(TEST_PATH + ".bak", JSON.stringify(out))
	check(IslandSave.read_save() == first, "valid .bak recovered when main corrupt")

	check(IslandSave.clear_save() == OK, "clear ok")
	check(not IslandSave.has_save() and not FileAccess.file_exists(TEST_PATH + ".bak"), "clear removes everything")
	session.free()
	_suites_done += 1


func _test_killed_enemy_applied() -> void:
	var s: Node = SessionScript.new()
	s.killed_enemy_ids[&"wolf_1"] = true
	var dead := Node3D.new()
	dead.name = "wolf_1"
	var alive := Node3D.new()
	alive.name = "wolf_2"
	s.register_enemy(dead)
	s.register_enemy(alive)
	check(dead.is_queued_for_deletion(), "persisted-killed enemy removed on register")
	check(not alive.is_queued_for_deletion(), "other enemy kept")
	dead.free()
	alive.free()
	s.free()
	_suites_done += 1


func _raw_write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
