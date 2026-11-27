extends SceneTree
## Island regression runner (P19-01): consumer-visible STATE and PROGRESSION regression against the real game modules.
##
## Run (Godot 4.7.2, from the project root):
##   C:/Godot/godot.exe --headless --fixed-fps 60 --path . --script res://scripts/tests/island_regression.gd
## Optional user args after `--`:   --only=symbol,energy,artifacts,boss,summit,newrun,seeds   --seeds-full
## Exit code 0 = every check passed, 1 = at least one failed (each failure is printed with its suite name).
## `--fixed-fps 60` makes simulated time run faster than wall-clock; without it every suite still passes but takes real time.
##
## WHAT THIS IS (and is not)
##  - It is a STATE regression: it drives the real modules through their consumer interfaces and checks what the player or
##    the session can observe. Player movement/traversal, camera and combat feel are NOT exercised: the player is
##    TELEPORTED next to each objective and the real Interactor (target selection with range, y-window and line of sight,
##    then the `interact` action event -> can_interact()/interact()) is used for every pickup, pillar, panel, socket,
##    altar and lever. This is NOT a full playthrough; the input-driven end-to-end run is scripts/tests/island_playthrough.gd.
##  - Documented test setup (the only direct state writes): enemy AI processing is switched off so that teleporting cannot
##    start fights (enemy Health/defeat/session paths stay real); the boss suite claims the three artifacts in the session
##    (the pickup path itself is covered by the `artifacts` suite), zeroes stamina regeneration and sets HP/stamina/potions
##    so that the retry snapshot is the exact tuple 70/45/5; boss damage to the golem uses its Health.apply_damage (the
##    same node the sword hurtbox targets) because swinging at it is a combat-feel test, not a state test.
##  - Nothing here asserts source text, wiring or "does not throw".

const GAME_SCENE := "res://scenes/world/island_game.tscn"
const SYMBOL_SCENE := "res://scenes/objectives/symbol_pillars.tscn"
const ENERGY_SCENE := "res://scenes/objectives/energy_path.tscn"
const SUMMIT_SCENE := "res://scenes/objectives/summit_route.tscn"
const SESSION_SCRIPT := preload("res://scripts/world/session_progress.gd")
const TERRAIN_SCRIPT := preload("res://scripts/world/island_terrain.gd")

const FOREST := &"forest_artifact"
const ENERGY := &"energy_artifact"
const SUMMIT := &"summit_artifact"
const ARTIFACTS: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]

const NEAR: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(-1.2, 0, 0), Vector3(0, 0, -1.2)]
const RING: Array[Vector3] = [Vector3(2, 0, 0), Vector3(0, 0, 2), Vector3(-2, 0, 0), Vector3(0, 0, -2), Vector3(1.6, 0, 1.6), Vector3(-1.6, 0, -1.6)]
## Compass directions of the energy puzzle: 0 N(-z) 1 E(+x) 2 S(+z) 3 W(-x).
const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

const SAVE_SCRIPT := preload("res://scripts/world/island_save.gd")
const SAVE_SUFFIXES: Array[String] = ["", ".tmp", ".bak"]
const SCRATCH_SAVE := "user://island_regression_scratch.json"
var _save_backup := {}
var _save_real_path := ""
var _save_guarded := false
var _checks := 0
var _failed: Array[String] = []
var _suite := ""
var _args := PackedStringArray()


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_main.call_deferred()


func _main() -> void:
	var only := ""
	for a in _args:
		if a.begins_with("--only="):
			only = a.substr(7)
	var wanted := only.split(",", false)
	guard_user_save()
	var suites: Array = [
		["symbol", test_symbol_pillars], ["energy", test_energy_path], ["artifacts", test_artifact_orders],
		["summit", test_summit_state], ["boss", test_boss], ["newrun", test_new_run], ["seeds", test_seed_matrix],
	]
	for entry in suites:
		if not wanted.is_empty() and not wanted.has(entry[0]):
			continue
		_suite = entry[0]
		print("== suite %s" % _suite)
		await (entry[1] as Callable).call()
	await shutdown_cleanly()
	_suite = "save-guard"
	restore_user_save()
	print("")
	print("island_regression: %d checks, %d failed (STATE regression with teleports; not a full playthrough)" % [_checks, _failed.size()])
	for line in _failed:
		print("  FAIL " + line)
	quit(0 if _failed.is_empty() else 1)


## Frees everything the suites left in the tree and lets the audio server drop finished playbacks before the engine exits,
## so the exit report only lists real leaks.
func shutdown_cleanly() -> void:
	paused = false
	for child in root.get_children():
		child.queue_free()
	await frames(10)
	OS.delay_msec(500)
	await frames(10)


# ============================================================================================================ user save guard
# Games started here autosave. The real user save must never be touched: the save path is redirected to a scratch file
# and the original bytes of the real save (+ .tmp/.bak) are restored exactly (and verified) at the end.

func guard_user_save() -> void:
	if _save_guarded:
		return
	_save_real_path = SAVE_SCRIPT.save_path
	for suffix in SAVE_SUFFIXES:
		var file := _save_real_path + suffix
		if FileAccess.file_exists(file):
			_save_backup[file] = FileAccess.get_file_as_bytes(file)
	_save_guarded = true
	SAVE_SCRIPT.save_path = SCRATCH_SAVE
	for suffix in SAVE_SUFFIXES:
		DirAccess.remove_absolute(SCRATCH_SAVE + suffix)


## Idempotent. Redirects back, deletes scratch files, restores the real save bytes and verifies them.
func restore_user_save() -> void:
	if not _save_guarded:
		return
	_save_guarded = false
	SAVE_SCRIPT.save_path = _save_real_path
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


func _finalize() -> void:
	restore_user_save()


# ============================================================================================================ helpers

func check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failed.append("[%s] %s" % [_suite, msg])
		printerr("FAIL [%s] %s" % [_suite, msg])
	return cond


func has_flag(flag: String) -> bool:
	return _args.has("--" + flag)


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


func arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func new_game(seed_value: int = 20261122, procedural: bool = false) -> Node:
	var g: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	g.island_seed = seed_value
	g.procedural = procedural
	g.start_in_menu = false
	root.add_child(g)
	await frames(4)
	quiet_enemies()
	return g


## Test setup: teleporting must not start fights, so enemy AI ticks are off. Health/defeat/session behaviour stays real.
func quiet_enemies() -> void:
	for e in get_nodes_in_group(&"enemies"):
		e.set_physics_process(false)


func end_game(g: Node) -> void:
	paused = false
	g.queue_free()
	await frames(3)


func teleport(g: Node, pos: Vector3) -> void:
	g.player.global_position = pos
	g.player.velocity = Vector3.ZERO
	await frames(2)


## Stands next to `item` (trying each offset) until the real Interactor selects it. False when no offset reaches it.
func reach(g: Node, item: Node3D, offsets: Array) -> bool:
	for off in offsets:
		await teleport(g, item.global_position + (off as Vector3) + Vector3(0, 0.1, 0))
		if await until(func(): return g.interactor.get_target() == item, 0.4):
			return true
	return false


## Sends the real `interact` action event to the Interactor (what E does). Handles reentry in the same frame.
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


## True when no offset lets the Interactor target `item` (sealed, collected, locked).
func unreachable(g: Node, item: Node3D, offsets: Array) -> bool:
	var reached: bool = await reach(g, item, offsets)
	return not reached


func kill_player(g: Node) -> bool:
	var p = g.player
	p.receive_damage(100000)
	check(p.is_dead(), "player must be dead after lethal receive_damage")
	return await until(func(): return not p.is_dead() and not g.session.is_respawn_pending(), 8.0)


func make_fixture(scene_path: String) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var session: Node = SESSION_SCRIPT.new()
	session.name = "Session"
	holder.add_child(session)
	var dummy := Node3D.new()
	dummy.name = "Player"
	holder.add_child(dummy)
	var module: Node3D = (load(scene_path) as PackedScene).instantiate()
	holder.add_child(module)
	module.setup(dummy, session)
	await frames(2)
	return {"holder": holder, "module": module, "session": session, "player": dummy}


func free_fixture(fx: Dictionary) -> void:
	(fx["holder"] as Node).queue_free()
	await frames(2)


# ============================================================================================================ symbol pillars

func symbol_clue_ids(m: Node) -> Array:
	var constants: Dictionary = (m.get_script() as GDScript).get_script_constant_map()
	var links: Array = constants["CLUE_LINKS"]
	var valid: Array = []
	for order in permutations([0, 1, 2, 3, 4, 5]):
		var ok := true
		for link: Vector2i in links:
			ok = ok and order.find(link.x) < order.find(link.y)
		if ok:
			valid.append(order)
	return valid


func permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out: Array = []
	for i in items.size():
		var rest := items.duplicate()
		rest.remove_at(i)
		for tail in permutations(rest):
			out.append([items[i]] + tail)
	return out


## Independent model of the chain rule from the design doc: next-correct extends, wrong resets, lit pillars cannot be pressed.
func chain_step(chain: Array, solution: Array, symbol: int) -> Array:
	if chain.has(symbol):
		return chain
	if symbol == solution[chain.size()]:
		return chain + [symbol]
	return []


func test_symbol_pillars() -> void:
	var fx := await make_fixture(SYMBOL_SCENE)
	var m = fx["module"]
	var dummy: Node = fx["player"]
	var session: Node = fx["session"]
	var sol: Array = m.get_solution()
	check(sol.size() == 6, "solution has six steps")
	var sorted := sol.duplicate()
	sorted.sort()
	check(arr_eq(sorted, [0, 1, 2, 3, 4, 5]), "six distinct pillars")
	var clue_solutions := symbol_clue_ids(m)
	check(clue_solutions.size() == 1, "five relational clues leave exactly one of 720 orders")
	if clue_solutions.size() == 1:
		check(arr_eq(clue_solutions[0], sol), "unique clue order matches solution")
	for link: Vector2i in (m.get_script() as GDScript).get_script_constant_map()["CLUE_LINKS"]:
		check(link.x != link.y, "clue relation is non-reflexive")
	var wrong: int = (int(sol[0]) + 1) % 6
	if wrong == sol[0]:
		wrong = (wrong + 1) % 6
	m.get_pillar_interactable(wrong).interact(dummy)
	check(m.get_progress().is_empty(), "wrong press resets sequence")
	check(not m.get_pillar_interactable(sol[0]).can_interact(dummy), "wrong press briefly locks pillars")
	m.reset_sequence()
	for sym in sol:
		check(m.get_pillar_interactable(sym).interact(dummy), "correct pillar %d accepted" % sym)
		await frames(1)
	check(m.is_solved(), "six-symbol solution opens seal")
	check(session.puzzle_progress.get(&"symbol_pillars", false), "solved progress recorded")
	check(not session.is_collected(FOREST), "solving does not collect artifact")
	for sym in 6:
		check(not m.get_pillar_interactable(sym).can_interact(dummy), "pillar %d locked after solve" % sym)
	await free_fixture(fx)
	var g := await new_game()
	var gm = g.objectives.get_node("SymbolPillars")
	var p = g.player
	var gs = g.session
	var gsol: Array = gm.get_solution()
	var hp0: int = p.get_health().current_health
	var pot0: int = p.potion_count
	check(await use(g, gm.get_pillar_interactable(gsol[0])), "interactor reaches first correct pillar")
	check(await use(g, gm.get_pillar_interactable((gsol[0] + 1) % 6)), "interactor reaches wrong pillar")
	check(gm.get_progress().is_empty() and not gm.is_solved(), "wrong press resets chain")
	check(p.get_health().current_health == hp0 and p.potion_count == pot0, "wrong order costs no HP or potion")
	check(await unreachable(g, gm.get_artifact(), RING), "sealed artifact is not targetable")
	await puzzle_persistence(g, gm, FOREST, &"symbol_pillars", Callable(self, "solve_symbol"), SYMBOL_SCENE)
	await end_game(g)

func solve_symbol(g: Node, m: Node) -> void:
	var solution: Array = m.get_solution()
	for symbol: int in solution:
		var item: Node3D = m.get_pillar_interactable(symbol)
		check(await until(func(): return item.can_interact(g.player), 4.0), "pillar %d unlocks" % symbol)
		check(await use(g, item), "pillar %d activated through interactor" % symbol)


## Shared flow for the two puzzles: solved-but-uncollected survives death, pickup exactly once, re-setup restores state.
func puzzle_persistence(g: Node, m: Node, artifact_id: StringName, key: StringName, solver: Callable, scene_path: String) -> void:
	var p = g.player
	var s = g.session
	await solver.call(g, m)
	check(m.is_solved(), "%s solved through real interactions" % key)
	check(s.puzzle_progress.get(key, false) == true, "%s progress key set" % key)
	check(not s.is_collected(artifact_id), "%s: solved but uncollected" % key)
	check(await until(func(): return m.get_node_or_null("Seal") == null, 3.0), "%s seal removed after solving" % key)
	check(await kill_player(g), "%s: respawned after death" % key)
	check(m.is_solved() and s.puzzle_progress.get(key, false) == true, "%s: solved state survives death/respawn" % key)
	check(not s.is_collected(artifact_id), "%s: uncollected artifact still uncollected after respawn" % key)
	var artifact: Node3D = m.get_artifact()
	check(await use(g, artifact, RING), "%s: artifact reachable and interactable after respawn" % key)
	check(s.is_collected(artifact_id) and s.count_kind(&"artifact") == 1, "%s: artifact collected exactly once" % key)
	press_e(g)
	press_e(g)
	await frames(2)
	check(s.count_kind(&"artifact") == 1 and s.collected_ids.size() == 1, "%s: repeated E cannot duplicate the artifact" % key)
	check(await kill_player(g), "%s: second respawn" % key)
	check(s.is_collected(artifact_id) and not artifact.visible, "%s: collected artifact does not reappear after respawn" % key)
	check(await unreachable(g, artifact, RING), "%s: collected artifact not targetable again" % key)
	check(s.puzzle_progress.get(key, false) == true and m.is_solved(), "%s: puzzle still solved after collection and death" % key)
	# Re-setup from the same session (what a module rebuild would do) restores solved and collected without interaction.
	var again: Node3D = (load(scene_path) as PackedScene).instantiate()
	again.position = m.position
	g.objectives.add_child(again)
	again.setup(p, s)
	await frames(3)
	check(again.is_solved(), "%s: a fresh module from the same session is already solved" % key)
	check(not again.get_artifact().visible, "%s: a fresh module hides the already collected artifact" % key)
	check(s.count_kind(&"artifact") == 1, "%s: rebuilding does not duplicate collected artifacts" % key)
	again.queue_free()
	await frames(2)


# ============================================================================================================ energy path

func dir_of(v: Vector3) -> int:
	if absf(v.x) > absf(v.z):
		return 1 if v.x > 0.0 else 3
	return 2 if v.z > 0.0 else 0


## Geometry read from the module's own node positions (source stub, altar stub, panel roots), not from its constants.
func energy_model(m: Node) -> Dictionary:
	var src := flat(m.get_node("SourcePlinth").position)
	var alt := flat(m.get_node("AltarPlinth").position)
	var cells: Array = []
	for i in m.get_panel_kinds().size():
		cells.append(flat(m.get_node("Panel%d" % (i + 1)).position))
	return {
		"src": src, "alt": alt, "cells": cells, "kinds": m.get_panel_kinds(),
		"emit": dir_of(m.get_node("SourceStub").position - m.get_node("SourcePlinth").position),
		"alt_in": dir_of(m.get_node("AltarStub").position - m.get_node("AltarPlinth").position),
		"step": src.distance_to(cells[0]),
	}


func ports_of(kind: String, orient: int) -> Array:
	var base: Array = [0, 2] if kind == "straight" else [0, 1]
	return [(base[0] + orient) % 4, (base[1] + orient) % 4]


## Independent port-connectivity trace: returns {prefix, reached}. Straight base N-S, elbow base N-E, clockwise quarter turns.
func energy_trace(model: Dictionary, orients: Array) -> Dictionary:
	var pos: Vector3 = model["src"]
	var dir: int = model["emit"]
	var prefix := 0
	var reached := false
	for _i in model["cells"].size() + 1:
		var nxt: Vector3 = pos + DIRS[dir] * float(model["step"])
		var entry := (dir + 2) % 4
		if nxt.distance_to(model["alt"]) < 0.1:
			reached = entry == int(model["alt_in"])
			break
		var idx := -1
		for k in model["cells"].size():
			if nxt.distance_to(model["cells"][k]) < 0.1:
				idx = k
		if idx < 0:
			break
		var pr := ports_of(model["kinds"][idx], orients[idx])
		if not pr.has(entry):
			break
		prefix += 1
		dir = pr[1] if pr[0] == entry else pr[0]
		pos = nxt
	return {"prefix": prefix, "reached": reached}


func combo_key(o: Array) -> int:
	var key := 0
	for orient in o:
		key = key * 4 + int(orient)
	return key


## Shortest press sequence (each press = +1 quarter turn of one panel) from `from` to `to` avoiding states in `forbidden`.
func press_path(from: Array, to: Array, forbidden: Dictionary) -> Array:
	var start := combo_key(from)
	var goal := combo_key(to)
	if start == goal:
		return []
	var prev := {start: [-1, -1]}
	var queue: Array = [from.duplicate()]
	var head := 0
	while head < queue.size():
		var cur: Array = queue[head]
		head += 1
		for panel in cur.size():
			var nxt := cur.duplicate()
			nxt[panel] = (nxt[panel] + 1) % 4
			var k := combo_key(nxt)
			if prev.has(k) or (forbidden.has(k) and k != goal):
				continue
			prev[k] = [combo_key(cur), panel]
			if k == goal:
				var path: Array = []
				var walk := k
				while walk != start:
					path.push_front(prev[walk][1])
					walk = prev[walk][0]
				return path
			queue.append(nxt)
	return []


func settle(m: Node) -> void:
	await until(func(): return not m.is_rotating(), 2.0)
	await physics_frame


func test_energy_path() -> void:
	var fx := await make_fixture(ENERGY_SCENE)
	var m = fx["module"]
	var model := energy_model(m)
	var kinds: Array = model["kinds"]
	check(kinds.size() == 4 and model["cells"].size() == 4 and float(model["step"]) > 1.0, "energy module exposes 4 panels on a grid")
	# Independent solution set over all 4^4 orientations.
	var solving: Dictionary = {}
	var all_states: Array = []
	for a in 4:
		for b in 4:
			for c in 4:
				for d in 4:
					var combo := [a, b, c, d]
					all_states.append(combo)
					if energy_trace(model, combo)["reached"]:
						solving[combo_key(combo)] = combo
	check(solving.size() > 0, "independent trace finds at least one solving orientation")
	var self_report: Dictionary = m.validate_orientations()
	var self_solving: Dictionary = {}
	for s in self_report["solving"]:
		self_solving[combo_key(s)] = true
	check(self_report["total"] == 256 and solving.size() == self_solving.size(), "module and independent model agree on solving count (%d vs %d)" % [solving.size(), self_solving.size()])
	for k in solving:
		check(self_solving.has(k), "module solving set contains independent solution %s" % [solving[k]])
	var initial: Array = m.get_orientations()
	check(not solving.has(combo_key(initial)), "initial orientation %s is not already solved" % [initial])
	check(not energy_trace(model, initial)["reached"], "initial layout does not connect source to altar")
	var last_flow := {"prefix": -1, "reached": false}
	m.flow_changed.connect(func(prefix: int, reached: bool): last_flow["prefix"] = prefix; last_flow["reached"] = reached)
	# Reentry: a second press while a panel turns is refused; only one quarter turn happens.
	var dummy: Node = fx["player"]
	var before: Array = m.get_orientations()
	check(m.get_panel_interactable(0).interact(dummy), "first panel press accepted")
	check(m.is_rotating(), "panel is rotating right after the press")
	check(not m.get_panel_interactable(1).interact(dummy), "other panel refused while one is rotating")
	check(not m.get_panel_interactable(0).interact(dummy), "same panel refused while rotating")
	check(not m.rotate_panel(2), "rotate_panel refused while rotating")
	await settle(m)
	var after: Array = m.get_orientations()
	check(after[0] == (before[0] + 1) % 4 and after.slice(1) == before.slice(1), "reentry produced exactly one quarter turn: %s -> %s" % [before, after])
	# All 256 combinations: single instance through every non-solving state (BFS avoiding solving ones), then solved ones.
	var visited: Dictionary = {}
	var cur: Array = m.get_orientations()
	visited[combo_key(cur)] = true
	var verify := func(orients: Array, label: String) -> void:
		var want := energy_trace(model, orients)
		check(arr_eq(m.get_orientations(), orients), "%s: orientations %s expected %s" % [label, m.get_orientations(), orients])
		check(last_flow["prefix"] == want["prefix"], "%s %s: flow prefix %s, independent %s" % [label, orients, last_flow["prefix"], want["prefix"]])
		check(m.is_solved() == bool(want["reached"]), "%s %s: is_solved %s, independent %s" % [label, orients, m.is_solved(), want["reached"]])
	for target in all_states:
		var k := combo_key(target)
		if solving.has(k) or visited.has(k):
			continue
		for panel in press_path(cur, target, solving):
			var ok: bool = m.get_panel_interactable(panel).interact(dummy)
			check(ok, "press panel %d accepted while unsolved" % panel)
			await settle(m)
			cur = m.get_orientations()
			visited[combo_key(cur)] = true
			verify.call(cur, "walk")
		check(not m.is_solved() and not session_solved(fx), "non-solving combination %s must not open the seal" % [target])
	check(visited.size() + solving.size() == 256, "non-solving walk covered %d + %d solving = 256 combinations" % [visited.size(), solving.size()])
	await free_fixture(fx)
	for k in solving:
		var fx2 := await make_fixture(ENERGY_SCENE)
		var m2 = fx2["module"]
		var dummy2: Node = fx2["player"]
		var path := press_path(m2.get_orientations(), solving[k], solving)
		var seen_solved_early := false
		for i in path.size():
			var accepted: bool = m2.get_panel_interactable(path[i]).interact(dummy2)
			check(accepted, "solving walk press accepted")
			await settle(m2)
			if i < path.size() - 1 and m2.is_solved():
				seen_solved_early = true
		check(not seen_solved_early, "solved before reaching %s" % [solving[k]])
		check(m2.is_solved(), "solving combination %s opens the seal" % [solving[k]])
		check(session_solved(fx2), "solved progress recorded for %s" % [solving[k]])
		check(not (fx2["session"] as Node).is_collected(ENERGY), "solving does not collect the artifact")
		var frozen: Array = m2.get_orientations()
		check(not m2.get_panel_interactable(0).interact(dummy2) and not m2.rotate_panel(1), "panels are locked after solving")
		await settle(m2)
		check(arr_eq(m2.get_orientations(), frozen), "orientations unchanged after the lock")
		visited[k] = true
		await free_fixture(fx2)
	check(visited.size() == 256, "all 256 orientation combinations verified (%d)" % visited.size())

	# Real game: real interactor presses, solved-but-uncollected persistence.
	var g := await new_game()
	var gm = g.objectives.get_node("EnergyPath")
	check(await unreachable(g, gm.get_artifact(), RING), "sealed energy artifact is not targetable")
	# Same-frame double E on a panel: reentry through the real interactor turns it once.
	var base_o: Array = gm.get_orientations()
	check(await reach(g, gm.get_panel_interactable(0), NEAR), "interactor reaches panel 1")
	press_e(g)
	press_e(g)
	await settle(gm)
	var turned: Array = gm.get_orientations()
	check(turned[0] == (base_o[0] + 1) % 4, "double E in one frame turns panel 1 once (%s -> %s)" % [base_o, turned])
	await puzzle_persistence(g, gm, ENERGY, &"energy_path", Callable(self, "solve_energy").bind([], solving), ENERGY_SCENE)
	await end_game(g)


func session_solved(fx: Dictionary) -> bool:
	return (fx["session"] as Node).puzzle_progress.get(&"energy_path", false) == true


func solve_energy(g: Node, m: Node, goal: Array, solving: Dictionary) -> void:
	# Pick the solution closest to the current orientations, then press the real interactables.
	var best: Array = []
	for k in solving:
		var route := press_path(m.get_orientations(), solving[k], {})
		if best.is_empty() or route.size() < best.size():
			best = route
	for panel in best:
		await use(g, m.get_panel_interactable(panel))
		await settle(m)


# ============================================================================================================ artifact orders

func test_artifact_orders() -> void:
	var signatures: Array[String] = []
	for order in permutations([0, 1, 2]):
		var g := await new_game()
		var p = g.player
		var s = g.session
		var sym = g.objectives.get_node("SymbolPillars")
		var eng = g.objectives.get_node("EnergyPath")
		var sum = g.objectives.get_node("SummitRoute")
		var label := "order %s" % [order]
		var potions0: int = p.potion_count
		var arena = g.boss.get_arena()
		var picked: Array[StringName] = []
		for which in order:
			if which == 0:
				check(await unreachable(g, sym.get_artifact(), RING), "%s: sealed forest artifact untargetable" % label)
				await solve_symbol(g, sym)
				check(await use(g, sym.get_artifact(), RING), "%s: forest artifact picked up through the interactor" % label)
				picked.append(FOREST)
			elif which == 1:
				check(await unreachable(g, eng.get_artifact(), RING), "%s: sealed energy artifact untargetable" % label)
				var model := energy_model(eng)
				var solving: Dictionary = {}
				for a in 4:
					for b in 4:
						for c in 4:
							for d in 4:
								var combo := [a, b, c, d]
								if energy_trace(model, combo)["reached"]:
									solving[combo_key(combo)] = combo
				await solve_energy(g, eng, [], solving)
				check(eng.is_solved(), "%s: energy puzzle solved" % label)
				check(await use(g, eng.get_artifact(), RING), "%s: energy artifact picked up through the interactor" % label)
				picked.append(ENERGY)
			else:
				check(await use(g, sum.get_artifact(), RING), "%s: summit artifact picked up without any puzzle prerequisite" % label)
				picked.append(SUMMIT)
			# Entitlement after each pickup: sockets accept only collected artifacts, altar needs all three installed.
			for id in ARTIFACTS:
				check(arena.consoles[id].can_interact(p) == picked.has(id), "%s: socket %s interactable=%s after %s" % [label, id, picked.has(id), picked])
			check(not arena.altar.can_interact(p), "%s: altar locked before installation" % label)
			check(s.count_kind(&"artifact") == picked.size(), "%s: collected %d artifacts after %s" % [label, s.count_kind(&"artifact"), picked])
		check(s.collected_ids.size() == 3 and s.count_kind(&"artifact") == 3, "%s: exactly three distinct artifacts, no duplicates (%s)" % [label, s.collected_ids.keys()])
		for id in ARTIFACTS:
			check(s.is_collected(id), "%s: %s collected" % [label, id])
		check(p.potion_count == potions0, "%s: artifact pickups do not change potions" % label)
		# Pressing E again at each pickup spot cannot duplicate anything.
		for node in [sym.get_artifact(), eng.get_artifact(), sum.get_artifact()]:
			check(await unreachable(g, node, RING), "%s: collected pickup is not targetable again" % label)
		check(s.collected_ids.size() == 3, "%s: still three after revisiting" % label)
		# Install in the same order; altar becomes available only after the third.
		var installed := 0
		for which in order:
			var id: StringName = ARTIFACTS[which]
			var console = arena.consoles[id]
			check(await use(g, console, [Vector3(0, 0, 1.3), Vector3(0, 0, 1.8), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]), "%s: socket %s reached" % [label, id])
			installed += 1
			check(s.puzzle_progress.get(&"gatekeeper_sockets", {}).has(id), "%s: %s installed in session" % [label, id])
			check(arena.altar.can_interact(p) == (installed == 3), "%s: altar interactable only with all three installed (n=%d)" % [label, installed])
		var sockets: Array = s.puzzle_progress[&"gatekeeper_sockets"].keys()
		sockets.sort()
		var coll: Array = s.collected_ids.keys()
		coll.sort()
		signatures.append("%s|%s|%s|%s" % [sockets, coll, arena.altar.can_interact(p), g.boss.get_mode_name()])
		await end_game(g)
	for sig in signatures:
		check(sig == signatures[0], "gate entitlement identical for every pickup order (%s vs %s)" % [sig, signatures[0]])


# ============================================================================================================ summit state

func test_summit_state() -> void:
	var g := await new_game()
	var p = g.player
	var s = g.session
	var m = g.objectives.get_node("SummitRoute")
	var decks: Array = m.find_children("BridgeDeck_*", "StaticBody3D", true, false)
	check(decks.size() > 0, "bridge has deck bodies")
	var closed := true
	for d in decks:
		closed = closed and (d as StaticBody3D).collision_layer == 0
	check(closed and not m.is_shortcut_open(), "bridge deck has no collision before the lever")
	check(not s.puzzle_progress.get(&"symbol_pillars", false) and not s.puzzle_progress.get(&"energy_path", false), "no puzzle solved at start")
	check(await use(g, m.get_artifact(), RING), "summit artifact reachable without solving either puzzle")
	check(s.is_collected(SUMMIT) and s.collected_ids.size() == 1, "summit artifact collected once")
	var enemies: Array = m.get_enemies()
	check(enemies.size() == 3, "summit has three guards")
	var foot: Node = enemies[0]
	var foot_id: StringName = foot.enemy_id
	var guard_id: StringName = enemies[1].enemy_id
	foot.get_node("Health").apply_damage(100000)
	check(s.killed_enemy_ids.has(foot_id) and not s.killed_enemy_ids.has(guard_id), "killing one guard is recorded for that guard only")
	var lever: Node3D = m.get_node("Interact_Lever")
	check(await use(g, lever, [Vector3(0, 0, 1.2), Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 0)]), "lever reachable through the interactor")
	await frames(3)
	check(m.is_shortcut_open() and s.puzzle_progress.get(&"summit_shortcut", false) == true, "lever opens the shortcut and records it")
	var opened := false
	for i in 240:
		opened = true
		for d in decks:
			opened = opened and (d as StaticBody3D).collision_layer != 0
		if opened:
			break
		await physics_frame
	check(opened, "bridge deck collision enabled once open")
	check(await kill_player(g), "respawn after death at the summit")
	check(m.is_shortcut_open() and s.puzzle_progress.get(&"summit_shortcut", false) == true, "shortcut stays open after respawn")
	check((not is_instance_valid(foot) or foot.get_node("Health").is_dead) and s.killed_enemy_ids.has(foot_id), "defeated guard stays dead after respawn")
	check(not enemies[1].get_node("Health").is_dead, "other guards were not killed by respawn")
	check(s.is_collected(SUMMIT) and s.count_kind(&"artifact") == 1, "summit artifact stays collected after respawn")
	var again: Node3D = (load(SUMMIT_SCENE) as PackedScene).instantiate()
	again.position = m.position
	g.objectives.add_child(again)
	again.setup(p, s)
	await frames(3)
	check(again.is_shortcut_open(), "rebuilt summit from the same session shows the open shortcut")
	var ids: Array = []
	for e in again.get_enemies():
		ids.append(e.enemy_id)
	check(not ids.has(foot_id) and ids.size() == 2, "rebuilt summit does not respawn the defeated guard (%s)" % [ids])
	check(not again.get_artifact().visible, "rebuilt summit hides the collected artifact")
	again.queue_free()
	await end_game(g)


# ============================================================================================================ boss

func boss_player_state(p: Node) -> Dictionary:
	return {"hp": p.get_health().current_health, "stamina": p.stamina, "potions": p.potion_count}


## Presses the real potion action like a player would: repeats the press until the channel starts (the player refuses
## while landing), then waits for the channel to complete and consume exactly one potion.
func drink(g: Node) -> bool:
	var p = g.player
	var before: int = p.potion_count
	for attempt in 16:
		var ev := InputEventAction.new()
		ev.action = &"potion"
		ev.pressed = true
		p._unhandled_input(ev)
		await frames(15)
		if p.is_drinking() or p.potion_count < before:
			break
	return await until(func(): return p.potion_count == before - 1 and not p.is_drinking(), 4.0)


## Uses a potion at the retry point. The retry point must be standable (a player restored there has to be able to act); if
## it is not, that is reported as its own failure and the potion is spent by direct setup so the rest of the flow still runs.
func spend_potion(g: Node, enc: Node) -> bool:
	var p = g.player
	await teleport(g, enc.get_retry_point())
	var standable: bool = await until(func(): return p.is_on_floor(), 1.5)
	check(standable, "retry point %s is standable (player on floor, not embedded in other geometry); y=%.2f" % [enc.get_retry_point(), p.global_position.y])
	if standable:
		return await drink(g)
	p.potion_count -= 1
	p.get_health().heal(40)
	return true

## Puts the player in front of the boss and forces slams until the real hit path (telegraph polygon ->
## player.receive_damage) kills it. Returns true when the player died.
var _saw_telegraph := false


func boss_kills_player(g: Node, enc: Node) -> bool:
	var p = g.player
	var ticks := 60 * 60
	for i in ticks:
		if p.is_dead():
			return true
		if enc.get_mode_name() == &"fighting":
			var body: Node3D = enc.get_boss()
			var spot: Vector3 = body.global_position + body.global_basis.z * 3.0
			p.global_position = Vector3(spot.x, body.global_position.y + 0.1, spot.z)
			p.velocity = Vector3.ZERO
			if enc.get_attack_state() == &"windup" and enc.is_telegraph_visible():
				_saw_telegraph = true
			if enc.get_attack_state() == &"pause":
				enc.force_attack(&"slam")
		await physics_frame
	return p.is_dead()


func test_boss() -> void:
	var g := await new_game()
	var p = g.player
	var s = g.session
	var enc = g.boss
	var arena = enc.get_arena()
	var altar_offsets: Array = [Vector3(0, 0, 2.0), Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0), Vector3(0, 0, 2.4)]
	var socket_offsets: Array = [Vector3(0, 0, 1.3), Vector3(0, 0, 1.8), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]
	# Setup (documented): artifacts claimed (pickup path covered elsewhere), exact resources for the 70/45/5 snapshot.
	for id in ARTIFACTS:
		check(s.claim(id, &"artifact"), "setup: claim %s" % id)
	p.stamina_regen = 0.0
	check(p.add_potions(2) == 2 and p.potion_count == 5, "setup: five potions")
	check(p.receive_damage(30) and p.get_health().current_health == 70, "setup: HP 70 through receive_damage")
	p.stamina = 45.0
	check(enc.get_mode_name() == &"dormant", "boss dormant at start")
	check(not arena.altar.can_interact(p), "altar refuses before sockets are installed")
	for id in ARTIFACTS:
		check(await use(g, arena.consoles[id], socket_offsets), "install %s through the interactor" % id)
		check(s.puzzle_progress[&"gatekeeper_sockets"].has(id), "%s recorded as installed" % id)
	check(enc.get_mode_name() == &"dormant", "installing artifacts does not start the fight")
	check(await use(g, arena.altar, altar_offsets), "altar reached through the interactor")
	check(enc.get_mode_name() == &"waking", "altar starts the wake sequence")
	check(await until(func(): return enc.get_mode_name() == &"fighting", 8.0), "boss reaches the fight")
	var snap: Dictionary = enc.get_snapshot()
	check(snap.get("hp", -1) == 70 and is_equal_approx(float(snap.get("stamina", -1.0)), 45.0) and snap.get("potions", -1) == 5, "snapshot is exactly 70/45/5, got %s" % [snap])
	var health: Node = enc.get_boss_health()
	var max_hp: int = health.max_health
	var started_before: bool = s.puzzle_progress.get(&"gatekeeper_started", false)
	check(started_before, "session records that the fight began")
	var start_pos: Vector3 = enc.get_boss().global_position

	for attempt in [1, 2, 3]:
		check(enc.attempt == attempt, "attempt counter is %d (got %d)" % [attempt, enc.attempt])
		check(health.current_health == max_hp and enc.phase == 1, "attempt %d starts at full boss HP, phase 1" % attempt)
		# Spend a potion for real in the failed attempt (safe retry point, outside every attack volume).
		check(await spend_potion(g, enc), "attempt %d: potion consumed (%d left)" % [attempt, p.potion_count])
		check(p.potion_count == 4 and p.get_health().current_health > 70, "attempt %d: potion used and healed (%s)" % [attempt, boss_player_state(p)])
		if attempt == 2:
			# Phase threshold: 51% -> phase 1, exactly 50% -> phase 2.
			health.apply_damage(max_hp / 2 - 1)
			check(enc.phase == 1 and health.current_health == max_hp - (max_hp / 2 - 1), "just above 50%% stays in phase 1 (%d/%d)" % [health.current_health, max_hp])
			health.apply_damage(1)
			check(enc.phase == 2 and health.current_health * 2 == max_hp, "exactly 50%% enters phase 2")
		# Death by real boss attacks.
		_saw_telegraph = false
		await teleport(g, enc.get_boss().global_position + enc.get_boss().global_basis.z * 3.0)
		check(await boss_kills_player(g, enc), "attempt %d: boss attacks kill the player" % attempt)
		check(_saw_telegraph, "attempt %d: a visible telegraph preceded the damage" % attempt)
		check(await until(func(): return enc.get_mode_name() == &"rearmed", 10.0), "attempt %d: boss rearms after respawn" % attempt)
		await frames(3)
		var now := boss_player_state(p)
		check(now["hp"] == 70 and is_equal_approx(float(now["stamina"]), 45.0) and now["potions"] == 5, "attempt %d: restored exactly to snapshot 70/45/5, got %s" % [attempt, now])
		check(arr_eq([enc.get_snapshot().get("hp"), enc.get_snapshot().get("potions")], [snap["hp"], snap["potions"]]), "attempt %d: same snapshot reused" % attempt)
		check(not p.is_dead() and not [&"dead", &"attack", &"dodge", &"drink", &"block"].has(p.get_action_state()), "attempt %d: player transient state cleared (%s)" % [attempt, p.get_action_state()])
		check(p.global_position.distance_to(enc.get_retry_point()) < 1.5, "attempt %d: player at the safe retry point" % attempt)
		check(health.current_health == max_hp and enc.phase == 1 and not health.is_dead, "attempt %d: boss full HP and phase 1 after retry" % attempt)
		check(enc.get_attack_kind() == &"" and enc.get_attack_state() == &"pause" and not enc.is_telegraph_visible(), "attempt %d: no attack transient survives (state %s, telegraph %s)" % [attempt, enc.get_attack_state(), enc.is_telegraph_visible()])
		check(enc.get_boss().global_position.distance_to(start_pos) < 0.6, "attempt %d: boss back at its home pose" % attempt)
		check(get_nodes_in_group(&"enemy_projectiles").is_empty(), "attempt %d: no projectiles" % attempt)
		for id in ARTIFACTS:
			check(s.is_collected(id) and s.puzzle_progress[&"gatekeeper_sockets"].has(id), "attempt %d: %s still collected and installed (no reinstall)" % [attempt, id])
		check(s.collected_ids.size() == 3, "attempt %d: no duplicated artifacts" % attempt)
		# Retry needs only the altar: no wake animation, no reinstall.
		check(await use(g, arena.altar, altar_offsets), "attempt %d: altar usable for retry" % attempt)
		if attempt < 3:
			check(enc.get_mode_name() == &"fighting", "attempt %d: retry begins the fight at once, no wake animation (%s)" % [attempt, enc.get_mode_name()])
		else:
			check(enc.get_mode_name() == &"fighting" and enc.attempt == 4, "final retry begins the fight (%s, attempt %d)" % [enc.get_mode_name(), enc.attempt])
	# Victory: the last attempt keeps whatever it ended with; snapshot is dropped and never applied again.
	check(await spend_potion(g, enc), "victory attempt: potion consumed")
	var kept := boss_player_state(p)
	check(kept["potions"] == 4 and kept["hp"] > 70, "victory attempt differs from the snapshot (%s)" % [kept])
	var wins := [0]
	var completions := [0]
	enc.encounter_won.connect(func(): wins[0] += 1)
	enc.completed.connect(func(): completions[0] += 1)
	health.apply_damage(health.current_health)
	check(enc.get_mode_name() == &"won" and wins[0] == 1, "boss death gives victory exactly once")
	check(enc.get_snapshot().is_empty() and not s.puzzle_progress.has(&"gatekeeper_snapshot"), "snapshot dropped on victory")
	var after_win := boss_player_state(p)
	check(after_win["hp"] == kept["hp"] and after_win["potions"] == kept["potions"], "victory keeps the remaining resources (%s vs %s)" % [after_win, kept])
	await teleport(g, enc.to_global(Vector3(0, 0.3, -21)))
	await frames(30)
	check(completions[0] == 0, "no completion while the gate is still sealed")
	await teleport(g, enc.get_retry_point())
	# Dying after victory is an ordinary respawn: full HP/stamina, kept potions; the snapshot is NOT applied.
	check(await kill_player(g), "post-victory death respawns")
	await frames(3)
	var respawned := boss_player_state(p)
	check(respawned["hp"] == p.max_hp and respawned["hp"] != 70, "post-victory respawn heals fully, not back to 70 (%s)" % [respawned])
	check(is_equal_approx(float(respawned["stamina"]), p.max_stamina) and float(respawned["stamina"]) != 45.0, "post-victory stamina is full, not snapshot 45")
	check(respawned["potions"] == 4, "post-victory potions keep the victory count 4, not snapshot 5 (%s)" % [respawned])
	check(enc.get_mode_name() == &"won" and health.is_dead, "boss stays defeated after the player's later death")
	check(await until(func(): return s.puzzle_progress.get(&"gatekeeper_gate_open", false) == true, 12.0), "gate opens after the victory sequence")
	# Completion fires once when the player crosses into the dock.
	await teleport(g, enc.to_global(Vector3(0, 0.3, -21)))
	check(await until(func(): return completions[0] >= 1, 3.0), "crossing the open gate completes the level")
	paused = false
	await teleport(g, enc.get_retry_point())
	await frames(10)
	await teleport(g, enc.to_global(Vector3(0, 0.3, -21)))
	await frames(30)
	paused = false
	check(completions[0] == 1, "completion emitted exactly once (got %d)" % completions[0])
	await end_game(g)


# ============================================================================================================ new run

func test_new_run() -> void:
	var g := await new_game()
	var old_id := g.get_instance_id()
	var p = g.player
	var s = g.session
	# Dirty the first run through real interactions: puzzle, artifact, potion use, death, checkpoint.
	var sym = g.objectives.get_node("SymbolPillars")
	await solve_symbol(g, sym)
	check(await use(g, sym.get_artifact(), RING), "dirty run: forest artifact collected")
	var camp: Node3D = g.terrain.get_node("CampCheckpoint")
	check(await use(g, camp, NEAR), "dirty run: camp checkpoint activated")
	var potion_id: StringName = g.terrain.layout["potions"][0]["id"]
	var potion: Node3D = null
	for node in g.terrain.get_children():
		if node.get("pickup_id") == potion_id:
			potion = node
	if potion != null:
		await use(g, potion, NEAR)
	var sum = g.objectives.get_node("SummitRoute")
	(sum.get_enemies()[0] as Node).get_node("Health").apply_damage(100000)
	check(s.collected_ids.size() >= 1 and s.killed_enemy_ids.size() >= 1 and s.checkpoint_id != &"", "dirty run has progress to inherit")
	check(await kill_player(g), "dirty run: died once")
	g.presentation.new_run_requested.emit(777, true)
	var fresh: Node = null
	for i in 600:
		await physics_frame
		for child in root.get_children():
			if child.get_instance_id() != old_id and child.get("island_seed") != null and child.get("session") != null and child.get("boss") != null:
				fresh = child
		if fresh != null:
			break
	check(fresh != null, "new run scene appears")
	if fresh == null:
		return
	await frames(6)
	quiet_enemies()
	var old_node = instance_from_id(old_id)
	check(old_node == null or (old_node as Node).is_queued_for_deletion() or not (old_node as Node).is_inside_tree(), "old run is discarded")
	var ns = fresh.session
	check(ns != s, "new run owns a new session object")
	check(ns.collected_ids.is_empty() and ns.killed_enemy_ids.is_empty(), "new session has no collected/killed ids")
	check(ns.checkpoint_id == &"" and not ns.is_respawn_pending(), "new session has no checkpoint or pending respawn")
	for key in [&"symbol_pillars", &"energy_path", &"summit_shortcut", &"gatekeeper_started", &"gatekeeper_defeated", &"gatekeeper_gate_open", &"gatekeeper_snapshot"]:
		check(not ns.puzzle_progress.get(key, false), "new session has no %s" % key)
	var ninstalled: Dictionary = ns.puzzle_progress.get(&"gatekeeper_sockets", {})
	check(ninstalled.is_empty(), "new run has no installed sockets")
	check(not fresh.objectives.get_node("SymbolPillars").is_solved(), "new symbol puzzle unsolved")
	check(fresh.objectives.get_node("SymbolPillars").get_artifact().visible, "new run shows the artifact pickup")
	check(fresh.objectives.get_node("SummitRoute").get_enemies().size() == 3 and not fresh.objectives.get_node("SummitRoute").is_shortcut_open(), "new summit has all guards and a closed shortcut")
	check(fresh.boss.get_mode_name() == &"dormant" and fresh.boss.get_snapshot().is_empty(), "new boss dormant without snapshot")
	var np = fresh.player
	check(np.potion_count == 3 and np.get_health().current_health == np.max_hp and not np.is_dead(), "new player has starting resources")
	check(np.global_position.distance_to(fresh.get_world_anchor(&"spawn")) < 2.5, "new player starts at the spawn anchor")
	check(fresh.terrain.requested_seed == 777 and fresh.terrain.procedural, "new run uses the requested seed")
	check(not paused, "tree is not left paused")
	await end_game(fresh)


# ============================================================================================================ seed matrix

func terrain_signature(t: Node) -> String:
	var acc := PackedStringArray()
	acc.append("%d|%s|%d" % [t.active_seed, t.used_fallback, t.generation_attempts])
	var hs := PackedFloat32Array()
	for ix in 41:
		for iz in 41:
			hs.append(snappedf(t.height_at(-125.0 + ix * 6.25, -125.0 + iz * 6.25), 0.001))
	acc.append(str(hash(hs)))
	for name in t.route_names():
		var pts: PackedVector3Array = t.get_route_points(name)
		acc.append("%s:%d:%d" % [name, pts.size(), hash(pts)])
	var obs := PackedFloat32Array()
	for o in t.get_obstacles():
		obs.append(o["pos"].x)
		obs.append(o["pos"].y)
		obs.append(o["r"])
	acc.append("obs:%d:%d" % [obs.size(), hash(obs)])
	acc.append("layout:%d" % hash(str(t.layout)))
	return ";".join(acc)


func make_terrain(seed_value: int, procedural: bool) -> Node3D:
	var t: Node3D = TERRAIN_SCRIPT.new()
	t.configure(seed_value, procedural)
	t.generate_data()
	return t


## Module footprints (module-local extents from each module's header) placed at the terrain's own anchors.
func module_rects(t: Node3D) -> Dictionary:
	var a: Dictionary = t.layout["anchors"]
	var sy: Vector3 = a[&"symbol"]
	var en: Vector3 = a[&"energy"]
	var su: Vector3 = a[&"summit"]
	var bo: Vector3 = a[&"boss"]
	return {
		&"symbol": Rect2(sy.x - 12, sy.z - 12, 24, 24), &"energy": Rect2(en.x - 9, en.z - 7, 18, 14),
		&"summit": Rect2(su.x - 25, su.z - 22, 50, 44), &"boss": Rect2(bo.x - 18, bo.z - 15, 36, 30),
	}


func check_terrain_constraints(t: Node3D, label: String) -> void:
	var T = TERRAIN_SCRIPT
	var rep: Dictionary = t.last_report
	check(rep["valid"] == true, "%s: layout reports valid (%s)" % [label, rep["errors"]])
	# Anchors fixed for every seed and on y = 0.
	var anchors: Dictionary = t.layout["anchors"]
	for name in [&"spawn", &"symbol", &"energy", &"summit", &"boss"]:
		check(anchors.has(name) and anchors[name] is Vector3, "%s: layout has anchor %s" % [label, name])
	for name in anchors:
		var a: Vector3 = anchors[name]
		if name == &"dock_end":
			# Out over water: its surface is the dock deck (boss + 6..22 m toward -Z, 8 m wide, top y 0.03), not the heightfield.
			# make_terrain builds data only (no nodes), so assert the anchor sits on that deck footprint.
			var off: Vector3 = a - (anchors[&"boss"] as Vector3)
			check(absf(off.x) <= 4.0 and off.z <= -6.0 + 0.01 and off.z >= -22.0 - 0.01, "%s: anchor dock_end lies on the dock deck footprint" % label)
			continue
		check(absf(t.height_at(a.x, a.z) - a.y) <= T.PAD_FLAT_TOLERANCE, "%s: anchor %s stands on the terrain surface" % [label, name])
	check(t.layout["camp"] is Vector3 and t.layout["encounters"].size() > 0 and t.layout["potions"].size() > 0, "%s: layout has camp, encounters and potions" % label)
	var ids := {}
	var placed: Array = [{"id": &"camp", "position": t.layout["camp"]}]
	placed.append_array(t.layout["encounters"])
	placed.append_array(t.layout["potions"])
	for entry: Dictionary in placed:
		var pos: Vector3 = entry["position"]
		var ground: float = t.height_at(pos.x, pos.z)
		check(not ids.has(entry["id"]), "%s: layout id %s is unique" % [label, entry["id"]])
		ids[entry["id"]] = true
		check(pos.y >= ground - 0.3 and pos.y <= ground + 2.0, "%s: %s at y=%.2f is neither buried nor floating over ground %.2f" % [label, entry["id"], pos.y, ground])
		check(t.is_dry_at(pos.x, pos.z), "%s: %s is on dry land" % [label, entry["id"]])
	# Routes: slope along the centerline and lateral edges measured by this runner from height_at.
	var worst := 0.0
	var worst_edge := 0.0
	var min_h := 99.0
	for name in t.route_names():
		var pts: PackedVector3Array = t.get_route_points(name)
		check(pts.size() >= 2, "%s: route %s has points" % [label, name])
		for i in range(pts.size() - 1):
			var a2 := Vector2(pts[i].x, pts[i].z)
			var b2 := Vector2(pts[i + 1].x, pts[i + 1].z)
			var length := a2.distance_to(b2)
			var steps := maxi(1, int(length))
			var dir := (b2 - a2).normalized()
			var side := Vector2(-dir.y, dir.x)
			var last_c: float = t.height_at(a2.x, a2.y)
			var last_l: float = t.height_at(a2.x + side.x * 4.5, a2.y + side.y * 4.5)
			var last_r: float = t.height_at(a2.x - side.x * 4.5, a2.y - side.y * 4.5)
			for k in range(1, steps + 1):
				var q := a2.lerp(b2, float(k) / steps)
				var step_len := length / steps
				var hc: float = t.height_at(q.x, q.y)
				var hl: float = t.height_at(q.x + side.x * 4.5, q.y + side.y * 4.5)
				var hr: float = t.height_at(q.x - side.x * 4.5, q.y - side.y * 4.5)
				worst = maxf(worst, rad_to_deg(atan2(absf(hc - last_c), step_len)))
				worst_edge = maxf(worst_edge, maxf(rad_to_deg(atan2(absf(hl - last_l), step_len)), rad_to_deg(atan2(absf(hr - last_r), step_len))))
				min_h = minf(min_h, hc)
				last_c = hc
				last_l = hl
				last_r = hr
	check(worst <= T.ROUTE_MAX_SLOPE_DEG + 0.5, "%s: route centerline slope %.1f deg <= %.1f" % [label, worst, T.ROUTE_MAX_SLOPE_DEG])
	check(worst_edge <= T.ROUTE_EDGE_MAX_SLOPE_DEG + 0.5, "%s: route edge slope %.1f deg <= %.1f" % [label, worst_edge, T.ROUTE_EDGE_MAX_SLOPE_DEG])
	check(min_h >= T.ROUTE_MIN_HEIGHT - 0.05, "%s: routes stay above the waterline (min %.2f)" % [label, min_h])
	# Objective pads flat; module footprints flat where the module floor sits.
	for name in [&"spawn", &"symbol", &"energy", &"summit", &"boss"]:
		var c: Vector3 = t.layout["anchors"][name]
		for k in 12:
			var ang := TAU * k / 12.0
			var h: float = t.height_at(c.x + cos(ang) * 3.0, c.z + sin(ang) * 3.0)
			check(absf(h - c.y) <= 0.05, "%s: pad %s flat at angle %d (%.3f vs anchor %.3f)" % [label, name, k, h, c.y])
	var rects := module_rects(t)
	for name in rects:
		var r: Rect2 = rects[name]
		var base_y: float = (t.layout["anchors"][name] as Vector3).y
		var x := r.position.x
		while x <= r.end.x:
			var z := r.position.y
			while z <= r.end.y:
				var h2: float = t.height_at(x, z)
				check(absf(h2 - base_y) <= 1.5, "%s: %s footprint ground near the anchor level %.2f at (%.0f,%.0f): %.2f" % [label, name, base_y, x, z, h2])
				z += 6.0
			x += 6.0
	# Solid decoration never blocks a route corridor nor sits in a module footprint.
	for o in t.get_obstacles():
		var pos: Vector2 = o["pos"]
		var rad: float = o["r"]
		check(t.route_distance(pos.x, pos.y) - rad >= T.ROUTE_HALF_WIDTH - 1.0, "%s: obstacle at %s blocks a route corridor" % [label, pos])
		for name in rects:
			check(not (rects[name] as Rect2).grow(rad).has_point(pos), "%s: obstacle at %s inside %s footprint" % [label, pos, name])


func test_seed_matrix() -> void:
	var full := has_flag("seeds-full")
	var baseline := make_terrain(1, false)
	var baseline_layout := str(baseline.layout)
	var baseline_sig := terrain_signature(baseline)
	var other := make_terrain(99999, false)
	check(terrain_signature(other) == baseline_sig, "non-procedural runs ignore the seed (baseline layout)")
	other.free()
	check_terrain_constraints(baseline, "baseline")
	var signatures: Dictionary = {}
	var fallbacks := 0
	for sd in range(1, 21):
		var a := make_terrain(sd, true)
		var b := make_terrain(sd, true)
		var sig_a := terrain_signature(a)
		check(sig_a == terrain_signature(b), "seed %d: two generations are identical (deterministic)" % sd)
		signatures[sig_a] = true
		var attempts_log: Array = a.attempt_log
		check(a.generation_attempts == attempts_log.size() and attempts_log.size() >= 1 and attempts_log.size() <= TERRAIN_SCRIPT.MAX_ATTEMPTS + 1, "seed %d: attempt log consistent (%d)" % [sd, attempts_log.size()])
		if a.used_fallback:
			fallbacks += 1
			check(a.active_seed == TERRAIN_SCRIPT.BASELINE_SEED, "seed %d: fallback uses the baseline seed" % sd)
			check(str(a.layout) == baseline_layout, "seed %d: fallback layout (anchors, encounters, potions, camp) equals the baseline layout" % sd)
			for i in range(attempts_log.size() - 1):
				check(attempts_log[i]["valid"] == false, "seed %d: attempt %d before fallback was invalid" % [sd, i])
		else:
			check(bool(attempts_log[attempts_log.size() - 1]["valid"]), "seed %d: accepted attempt is valid" % sd)
		check_terrain_constraints(a, "seed %d" % sd)
		a.free()
		b.free()
	check(signatures.size() >= 5, "seeds produce distinct layouts (%d distinct of 20, %d fallbacks)" % [signatures.size(), fallbacks])
	# Forced invalid layouts: every derived attempt rejected -> proven fallback, identical to the baseline.
	var forced := GDScript.new()
	forced.source_code = "extends \"res://scripts/world/island_terrain.gd\"\nfunc validate_layout() -> Dictionary:\n\tvar r := super()\n\tif active_seed != BASELINE_SEED:\n\t\tr[\"valid\"] = false\n\t\tr[\"errors\"].append(\"forced invalid\")\n\treturn r\n"
	check(forced.reload() == OK, "forced-invalid terrain script compiles")
	var ft: Node3D = forced.new()
	ft.configure(4242, true)
	ft.generate_data()
	check(ft.used_fallback and ft.active_seed == TERRAIN_SCRIPT.BASELINE_SEED, "all attempts invalid -> baseline fallback")
	check(ft.generation_attempts == TERRAIN_SCRIPT.MAX_ATTEMPTS + 1 and ft.attempt_log.size() == TERRAIN_SCRIPT.MAX_ATTEMPTS + 1, "fallback after %d rejected attempts" % TERRAIN_SCRIPT.MAX_ATTEMPTS)
	check(terrain_signature(ft).get_slice(";", 1) == baseline_sig.get_slice(";", 1), "fallback terrain equals the baseline terrain")
	check(ft.last_report["valid"] == true, "fallback layout is valid")
	ft.free()
	baseline.free()
	# Actual collision against height_at (needs the tree and a physics frame).
	var seeds: Array = range(1, 21) if full else [1, 7, 13]
	for sd in seeds:
		var holder := Node3D.new()
		root.add_child(holder)
		var t: Node3D = TERRAIN_SCRIPT.new()
		t.configure(sd, true)
		holder.add_child(t)
		await frames(3)
		var probe: Dictionary = t.probe_collision()
		check(probe["checked"] > 20 and probe["missed"] == 0, "seed %d: collision exists under every anchor/route sample (%s)" % [sd, probe])
		check(probe["max_error"] < 0.1, "seed %d: collision surface equals height_at (max error %.3f)" % [sd, probe["max_error"]])
		holder.queue_free()
		await frames(2)
