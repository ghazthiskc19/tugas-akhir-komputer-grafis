extends SceneTree
## Real enemy scenes and real GroundPlayer damage/defenses in an isolated physics arena.
## Setup only: teleports, optional active-window stress override, and disabling reacquisition after reset/stagger.
## No island state/save side effects. Run from project root:
## C:/Godot/godot.exe --headless --fixed-fps 60 --path . --script res://scripts/tests/enemy_pattern_regression.gd

const PLAYER_FIXTURE := preload("res://scenes/tests/movement_lab.tscn")
const ENEMIES := {
	"standard": preload("res://scenes/enemies/standard_melee.tscn"),
	"heavy": preload("res://scenes/enemies/heavy_melee.tscn"),
	"ranged": preload("res://scenes/enemies/ranged_enemy.tscn"),
}

var _world: Node3D
var _player: Node
var _enemy: Node
var _events: Array = []
var _damage: Array = []
var _checks := 0
var _failures: Array[String] = []


## Pin only horizontal contact: preserve real gravity/floor contact so a grounded dodge can start.
class ContactAnchor extends Node:
	var player: Node3D
	var contact := Vector3.ZERO

	func _physics_process(_delta: float) -> void:
		var position := player.global_position
		position.x = contact.x
		position.z = contact.z
		player.global_position = position
		player.velocity.x = 0.0
		player.velocity.z = 0.0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	for kind in ["standard", "heavy", "ranged"]:
		await _test_chain(kind)
		await _test_wall(kind)
	await _test_heavy_closing()
	await _test_heavy_sweep()
	await _test_ranged_spacing()
	await _test_commit()
	await _test_block()
	await _test_dodge_contact()
	for interruption in ["reset", "stagger", "death"]:
		await _test_cancel(interruption)
	await _test_dead_player()
	await _test_leash()
	print("enemy_pattern_regression: %d checks, %d failed" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("FAIL " + failure)
	await _end_case()
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _until(predicate: Callable, seconds: float) -> bool:
	for _i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if predicate.call():
			return true
		await physics_frame
	return bool(predicate.call())


func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.position = position
	return body


func _new_case(kind: String, distance: float, settings: Dictionary = {}) -> void:
	await _end_case()
	_events.clear()
	_damage.clear()
	_world = Node3D.new()
	root.add_child(_world)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	_world.add_child(camera)
	_box(Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	# Reuse the authored player rather than reproducing its collision/animation/health wiring.
	var fixture: Node = PLAYER_FIXTURE.instantiate()
	_player = fixture.get_node("Player")
	fixture.remove_child(_player)
	fixture.free()
	_player.combat_enabled = true
	_player.position = Vector3(0, 0.01, distance)
	_world.add_child(_player)
	_player.damage_taken.connect(func(amount: int, blocked: bool) -> void:
		_damage.append([amount, blocked, Engine.get_physics_frames()]))
	_enemy = (ENEMIES[kind] as PackedScene).instantiate()
	_enemy.overrides = settings
	_world.add_child(_enemy)
	_enemy.set_physics_process(false)
	_enemy.state_changed.connect(func(next: StringName) -> void:
		_events.append([next, Engine.get_physics_frames()]))
	_check(await _until(func(): return _player.is_on_floor(), 3.0),
		kind + ": real player fixture reaches the arena floor before combat")


func _end_case() -> void:
	Input.action_release(&"block")
	Input.action_release(&"dodge")
	if is_instance_valid(_world):
		_world.queue_free()
		await _frames(4)
	_world = null
	_player = null
	_enemy = null


func _start() -> void:
	_enemy.set_physics_process(true)


func _count(state_name: StringName) -> int:
	var count := 0
	for event in _events:
		if event[0] == state_name:
			count += 1
	return count


func _first_combo_finished() -> bool:
	return _count(&"active") > 0 and _enemy.get_state_name() == &"chase"


func _test_chain(kind: String) -> void:
	var distance := 7.0 if kind == "ranged" else (2.2 if kind == "heavy" else 1.3)
	await _new_case(kind, distance)
	_start()
	_check(await _until(_first_combo_finished, 8.0), kind + ": bounded combo reaches full recovery and chase")
	_enemy.set_physics_process(false)
	await _frames(40) # Let the last real bolt arrive.
	var expected := 3 if kind == "ranged" else 2
	var amount := 10 if kind == "ranged" else (32 if kind == "heavy" else 12)
	_check(_count(&"windup") == expected and _count(&"active") == expected,
		kind + ": every strike has a separate visible warning and active window")
	_check(_damage.size() == expected and _player.get_health().current_health == 100 - expected * amount,
		kind + ": each strike pressures a stationary real player exactly once")
	if _damage.size() == expected:
		for index in range(1, expected):
			_check(_damage[index][2] - _damage[index - 1][2] < 1.5 * Engine.physics_ticks_per_second,
				kind + ": real followup damage arrives before a potion could finish between hits")


func _test_wall(kind: String) -> void:
	var distance := 7.0 if kind == "ranged" else 2.0
	await _new_case(kind, distance)
	_start()
	_check(await _until(func(): return _enemy.get_state_name() == &"windup", 3.0), kind + ": wall test starts a real attack")
	var wall := _box(Vector3(0, 1.5, distance * 0.5), Vector3(20, 3, 0.25))
	_check(await _until(_first_combo_finished, 8.0), kind + ": obstructed chain still terminates")
	_check(_damage.is_empty() and _player.get_health().current_health == 100,
		kind + ": wall inserted during windup shields every strike/bolt")
	wall.queue_free()
	_check(await _until(func(): return not _damage.is_empty(), 8.0),
		kind + ": removing cover restores actual damage (not a disabled attack)")


func _test_heavy_closing() -> void:
	await _new_case("heavy", 9.0)
	_start()
	await _frames(75)
	_check(_enemy.global_position.z > 3.5, "heavy: closes a distant gap instead of slow baseline walking")
	_check(await _until(func(): return not _damage.is_empty(), 5.0), "heavy: gap closing ends in a damaging strike")


func _test_ranged_spacing() -> void:
	await _new_case("ranged", 2.0)
	_start()
	await _frames(75)
	_check(_enemy.global_position.z < -1.5, "ranged: retreats from a close player while retaining aim")
	_check(await _until(func(): return not _damage.is_empty(), 6.0), "ranged: retreat transitions back into real burst pressure")
	await _new_case("ranged", 7.0)
	_start()
	await _frames(35)
	_check(absf(_enemy.global_position.x) > 0.2, "ranged: sidesteps while warning instead of planting until recovery")

func _test_heavy_sweep() -> void:
	await _new_case("heavy", 2.2)
	_start()
	_check(await _until(func(): return _count(&"windup") == 2 and _enemy.get_state_name() == &"windup" and _enemy._state_time > 0.65, 5.0),
		"heavy: delayed second warning reaches its committed sweep")
	var origin: Vector3 = _enemy.global_position
	# Enter only the sweep's flank AFTER aim locks: a narrow repeat of the chop would miss here.
	_player.global_position = origin + Vector3(2.0, 0.01, 1.3)
	await _until(_first_combo_finished, 4.0)
	_check(_damage.size() == 2 and _player.get_health().current_health == 36,
		"heavy: broad followup damages a real player outside the first chop's width")



func _test_commit() -> void:
	await _new_case("standard", 1.3)
	_start()
	_check(await _until(func(): return _enemy.get_state_name() == &"windup" and _enemy._state_time > 0.50, 3.0),
		"standard: reaches committed warning")
	var origin: Vector3 = _enemy.global_position
	var facing: float = _enemy.rotation.y
	_player.global_position = Vector3(4, 0.01, 1.3)
	_check(await _until(func(): return _enemy.get_state_name() == &"active", 1.0), "standard: committed strike becomes active")
	await _frames(5)
	_check(_enemy.global_position.distance_to(origin) < 0.01 and absf(angle_difference(facing, _enemy.rotation.y)) < 0.01,
		"standard: late warning and active preserve the committed origin and direction")
	_check(_damage.is_empty(), "standard: committed strike cannot track a player out of its warned box")


func _test_block() -> void:
	await _new_case("standard", 1.3)
	Input.action_press(&"block")
	_check(await _until(func(): return _player.is_blocking(), 1.0), "block: actual input raises guard")
	_start()
	await _until(_first_combo_finished, 5.0)
	_check(_damage.size() == 2 and _damage[0][1] and _damage[1][1] and _player.get_health().current_health == 94,
		"block: both separately warned hits use real guard reduction")


func _test_dodge_contact() -> void:
	await _new_case("standard", 1.3, {"active": 0.32})
	_enemy.process_physics_priority = 2
	var anchor := ContactAnchor.new()
	anchor.player = _player
	anchor.contact = _player.global_position
	anchor.process_physics_priority = 1
	_world.add_child(anchor)
	_enemy.state_changed.connect(func(next: StringName) -> void:
		if next == &"active" and _count(&"active") == 1:
			var event := InputEventAction.new()
			event.action = &"dodge"
			event.pressed = true
			_player._unhandled_input(event))
	_start()
	_check(await _until(func(): return _count(&"recovery") == 1, 4.0), "dodge: first live window completes")
	_check(_player.stamina < 100 and _player.get_health().current_health == 100,
		"dodge: a real dodge rejects contact once; same strike never retries after immunity expires")
	await _until(_first_combo_finished, 4.0)
	_check(_damage.size() == 1 and _player.get_health().current_health == 88,
		"dodge: immunity is not carried into the separately warned followup")


func _test_cancel(interruption: String) -> void:
	await _new_case("ranged", 10.0)
	_start()
	_check(await _until(func(): return not get_nodes_in_group(&"enemy_projectiles").is_empty(), 4.0),
		interruption + ": first aimed bolt is genuinely airborne")
	if interruption == "death":
		_enemy.get_node("Health").apply_damage(999)
	elif interruption == "stagger":
		_enemy.get_node("Health").apply_damage(1)
		_check(_enemy.get_state_name() == &"stagger", "stagger: ranged attack really interrupted")
		_enemy.set_physics_process(false) # Freeze fresh acquisition, not projectile physics.
	else:
		_enemy.reset_encounter()
		_check(_enemy.get_state_name() == &"idle", "reset: encounter is idle immediately")
		_enemy.set_physics_process(false) # A nearby living target would legitimately start a NEW combo.
	await _frames(180)
	_check(_count(&"active") == 1 and get_nodes_in_group(&"enemy_projectiles").is_empty(),
		interruption + ": interrupts remaining burst and removes airborne pressure")
	_check(_damage.is_empty() and _player.get_health().current_health == 100,
		interruption + ": interrupted projectile cannot deliver delayed real-player damage")


func _test_dead_player() -> void:
	await _new_case("standard", 1.3)
	_start()
	await _until(func(): return _enemy.get_state_name() == &"windup", 3.0)
	_player.receive_damage(999)
	await _frames(150)
	_check(_count(&"active") == 0 and _player.is_dead(), "death: player death cancels pending strikes without restarting")


func _test_leash() -> void:
	await _new_case("standard", 1.3)
	_start()
	await _until(func(): return _enemy.get_state_name() == &"windup", 3.0)
	_player.global_position = Vector3(0, 0.01, 35)
	await _frames(120)
	_check(_count(&"active") == 0 and _enemy.global_position.length() < 0.5,
		"leash: leaving the encounter during a warning cancels the chain and returns home")
