extends "res://scripts/camera/smooth_follow_camera.gd"
## I06 kamera orbit: yaw 360 derajat, pitch dibatasi, titik fokus mengikuti target dengan damping.
## Input: tahan klik tengah (mouse tertangkap, delta relatif) atau stick kanan gamepad.
## Tidak ada auto-yaw dari pemain dan tidak ada collision kamera (lihat collision_orbit_camera.gd).
## Kontrak publik: is_orbiting() dan get_target_focus().

const STICK_DEADZONE := 0.2

@export_range(0.0, 89.0) var min_pitch_degrees := 20.0
@export_range(0.0, 89.0) var max_pitch_degrees := 65.0
## Radian per piksel delta mouse.
@export var mouse_sensitivity := 0.003
## Radian per detik pada stick penuh.
@export var stick_speed := 2.0

var _yaw := 0.0
var _pitch := 0.0
var _ideal_distance := 1.0
var _focus := Vector3.ZERO

var _arm_distance := 1.0
var _mouse_orbiting := false
var _saved_mouse := Vector2i.ZERO
var _window_focused := true
## Nilai mentah stick kanan per device dari event; device yang terputus dihapus.
var _sticks: Dictionary[int, Vector2] = {}
var _stick_input := Vector2.ZERO


func _ready() -> void:
	super._ready()
	if _target == null:
		return
	# Orbit awal diturunkan dari offset I05 (pitch ~37,9 derajat, yaw 0).
	_ideal_distance = offset.length()
	_yaw = atan2(offset.x, offset.z)
	_pitch = clampf(
		atan2(offset.y, Vector2(offset.x, offset.z).length()),
		deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees)
	)
	_focus = get_target_focus()
	_place(0.0)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	cancel_orbit()


func _notification(what: int) -> void:
	# Fokus hilang: lepas capture; tidak ada capture otomatis saat fokus kembali.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_sticks.clear()
		_stick_input = Vector2.ZERO
		cancel_orbit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


## True saat klik tengah menangkap mouse ATAU stick kanan aktif (di luar deadzone).
func is_orbiting() -> bool:
	return _mouse_orbiting or _stick_input != Vector2.ZERO


## Titik fokus target (belum di-damping): posisi target + focus_height.
func get_target_focus() -> Vector3:
	return _target.global_position + Vector3(0.0, focus_height, 0.0)


## Melepas capture mouse dan mengembalikan pointer ke posisi sebelum orbit.
func cancel_orbit() -> void:
	if not _mouse_orbiting:
		return
	_mouse_orbiting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.warp_mouse(_saved_mouse)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_MIDDLE:
			return
		if button.pressed and _window_focused and not _mouse_orbiting:
			_saved_mouse = DisplayServer.mouse_get_position()
			_mouse_orbiting = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not button.pressed:
			cancel_orbit()
	elif event is InputEventMouseMotion:
		if _mouse_orbiting:
			_rotate((event as InputEventMouseMotion).relative * mouse_sensitivity)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			cancel_orbit()
	elif event is InputEventJoypadMotion:
		if not _window_focused:
			return
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_RIGHT_X and motion.axis != JOY_AXIS_RIGHT_Y:
			return
		var stick: Vector2 = _sticks.get(motion.device, Vector2.ZERO)
		if motion.axis == JOY_AXIS_RIGHT_X:
			stick.x = motion.axis_value
		else:
			stick.y = motion.axis_value
		_sticks[motion.device] = stick


func _process(delta: float) -> void:
	_update_stick(delta)
	_follow_focus(delta)
	_place(delta)


## Stick: deadzone radial lalu skala ulang; device dengan defleksi terbesar yang dipakai.
func _update_stick(delta: float) -> void:
	var best := Vector2.ZERO
	var best_squared := 0.0
	for device: int in _sticks:
		var stick: Vector2 = _sticks[device]
		if stick.length_squared() > best_squared:
			best = stick
			best_squared = stick.length_squared()
	_stick_input = Vector2.ZERO
	if best_squared > STICK_DEADZONE * STICK_DEADZONE:
		var length := sqrt(best_squared)
		var strength := minf((length - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 1.0)
		_stick_input = best / length * strength
		_rotate(_stick_input * stick_speed * delta)


## Delta (x = geser horizontal, y = geser vertikal) -> yaw/pitch. Mouse ke kanan memutar pandangan ke kanan.
func _rotate(amount: Vector2) -> void:
	_yaw = wrapf(_yaw - amount.x, -PI, PI)
	_pitch = clampf(_pitch + amount.y, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func _follow_focus(delta: float) -> void:
	var goal := get_target_focus()
	_focus.x = lerpf(_focus.x, goal.x, 1.0 - exp(-horizontal_damping * delta))
	_focus.z = lerpf(_focus.z, goal.z, 1.0 - exp(-horizontal_damping * delta))
	_focus.y = lerpf(_focus.y, goal.y, 1.0 - exp(-vertical_damping * delta))


## Arah dari fokus ke kamera (vektor satuan).
func _direction() -> Vector3:
	return Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	)


func _place(delta: float) -> void:
	var direction := _direction()
	_arm_distance = _placement_distance(delta)
	global_position = _focus + direction * _arm_distance
	global_basis = Basis.looking_at(-direction, Vector3.UP)


## Jarak kamera dari fokus. Subclass collision menimpa ini.
func _placement_distance(_delta: float) -> float:
	return _ideal_distance


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_sticks.erase(device)


## Yaw/pitch dalam radian (pitch = elevasi kamera di atas fokus).
func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


## Jarak kamera-fokus yang dipakai pada frame terakhir (setelah collision pada subclass).
func get_arm_distance() -> float:
	return _arm_distance


## Posisi fokus ter-damping yang dipakai sebagai pangkal lengan kamera.
func get_damped_focus() -> Vector3:
	return _focus
