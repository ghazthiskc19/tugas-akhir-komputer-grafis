extends "res://scripts/camera/orbit_camera.gd"
## I07: kamera orbit + collision dunia.
## Seluruh update (stick, fokus ter-damping, query, penempatan) berjalan di satu langkah fisika (dilewati saat jeda),
## sehingga batas jarak selalu dihitung dari arah dan fokus yang sama dengan yang dipakai menempatkan kamera.
## Sphere cast memakai radius penuh (>= near plane); tidak ada radius yang dikecilkan diam-diam.
## Mendekat segera saat terhalang atau zoom-in; zoom-out/kembali halus tetapi tidak pernah melewati batas aktif.

@export var collision_enabled := true
## Hanya dunia (layer 1); pemain (layer 2) tidak menghalangi.
@export_flags_3d_physics var world_mask := 1
## Radius bola probe; lebih besar dari near plane sehingga dinding tidak memotong near plane.
@export var probe_radius := 0.25
## Jarak tambahan dari permukaan.
@export var probe_margin := 0.1
## Laju (1/detik) kembali ke jarak ideal setelah halangan hilang.
@export var return_damping := 4.0

## Langkah pencarian garis saat fokus ter-damping berada di dalam padatan.
const RECOVERY_STEPS := 8

var _probe := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _space: PhysicsDirectSpaceState3D
var _limit := INF
var _distance := -1.0


func _ready() -> void:
	super._ready()
	if _target == null:
		return
	_probe.radius = probe_radius
	_query.shape = _probe
	_query.collision_mask = world_mask
	if _target is CollisionObject3D:
		_query.exclude = [(_target as CollisionObject3D).get_rid()]
	# Satu jalur update saja: _process orbit dimatikan, semuanya di _physics_process.
	set_process(false)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if is_paused():
		return
	_update_stick(delta)
	_follow_focus(delta)
	_limit = INF
	if collision_enabled:
		_space = get_world_3d().direct_space_state
		if not _recover_focus():
			# Tidak ada titik bebas antara fokus ter-damping dan target: tahan posisi kamera terakhir.
			_limit = 0.0
			return
		_limit = _measure_limit()
	_place(delta)


## Batas jarak aman terakhir dari sphere cast fisika (INF bila tidak terhalang atau collision mati).
func get_arm_limit() -> float:
	return _limit


## Fokus ter-damping bisa melintasi padatan (cast_motion mengabaikan padatan tempat bola sudah berada).
## Bila bola penuh overlap di fokus, geser fokus ke arah target sampai bebas. False bila tidak ada.
func _recover_focus() -> bool:
	if not _overlaps(_focus):
		return true
	var anchor := get_target_focus()
	for step in range(1, RECOVERY_STEPS + 1):
		var candidate := _focus.lerp(anchor, float(step) / RECOVERY_STEPS)
		if not _overlaps(candidate):
			_focus = candidate
			return true
	return false


func _measure_limit() -> float:
	var reach := _ideal_distance + probe_margin
	var direction := _direction()
	_query.transform = Transform3D(Basis.IDENTITY, _focus)
	_query.motion = direction * reach
	var result := _space.cast_motion(_query)
	var limit := _ideal_distance
	if result.size() >= 2 and result[0] < 1.0:
		# Boleh lebih kecil dari batas "nyaman"; tidak pernah dipaksa maju ke dalam halangan.
		limit = clampf(result[0] * reach - probe_margin, 0.0, _ideal_distance)
	# Verifikasi akhir dengan radius penuh di posisi kamera; mundur bertahap bila masih overlap.
	for i in 4:
		if limit <= 0.0 or not _overlaps(_focus + direction * limit):
			return limit
		limit *= 0.5
	return 0.0 if _overlaps(_focus + direction * limit) else limit


func _overlaps(origin: Vector3) -> bool:
	_query.transform = Transform3D(Basis.IDENTITY, origin)
	_query.motion = Vector3.ZERO
	return not _space.intersect_shape(_query, 1).is_empty()


func _placement_distance(delta: float) -> float:
	if _distance < 0.0:
		_distance = _ideal_distance
	var limit := minf(_limit, _ideal_distance)
	if limit <= _distance:
		_distance = limit
	else:
		var eased := lerpf(_distance, _ideal_distance, 1.0 - exp(-return_damping * delta))
		_distance = minf(eased, limit)
	return _distance
