extends SceneTree
## Consumer test for the central causeway (real physics bodies, real session, saved-state restoration).
## Run: C:/Godot/godot.exe --headless --path . --script res://scripts/tests/central_passage_regression.gd
## Exit 0 = all checks passed. Touches no save file (session export/import stays in memory).

const T := preload("res://scripts/world/island_terrain.gd")
const P := preload("res://scripts/world/central_passage.gd")
const SessionScript := preload("res://scripts/world/session_progress.gd")

var _checks := 0
var _failures := 0


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await _run()
	print("central_passage_regression: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	var terrain: Node3D = T.new()
	terrain.configure(42, true)
	terrain.generate_data()
	var session: Node = SessionScript.new()
	var passage: Node3D = P.new()
	root.add_child(passage)
	passage.build(terrain, session, 42)
	var plan: Dictionary = passage.get_plan()
	check(bool(plan["ok"]), "plan ok: %s" % [plan["errors"]])
	check(not passage.is_open(), "sealed with no artifacts")
	await physics_frame
	await physics_frame
	var g := Vector2(plan["gate_center"])
	var t := Vector2(plan["gate_tangent"])
	var ground: float = terrain.height_at(g.x, g.y)
	var door_from := Vector3(g.x - t.x * 4.0, ground + 1.5, g.y - t.y * 4.0)
	var door_to := Vector3(g.x + t.x * 4.0, ground + 1.5, g.y + t.y * 4.0)
	check(_blocked(door_from, door_to), "closed doorway blocks the player layer")
	# Wall flanks block at several stretches, both sides, at body height.
	var left: Array = plan["left"]
	var right: Array = plan["right"]
	var route: Array = plan["route"]
	for k in [0, route.size() / 3, route.size() / 2, route.size() - 3]:
		var c: Vector2 = route[k]
		for side: Array in [left, right]:
			var w: Vector2 = side[k]
			var dir := (w - c).normalized()
			var a := c + dir * 8.0
			var b := c + dir * 18.0
			var h: float = terrain.height_at(w.x, w.y) + 1.5
			check(_blocked(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y)), "wall blocks at sample %d" % k)
	# Jumping is not an option: the walls rise far above the 1.3 m jump apex.
	var c0: Vector2 = route[route.size() / 2]
	var w0: Vector2 = left[route.size() / 2]
	var d0 := (w0 - c0).normalized()
	var top_h: float = terrain.height_at(w0.x, w0.y) + 3.0
	check(_blocked(Vector3(c0.x + d0.x * 8.0, top_h, c0.y + d0.y * 8.0), Vector3(c0.x + d0.x * 18.0, top_h, c0.y + d0.y * 18.0)), "wall still blocks 3 m above the ground")
	# One artifact is not enough; both open it.
	check(session.claim(&"forest_artifact", &"artifact"), "claim forest artifact")
	await physics_frame
	check(not passage.is_open() and _blocked(door_from, door_to), "forest artifact alone keeps the door shut")
	check(session.claim(&"energy_artifact", &"artifact"), "claim energy artifact")
	await physics_frame
	await physics_frame
	check(passage.is_open(), "both branch artifacts open the gate")
	check(not _blocked(door_from, door_to), "open doorway lets the player through")
	check(_blocked(Vector3(c0.x + d0.x * 8.0, top_h - 1.5, c0.y + d0.y * 8.0), Vector3(c0.x + d0.x * 18.0, top_h - 1.5, c0.y + d0.y * 18.0)), "walls stay solid after opening")
	passage.queue_free()
	await physics_frame
	# Saved-state restoration: fresh session imports the exported progress; the gate is open without any animation.
	var saved: Dictionary = session.export_state()
	var restored: Node = SessionScript.new()
	check(restored.import_state(saved), "session import")
	var again: Node3D = P.new()
	root.add_child(again)
	again.build(terrain, restored, 42)
	await physics_frame
	await physics_frame
	check(again.is_open() and not _blocked(door_from, door_to), "restored save opens the gate immediately")
	again.queue_free()
	# A save with only one branch artifact restores a sealed gate.
	var partial: Node = SessionScript.new()
	partial.claim(&"forest_artifact", &"artifact")
	var half: Node = SessionScript.new()
	check(half.import_state(partial.export_state()), "partial import")
	var sealed: Node3D = P.new()
	root.add_child(sealed)
	sealed.build(terrain, half, 42)
	await physics_frame
	await physics_frame
	check(not sealed.is_open() and _blocked(door_from, door_to), "partial save restores a sealed gate")
	sealed.queue_free()
	terrain.free()
	await process_frame
	await process_frame
	session.free()
	restored.free()
	partial.free()
	half.free()
	# AudioServer releases freed one-shot playbacks on its wall-clock thread, not at fixed simulation speed.
	OS.delay_msec(500)
	await process_frame
	await process_frame


func _blocked(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not root.world_3d.direct_space_state.intersect_ray(query).is_empty()
