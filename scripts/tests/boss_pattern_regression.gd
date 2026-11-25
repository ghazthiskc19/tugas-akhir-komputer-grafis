extends SceneTree
## Consumer-level boss chain regression. Fixture: fixed Island1, other enemy AI disabled, player positioned inside each
## displayed zone so dodge assertions measure receive_damage/i-frames rather than escaping the geometry. Activation uses
## the encounter's console interface; phase changes/death use real Health damage, never boss state mutation.
## Run: C:/Godot/godot.exe --headless --fixed-fps 60 --path . --script res://scripts/tests/boss_pattern_regression.gd

const GAME := preload("res://scenes/world/island_game.tscn")
const DT := 1.0 / 60.0
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var game: Node = GAME.instantiate()
	game.start_in_menu = false
	game.procedural = false
	root.add_child(game)
	await frames(8)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)
	var player: Node = game.player
	var boss: Node = game.boss
	var arena: Node = boss.get_arena()
	for id: StringName in [&"forest_artifact", &"energy_artifact", &"summit_artifact"]:
		game.session.claim(id, &"artifact")
		check(boss.use_console(arena.consoles[id], player), "artifact socket accepts activation setup")
	check(boss.use_console(arena.altar, player), "altar starts the encounter")
	check(await until(func(): return boss.get_mode_name() == &"fighting", 6.0), "wake enters combat")
	await pressure_case(boss, player)
	await combo_case(boss, player, 2, false, "phase one stationary")
	await combo_case(boss, player, 2, true, "phase one fresh dodges")
	await combo_case(boss, player, 2, true, "one dodge cannot cover both strikes", true)
	await combo_case(boss, player, 2, false, "phase transition cannot extend a running chain", false, true)
	check(boss.get_hud_state()["phase"] == 2, "exactly half health enters phase two")
	# A new phase never extends an already-started chain; new phase-two chains have a fixed budget of two or three.
	var durations: Array[float] = []
	for i in 3:
		var result: Dictionary = await combo_case(boss, player, 0, false, "phase two stationary %d" % i)
		durations.append_array(result["windups"])
	check(durations.max() - durations.min() > 0.3, "phase two exposes distinct quick/delayed windups")
	await combo_case(boss, player, 0, true, "phase two fresh dodges")
	await cancellation_case(game, boss, player)
	print("boss_pattern_regression: %d checks, %d failed" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("FAIL " + failure)
	game.queue_free()
	await frames(12)
	quit(0 if _failures.is_empty() else 1)


func combo_case(boss: Node, player: Node, expected_length: int, dodge_each: bool, label: String, first_only := false, cross_phase := false) -> Dictionary:
	check(await until(func(): return boss.get_attack_state() == &"pause", 12.0), label + ": ready")
	player.get_health().restore_full()
	player.stamina = player.max_stamina
	place_in_front(boss, player)
	var damage: Array[int] = []
	var hit_frames: Array[int] = []
	var received := func(amount: int, _blocked: bool):
		damage.append(amount)
		hit_frames.append(Engine.get_physics_frames())
	player.damage_taken.connect(received)
	check(boss.force_attack(&"sweep", true), label + ": forced normal combo")
	var seen := 0
	var dodge_count := 0
	var dodged_strike := 0
	var damage_expected := 0
	var windups: Array[float] = []
	var windup_started := 0
	var final_recovery_started := 0
	var previous_state := &""
	var locked_poly := PackedVector2Array()
	var locked_yaw := 0.0
	var locked_index := 0
	var lock_stable := true
	var active_visible := true
	var final_recovery := 0.0
	var finished := false
	for tick in 1200:
		var state: StringName = boss.get_attack_state()
		var timing: Dictionary = boss.get_attack_timing()
		var index: int = timing["chain_index"]
		if state == &"windup" and index != seen:
			seen = index
			windup_started = Engine.get_physics_frames()
			match boss.get_attack_kind():
				&"sweep": damage_expected += 24
				&"slam": damage_expected += 38
				&"charge": damage_expected += 30
			check(boss.is_telegraph_visible(), label + ": every followup starts a visible warning")
		if state == &"windup" or state == &"active":
			place_in_front(boss, player)
		if state == &"windup" and bool(timing["locked"]):
			# Change sides after the lock, then stand inside the advertised polygon during active damage.
			var body: Node3D = boss.get_boss()
			player.global_position = body.global_position - body.global_basis.z * 3.0 + Vector3.UP * 0.1
		elif state == &"active" and float(timing["elapsed"]) < DT * 0.5:
			# Also challenge the active lock for one tick, before returning to the zone ahead of its hit.
			var body: Node3D = boss.get_boss()
			player.global_position = body.global_position - body.global_basis.z * 3.0 + Vector3.UP * 0.1
		if bool(timing["locked"]) and (state == &"windup" or state == &"active"):
			if locked_index != index:
				locked_index = index
				locked_poly = boss.get_telegraph().polygon.duplicate()
				locked_yaw = boss.get_boss().global_rotation.y
			else:
				lock_stable = lock_stable and locked_poly == boss.get_telegraph().polygon
				lock_stable = lock_stable and is_equal_approx(locked_yaw, boss.get_boss().global_rotation.y)
		if state == &"active":
			active_visible = active_visible and boss.is_telegraph_visible()
			if previous_state != &"active" and boss.get_attack_kind() == &"sweep":
				windups.append((Engine.get_physics_frames() - windup_started) * DT)
			if dodge_each and dodged_strike != index and (not first_only or index == 1):
				var hit_fraction := 0.4 if boss.get_attack_kind() == &"sweep" else 0.5
				if float(timing["elapsed"]) >= float(timing["duration"]) * hit_fraction - 0.07:
					Input.parse_input_event(action_event(&"dodge", true))
					dodged_strike = index
		if player.is_dodging() and dodged_strike > dodge_count:
			dodge_count = dodged_strike
			Input.parse_input_event(action_event(&"dodge", false))
		if state == &"recovery" and previous_state == &"active":
			if bool(timing["final_recovery"]):
				final_recovery_started = Engine.get_physics_frames()
			else:
				check(float(timing["duration"]) <= 0.31, label + ": interstrike reset is tight")
			if cross_phase and index == 1:
				boss.get_boss_health().apply_damage(210)
		if state == &"pause":
			if final_recovery_started > 0:
				final_recovery = (Engine.get_physics_frames() - final_recovery_started) * DT
			finished = true
			break
		previous_state = state
		await physics_frame
	Input.parse_input_event(action_event(&"dodge", false))
	player.damage_taken.disconnect(received)
	check(finished, label + ": chain terminates in a real pause")
	check(seen == expected_length if expected_length > 0 else seen >= 2 and seen <= 3, label + ": bounded strike count %d" % seen)
	check(lock_stable and active_visible, label + ": locked geometry/facing survives every active window")
	check(final_recovery >= 1.1, label + ": full-chain recovery permits a punish")
	if first_only:
		check(dodge_count == 1 and damage.size() == seen - 1, label + ": first dodge expires before the followup")
		check(player.get_health().current_health == 100 - (damage_expected - 24), label + ": undodged followup deals its real damage")
	elif dodge_each:
		check(dodge_count == seen, label + ": distinct dodge accepted for each strike")
		check(damage.is_empty() and player.get_health().current_health == 100, label + ": real dodge i-frames avoid the entire combo")
	else:
		check(damage.size() == seen, label + ": each telegraphed strike reaches the real damage consumer once")
		check(player.get_health().current_health == 100 - damage_expected, label + ": baseline HP reflects 24/38/30 damage")
		for i in range(1, hit_frames.size()):
			check(hit_frames[i] - hit_frames[i - 1] > 30, label + ": strikes require distinct dodge windows")
	return {"windups": windups}


func pressure_case(boss: Node, player: Node) -> void:
	player.get_health().restore_full()
	var body: Node3D = boss.get_boss()
	# The opening pause walks the boss toward the player (<= 3.6 m), and the altar/consoles block the centre line,
	# so use an open side-lane target that remains long range at the decision.
	player.global_position = boss.to_global(Vector3(8.0, 0.1, 5.0))
	player.velocity = Vector3.ZERO
	check(await until(func(): return boss.get_attack_state() == &"windup", 4.0), "far stationary target gets an autonomous attack")
	var player_position: Vector3 = player.global_position
	var flat: Vector3 = player_position - body.global_position
	flat.y = 0.0
	var decision_distance: float = flat.length()
	check(decision_distance >= 7.8, "pressure fixture is still long range at the decision (%.2f m)" % decision_distance)
	check(boss.get_attack_kind() == &"charge", "long-range selection closes distance instead of whiffing a short attack")
	check(await until(func(): return boss.get_attack_state() == &"recovery", 4.0), "autonomous charge resolves")
	check(player.get_health().current_health == 70, "autonomous charge pressures its real stationary damage consumer")
	check(await until(func(): return boss.get_attack_state() == &"pause", 8.0), "autonomous chain still ends")


func cancellation_case(game: Node, boss: Node, player: Node) -> void:
	player.get_health().restore_full()
	player.stamina = player.max_stamina
	player.receive_damage(76)  # The chain's first sweep must kill through the actual damage callback.
	var snapshot: Dictionary = boss.get_snapshot()
	check(boss.force_attack(&"sweep", true), "cancellation: combo begins")
	for tick in 240:
		if boss.get_mode_name() == &"player_down":
			break
		place_in_front(boss, player)
		await physics_frame
	check(boss.get_mode_name() == &"player_down" and not boss.is_telegraph_visible(), "player death clears the pending chain and warning")
	check(await until(func(): return boss.get_mode_name() == &"rearmed", 10.0), "respawn returns to retry altar")
	check(player.get_health().current_health == snapshot["hp"] and is_equal_approx(player.stamina, snapshot["stamina"]) and player.potion_count == snapshot["potions"], "retry restores the original resource snapshot")
	check(boss.get_attack_timing()["chain_index"] == 0, "retry discards all chain progress")
	check(boss.use_console(boss.get_arena().altar, player), "retry restarts combat")
	check(boss.force_attack(&"sweep", true), "victory: fresh chain begins")
	for tick in 240:
		if boss.get_attack_state() == &"recovery":
			break
		place_in_front(boss, player)
		await physics_frame
	boss.get_boss_health().apply_damage(420)
	var hp_at_victory: int = player.get_health().current_health
	await frames(240)
	check(boss.is_won() and boss.get_attack_state() == &"pause" and not boss.is_telegraph_visible(), "boss death permanently cuts its chain")
	check(player.get_health().current_health == hp_at_victory and boss.get_attack_timing()["chain_index"] == 0, "no pending strike damages the player after victory")
	check(not game.session.puzzle_progress.has(&"gatekeeper_snapshot"), "victory still clears persisted retry snapshot")


func place_in_front(boss: Node, player: Node) -> void:
	var body: Node3D = boss.get_boss()
	player.global_position = body.global_position + body.global_basis.z * 3.0 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO


func action_event(action: StringName, pressed: bool) -> InputEvent:
	var event: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	if event is InputEventKey:
		event.pressed = pressed
	elif event is InputEventMouseButton:
		event.pressed = pressed
	return event


func until(predicate: Callable, seconds: float) -> bool:
	for tick in int(ceil(seconds / DT)):
		if predicate.call():
			return true
		await physics_frame
	return bool(predicate.call())


func frames(count: int) -> void:
	for tick in count:
		await physics_frame


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
