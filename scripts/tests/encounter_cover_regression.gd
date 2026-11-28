extends SceneTree
## Real island encounters: cover must stop torso-height shots and the next pack must stay idle on approach.
## Run with -- --qa-no-save; fixture positions never touch a disk save.
const GAME := preload("res://scenes/world/island_game.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	for spec in [[20261122, false], [42, true], [7, true]]:
		var game := GAME.instantiate()
		game.start_in_menu = false
		game.island_seed = spec[0]
		game.procedural = spec[1]
		root.add_child(game)
		paused = false
		var terrain: Node3D = game.terrain
		var layout: Dictionary = terrain.layout
		var covered := {}
		for i in 3:
			await physics_frame
		for obstacle: Dictionary in terrain.get_obstacles():
			if obstacle["kind"] != &"rock":
				continue
			var p: Vector2 = obstacle["pos"]
			var pad_found := StringName()
			for pad: StringName in layout["enc_pads"]:
				var c: Vector3 = layout["anchors"][pad]
				var delta := p - Vector2(c.x, c.z)
				var tangent: Vector2 = layout["enc_dirs"][pad]
				var lateral := Vector2(-tangent.y, tangent.x)
				if absf(delta.dot(lateral)) >= 6.0 and absf(delta.dot(lateral)) <= 10.0 and absf(delta.dot(tangent)) <= 4.0:
					pad_found = pad
					break
			if pad_found == &"":
				continue
			for enemy: Dictionary in layout["encounters"]:
				var pos: Vector3 = enemy["position"]
				check(p.distance_to(Vector2(pos.x, pos.z)) > float(obstacle["r"]) + 0.7,
					"cover clears enemy spawn seed %s" % spec[0])
			var y: float = terrain.height_at(p.x, p.y) + 1.2
			var query := PhysicsRayQueryParameters3D.create(Vector3(p.x - 2, y, p.y), Vector3(p.x + 2, y, p.y), 1)
			var hit := terrain.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit["collider"].name == "DecorationCollision":
				covered[pad_found] = true
		for enemy: Dictionary in layout["encounters"]:
			if enemy["archetype"] == "ranged":
				check(covered.has(enemy["pad"]), "ranged pack has torso-height collidable cover: %s seed %s" % [enemy["pad"], spec[0]])
		var first: StringName = layout["enc_pads"][0]
		var next: StringName = layout["enc_pads"][1]
		var center: Vector3 = layout["anchors"][first]
		var direction: Vector2 = layout["enc_dirs"][first]
		game.player.global_position = center - Vector3(direction.x, 0, direction.y) * 6.0 + Vector3.UP * 0.1
		game.player.set_physics_process(false)
		for i in 30:
			await physics_frame
		var first_engaged := false
		for enemy in game.get_node("Enemies").get_children():
			var pad := StringName()
			for entry: Dictionary in layout["encounters"]:
				if entry["id"] == enemy.enemy_id:
					pad = entry["pad"]
					break
			if pad == first and enemy.get_state_name() != &"idle":
				first_engaged = true
			if pad == next:
				check(enemy.get_state_name() == &"idle", "next pack stays idle on first approach seed %s" % spec[0])
		check(first_engaged, "first pack detects the actual player seed %s" % spec[0])
		game.queue_free()
		for i in 12:
			await process_frame
		OS.delay_msec(500)
	print("encounter_cover_physics: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures > 0 else 0)
