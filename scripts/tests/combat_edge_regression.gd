extends SceneTree
## Combat edge-case regression (P06-08 / P08-08 / A06 / A07 / A08 / A13): potion rules, i-frame boundaries, stamina thresholds and
## death/respawn hygiene, driven through the REAL player scene (scenes/world/island_game.tscn, start_in_menu = false).
##
## Run (Godot 4.7.2, from the project root):
##   C:/Godot/godot.exe --headless --fixed-fps 60 --path . --script res://scripts/tests/combat_edge_regression.gd
## Optional user args after `--`:   --only=potion,schedule,iframes,projectile,boss,stamina,guard,death
## Exit code 0 = every check passed, 1 = at least one failed. A summary is also written to user://test/combat_edge_regression.log.
##
## HOW IT DRIVES THE GAME
##  - Player actions (Q potion, Alt dodge, LMB attack, RMB block, E interact) are real InputEvents built from the project's own
##    InputMap events and sent with Input.parse_input_event. The only exception: "queued" presses that must still be outstanding
##    when the player dies are injected by calling the player's engine callback _unhandled_input() with InputEventAction (the exact
##    call the engine makes), because an Input-buffered event cannot be delivered between the flush and the physics tick.
##  - Enemy damage uses the real consumer interface: Player.receive_damage(int). Projectiles are the real enemy_projectile.gd
##    script instantiated with the same public properties Enemy._fire_projectile sets (the script has no configure() API). The boss
##    suite runs the real Gatekeeper encounter (artifacts claimed in the session, sockets/altar used through the Interactor
##    consumer interface) and forces real slams.
##  - Documented test setup (the ONLY direct state writes): enemy AI processing is off so teleports cannot start fights; HP is set
##    with Health.restore_full() + receive_damage(); stamina / potion_count / stamina_regen / rotation are assigned where a scenario
##    needs an exact starting resource; the player is teleported (never movement-driven); the tree is paused through the camera's
##    pause_game()/resume_game() (what the Esc overlay calls).
##  - NOT covered: animation/UI quality, enemy AI melee timing, fully input-driven movement, gamepad. This is not a playthrough.
##  - Nothing here asserts source text, wiring or "does not throw": every check reads HP / potions / stamina / enemy HP / states.

const GAME_SCENE := "res://scenes/world/island_game.tscn"
const PROJECTILE := preload("res://scripts/enemies/enemy_projectile.gd")
const DT := 1.0 / 60.0
const START := Vector3(0, 0.1, 85)

var _checks := 0
var _failed: Array[String] = []
var _suite := ""
var _args := PackedStringArray()
var _notes: Array[String] = []
var _drink_ticks := 0


## Collects every player signal so scenarios can assert on what the player/HUD would see.
class Probe extends RefCounted:
	var refused: Array[StringName] = []
	var drunk: Array[int] = []
	var cancelled := 0
	var damage: Array = []  ## [amount, blocked, physics frame]
	var died := 0
	var hits: Array = []  ## [damageable, amount]
	var swings := 0

	func _init(p: Node) -> void:
		p.action_refused.connect(func(a: StringName) -> void: refused.append(a))
		p.potion_drunk.connect(func(h: int) -> void: drunk.append(h))
		p.potion_cancelled.connect(func() -> void: cancelled += 1)
		p.damage_taken.connect(func(a: int, b: bool) -> void: damage.append([a, b, Engine.get_physics_frames()]))
		p.died.connect(func() -> void: died += 1)
		p.attack_hit.connect(func(d: Node, a: int) -> void: hits.append([d, a]))
		p.attack_started.connect(func() -> void: swings += 1)

	func clear() -> void:
		refused.clear()
		drunk.clear()
		cancelled = 0
		damage.clear()
		died = 0
		hits.clear()
		swings = 0


## Deterministic damage scheduler. Give it a process_priority below the player's (runs before the player's tick) or above (after).
class Striker extends Node:
	var player: Node
	var mode := &"count"  ## count | before | after
	var amount := 10
	var target_obs := 0  ## before: fire on the tick where the player was seen drinking for the target_obs-th time
	var delay := 0  ## after: ticks to wait after the player stopped drinking
	var obs := 0
	var fired := -1
	var result := false
	var _was := false
	var _wait := -1

	func _physics_process(_d: float) -> void:
		var drinking: bool = player.is_drinking()
		if drinking:
			obs += 1
		if fired < 0:
			if mode == &"before" and drinking and obs == target_obs:
				_fire()
			elif mode == &"after":
				if _wait < 0 and _was and not drinking:
					_wait = delay
				if _wait == 0:
					_fire()
				elif _wait > 0:
					_wait -= 1
		_was = drinking

	func _fire() -> void:
		fired = Engine.get_physics_frames()
		result = player.receive_damage(amount)


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_main.call_deferred()


func _main() -> void:
	var only := ""
	for a in _args:
		if a.begins_with("--only="):
			only = a.substr(7)
	var wanted := only.split(",", false)
	var suites: Array = [
		["potion", test_potion_basics], ["interrupt", test_potion_interrupts], ["pause", test_potion_pause],
		["schedule", test_potion_schedule], ["iframes", test_iframes_direct], ["projectile", test_iframes_projectile],
		["boss", test_iframes_boss], ["stamina", test_stamina], ["guard", test_guard_impact], ["death", test_death_hygiene],
	]
	for entry in suites:
		if not wanted.is_empty() and not wanted.has(entry[0]):
			continue
		_suite = entry[0]
		print("== suite %s" % _suite)
		await (entry[1] as Callable).call()
	var summary := "combat_edge_regression: %d checks, %d failed" % [_checks, _failed.size()]
	print("")
	print(summary)
	for line in _notes:
		print("  note: " + line)
	for line in _failed:
		print("  FAIL " + line)
	DirAccess.make_dir_recursive_absolute("user://test")
	var log := FileAccess.open("user://test/combat_edge_regression.log", FileAccess.WRITE)
	if log != null:
		log.store_line(summary)
		for line in _notes:
			log.store_line("note: " + line)
		for line in _failed:
			log.store_line("FAIL " + line)
		log.close()
	await shutdown_cleanly()
	quit(0 if _failed.is_empty() else 1)


func shutdown_cleanly() -> void:
	paused = false
	for child in root.get_children():
		child.queue_free()
	await frames(10)
	OS.delay_msec(500)
	await frames(10)


# ============================================================================================================ helpers

func check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failed.append("[%s] %s" % [_suite, msg])
		printerr("FAIL [%s] %s" % [_suite, msg])
	return cond


func note(msg: String) -> void:
	_notes.append("[%s] %s" % [_suite, msg])
	print("  note [%s] %s" % [_suite, msg])


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


func new_game() -> Node:
	var g: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	g.start_in_menu = false
	g.procedural = false  # Resource edge cases use the documented fixed START fixture.
	root.add_child(g)
	await frames(6)
	for e in get_nodes_in_group(&"enemies"):
		e.set_physics_process(false)  # documented setup: no AI fights while teleporting
	await until(func(): return g.player.is_on_floor(), 3.0)
	# The spawn drop triggers the Jump_Land state (0.67 s) in which the player refuses grounded actions.
	await frames(int(ceil(g.player.get_node("AnimationPlayer").get_animation(&"jump_land").length * 60.0)) + 6)
	return g


func end_game(g: Node) -> void:
	paused = false
	g.queue_free()
	await frames(3)


func hp(p: Node) -> int:
	return p.get_health().current_health


func idle_state(p: Node) -> bool:
	return not p.is_dead() and not p.is_attacking() and not p.is_dodging() and not p.is_drinking()


## Documented setup: waits for any action to end, then sets exact HP / potions / full stamina. Does not use any heal path.
func reset_state(p: Node, hp_value := 100, potions := 3) -> void:
	await until(func(): return idle_state(p) and p.is_on_floor(), 6.0)
	p.get_health().restore_full()
	if hp_value < p.get_health().max_health:
		p.receive_damage(p.get_health().max_health - hp_value)
	p.stamina = p.max_stamina
	p.potion_count = potions
	await frames(2)


func place(g: Node, pos: Vector3, yaw := 0.0) -> void:
	g.player.global_position = pos
	g.player.rotation.y = yaw
	g.player.velocity = Vector3.ZERO
	await frames(3)
	await until(func(): return g.player.is_on_floor(), 1.0)


func ev(action: StringName, pressed: bool) -> InputEvent:
	var source: InputEvent = InputMap.action_get_events(action)[0]
	var event: InputEvent = source.duplicate()
	if event is InputEventKey:
		(event as InputEventKey).pressed = pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		mb.pressed = pressed
		mb.position = root.get_visible_rect().size * 0.5
		mb.global_position = mb.position
		mb.button_mask = (1 << (mb.button_index - 1)) if pressed else 0
	return event


func down(action: StringName) -> void:
	Input.parse_input_event(ev(action, true))


func up(action: StringName) -> void:
	Input.parse_input_event(ev(action, false))


## One fresh press edge, released after `hold` physics frames.
func tap(action: StringName, hold := 2) -> void:
	down(action)
	await frames(hold)
	up(action)
	await frames(1)


## Presses the action and returns the physics frame on which `pred` first became true (-1 on timeout). The release is sent right after.
func press_until(action: StringName, pred: Callable, max_ticks := 30) -> int:
	down(action)
	var n := 0
	while not pred.call() and n < max_ticks:
		await physics_frame
		n += 1
	up(action)
	return Engine.get_physics_frames() if pred.call() else -1


## Starts a dodge with the real key. Returns the frame on which the player was first seen dodging: that is dodge age 1 tick.
func dodge_now(p: Node) -> int:
	return await press_until(&"dodge", func(): return p.is_dodging())


func start_drink(p: Node) -> bool:
	var frame := await press_until(&"potion", func(): return p.is_drinking())
	await frames(1)
	return frame >= 0


func wait_respawn(g: Node, seconds := 8.0) -> bool:
	return await until(func(): return not g.player.is_dead() and not g.session.is_respawn_pending(), seconds)


func spawn_projectile(g: Node, pos: Vector3, vel: Vector3, dmg: int, life := 8.0) -> Node3D:
	var shooter: Node = g.get_node("Enemies").get_child(2)  # the ranged guard: same shooter fields the real enemy sets
	var proj := Node3D.new()
	proj.set_script(PROJECTILE)
	proj.set("velocity", vel)
	proj.set("damage", dmg)
	proj.set("lifetime", life)
	proj.set("radius", 0.22)
	proj.set("shooter", shooter)
	proj.set("shooter_rid", shooter.get_rid())
	shooter.get_parent().add_child(proj)
	proj.global_position = pos
	return proj


func gone(node: Variant) -> bool:
	return not is_instance_valid(node) or (node as Node).is_queued_for_deletion()


## Lambdas must not capture a node that will be freed, so projectile waits poll through this helper instead of until().
func wait_gone(node: Variant, max_seconds: float) -> bool:
	for i in int(max_seconds * Engine.physics_ticks_per_second):
		if gone(node):
			return true
		await physics_frame
	return gone(node)


func action_event(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func horizontal_speed(p: Node) -> float:
	return Vector3(p.velocity.x, 0.0, p.velocity.z).length()


# ============================================================================================================ potion

func test_potion_basics() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	check(p.potion_count == 3 and hp(p) == 100 and is_equal_approx(p.stamina, 100.0), "start: 3 potions, 100 HP, 100 stamina")
	# Input sanity: a real LMB press must reach the player (otherwise every later check is meaningless).
	await tap(&"attack")
	check(probe.swings == 1, "real LMB input starts exactly one swing (got %d)" % probe.swings)
	await until(func(): return idle_state(p), 2.0)
	probe.clear()

	# --- Full HP: refused, nothing consumed, nothing starts.
	await tap(&"potion")
	await frames(4)
	check(probe.refused == [&"potion"], "full HP: potion refused once (%s)" % [probe.refused])
	check(not p.is_drinking() and p.potion_count == 3 and hp(p) == 100, "full HP: no drink, 3 potions, 100 HP")
	await frames(120)
	check(p.potion_count == 3 and hp(p) == 100 and probe.drunk.is_empty(), "full HP: still 3 potions / 100 HP 2 s later")

	# --- Stock empty (documented setup: potion_count = 0) while hurt.
	p.potion_count = 0
	p.receive_damage(60)
	check(hp(p) == 40, "setup: HP 40")
	probe.clear()
	await tap(&"potion")
	await frames(4)
	check(probe.refused == [&"potion"] and not p.is_drinking(), "empty stock: refused, no drink (%s)" % [probe.refused])
	await frames(120)
	check(p.potion_count == 0 and hp(p) == 40 and probe.drunk.is_empty(), "empty stock: HP 40 and 0 potions 2 s later (HP %d)" % hp(p))

	# --- Double press: two press edges in ONE frame -> exactly one drink; mashing Q during the drink never restarts it.
	p.potion_count = 3
	probe.clear()
	down(&"potion")
	up(&"potion")
	down(&"potion")
	up(&"potion")
	await frames(3)
	check(p.is_drinking(), "double press in one frame starts a drink")
	var last_progress: float = p.get_drink_progress()
	var monotonic := true
	var ticks := 0
	while p.is_drinking() and ticks < 200:
		if ticks % 10 == 0:
			down(&"potion")
		elif ticks % 10 == 2:
			up(&"potion")
		await physics_frame
		ticks += 1
		var now: float = p.get_drink_progress()
		if p.is_drinking() and now < last_progress:
			monotonic = false
		last_progress = now
	_drink_ticks = ticks + 3
	up(&"potion")
	await frames(2)
	check(monotonic, "mashing Q mid-drink never restarts the channel")
	check(_drink_ticks >= 86 and _drink_ticks <= 94, "drink lasts ~1.5 s (%d ticks)" % _drink_ticks)
	check(p.potion_count == 2 and hp(p) == 80, "double press consumed exactly ONE potion and healed 40 (potions %d, HP %d)" % [p.potion_count, hp(p)])
	check(probe.drunk == [40] and probe.cancelled == 0 and probe.refused.is_empty(), "one potion_drunk(40), no cancel, no refusal (%s %d %s)" % [probe.drunk, probe.cancelled, probe.refused])
	await frames(60)
	check(not p.is_drinking() and p.potion_count == 2 and hp(p) == 80, "no second drink starts by itself after the first (potions %d)" % p.potion_count)

	# --- Heal clamps at max HP but the potion is still spent.
	probe.clear()
	await tap(&"potion")
	check(await until(func(): return p.is_drinking(), 0.5), "second drink starts")
	await until(func(): return not p.is_drinking(), 3.0)
	check(hp(p) == 100 and p.potion_count == 1 and probe.drunk == [20], "heal clamped to 100 (healed 20), potion spent (HP %d, potions %d, %s)" % [hp(p), p.potion_count, probe.drunk])
	# --- Back at full HP the next press is refused again and keeps the last potion.
	await tap(&"potion")
	await frames(4)
	check(probe.refused == [&"potion"] and p.potion_count == 1 and not p.is_drinking(), "full HP again: refused, last potion kept")
	await end_game(g)


func test_potion_interrupts() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)

	# --- Block held: ignored while drinking (does not cancel, guard does not raise), guard comes up after the drink.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "block case: drink started")
	await frames(30)
	down(&"block")
	await frames(10)
	check(p.is_drinking() and not p.is_blocking() and is_equal_approx(p.stamina, 100.0), "holding block mid-drink neither cancels nor raises the guard nor drains stamina (drinking %s, blocking %s, stamina %.1f)" % [p.is_drinking(), p.is_blocking(), p.stamina])
	await until(func(): return not p.is_drinking(), 3.0)
	check(p.potion_count == 2 and hp(p) == 80 and probe.cancelled == 0, "block-held drink still completes: potions 2, HP 80 (potions %d, HP %d)" % [p.potion_count, hp(p)])
	await frames(4)
	check(p.is_blocking(), "the held guard comes up once the drink is over")
	probe.damage.clear()
	check(p.receive_damage(40) and hp(p) == 70 and probe.damage.size() == 1 and probe.damage[0][0] == 10 and probe.damage[0][1] == true, "blocked hit takes 25%% (HP 80 -> 70, got %d)" % hp(p))
	up(&"block")
	await frames(3)

	# --- Q while blocking: the guard drops and the drink starts.
	await reset_state(p, 40, 3)
	down(&"block")
	await frames(6)
	check(p.is_blocking(), "setup: guard up")
	probe.clear()
	await tap(&"potion")
	await frames(2)
	check(p.is_drinking() and not p.is_blocking(), "Q while blocking starts the drink and drops the guard")
	up(&"block")
	await until(func(): return not p.is_drinking(), 3.0)
	check(p.potion_count == 2 and hp(p) == 80, "drink after block completes normally (potions %d, HP %d)" % [p.potion_count, hp(p)])

	# --- Dodge cancels with no cost and no late heal.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "dodge case: drink started")
	await frames(30)
	var d: int = await dodge_now(p)
	check(d >= 0 and not p.is_drinking(), "dodge during the drink starts the dodge and ends the drink")
	check(probe.cancelled == 1 and p.potion_count == 3 and hp(p) == 40 and probe.drunk.is_empty(), "dodge cancel: 3 potions, HP 40, one cancel (potions %d, HP %d, cancels %d)" % [p.potion_count, hp(p), probe.cancelled])
	check(is_equal_approx(p.stamina, 75.0), "dodge cost 25 stamina (%.2f)" % p.stamina)
	await frames(150)
	check(p.potion_count == 3 and hp(p) == 40 and probe.drunk.is_empty(), "no late heal/consume after the dodge cancel (potions %d, HP %d)" % [p.potion_count, hp(p)])

	# --- Attack cancels with no cost; the swing is real.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "attack case: drink started")
	await frames(30)
	await tap(&"attack")
	check(not p.is_drinking() and probe.swings == 1 and probe.cancelled == 1, "attack cancels the drink and swings once (swings %d, cancels %d)" % [probe.swings, probe.cancelled])
	await until(func(): return idle_state(p), 2.0)
	await frames(120)
	check(p.potion_count == 3 and hp(p) == 40 and probe.drunk.is_empty(), "no late heal/consume after the attack cancel (potions %d, HP %d)" % [p.potion_count, hp(p)])

	# --- Non-lethal damage cancels: HP shows only the damage, never a heal.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "damage case: drink started")
	await frames(30)
	check(p.receive_damage(10), "damage is applied during the drink")
	check(not p.is_drinking() and probe.cancelled == 1 and hp(p) == 30 and p.potion_count == 3, "damage cancel: HP 30, 3 potions, one cancel (HP %d, potions %d)" % [hp(p), p.potion_count])
	await frames(150)
	check(hp(p) == 30 and p.potion_count == 3 and probe.drunk.is_empty(), "no late heal after the damage cancel (HP %d)" % hp(p))

	# --- Death cancels: potion kept through the respawn, nothing completes later.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "death case: drink started")
	await frames(30)
	p.receive_damage(1000)
	check(p.is_dead() and not p.is_drinking() and probe.cancelled == 1 and probe.died == 1 and p.potion_count == 3, "death cancels the drink without spending it")
	check(await wait_respawn(g), "player respawns")
	await frames(120)
	check(hp(p) == 100 and p.potion_count == 3 and probe.drunk.is_empty() and not p.is_drinking(), "after respawn: full HP, 3 potions, no stale drink (HP %d, potions %d)" % [hp(p), p.potion_count])
	await end_game(g)


func test_potion_pause() -> void:
	var g := await new_game()
	var p = g.player
	var cam: Node = p.get_node(p.camera_path)
	var probe := Probe.new(p)
	await reset_state(p, 40, 3)
	probe.clear()

	# --- Q pressed while paused never becomes a drink after resuming.
	cam.pause_game()
	await frames(3)
	down(&"potion")
	await frames(3)
	up(&"potion")
	await frames(3)
	cam.resume_game()
	await frames(30)
	check(not p.is_drinking() and p.potion_count == 3 and hp(p) == 40 and probe.refused.is_empty(), "Q pressed during pause does not start a drink after resume (drinking %s)" % p.is_drinking())

	# --- Pause mid-drink freezes the channel; resume continues with the remaining time; consumed exactly once.
	check(await start_drink(p), "drink started")
	await frames(30)
	var before: float = p.get_drink_progress()
	check(before > 0.3 and before < 0.45, "progress ~1/3 before pausing (%.3f)" % before)
	cam.pause_game()
	await frames(180)
	check(is_equal_approx(p.get_drink_progress(), before) and p.is_drinking(), "3 s of pause: progress frozen at %.3f (%.3f), still drinking" % [before, p.get_drink_progress()])
	check(p.potion_count == 3 and hp(p) == 40 and probe.drunk.is_empty(), "nothing consumed or healed while paused")
	cam.resume_game()
	var ticks := 0
	while p.is_drinking() and ticks < 200:
		await physics_frame
		ticks += 1
	var expected := int(round((1.0 - before) * 90.0))
	check(absi(ticks - expected) <= 3, "remaining channel after resume ~%d ticks (got %d)" % [expected, ticks])
	check(p.potion_count == 2 and hp(p) == 80 and probe.drunk == [40] and probe.cancelled == 0, "pause/resume drink consumed once and healed 40 (potions %d, HP %d, %s)" % [p.potion_count, hp(p), probe.drunk])
	await frames(60)
	check(p.potion_count == 2 and hp(p) == 80, "no second consume after resume")
	await end_game(g)


func test_potion_schedule() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	# Calibration: a Striker running BEFORE the player (priority -100) counts the ticks where the drink is visible.
	await reset_state(p, 40, 3)
	var counter := Striker.new()
	counter.player = p
	counter.process_priority = -100
	g.add_child(counter)
	check(await start_drink(p), "calibration drink started")
	await until(func(): return not p.is_drinking(), 3.0)
	var m: int = counter.obs
	counter.queue_free()
	check(m >= 86 and m <= 92 and p.potion_count == 2 and hp(p) == 80, "calibration: drink visible %d ticks, potion spent, HP 80" % m)

	# Each case: [mode, priority, target_obs or delay, name]. Damage 10 from HP 40.
	var cases: Array = [
		[&"before", -100, m - 1, "damage the tick BEFORE completion"],
		[&"before", -100, m, "damage first on the completion tick"],
		[&"after", 100, 0, "damage AFTER completion on the same tick"],
		[&"after", 100, 1, "damage the tick after completion"],
	]
	for i in cases.size():
		var c: Array = cases[i]
		await reset_state(p, 40, 3)
		probe.clear()
		var striker := Striker.new()
		striker.player = p
		striker.mode = c[0]
		striker.process_priority = c[1]
		if c[0] == &"before":
			striker.target_obs = c[2]
		else:
			striker.delay = c[2]
		g.add_child(striker)
		check(await start_drink(p), "case %d: drink started" % i)
		await until(func(): return striker.fired >= 0, 3.0)
		await frames(5)
		var label: String = c[3]
		check(striker.fired >= 0 and striker.result, "%s: damage applied" % label)
		if c[0] == &"before":
			check(probe.cancelled == 1 and probe.drunk.is_empty() and p.potion_count == 3 and hp(p) == 30,
				"%s -> cancelled, no free heal, potion kept: HP 30, 3 potions (HP %d, potions %d, drunk %s)" % [label, hp(p), p.potion_count, probe.drunk])
		else:
			check(probe.cancelled == 0 and probe.drunk == [40] and p.potion_count == 2 and hp(p) == 70,
				"%s -> potion consumed ONCE, heal then damage: HP 70, 2 potions (HP %d, potions %d, drunk %s)" % [label, hp(p), p.potion_count, probe.drunk])
		await frames(120)
		check(p.potion_count == (3 if c[0] == &"before" else 2) and hp(p) == (30 if c[0] == &"before" else 70), "%s: state stable 2 s later" % label)
		striker.queue_free()

	# Lethal blow right after completion: the potion was spent exactly once, respawn keeps the count.
	await reset_state(p, 40, 3)
	probe.clear()
	var killer := Striker.new()
	killer.player = p
	killer.mode = &"after"
	killer.process_priority = 100
	killer.amount = 1000
	g.add_child(killer)
	check(await start_drink(p), "lethal case: drink started")
	await until(func(): return killer.fired >= 0, 3.0)
	check(p.is_dead() and probe.drunk == [40] and p.potion_count == 2 and probe.died == 1, "completion-first then lethal: potion spent once, one death (potions %d, drunk %s, died %d)" % [p.potion_count, probe.drunk, probe.died])
	check(await wait_respawn(g), "respawn after the lethal case")
	await frames(60)
	check(hp(p) == 100 and p.potion_count == 2, "respawn: full HP, 2 potions kept (HP %d, potions %d)" % [hp(p), p.potion_count])
	killer.queue_free()
	await end_game(g)


# ============================================================================================================ i-frames

func test_iframes_direct() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	var enemies: Node = g.get_node("Enemies")
	var melee_damage := 0
	var heavy_damage := 0
	for enemy in enemies.get_children():
		if enemy.archetype == "standard":
			melee_damage = int(enemy.cfg["damage"])
		elif enemy.archetype == "heavy":
			heavy_damage = int(enemy.cfg["damage"])
	var avoided: Array[int] = []
	var landed: Array[int] = []
	var speed_at: Dictionary = {}
	for k in range(1, 18):
		await reset_state(p, 100, 3)
		await place(g, START, 0.0)
		probe.clear()
		var d: int = await dodge_now(p)
		check(d >= 0, "k=%d: dodge started with the real key" % k)
		await frames(k - 1)
		var dodging: bool = p.is_dodging()
		var speed := horizontal_speed(p)
		var moved: float = p.global_position.distance_to(START)
		var amount := melee_damage if k % 2 == 1 else heavy_damage
		var before_hp := hp(p)
		var applied: bool = p.receive_damage(amount)
		speed_at[k] = speed
		if applied:
			landed.append(k)
		else:
			avoided.append(k)
		if k <= 14:
			check(dodging and speed > 4.5 and moved > 0.05, "k=%d: still really dodging and moving (dodging %s, %.1f m/s, moved %.2f m)" % [k, dodging, speed, moved])
		elif k >= 17:
			check(not dodging, "k=%d: dodge is over (0.25 s = 15 ticks, 16 with float accumulation)" % k)
		if k <= 10:
			check(not applied and hp(p) == before_hp and probe.damage.is_empty(), "k=%d (%.3f s): i-frames avoid %d damage: HP %d unchanged, no damage_taken" % [k, k * DT, amount, hp(p)])
		else:
			check(applied and hp(p) == before_hp - amount and probe.damage.size() == 1 and probe.damage[0][0] == amount and probe.damage[0][1] == false,
				"k=%d (%.3f s): after the 0.18 s window %d damage lands: HP %d -> %d" % [k, k * DT, amount, before_hp, hp(p)])
	# Movement excluded: the avoided tick and the first vulnerable tick have the same dodge motion.
	check(absf(float(speed_at[10]) - float(speed_at[11])) < 1.0 and float(speed_at[11]) > 5.0,
		"avoid (k=10, %.2f m/s) and first hit (k=11, %.2f m/s) happen at the same dodge speed: iframes, not movement" % [speed_at[10], speed_at[11]])
	check(avoided == range(1, 11) and landed == range(11, 18), "i-frame boundary is exactly 10 ticks: avoided %s, landed %s" % [avoided, landed])
	await end_game(g)


func test_iframes_projectile() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	var pdamage := 14

	# --- Control: a projectile hits a standing player (proves the lane, mask and damage number are real).
	await reset_state(p, 100, 3)
	await place(g, START, 0.0)
	probe.clear()
	var proj := spawn_projectile(g, Vector3(START.x, START.y + 1.0, START.z - 4.0), Vector3(0, 0, 13), pdamage)
	check(await wait_gone(proj, 1.0), "control: projectile resolves")
	check(hp(p) == 86 and probe.damage.size() == 1 and probe.damage[0][0] == pdamage and probe.damage[0][1] == false, "control: standing player takes the projectile's 14 damage (HP %d)" % hp(p))

	# --- Blocked: 14 * 0.25 = 3.5 -> 4.
	await reset_state(p, 100, 3)
	await place(g, START, 0.0)
	down(&"block")
	await frames(6)
	probe.clear()
	proj = spawn_projectile(g, Vector3(START.x, START.y + 1.0, START.z - 4.0), Vector3(0, 0, 13), pdamage)
	await wait_gone(proj, 1.0)
	check(p.is_blocking() and hp(p) == 96 and probe.damage.size() == 1 and probe.damage[0][1] == true, "blocked projectile deals 4 (HP %d, blocked %s)" % [hp(p), probe.damage.size() > 0 and probe.damage[0][1]])
	up(&"block")
	await frames(3)

	# --- Dodge into the projectile lane: scan the arrival time across the i-frame boundary.
	var saw_avoid := false
	var saw_hit := false
	var table: Array = []
	for gap in [2.0, 3.0, 4.0, 4.6, 5.0, 5.4, 5.8, 6.4, 7.5, 9.0]:
		await reset_state(p, 100, 3)
		await place(g, START, 0.0)
		probe.clear()
		var d: int = await dodge_now(p)
		var pos: Vector3 = p.global_position
		proj = spawn_projectile(g, Vector3(pos.x, pos.y + 1.0, pos.z - gap), Vector3(0, 0, 13), pdamage)
		var resolved := -1
		for i in 200:
			if gone(proj):
				resolved = Engine.get_physics_frames()
				break
			await physics_frame
		check(resolved >= 0, "gap %.1f: projectile resolved" % gap)
		# Player ticks before the projectile (tree order); the projectile saw dodge age (r - d + 2) when it resolved at r = resolved - 1.
		var age := (resolved - 1) - d + 2
		var took := probe.damage.size() > 0
		table.append([gap, age, took])
		if age <= 9:
			saw_avoid = true
			check(not took and hp(p) == 100, "gap %.1f arrives at dodge age %d (<= 0.18 s): avoided, HP %d" % [gap, age, hp(p)])
		elif age >= 12:
			saw_hit = true
			check(took and hp(p) == 100 - pdamage, "gap %.1f arrives at dodge age %d (> 0.18 s): hits, HP %d" % [gap, age, hp(p)])
		check(is_equal_approx(p.stamina, 75.0) or p.stamina > 75.0, "gap %.1f: dodge spent stamina (%.1f)" % [gap, p.stamina])
	note("projectile arrival scan [gap, dodge age, damaged]: %s" % [table])
	check(saw_avoid and saw_hit, "scan covered both an avoided arrival and a post-window hit (avoid %s, hit %s)" % [saw_avoid, saw_hit])
	await end_game(g)


func test_iframes_boss() -> void:
	var g := await new_game()
	var p = g.player
	var s = g.session
	var enc = g.boss
	var arena = enc.get_arena()
	var probe := Probe.new(p)
	var altar_offsets: Array = [Vector3(0, 0, 2.0), Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0), Vector3(0, 0, 2.4)]
	var socket_offsets: Array = [Vector3(0, 0, 1.3), Vector3(0, 0, 1.8), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]
	var ids: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]
	for id in ids:
		s.claim(id, &"artifact")  # documented: the pickup path itself is covered by island_regression
	for id in ids:
		check(await use(g, arena.consoles[id], socket_offsets), "install %s through the interactor" % id)
	check(await use(g, arena.altar, altar_offsets), "altar through the interactor")
	check(await until(func(): return enc.get_mode_name() == &"fighting", 10.0), "boss reaches the fight")
	var slam_damage: int = enc.get_script().get_script_constant_map()["ATTACKS"][&"slam"]["damage"]

	# Baseline: no dodge, the slam lands for its full damage.
	var base: Dictionary = await boss_run(g, enc, p, probe, -1)
	check(base["hit"] >= 0 and base["hp_after"] == 100 - slam_damage and base["saw_active"], "baseline slam deals %d (HP %d)" % [slam_damage, base["hp_after"]])
	var hit_rel: int = base["hit"] - base["force"]
	note("boss slam lands %d ticks after force_attack" % hit_rel)
	var saw_avoid := false
	var saw_hit := false
	var table: Array = []
	for target_age in [3, 6, 9, 12, 14, 18]:
		var r: Dictionary = await boss_run(g, enc, p, probe, hit_rel - target_age)
		check(r["dodge"] >= 0 and r["saw_active"], "age %d: the dodge started and the slam still went through its active phase" % target_age)
		var took: bool = r["hit"] >= 0
		var age: int = (r["hit"] - r["dodge"] + 2) if took else -1
		table.append([target_age, age, took])
		if target_age <= 9:
			saw_avoid = true
			check(not took and r["hp_after"] == 100, "slam during dodge age ~%d: avoided, HP %d, no damage_taken" % [target_age, r["hp_after"]])
		elif target_age >= 12:
			saw_hit = true
			check(took and r["hp_after"] == 100 - slam_damage, "slam at dodge age ~%d (after 0.18 s): lands %d, HP %d" % [target_age, slam_damage, r["hp_after"]])
	note("boss scan [target age, measured age, damaged]: %s" % [table])
	check(saw_avoid and saw_hit, "boss scan covered avoided and post-window cases")
	await end_game(g)


## One forced slam against a stationary player. press_offset = ticks after force_attack at which the Alt press is sent (-1 = none).
func boss_run(g: Node, enc: Node, p: Node, probe: Probe, press_offset: int) -> Dictionary:
	var out := {"force": -1, "hit": -1, "dodge": -1, "hp_after": 0, "saw_active": false}
	var body: Node3D = enc.get_boss()
	var ready := false
	for i in 900:
		var spot: Vector3 = body.global_position + body.global_basis.z * 3.0
		p.global_position = Vector3(spot.x, body.global_position.y + 0.1, spot.z)
		p.velocity = Vector3.ZERO
		if enc.get_mode_name() == &"fighting" and enc.get_attack_state() == &"pause" and i > 3:
			ready = true
			break
		await physics_frame
	check(ready, "boss run: boss is between attacks")
	p.get_health().restore_full()
	p.stamina = p.max_stamina
	probe.clear()
	out["force"] = Engine.get_physics_frames()
	check(enc.force_attack(&"slam"), "boss run: slam forced")
	for i in 600:
		var frame := Engine.get_physics_frames()
		if press_offset >= 0 and frame - int(out["force"]) == press_offset:
			down(&"dodge")
		if out["dodge"] < 0 and p.is_dodging():
			out["dodge"] = frame
			up(&"dodge")
		if enc.get_attack_state() == &"active":
			out["saw_active"] = true
		if enc.get_attack_state() == &"recovery" and out["saw_active"]:
			break
		await physics_frame
	up(&"dodge")
	await frames(2)
	out["hp_after"] = hp(p)
	if not probe.damage.is_empty():
		out["hit"] = int(probe.damage[0][2])
	return out


# ============================================================================================================ stamina

func test_stamina() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	await place(g, START, 0.0)

	# --- Exact dodge threshold (regen disabled so nothing can sneak a tick of stamina in).
	p.stamina_regen = 0.0
	p.stamina = 24.9
	probe.clear()
	await tap(&"dodge")
	await frames(10)
	check(probe.refused == [&"dodge"] and not p.is_dodging() and is_equal_approx(p.stamina, 24.9), "24.9 stamina: dodge refused, stamina untouched (%.2f, %s)" % [p.stamina, probe.refused])
	check(p.global_position.distance_to(START) < 0.1, "refused dodge does not move the player (%.2f m)" % p.global_position.distance_to(START))
	p.stamina = 25.0
	probe.clear()
	var d: int = await dodge_now(p)
	check(d >= 0 and probe.refused.is_empty(), "exactly 25.0 stamina: dodge accepted")
	check(p.stamina == 0.0, "exact threshold dodge leaves exactly 0.0 stamina (%s)" % p.stamina)
	await until(func(): return not p.is_dodging(), 1.0)
	check(p.global_position.distance_to(START) > 1.2, "accepted dodge moved the player (%.2f m)" % p.global_position.distance_to(START))
	await frames(5)
	await tap(&"dodge")
	await frames(5)
	check(probe.refused == [&"dodge"] and not p.is_dodging() and p.stamina == 0.0, "second dodge at 0 stamina refused (%s)" % [probe.refused])

	# --- Regen: nothing for 0.75 s after the dodge, then 25/s.
	p.stamina_regen = 25.0
	await place(g, START, 0.0)
	await reset_state(p, 100, 3)
	p.stamina = 25.0
	d = await dodge_now(p)
	await until(func(): return not p.is_dodging(), 1.0)
	var first_rise := -1
	var rise_value := 0.0
	var samples: Array = []
	for i in 160:
		await physics_frame
		samples.append(p.stamina)
		if first_rise < 0 and p.stamina > 0.0:
			first_rise = i
			rise_value = p.stamina
	var delay_ticks := first_rise
	check(delay_ticks >= 43 and delay_ticks <= 47, "regen starts ~0.75 s after the dodge (first rise after %d ticks = %.3f s)" % [delay_ticks, delay_ticks * DT])
	var after_second: float = samples[first_rise + 60]
	check(absf(after_second - rise_value - 25.0) < 0.8, "regen rate 25/s (gained %.2f in 1 s)" % (after_second - rise_value))

	# --- Regen clamps at max: never above, lands exactly on it.
	await reset_state(p, 100, 3)
	await frames(60)
	p.stamina = 99.9
	var above := false
	for i in 30:
		await physics_frame
		if p.stamina > p.max_stamina:
			above = true
	check(not above and p.stamina == p.max_stamina, "regen clamps exactly at max (%.4f)" % p.stamina)

	# --- Block: breaks at 0, stays refused (one refusal per hold) until 20 stamina, resumes on the first tick it can.
	await reset_state(p, 100, 3)
	p.stamina = 1.0
	probe.clear()
	down(&"block")
	var trace: Array = []
	var broke_hp_test := false
	var hit_while_broken := false
	var resumed_index := -1
	for i in 200:
		await physics_frame
		trace.append([p.stamina, p.is_blocking()])
		if not broke_hp_test and trace.size() > 20 and not p.is_blocking():
			broke_hp_test = true
			probe.damage.clear()
			var before := hp(p)
			check(p.receive_damage(40) and hp(p) == before - 40 and probe.damage[0][1] == false, "broken guard: a 40 hit is NOT reduced (HP %d -> %d)" % [before, hp(p)])
			hit_while_broken = true
		if i > 10 and p.is_blocking() and resumed_index < 0:
			resumed_index = i
			break
	check(resumed_index > 0, "guard resumes while RMB is still held once stamina recovers")
	var raised_at := -1
	var broke_at := -1
	for i in trace.size():
		if raised_at < 0 and trace[i][1]:
			raised_at = i
		elif raised_at >= 0 and not trace[i][1]:
			broke_at = i
			break
	check(raised_at >= 0 and broke_at > raised_at and broke_at - raised_at < 10, "guard rises, then breaks within a few ticks at 1 stamina (raised %d, broke %d)" % [raised_at, broke_at])
	var ever_blocking_while_broken := false
	for i in range(broke_at, resumed_index):
		if trace[i][1]:
			ever_blocking_while_broken = true
	check(not ever_blocking_while_broken, "never blocks between the break and the resume")
	check(probe.refused.count(&"block") == 1, "exactly one block refusal for the whole broken hold (%d)" % probe.refused.count(&"block"))
	check(trace[resumed_index - 1][0] >= 20.0 and trace[resumed_index - 2][0] < 20.0, "resumes on the first tick after stamina reaches 20 (prev samples %.2f / %.2f)" % [trace[resumed_index - 2][0], trace[resumed_index - 1][0]])
	check(hit_while_broken, "broken-guard hit was exercised")
	# Resuming at 20 stamina is not enough to absorb a boss slam's 30.4 stamina impact.
	probe.damage.clear()
	var resumed_hp := hp(p)
	check(p.receive_damage(38) and hp(p) == resumed_hp - 38 and not p.is_blocking() and p.stamina == 0.0
		and probe.damage.size() == 1 and probe.damage[0][1] == false, "resumed low guard breaks against 38: full damage, no negative stamina")
	up(&"block")
	check(await until(func(): return p.stamina >= 40.0, 3.0), "guard replenishes enough stamina for the original blocked-40 control")
	down(&"block")
	await frames(3)
	probe.damage.clear()
	var before_block := hp(p)
	check(p.receive_damage(40) and hp(p) == before_block - 10 and probe.damage[0][1] == true, "resumed guard reduces a 40 hit to 10 (HP %d -> %d)" % [before_block, hp(p)])
	up(&"block")
	await frames(3)
	await end_game(g)


## Impact costs are tested through receive_damage; guard and dodge are raised with real input, not private state flags.
func test_guard_impact() -> void:
	var g := await new_game()
	var p = g.player
	var probe := Probe.new(p)
	p.stamina_regen = 0.0  # Exact resource fixtures: no tick can refill the guard between combo hits.

	await reset_state(p)
	p.stamina = 80.0
	probe.clear()
	check(p.receive_damage(24) and hp(p) == 76 and p.stamina == 80.0 and probe.damage.size() == 1
		and probe.damage[0][1] == false, "unblocked hit: full damage, no guard stamina cost")

	await reset_state(p)
	down(&"block")
	await frames(3)
	p.stamina = 40.0
	probe.clear()
	check(p.is_blocking(), "boss-slam control: real RMB raised the guard")
	check(not p.receive_damage(0) and not p.receive_damage(-10) and p.stamina == 40.0 and hp(p) == 100
		and probe.damage.is_empty(), "non-positive damage never spends guard stamina")
	check(p.receive_damage(38) and hp(p) == 90 and is_equal_approx(p.stamina, 9.6) and probe.damage.size() == 1
		and probe.damage[0][1] == true and p.is_blocking(), "adequate guard: 38 becomes 10 HP damage and costs 30.4 stamina")
	up(&"block")
	await frames(3)

	await reset_state(p)
	down(&"block")
	await frames(3)
	p.stamina = 80.0
	probe.clear()
	check(p.receive_damage(24) and hp(p) == 94 and is_equal_approx(p.stamina, 60.8), "combo sweep: 6 HP damage, 19.2 stamina impact")
	check(p.receive_damage(38) and hp(p) == 84 and is_equal_approx(p.stamina, 30.4), "combo slam: 10 HP damage, 30.4 stamina impact")
	check(p.receive_damage(30) and hp(p) == 76 and is_equal_approx(p.stamina, 6.4), "combo charge: 8 HP damage, 24 stamina impact")
	check(probe.damage.size() == 3 and probe.damage[0][1] and probe.damage[1][1] and probe.damage[2][1],
		"all three adequately funded combo hits report blocked")
	check(p.receive_damage(24) and hp(p) == 52 and p.stamina == 0.0 and not p.is_blocking()
		and probe.damage.size() == 4 and probe.damage[3][1] == false and probe.refused == [&"block"],
		"continued combo exhausts the guard: the breaking hit deals full 24, emits one refusal and clamps stamina to zero")
	check(p.receive_damage(10) and hp(p) == 42 and p.stamina == 0.0 and probe.damage.size() == 5
		and probe.damage[4][1] == false, "another hit in the same frame cannot reblock or receive a discount")
	await frames(10)
	check(not p.is_blocking() and p.stamina == 0.0 and probe.refused == [&"block"], "broken held guard refuses only once and cannot resume without stamina")
	up(&"block")
	await frames(3)

	for available in [7.9, 8.0]:
		await reset_state(p)
		down(&"block")
		await frames(3)
		p.stamina = available
		probe.clear()
		check(p.receive_damage(10), "minimum-cost boundary %.1f: hit applies" % available)
		var adequate: bool = available == 8.0
		check(hp(p) == (97 if adequate else 90) and p.stamina == 0.0 and not p.is_blocking()
			and probe.damage.size() == 1 and probe.damage[0][1] == adequate and probe.refused == [&"block"],
			"minimum 8 stamina: %.1f %s; guard breaks without negative stamina" % [available, "blocks this hit" if adequate else "takes full damage"])
		up(&"block")
		await frames(3)

	await reset_state(p)
	down(&"block")
	await frames(3)
	p.stamina = 20.0
	probe.clear()
	check(p.receive_damage(38) and hp(p) == 62 and p.stamina == 0.0 and not p.is_blocking()
		and probe.damage.size() == 1 and probe.damage[0][1] == false, "low guard: 20 cannot fund a slam, full 38 damage")
	up(&"block")
	p.stamina_regen = 25.0
	await frames(30)
	check(p.stamina == 0.0, "impact break retains the 0.75 s regeneration delay")
	check(await until(func(): return p.stamina >= 20.0, 2.0), "impact-broken stamina regenerates back to the existing 20-point resume threshold")
	p.stamina_regen = 0.0

	await reset_state(p)
	down(&"block")
	await frames(3)
	p.stamina = 100.0
	# Parsed input may reach the player after another held-guard tick. Observe the last guard resource signal,
	# then the dodge's immediate resource signal, so ordinary 18/s guard drain is not mistaken for dodge cost.
	var dodge_resources: Dictionary = {"before": 100.0, "after": -1.0}
	var sample_dodge: Callable = func() -> void:
		if p.is_dodging():
			if float(dodge_resources["after"]) < 0.0:
				dodge_resources["after"] = p.stamina
		else:
			dodge_resources["before"] = p.stamina
	p.resources_changed.connect(sample_dodge)
	check(await dodge_now(p) >= 0, "guard-to-dodge: real Alt starts the dodge")
	p.resources_changed.disconnect(sample_dodge)
	var after_dodge: float = p.stamina
	probe.clear()
	var applied: bool = p.receive_damage(38)
	check(is_equal_approx(float(dodge_resources["before"]) - float(dodge_resources["after"]), 25.0)
		and not applied and hp(p) == 100 and p.stamina == after_dodge and probe.damage.is_empty() and probe.refused.is_empty(),
		"iframe-avoided slam: dodge spends 25, hit adds no cost or damage (before %.3f, after %.3f, current %.3f, applied %s)"
		% [dodge_resources["before"], dodge_resources["after"], p.stamina, applied])
	up(&"block")
	await until(func(): return not p.is_dodging(), 1.0)
	await end_game(g)


# ============================================================================================================ death hygiene

func test_death_hygiene() -> void:
	var g := await new_game()
	var p = g.player
	var s = g.session
	var probe := Probe.new(p)
	var enemy: Node = g.get_node("Enemies").get_child(1)  # heavy guard, AI off (setup), real Health + hurtbox
	var enemy_hp: Node = enemy.get_node("Health")
	var front: Vector3 = enemy.global_position + Vector3(0, 0.1, -1.4)

	# --- Control: a real swing in front of the heavy guard deals exactly the first-hit damage once.
	await reset_state(p, 100, 3)
	await place(g, front, 0.0)
	probe.clear()
	await tap(&"attack")
	await until(func(): return idle_state(p), 2.0)
	check(enemy_hp.current_health == enemy_hp.max_health - 20 and probe.hits.size() == 1 and probe.hits[0][1] == 20, "control: one swing deals 20 to the guard (HP %d/%d)" % [enemy_hp.current_health, enemy_hp.max_health])
	enemy_hp.restore_full()

	# --- A: death during an attack, queued presses outstanding at the moment of death.
	await reset_state(p, 100, 3)
	await place(g, front, 0.0)
	probe.clear()
	await tap(&"attack")
	var window: Vector2 = p.get_attack_window()
	check(p.is_attacking() and p.get_attack_time() + 2.0 * DT < window.x, "setup: swing in progress before the hit window opens (t %.3f, window %s)" % [p.get_attack_time(), window])
	p._unhandled_input(action_event(&"attack"))
	p._unhandled_input(action_event(&"dodge"))
	p._unhandled_input(action_event(&"potion"))
	down(&"attack")
	down(&"dodge")
	down(&"potion")
	p.receive_damage(1000)
	up(&"attack")
	up(&"dodge")
	up(&"potion")
	check(p.is_dead() and not p.is_attacking() and probe.died == 1, "death ends the swing (attacking %s, died %d)" % [p.is_attacking(), probe.died])
	var enemy_before: int = enemy_hp.current_health
	await frames(100)
	check(enemy_hp.current_health == enemy_before and probe.hits.is_empty(), "no stale hit lands on the guard after death (HP %d, hits %d)" % [enemy_hp.current_health, probe.hits.size()])
	check(p.is_dead() and not p.is_attacking() and not p.is_dodging() and not p.is_drinking(), "dead player stays inert: no queued action fired")
	check(await wait_respawn(g), "respawn after death mid-attack")
	await frames(90)
	check(hp(p) == 100 and is_equal_approx(p.stamina, 100.0) and p.potion_count == 3, "respawn: 100 HP, 100 stamina (no stale dodge cost), 3 potions (HP %d, stamina %.1f, potions %d)" % [hp(p), p.stamina, p.potion_count])
	check(idle_state(p) and p.get_action_state() == &"idle" and p.global_position.distance_to(START) < 0.6, "respawn: idle at the checkpoint, nothing in progress (%s, %.2f m)" % [p.get_action_state(), p.global_position.distance_to(START)])
	check(probe.swings == 1 and probe.refused.is_empty(), "no extra swing/refusal appeared from the dropped presses (swings %d, %s)" % [probe.swings, probe.refused])
	# A fresh swing after the respawn is a normal single hit again.
	await place(g, front, 0.0)
	probe.clear()
	await tap(&"attack")
	await until(func(): return idle_state(p), 2.0)
	check(enemy_hp.current_health == enemy_hp.max_health - 20 and probe.hits.size() == 1, "after respawn a swing deals exactly one 20 hit (HP %d/%d, hits %d)" % [enemy_hp.current_health, enemy_hp.max_health, probe.hits.size()])
	enemy_hp.restore_full()

	# --- B: death during a dodge with a projectile still in flight, then respawn.
	await reset_state(p, 100, 3)
	await place(g, START, 0.0)
	probe.clear()
	var d: int = await dodge_now(p)
	await frames(11)
	check(p.is_dodging(), "setup: still dodging at age 12")
	var proj := spawn_projectile(g, Vector3(START.x, START.y + 1.0, START.z - 6.5), Vector3(0, 0, 1.5), 14, 20.0)
	check(p.receive_damage(1000) and p.is_dead() and not p.is_dodging(), "lethal hit at dodge age 12 (after the i-frames) kills and ends the dodge")
	await frames(30)
	check(not gone(proj) and probe.damage.size() == 1, "projectile still in flight while the player lies dead, no extra damage_taken (%d)" % probe.damage.size())
	check(await wait_respawn(g), "respawn after death mid-dodge")
	await frames(5)
	check(gone(proj) and get_nodes_in_group(&"enemy_projectiles").all(func(n): return gone(n)), "respawn clears the outstanding projectile")
	check(hp(p) == 100 and is_equal_approx(p.stamina, 100.0) and not p.is_dodging(), "respawn: 100 HP, 100 stamina (dodge cost refunded), no dodge (%d, %.1f)" % [hp(p), p.stamina])
	await frames(300)
	check(hp(p) == 100 and probe.damage.size() == 1, "no stale projectile hit after respawn (HP %d, hits %d)" % [hp(p), probe.damage.size()])

	# --- C: death during a drink, queued presses outstanding, then stale-heal check.
	await reset_state(p, 40, 3)
	probe.clear()
	check(await start_drink(p), "drink for the death case started")
	await frames(20)
	p._unhandled_input(action_event(&"potion"))
	p._unhandled_input(action_event(&"attack"))
	p.receive_damage(1000)
	check(p.is_dead() and not p.is_drinking() and probe.cancelled == 1 and p.potion_count == 3 and probe.drunk.is_empty(), "death during the drink: cancelled, potion kept, no heal")
	check(await wait_respawn(g), "respawn after death mid-drink")
	await frames(30)
	p.receive_damage(30)
	await frames(240)
	check(hp(p) == 70 and p.potion_count == 3 and probe.drunk.is_empty() and not p.is_drinking(), "no stale drink/heal after respawn: HP stays 70, 3 potions (HP %d, potions %d)" % [hp(p), p.potion_count])
	check(is_equal_approx(p.stamina, 100.0) and probe.swings == 0, "no stale attack from the dropped press (swings %d)" % probe.swings)

	# --- D: interact is refused during attack/dodge/drink/death and nothing is queued; exactly one pickup afterwards.
	var pickup: Node = null
	for c in g.terrain.get_children():
		if "pickup_id" in c and c.pickup_id == &"island_potion_0":
			pickup = c
	check(pickup != null, "found the real potion pickup")
	await reset_state(p, 100, 3)
	var stand: Vector3 = pickup.global_position + Vector3(-1.2, 0.1, 0)
	await place(g, stand, 0.0)
	check(await until(func(): return g.interactor.get_target() == pickup, 1.0), "interactor targets the pickup")
	var base_potions: int = p.potion_count
	# attack
	probe.clear()
	down(&"attack")
	await frames(2)
	up(&"attack")
	check(p.is_attacking(), "setup: attacking")
	await tap(&"interact")
	check(p.potion_count == base_potions and not s.is_collected(&"island_potion_0") and pickup.visible, "E during an attack does not collect the potion")
	await until(func(): return idle_state(p), 2.0)
	await frames(30)
	check(p.potion_count == base_potions and not s.is_collected(&"island_potion_0"), "no queued E collects it after the attack ends")
	# dodge
	await place(g, stand, 0.0)
	await dodge_now(p)
	await tap(&"interact")
	check(p.potion_count == base_potions and not s.is_collected(&"island_potion_0"), "E during a dodge does not collect the potion")
	await until(func(): return idle_state(p), 2.0)
	await frames(30)
	check(p.potion_count == base_potions and not s.is_collected(&"island_potion_0"), "no queued E collects it after the dodge ends")
	# drink
	await place(g, stand, 0.0)
	p.receive_damage(30)
	check(await start_drink(p), "drink started next to the pickup")
	await frames(20)
	await tap(&"interact")
	check(p.potion_count == base_potions and not s.is_collected(&"island_potion_0"), "E during a drink does not collect the potion")
	await until(func(): return not p.is_drinking(), 3.0)
	await frames(30)
	check(p.potion_count == base_potions - 1 and hp(p) == 100 and not s.is_collected(&"island_potion_0"), "drink completed (potions %d), still no phantom pickup (collected %s)" % [p.potion_count, s.is_collected(&"island_potion_0")])
	# death
	var potions_at_death: int = p.potion_count
	await place(g, stand, 0.0)
	p.receive_damage(1000)
	await tap(&"interact")
	check(p.is_dead() and p.potion_count == potions_at_death and not s.is_collected(&"island_potion_0") and pickup.visible, "E while dead does not collect the potion")
	check(await wait_respawn(g), "respawn after the interact-while-dead case")
	await frames(60)
	check(p.potion_count == potions_at_death and not s.is_collected(&"island_potion_0") and pickup.visible, "no phantom pickup after respawn (potions %d)" % p.potion_count)
	await place(g, stand, 0.0)
	check(await until(func(): return g.interactor.get_target() == pickup, 1.0), "interactor targets the pickup again")
	await tap(&"interact")
	check(p.potion_count == potions_at_death + 1 and s.is_collected(&"island_potion_0") and not pickup.visible, "a deliberate E after respawn collects exactly one potion (%d)" % p.potion_count)
	await tap(&"interact")
	await frames(10)
	check(p.potion_count == potions_at_death + 1 and s.count_kind(&"potion") == 1, "second E collects nothing (potions %d, claims %d)" % [p.potion_count, s.count_kind(&"potion")])

	# --- E: a broken guard / held RMB does not survive death: the respawned player blocks at once with full stamina.
	await reset_state(p, 100, 3)
	await place(g, START, 0.0)
	p.stamina = 0.5
	down(&"block")
	await until(func(): return not p.is_blocking() and p.stamina == 0.0, 1.0)
	await frames(5)
	check(not p.is_blocking() and p.stamina < 5.0, "setup: guard broken at 0 stamina (stamina %.2f)" % p.stamina)
	p.receive_damage(1000)
	check(await wait_respawn(g), "respawn after death with a broken guard")
	await frames(4)
	check(p.is_blocking() and p.stamina > 95.0 and p.stamina < 100.0, "RMB still held after respawn: guard up at once, stamina %.2f draining from full (no stale broken latch)" % p.stamina)
	up(&"block")
	await frames(5)
	check(not p.is_blocking(), "guard drops when RMB is released")
	await end_game(g)


# ============================================================================================================ interactor helpers (boss setup)

func reach(g: Node, item: Node3D, offsets: Array) -> bool:
	for off in offsets:
		g.player.global_position = item.global_position + (off as Vector3) + Vector3(0, 0.1, 0)
		g.player.velocity = Vector3.ZERO
		await frames(2)
		if await until(func(): return g.interactor.get_target() == item, 0.4):
			return true
	return false


func use(g: Node, item: Node3D, offsets: Array) -> bool:
	var reached: bool = await reach(g, item, offsets)
	if not reached:
		return false
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	g.interactor._unhandled_input(e)
	await frames(2)
	return true
