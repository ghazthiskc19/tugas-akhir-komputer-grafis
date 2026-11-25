extends Node
## Island session: collected/killed IDs, active checkpoint, puzzle/boss progress; death -> respawn at checkpoint (no scene reload).
## Persisted via export_state()/import_state() (island_save.gd); import BEFORE objectives/boss bind.
## Wiring: add as node "Session" (group `session`), set player_path; enemies via register_enemy() or group `enemies`.

const IslandSave := preload("res://scripts/world/island_save.gd")

signal status_changed
signal checkpoint_changed(checkpoint_id: StringName)
signal respawned

@export var player_path: NodePath
@export var respawn_delay := 2.0
@export var death_y := -8.0
## Group scanned (deferred, after everyone is ready) for enemies; use register_enemy() for extra nodes.
@export var enemy_group := &"enemies"

var checkpoint_transform := Transform3D.IDENTITY
var checkpoint_id := &""
## id -> kind (&"potion", &"artifact", ...). Survives death for the whole session.
var collected_ids: Dictionary[StringName, StringName] = {}
var killed_enemy_ids: Dictionary[StringName, bool] = {}
## Real objective state (see IslandSave.decode_progress for the validated keys): puzzle flags, gatekeeper sockets/started/
## snapshot/defeated/gate_open. Mutated in place by the objectives and the gatekeeper.
var puzzle_progress: Dictionary = {}

var _player: Node3D
var _enemies: Array[Node] = []
var _respawn_pending := false


func _ready() -> void:
	add_to_group(&"session")
	_auto_initialize.call_deferred()


func _auto_initialize() -> void:
	if _player == null:
		var node := get_node_or_null(player_path) as Node3D
		if node == null:
			node = get_tree().get_first_node_in_group(&"player") as Node3D
		if node != null:
			initialize(node)
	if _enemies.is_empty():
		for enemy in get_tree().get_nodes_in_group(enemy_group):
			register_enemy(enemy)


## Binds the player (connects died). Safe to call again with a different player.
func initialize(player: Node3D) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_signal(&"died"):
		if _player.died.is_connected(_on_player_died):
			_player.died.disconnect(_on_player_died)
	_player = player
	if checkpoint_transform == Transform3D.IDENTITY:
		checkpoint_transform = player.global_transform
	if player.has_signal(&"died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	status_changed.emit()


func register_enemy(enemy: Node) -> void:
	if enemy == null or _enemies.has(enemy):
		return
	# Persisted kill: the enemy stays dead for the session, so remove it instead of registering.
	if killed_enemy_ids.has(_enemy_id(enemy)) and not _is_enemy_dead(enemy):
		enemy.queue_free()
		return
	_enemies.append(enemy)
	if enemy.has_signal(&"defeated") and not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
	if _is_enemy_dead(enemy):
		_mark_killed(enemy)


## JSON-friendly snapshot (see island_save.gd). Includes the exact boss snapshot inside puzzle_progress.
func export_state() -> Dictionary:
	var killed: Array = []
	for id in killed_enemy_ids:
		killed.append(String(id))
	var collected := {}
	for id in collected_ids:
		collected[String(id)] = String(collected_ids[id])
	return {
		"checkpoint_id": String(checkpoint_id),
		"checkpoint_transform": IslandSave.encode_transform(checkpoint_transform),
		"collected": collected,
		"killed": killed,
		"puzzle_progress": IslandSave.encode_progress(puzzle_progress),
	}


## Transactional: validates everything first, assigns only when the whole payload is valid. Call BEFORE objective setup
## (objectives/gatekeeper read puzzle_progress, collected and killed ids when they bind).
func import_state(data: Dictionary) -> bool:
	var decoded := IslandSave.decode_session(data)
	if decoded.is_empty():
		return false
	checkpoint_id = decoded["checkpoint_id"]
	checkpoint_transform = decoded["checkpoint_transform"]
	collected_ids = decoded["collected"]
	killed_enemy_ids = decoded["killed"]
	puzzle_progress = decoded["puzzle_progress"]
	status_changed.emit()
	return true


## True when the boss fight was started but not won: resume at the boss retry entrance with the original snapshot.
func is_boss_retry_pending() -> bool:
	return puzzle_progress.get(&"gatekeeper_started", false) == true \
		and puzzle_progress.get(&"gatekeeper_defeated", false) != true \
		and puzzle_progress.get(&"gatekeeper_snapshot") is Dictionary


func get_boss_snapshot() -> Dictionary:
	var snap: Variant = puzzle_progress.get(&"gatekeeper_snapshot")
	return snap.duplicate() if snap is Dictionary else {}


## Drops enemy registrations (not collected/killed state) so the parent can re-register.
func clear_registrations() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.has_signal(&"defeated") and enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.disconnect(_on_enemy_defeated)
	_enemies.clear()


## Atomically claims a pickup id. False when already claimed.
func claim(id: StringName, kind: StringName) -> bool:
	if id == &"" or collected_ids.has(id):
		return false
	collected_ids[id] = kind
	status_changed.emit()
	return true


func is_collected(id: StringName) -> bool:
	return collected_ids.has(id)


func count_kind(kind: StringName) -> int:
	var n := 0
	for k in collected_ids.values():
		if k == kind:
			n += 1
	return n


## Sets the respawn point to `spot`'s transform. Never heals. False if already active.
func set_checkpoint(id: StringName, spot: Node3D) -> bool:
	if id == checkpoint_id:
		return false
	checkpoint_id = id
	checkpoint_transform = spot.global_transform
	checkpoint_changed.emit(id)
	status_changed.emit()
	return true


func get_status() -> String:
	var cp := "awal" if checkpoint_id == &"" else String(checkpoint_id)
	return "Checkpoint: %s • Artefak: %d • Ramuan diambil: %d • Musuh kalah: %d%s" % [
		cp, count_kind(&"artifact"), count_kind(&"potion"), killed_enemy_ids.size(),
		" • Bangkit..." if _respawn_pending else "",
	]


func is_respawn_pending() -> bool:
	return _respawn_pending


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _respawn_pending:
		return
	if _player.global_position.y >= death_y or _player.has_method(&"is_dead") and _player.is_dead():
		return
	_kill_player_environment()


## Environment death: lethal through the real Health so i-frames/defense cannot save the player.
func _kill_player_environment() -> void:
	var health := _player.get_node_or_null(^"Health")
	if health != null:
		health.apply_damage(health.max_health)
	elif _player.has_method(&"receive_damage"):
		_player.receive_damage(1000000)


func _on_enemy_defeated(enemy_id: StringName) -> void:
	if enemy_id != &"" and not killed_enemy_ids.has(enemy_id):
		killed_enemy_ids[enemy_id] = true
		status_changed.emit()


func _is_enemy_dead(enemy: Node) -> bool:
	var health := enemy.get_node_or_null(^"Health")
	return health != null and health.is_dead


func _enemy_id(enemy: Node) -> StringName:
	return enemy.get(&"enemy_id") if enemy.get(&"enemy_id") != null else StringName(enemy.name)


func _mark_killed(enemy: Node) -> void:
	_on_enemy_defeated(_enemy_id(enemy))


func _on_player_died() -> void:
	if _respawn_pending:
		return
	_respawn_pending = true
	status_changed.emit()
	# process_always=false: timer pauses with the tree.
	get_tree().create_timer(respawn_delay, false).timeout.connect(_respawn)


func _respawn() -> void:
	if not _respawn_pending:
		return
	_respawn_pending = false
	if _player == null or not is_instance_valid(_player) or not is_inside_tree():
		return
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		projectile.queue_free()
	_player.global_transform = checkpoint_transform
	if "velocity" in _player:
		_player.velocity = Vector3.ZERO
	if _player.has_method(&"restore_for_respawn"):
		_player.restore_for_respawn()
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if _is_enemy_dead(enemy):
			_mark_killed(enemy)
		elif enemy.has_method(&"reset_encounter"):
			enemy.reset_encounter()
	respawned.emit()
	status_changed.emit()
