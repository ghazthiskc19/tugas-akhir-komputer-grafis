extends SceneTree
## Island completion regression: consumer-level checks of the moving layout, safe ground, save/continue and the boss retry.
##
## Run (Godot 4.7.2, from the project root):
##   C:/Godot/godot.exe --headless --fixed-fps 60 --path . --script res://scripts/tests/island_completion_regression.gd
## Optional user args after `--`:   --only=anchors,persist,boss
## Exit code 0 = every check passed, 1 = at least one failed.
##
## SUITES
##  anchors  baseline AND procedural games: objective roots / camp / potions / encounters sit exactly at terrain.layout, the
##           interactables of every module stand on the terrain, the player settles at the spawn, no enemy is near the spawn
##           and every enemy comes to rest on real collision ground (live physics, nothing is silenced).
##  persist  real interactions (symbol puzzle + forest artifact, energy puzzle solved but NOT collected, summit artifact,
##           killed guard, camp checkpoint, potion pickup) -> save_run to disk -> scene recreation through pending_save
##           (the seed/procedural flags handed to the new scene are deliberately wrong) -> identical state, no duplicate
##           pickups/enemies -> the uncollected artifact is still collectable exactly once -> Continue path
##           (continue_saved_run) restores the same session again.
##  boss     boss fight started and left mid-fight: the save holds the live resources 20/10/0 but the loaded run resumes at the
##           boss entrance with the exact first-attempt snapshot 70/45/2, which a later death restores again; victory ->
##           save -> load keeps the boss won and the gate available (opens, completion fires once).
##
## TEST SETUP (the only direct state writes, documented): the player is teleported next to objectives (the real Interactor,
## with range/line-of-sight, is used for every pickup, pillar, panel, socket, altar and checkpoint); the boss suite claims the
## three artifacts in the session and writes HP/stamina/potions so that the snapshot is the exact tuple 70/45/2; the boss and
## guard are hurt through their Health node. This is state regression, NOT traversal or a playthrough.
##
## USER SAVE SAFETY: island_save.save_path is redirected to a scratch file for the whole run; the original bytes of the real
## save (+ .tmp/.bak) are backed up first and restored and verified at the end (also from _finalize()).

const GAME_SCENE := "res://scenes/world/island_game.tscn"
const SESSION_SCRIPT := preload("res://scripts/world/session_progress.gd")
const SAVE := preload("res://scripts/world/island_save.gd")
const SAVE_SUFFIXES: Array[String] = ["", ".tmp", ".bak"]
const SCRATCH_SAVE := "user://island_completion_test.json"

const FOREST := &"forest_artifact"
const ENERGY := &"energy_artifact"
const SUMMIT := &"summit_artifact"
const ARTIFACTS: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]
const NEAR: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(-1.2, 0, 0), Vector3(0, 0, -1.2)]
const RING: Array[Vector3] = [Vector3(2, 0, 0), Vector3(0, 0, 2), Vector3(-2, 0, 0), Vector3(0, 0, -2), Vector3(1.6, 0, 1.6), Vector3(-1.6, 0, -1.6)]
const SOCKET_OFFSETS: Array[Vector3] = [Vector3(0, 0, 1.3), Vector3(0, 0, 1.8), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]
const ALTAR_OFFSETS: Array[Vector3] = [Vector3(0, 0, 2.0), Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0), Vector3(0, 0, 2.4)]
const ENEMY_SPAWN_SAFE_DISTANCE := 18.0

var _checks := 0
var _failed: Array[String] = []
var _suite := ""
var _args := PackedStringArray()
var _save_backup := {}
var _save_real_path := ""
var _save_guarded := false


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_main.call_deferred()


func _main() -> void:
	var only := ""
	for a in _args:
		if a.begins_with("--only="):
			only = a.substr(7)
	var wanted := only.split(",", false)
	_suite = "save-guard"
	guard_user_save()
	var suites: Array = [["anchors", test_anchors, 60], ["persist", test_persist, 45], ["boss", test_boss_retry, 45]]
	for entry in suites:
		if not wanted.is_empty() and not wanted.has(entry[0]):
			continue
		_suite = entry[0]
		print("== suite %s" % _suite)
		var before := _checks
		await (entry[1] as Callable).call()
		check(_checks - before >= int(entry[2]), "suite ran to completion: %d checks, expected at least %d (a script error aborts a suite)" % [_checks - before, entry[2]])
	await shutdown_cleanly()
	_suite = "save-guard"
	restore_user_save()
	print("")
	print("island_completion_regression: %d checks, %d failed (STATE regression with teleports; not a full playthrough)" % [_checks, _failed.size()])
	for line in _failed:
		print("  FAIL " + line)
	quit(0 if _failed.is_empty() else 1)


func _finalize() -> void:
	restore_user_save()


func shutdown_cleanly() -> void:
	paused = false
	for child in root.get_children():
		child.queue_free()
	await frames(10)
	OS.delay_msec(500)
	await frames(10)


# ============================================================================================================ user save guard

func guard_user_save() -> void:
	if _save_guarded:
		return
	_save_real_path = SAVE.save_path
	for suffix in SAVE_SUFFIXES:
		var file := _save_real_path + suffix
		if FileAccess.file_exists(file):
			_save_backup[file] = FileAccess.get_file_as_bytes(file)
	_save_guarded = true
	SAVE.save_path = SCRATCH_SAVE
	for suffix in SAVE_SUFFIXES:
		DirAccess.remove_absolute(SCRATCH_SAVE + suffix)


## Idempotent. Redirects back, deletes scratch files, restores the real save bytes and verifies them.
func restore_user_save() -> void:
	if not _save_guarded:
		return
	_save_guarded = false
	SAVE.save_path = _save_real_path
	for suffix in SAVE_SUFFIXES:
		if FileAccess.file_exists(SCRATCH_SAVE + suffix):
			DirAccess.remove_absolute(SCRATCH_SAVE + suffix)
	for suffix in SAVE_SUFFIXES:
		var file := _save_real_path + suffix
		if _save_backup.has(file):
			var out := FileAccess.open(file, FileAccess.WRITE)
			if out != null:
				out.store_buffer(_save_backup[file])
				out.close()
		elif FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
		var same: bool = (FileAccess.file_exists(file) == _save_backup.has(file)) \
			and (not _save_backup.has(file) or FileAccess.get_file_as_bytes(file) == _save_backup[file])
		check(same, "user save file %s restored to its original bytes" % file)


# ============================================================================================================ helpers

func check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failed.append("[%s] %s" % [_suite, msg])
		printerr("FAIL [%s] %s" % [_suite, msg])
	return cond


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func until(pred: Callable, max_seconds: float) -> bool:
	var ticks := int(max_seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if pred.call():
			return true
		await physics_frame
	return bool(pred.call())


func quiet_enemies() -> void:
	for e in get_nodes_in_group(&"enemies"):
		e.set_physics_process(false)


## Fresh scene with explicit seed/procedural flags. `quiet` switches enemy AI off (teleporting must not start fights).
func new_game(seed_value: int, procedural: bool, quiet: bool = true) -> Node:
	var g: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	g.island_seed = seed_value
	g.procedural = procedural
	g.start_in_menu = false
	root.add_child(g)
	await frames(4)
	if quiet:
		quiet_enemies()
	return g


## Scene recreation exactly as the Continue button does it, but synchronous: the flags handed over are deliberately WRONG so
## the test proves the scene takes seed/procedural from the save. _ready (and so the whole restore) has run on return.
func load_game(saved: Dictionary) -> Node:
	var g: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	g.island_seed = -12345
	g.procedural = not bool(saved["procedural"])
	g.start_in_menu = false
	g.pending_save = saved
	root.add_child(g)
	return g


func end_game(g: Node) -> void:
	paused = false
	g.queue_free()
	await frames(3)


func teleport(g: Node, pos: Vector3) -> void:
	g.player.global_position = pos
	g.player.velocity = Vector3.ZERO
	await frames(2)


func reach(g: Node, item: Node3D, offsets: Array) -> bool:
	for off in offsets:
		await teleport(g, item.global_position + (off as Vector3) + Vector3(0, 0.1, 0))
		if await until(func(): return g.interactor.get_target() == item, 0.4):
			return true
	return false


func press_e(g: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	g.interactor._unhandled_input(ev)


func use(g: Node, item: Node3D, offsets: Array = NEAR) -> bool:
	var reached: bool = await reach(g, item, offsets)
	if not reached:
		return false
	press_e(g)
	await frames(2)
	return true


func unreachable(g: Node, item: Node3D, offsets: Array) -> bool:
	var reached: bool = await reach(g, item, offsets)
	return not reached


func kill_player(g: Node) -> bool:
	var p = g.player
	p.receive_damage(100000)
	check(p.is_dead(), "player must be dead after lethal receive_damage")
	return await until(func(): return not p.is_dead() and not g.session.is_respawn_pending(), 8.0)


func settle(m: Node) -> void:
	await until(func(): return not m.is_rotating(), 2.0)
	await physics_frame


func solve_symbol(g: Node, m: Node) -> void:
	for sym in m.get_solution():
		check(await use(g, m.get_pillar_interactable(sym)), "interactor reaches pillar %d" % sym)


## Presses the real panels towards the module's own nearest solving orientation.
func solve_energy(g: Node, m: Node) -> void:
	var cur: Array = m.get_orientations()
	var best: Array = []
	var best_cost := 1000
	for target: Array in m.validate_orientations()["solving"]:
		var presses: Array = []
		var cost := 0
		for i in cur.size():
			var n: int = ((int(target[i]) - int(cur[i])) % 4 + 4) % 4
			presses.append(n)
			cost += n
		if cost < best_cost:
			best_cost = cost
			best = presses
	check(not best.is_empty(), "energy module reports a solving orientation")
	for i in best.size():
		for _k in int(best[i]):
			if m.is_solved():
				return
			check(await use(g, m.get_panel_interactable(i)), "interactor reaches energy panel %d" % i)
			await settle(m)


func resources(p: Node) -> Dictionary:
	return {"hp": p.get_health().current_health, "stamina": p.stamina, "potions": p.potion_count}


func resources_match(got: Dictionary, hp: int, stamina: float, potions: int) -> bool:
	return got["hp"] == hp and absf(float(got["stamina"]) - stamina) < 0.001 and got["potions"] == potions


func ground_hit(pos: Vector3, from_above: float = 3.0, exclude: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * from_above, pos + Vector3.DOWN * 8.0, 1)
	q.exclude = exclude
	return root.get_world_3d().direct_space_state.intersect_ray(q)


## Every node carrying a pickup_id -> {id: [nodes]}.
func pickup_census(g: Node) -> Dictionary:
	var out := {}
	for n in g.find_children("*", "", true, false):
		var id: Variant = n.get("pickup_id")
		if id != null and id != &"":
			if not out.has(id):
				out[id] = []
			out[id].append(n)
	return out


func check_no_duplicate_pickups(g: Node, label: String) -> void:
	var census := pickup_census(g)
	for id in census:
		check(census[id].size() == 1, "%s: pickup %s exists exactly once (%d)" % [label, id, census[id].size()])
	var expected: Array = []
	for config: Dictionary in g.terrain.layout["potions"]:
		expected.append(config["id"])
	for id in expected:
		check(census.has(id), "%s: layout potion %s exists" % [label, id])


func live_enemies(g: Node) -> Array:
	var out: Array = []
	for e in get_nodes_in_group(&"enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and g.is_ancestor_of(e) and e.get("enemy_id") != null:
			out.append(e)
	return out


func normalized(state: Dictionary) -> String:
	var copy := state.duplicate(true)
	var killed: Array = copy["killed"]
	killed.sort()
	return JSON.stringify(copy, "", true)


## Newest island scene in the root other than `old_id` (what Continue / New run leave behind after the deferred swap).
func await_replacement(old_id: int) -> Node:
	for i in 600:
		await physics_frame
		for child in root.get_children():
			if child.get_instance_id() != old_id and child.get("island_seed") != null and child.get("session") != null and child.get("boss") != null:
				return child
	return null


# ============================================================================================================ anchors

func test_anchors() -> void:
	for config: Array in [[20261122, false], [3, true]]:
		var proc: bool = config[1]
		var label := "%s seed %d" % ["procedural" if proc else "baseline", config[0]]
		var g := await new_game(config[0], proc, false)
		var layout: Dictionary = g.terrain.layout
		var anchors: Dictionary = layout["anchors"]
		var p = g.player
		var hp0: int = p.get_health().current_health
		var named := {&"symbol": "SymbolPillars", &"energy": "EnergyPath", &"summit": "SummitRoute"}
		for id in named:
			check(g.get_world_anchor(id).is_equal_approx(anchors[id]), "%s: get_world_anchor(%s) is the layout anchor" % [label, id])
			var module: Node3D = g.objectives.get_node(named[id])
			check(module.global_position.distance_to(anchors[id]) < 0.01, "%s: %s root sits on its anchor %s (is %s)" % [label, named[id], anchors[id], module.global_position])
		check(g.boss.global_position.distance_to(anchors[&"boss"]) < 0.01, "%s: boss root sits on its anchor" % label)
		check(layout["camp"] is Vector3 and g.terrain.get_node("CampCheckpoint").global_position.distance_to(layout["camp"]) < 0.01, "%s: camp checkpoint sits on layout camp" % label)
		# Pickups and encounters sit where the layout says.
		var census := pickup_census(g)
		for config_potion: Dictionary in layout["potions"]:
			var nodes: Array = census.get(config_potion["id"], [])
			check(nodes.size() == 1 and (nodes[0] as Node3D).global_position.distance_to(config_potion["position"]) < 0.01, "%s: potion %s sits on layout position" % [label, config_potion["id"]])
		check_no_duplicate_pickups(g, label)
		var by_id := {}
		for e in live_enemies(g):
			by_id[e.enemy_id] = e
		for enc: Dictionary in layout["encounters"]:
			check(by_id.has(enc["id"]), "%s: encounter %s exists" % [label, enc["id"]])
		# Actual interactables of every module stand on the terrain (neither buried nor floating).
		var items: Array = []
		var sym = g.objectives.get_node("SymbolPillars")
		for i in 4:
			items.append(sym.get_pillar_interactable(i))
		items.append(sym.get_artifact())
		var eng = g.objectives.get_node("EnergyPath")
		for i in 3:
			items.append(eng.get_panel_interactable(i))
		items.append(eng.get_artifact())
		var sum = g.objectives.get_node("SummitRoute")
		items.append(sum.get_artifact())
		items.append(sum.get_node("Interact_Lever"))
		for id in ARTIFACTS:
			items.append(g.boss.get_arena().consoles[id])
		items.append(g.boss.get_arena().altar)
		for item: Node3D in items:
			var pos := item.global_position
			var hit := ground_hit(pos, 1.0)
			check(not hit.is_empty(), "%s: collision ground exists under %s" % [label, item.name])
			if not hit.is_empty():
				var rel: float = pos.y - (hit["position"] as Vector3).y
				check(rel >= -1.1 and rel <= 2.5, "%s: %s stands %.2f above its collision surface" % [label, item.name, rel])
		# Spawn: safe and on real collision ground.
		var spawn: Vector3 = g.get_world_anchor(&"spawn")
		check(await until(func(): return p.is_on_floor(), 2.0), "%s: player settles on floor at the spawn" % label)
		check(absf(p.global_position.y - spawn.y) < 0.5 and flat_distance(p.global_position, spawn) < 1.0, "%s: player rests at the spawn anchor (%s vs %s)" % [label, p.global_position, spawn])
		for e in live_enemies(g):
			check(flat_distance(e.global_position, spawn) >= ENEMY_SPAWN_SAFE_DISTANCE, "%s: enemy %s is %.1f m from the spawn (min %.0f)" % [label, e.enemy_id, flat_distance(e.global_position, spawn), ENEMY_SPAWN_SAFE_DISTANCE])
		# Enemies settle on collision ground with live physics (AI on, player parked at the safe spawn).
		await frames(90)
		for e: Node3D in live_enemies(g):
			var hit := ground_hit(e.global_position, 3.0, [e.get_rid()] if e is CollisionObject3D else [])
			check(not hit.is_empty(), "%s: ground exists under enemy %s" % [label, e.enemy_id])
			if not hit.is_empty():
				var rel: float = e.global_position.y - hit["position"].y
				check(rel >= -0.2 and rel <= 0.6, "%s: enemy %s rests on the ground (%.2f above it)" % [label, e.enemy_id, rel])
		check(not p.is_dead() and p.get_health().current_health == hp0, "%s: nothing hurt the player at the spawn" % label)
		await end_game(g)


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# ============================================================================================================ persist

func test_persist() -> void:
	var g := await new_game(7, true)
	var p = g.player
	var s = g.session
	var health = p.get_health()
	var layout_before := str(g.terrain.layout)
	var sym = g.objectives.get_node("SymbolPillars")
	var eng = g.objectives.get_node("EnergyPath")
	var sum = g.objectives.get_node("SummitRoute")
	# Real progress through the real interactions.
	await solve_symbol(g, sym)
	check(sym.is_solved(), "symbol puzzle solved")
	check(await use(g, sym.get_artifact(), RING), "forest artifact collected")
	await solve_energy(g, eng)
	check(eng.is_solved() and not s.is_collected(ENERGY), "energy puzzle solved but artifact NOT collected")
	check(await use(g, sum.get_artifact(), RING), "summit artifact collected")
	var guard: Node = sum.get_enemies()[0]
	var guard_id: StringName = guard.enemy_id
	guard.get_node("Health").apply_damage(100000)
	check(s.killed_enemy_ids.has(guard_id), "guard %s recorded as killed" % guard_id)
	check(await use(g, g.terrain.get_node("CampCheckpoint"), NEAR), "camp checkpoint activated")
	var potion_id: StringName = g.terrain.layout["potions"][0]["id"]
	var potion: Node3D = pickup_census(g)[potion_id][0]
	check(await use(g, potion, NEAR), "potion %s picked up" % potion_id)
	check(s.is_collected(potion_id), "potion recorded in the session")
	# Setup (documented): exact resources to persist.
	p.stamina_regen = 0.0
	health.current_health = 70
	health.health_changed.emit(70, health.max_health)
	p.stamina = 45.0
	var potions_before: int = p.potion_count
	check(potions_before >= 1, "player holds potions (%d)" % potions_before)
	g.begin_run()
	check(g.save_run(), "save_run writes the save")
	check(g.has_saved_run(), "has_saved_run is true after saving")
	var saved := SAVE.read_save()
	check(not saved.is_empty() and saved["island_seed"] == 7 and saved["procedural"] == true, "disk save carries seed 7 / procedural")
	check(not saved.is_empty() and resources_match(saved["player"], 70, 45.0, potions_before), "disk save carries resources 70/45/%d (%s)" % [potions_before, saved.get("player")])
	var exported := normalized(s.export_state())
	var expected_checkpoint: Vector3 = s.checkpoint_transform.origin
	var killed_before: Array = s.killed_enemy_ids.keys()
	await end_game(g)
	if saved.is_empty():
		return

	# Scene recreation through pending_save (value read back from disk).
	var h := load_game(saved)
	check(h.island_seed == 7 and h.procedural == true, "recreated scene takes seed/procedural from the save")
	check(str(h.terrain.layout) == layout_before, "recreated scene has the identical layout")
	var hp = h.player
	check(resources_match(resources(hp), 70, 45.0, potions_before), "player resources restored exactly (%s)" % [resources(hp)])
	check(hp.global_position.distance_to(expected_checkpoint) < 0.01, "player restored at the checkpoint (%s vs %s)" % [hp.global_position, expected_checkpoint])
	check(h.session.checkpoint_id == &"camp", "camp checkpoint still active")
	check(normalized(h.session.export_state()) == exported, "session state identical after recreation")
	await frames(4)
	quiet_enemies()
	await verify_persisted_world(h, "pending_save", guard_id, potion_id, killed_before)
	check_no_duplicate_pickups(h, "pending_save")
	# The solved-but-uncollected artifact is still there and collectable exactly once.
	var h_eng = h.objectives.get_node("EnergyPath")
	check(await use(h, h_eng.get_artifact(), RING), "energy artifact still collectable after load")
	check(h.session.is_collected(ENERGY) and h.session.count_kind(&"artifact") == 3, "energy artifact collected exactly once after load")
	press_e(h)
	press_e(h)
	await frames(2)
	check(h.session.count_kind(&"artifact") == 3, "repeated E cannot duplicate artifacts after load")
	h.player.stamina_regen = 0.0
	h.player.stamina = 45.0
	h.begin_run()
	check(h.save_run(), "second save_run succeeds")
	var second_state := normalized(h.session.export_state())
	var second_res := resources(h.player)

	# Continue path: reads the disk save and swaps the scene.
	check(h.has_saved_run(), "has_saved_run true for Continue")
	var old_id := h.get_instance_id()
	h.continue_saved_run()
	var c := await await_replacement(old_id)
	check(c != null, "Continue produced a replacement scene")
	if c != null:
		await frames(4)
		quiet_enemies()
		check(c.island_seed == 7 and c.procedural == true, "continued scene keeps seed/procedural")
		check(normalized(c.session.export_state()) == second_state, "continued session identical to the saved one")
		check(resources_match(resources(c.player), second_res["hp"], 45.0, second_res["potions"]), "continued resources equal the saved ones (%s)" % [resources(c.player)])
		check(c.session.count_kind(&"artifact") == 3 and c.session.checkpoint_id == &"camp", "continued run keeps all artifacts and the checkpoint")
		check_no_duplicate_pickups(c, "continue")
		for n in ARTIFACTS:
			for node: Node3D in pickup_census(c).get(n, []):
				check(not node.visible, "continue: collected artifact %s stays hidden" % n)
		await end_game(c)
	elif is_instance_valid(h):
		await end_game(h)


func verify_persisted_world(h: Node, label: String, guard_id: StringName, potion_id: StringName, killed_before: Array) -> void:
	var s = h.session
	var sym = h.objectives.get_node("SymbolPillars")
	var eng = h.objectives.get_node("EnergyPath")
	var sum = h.objectives.get_node("SummitRoute")
	check(sym.is_solved() and s.puzzle_progress.get(&"symbol_pillars", false) == true, "%s: symbol puzzle still solved" % label)
	check(eng.is_solved() and s.puzzle_progress.get(&"energy_path", false) == true, "%s: energy puzzle still solved" % label)
	check(await until(func(): return sym.get_node_or_null("Seal") == null and eng.get_node_or_null("Seal") == null, 3.0), "%s: solved seals are gone" % label)
	check(s.is_collected(FOREST) and not sym.get_artifact().visible, "%s: forest artifact collected and hidden" % label)
	check(s.is_collected(SUMMIT) and not sum.get_artifact().visible, "%s: summit artifact collected and hidden" % label)
	check(not s.is_collected(ENERGY) and eng.get_artifact().visible, "%s: solved energy artifact still waiting on its pad" % label)
	var census := pickup_census(h)
	check(not (census[potion_id][0] as Node3D).visible and s.is_collected(potion_id), "%s: collected potion stays hidden" % label)
	for id in killed_before:
		check(s.killed_enemy_ids.has(id), "%s: kill %s persisted" % [label, id])
	await until(func(): return live_enemies(h).all(func(e): return not s.killed_enemy_ids.has(e.enemy_id)), 2.0)
	var seen := {}
	for e in live_enemies(h):
		check(not s.killed_enemy_ids.has(e.enemy_id), "%s: killed enemy %s is not alive again" % [label, e.enemy_id])
		check(not seen.has(e.enemy_id), "%s: enemy %s exists once" % [label, e.enemy_id])
		seen[e.enemy_id] = true
	check(not seen.has(guard_id), "%s: summit guard %s did not respawn" % [label, guard_id])
	var layout_ids := {}
	for enc: Dictionary in h.terrain.layout["encounters"]:
		layout_ids[enc["id"]] = true
	for id in layout_ids:
		check(seen.has(id) == not s.killed_enemy_ids.has(id), "%s: layout enemy %s alive iff not killed" % [label, id])
	var visible_artifacts := 0
	for id in ARTIFACTS:
		for node: Node3D in census.get(id, []):
			if node.visible:
				visible_artifacts += 1
	check(visible_artifacts == 1, "%s: exactly one artifact pickup remains visible (%d)" % [label, visible_artifacts])
	check(s.count_kind(&"artifact") == 2, "%s: two artifacts collected (%d)" % [label, s.count_kind(&"artifact")])


# ============================================================================================================ boss retry

func test_boss_retry() -> void:
	var g := await new_game(20261122, false)
	var p = g.player
	var s = g.session
	var enc = g.boss
	var arena = enc.get_arena()
	var health = p.get_health()
	# Setup (documented): artifacts claimed (the pickup path is covered by `persist`), exact resources.
	for id in ARTIFACTS:
		check(s.claim(id, &"artifact"), "setup: claim %s" % id)
	p.stamina_regen = 0.0
	p.potion_count = 2
	health.current_health = 70
	health.health_changed.emit(70, health.max_health)
	p.stamina = 45.0
	for id in ARTIFACTS:
		check(await use(g, arena.consoles[id], SOCKET_OFFSETS), "install %s through the interactor" % id)
	check(await use(g, arena.altar, ALTAR_OFFSETS), "altar reached")
	check(await until(func(): return enc.get_mode_name() == &"fighting", 8.0), "boss reaches the fight")
	check(snapshot_is(enc.get_snapshot(), 70, 45.0, 2), "snapshot is exactly 70/45/2 (%s)" % [enc.get_snapshot()])
	# The fight goes badly: live resources diverge from the snapshot, the boss is hurt.
	p.potion_count = 0
	health.current_health = 20
	p.stamina = 10.0
	enc.get_boss_health().apply_damage(enc.get_boss_health().max_health / 2)
	g.begin_run()
	check(g.save_run(), "save during the fight")
	var saved := SAVE.read_save()
	check(not saved.is_empty() and resources_match(saved["player"], 20, 10.0, 0), "the save holds the live resources 20/10/0 (%s)" % [saved.get("player")])
	check(not saved.is_empty() and snapshot_is(saved["session"]["puzzle_progress"].get("gatekeeper_snapshot", {}), 70, 45.0, 2), "the save keeps the exact snapshot 70/45/2")
	await end_game(g)
	if saved.is_empty():
		return

	# Load: resume at the boss entrance with the snapshot, never the live values.
	var h := load_game(saved)
	var hp = h.player
	var henc = h.boss
	var harena = henc.get_arena()
	check(resources_match(resources(hp), 70, 45.0, 2), "loaded player has the snapshot 70/45/2, not 20/10/0 (%s)" % [resources(hp)])
	check(hp.global_position.distance_to(henc.to_global(Vector3(0, 0.1, 13.5))) < 0.01, "loaded player stands at the boss entrance (%s)" % hp.global_position)
	check(henc.get_mode_name() == &"rearmed", "boss is rearmed after load (%s)" % henc.get_mode_name())
	check(snapshot_is(henc.get_snapshot(), 70, 45.0, 2), "boss kept the exact snapshot after load")
	check(henc.get_boss_health().current_health == henc.get_boss_health().max_health and henc.phase == 1, "boss is back to full HP, phase 1")
	check(h.session.is_boss_retry_pending(), "session reports a pending boss retry")
	for id in ARTIFACTS:
		check(h.session.is_collected(id) and h.session.puzzle_progress[&"gatekeeper_sockets"].has(id), "loaded: %s collected and installed" % id)
	check(h.session.collected_ids.size() == 3, "loaded: no duplicated artifacts")
	check_no_duplicate_pickups(h, "boss load")
	await frames(4)
	quiet_enemies()
	hp.stamina_regen = 0.0
	check(await until(func(): return hp.is_on_floor(), 2.0), "loaded player stands on the entrance ground")
	check(await use(h, harena.altar, ALTAR_OFFSETS), "altar usable for the retry right after load")
	check(henc.get_mode_name() == &"fighting", "retry starts the fight at once (%s)" % henc.get_mode_name())
	# A death restores the same snapshot again.
	hp.potion_count = 0
	hp.stamina = 5.0
	check(await kill_player(h), "player dies in the retry")
	check(await until(func(): return henc.get_mode_name() == &"rearmed", 10.0), "boss rearms after the death")
	await frames(3)
	check(resources_match(resources(hp), 70, 45.0, 2), "death after load restores 70/45/2 (%s)" % [resources(hp)])
	check(henc.get_retry_point().distance_to(hp.global_position) < 1.5, "player at the retry point")
	check(await use(h, harena.altar, ALTAR_OFFSETS), "altar usable for the final attempt")
	check(await until(func(): return henc.get_mode_name() == &"fighting", 2.0), "final attempt fighting")
	# Victory, then immediately save (the gate sequence is still running).
	var completions := [0]
	henc.completed.connect(func(): completions[0] += 1)
	henc.get_boss_health().apply_damage(henc.get_boss_health().current_health)
	check(henc.get_mode_name() == &"won", "boss defeated")
	check(not h.session.puzzle_progress.has(&"gatekeeper_snapshot") and h.session.puzzle_progress.get(&"gatekeeper_defeated", false) == true, "victory drops the snapshot and records the defeat")
	var won_res := resources(hp)
	h.begin_run()
	check(h.save_run(), "save right after the victory")
	var saved_won := SAVE.read_save()
	check(not saved_won.is_empty() and not saved_won["session"]["puzzle_progress"].has("gatekeeper_snapshot"), "won save has no snapshot")
	await end_game(h)
	if saved_won.is_empty():
		return

	# Load a won boss: still won, the gate stays available (opens even though the save predates the gate opening).
	var w := load_game(saved_won)
	var wenc = w.boss
	check(wenc.get_mode_name() == &"won", "loaded boss stays won (%s)" % wenc.get_mode_name())
	check(wenc.get_snapshot().is_empty() and not w.session.is_boss_retry_pending(), "won boss has no retry snapshot")
	check(resources_match(resources(w.player), won_res["hp"], float(won_res["stamina"]), won_res["potions"]), "won save keeps the live resources %s (%s)" % [won_res, resources(w.player)])
	check(not w.player.global_position.distance_to(wenc.to_global(Vector3(0, 0.1, 13.5))) < 0.01, "won boss does not pull the player back to the entrance")
	var gate_ok: bool = await until(func(): return wenc.get_arena().is_gate_open() and w.session.puzzle_progress.get(&"gatekeeper_gate_open", false) == true, 12.0)
	check(gate_ok, "gate becomes available after loading a won boss")
	w.player.stamina_regen = 0.0
	w.begin_run()
	check(w.save_run(), "save with the open gate")
	var saved_open := SAVE.read_save()
	await end_game(w)
	if saved_open.is_empty():
		return

	var o := load_game(saved_open)
	var oenc = o.boss
	check(oenc.get_mode_name() == &"won", "boss still won after the second load")
	check(await until(func(): return oenc.get_arena().is_gate_open() and oenc.get_status().contains("terbuka"), 12.0), "open gate is restored open and finished")
	var done := [0]
	oenc.completed.connect(func(): done[0] += 1)
	await frames(4)
	quiet_enemies()
	await teleport(o, oenc.to_global(Vector3(0, 0.3, -21)))
	check(await until(func(): return done[0] >= 1, 3.0), "crossing the restored gate completes the level")
	paused = false
	await frames(30)
	check(done[0] == 1, "completion emitted exactly once (got %d)" % done[0])
	await end_game(o)


func snapshot_is(snap: Variant, hp: int, stamina: float, potions: int) -> bool:
	return snap is Dictionary and snap.size() == 3 and int(snap.get("hp", -1)) == hp \
		and absf(float(snap.get("stamina", -1.0)) - stamina) < 0.001 and int(snap.get("potions", -1)) == potions
