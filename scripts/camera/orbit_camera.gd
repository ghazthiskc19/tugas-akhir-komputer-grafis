extends "res://scripts/camera/smooth_follow_camera.gd"
## Kamera orbit third-person bergaya mouse-look (default: mouse tertangkap).
## Mouse: gerak = yaw/pitch (screen_relative), scroll = zoom lengan kamera. Stick kanan gamepad: orbit.
## Esc menukar jeda SceneTree sungguhan; kamera berjalan saat jeda (PROCESS_MODE_ALWAYS) dan memiliki
## overlay jeda (CanvasLayer) dengan tombol Lanjutkan. Hilang fokus jendela = jeda dan mouse dilepas;
## kembali ke permainan hanya lewat klik Lanjutkan atau Esc (tidak pernah otomatis saat fokus kembali).
## Tidak ada auto-yaw dari pemain dan tidak ada collision kamera (lihat collision_orbit_camera.gd).
## Kontrak publik: get_target_focus(), get_zoom_distance(), is_paused(), is_mouse_captured(),
## pause_game(), resume_game(), toggle_pause(), get_pause_panel(), get_resume_button().

const STICK_DEADZONE := 0.2
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const Vfx := preload("res://scripts/vfx/combat_vfx.gd")

@export_range(0.0, 89.0) var min_pitch_degrees := 20.0
@export_range(0.0, 89.0) var max_pitch_degrees := 65.0
## Radian per piksel layar (screen_relative).
@export var mouse_sensitivity := 0.003
## Radian per detik pada stick penuh.
@export var stick_speed := 2.0
## Batas jarak lengan yang diminta lewat scroll (meter).
@export var min_distance := 4.0
@export var max_distance := 14.0
## Perubahan jarak per langkah scroll (meter).
@export var zoom_step := 1.0

var _yaw := 0.0
var _pitch := 0.0
## Jarak lengan yang diminta (target zoom). Subclass collision dapat menempatkan kamera lebih dekat.
var _ideal_distance := 1.0
var _focus := Vector3.ZERO
## Guncangan: trauma^2 * SHAKE_METERS geser kamera (meter; ~4 px per 0,1 m pada jarak awal), roll SHAKE_ROLL_DEGREES,
## meluruh SHAKE_DECAY per detik. Diskalakan Vfx.shake_scale (pengaturan pemain).
const MAX_SHAKE := 1.0
const SHAKE_DECAY := 2.4
const SHAKE_METERS := 0.9
const SHAKE_ROLL_DEGREES := 3.5
const SHAKE_FREQUENCY := 42.0
var _shake := 0.0
var _shake_clock := 0.0
## Diagnostik (x/y = geser meter, z = kekuatan) frame terakhir; dipakai pengukuran tuning.
var last_shake_offset := Vector3.ZERO
var _base_basis := Basis.IDENTITY
var _roll_applied := false

var _arm_distance := 1.0
var _captured := false
## Event gerak pertama setelah capture dibuang agar tidak ada rotasi dari delta lama.
var _drop_next_motion := false
var _window_focused := true
## Nilai mentah stick kanan per device dari event; device yang terputus dihapus.
var _sticks: Dictionary[int, Vector2] = {}
var _stick_input := Vector2.ZERO

var _pause_layer: CanvasLayer
var _pause_panel: Control
var _resume_button: Button


func _ready() -> void:
	# Kamera dan overlay jeda tetap berjalan saat SceneTree dijeda.
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	if _target == null:
		return
	_ideal_distance = clampf(offset.length(), min_distance, max_distance)
	_yaw = atan2(offset.x, offset.z)
	_pitch = clampf(
		atan2(offset.y, Vector2(offset.x, offset.z).length()),
		deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees)
	)
	_focus = get_target_focus()
	_place(0.0)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_pause_ui()
	_enable_shake_driver.call_deferred()
	# Default: mouse tertangkap. Tidak membaca fokus di sini (race saat jendela dibuat);
	# hilang fokus ditangani NOTIFICATION_WM_WINDOW_FOCUS_OUT.
	resume_game()


func _exit_tree() -> void:
	Vfx.reset_transients()
	_release_mouse()
	if is_inside_tree():
		get_tree().paused = false


func _notification(what: int) -> void:
	# Fokus hilang: jeda dan lepas mouse; tidak ada capture otomatis saat fokus kembali.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_sticks.clear()
		_stick_input = Vector2.ZERO
		if _resume_button != null:
			pause_game()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


## True saat SceneTree dijeda (overlay jeda tampil).
func is_paused() -> bool:
	return is_inside_tree() and get_tree().paused


## True saat mouse tertangkap untuk mouse-look.
func is_mouse_captured() -> bool:
	return _captured


## Jarak lengan yang diminta (hasil scroll), selalu dalam [min_distance, max_distance].
func get_zoom_distance() -> float:
	return _ideal_distance

func set_zoom_distance(distance: float) -> void:
	_ideal_distance = clampf(distance, min_distance, max_distance)


## Titik fokus target (belum di-damping): posisi target + focus_height.
func get_target_focus() -> Vector3:
	return _target.global_position + Vector3(0.0, focus_height, 0.0)


## Root overlay jeda (Control "CameraPause/Panel"); visible hanya saat jeda.
func get_pause_panel() -> Control:
	return _pause_panel


## Tombol "Lanjutkan" pada overlay jeda.
func get_resume_button() -> Button:
	return _resume_button


## Menjeda SceneTree, menampilkan overlay, melepas mouse. Aman dipanggil berulang.
func pause_game() -> void:
	Vfx.reset_transients()
	get_tree().paused = true
	var opening := not _pause_panel.visible or _pause_panel.modulate.a < 1.0
	_pause_panel.visible = true
	if opening:
		UI_THEME.reveal(_pause_panel, _pause_panel.get_node("Frame") as Control)
	_release_mouse()


## Melanjutkan: tutup overlay, tangkap mouse, buang delta mouse lama.
## Permainan lanjut seketika; hanya overlay yang memudar keluar.
func resume_game() -> void:
	get_tree().paused = false
	UI_THEME.dismiss(_pause_panel, _pause_panel.get_node("Frame") as Control)
	_captured = true
	_drop_next_motion = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause() -> void:
	if is_paused():
		resume_game()
	else:
		pause_game()


func _release_mouse() -> void:
	_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_pause_ui() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "CameraPause"
	_pause_layer.layer = 100
	add_child(_pause_layer)

	_pause_panel = Control.new()
	_pause_panel.name = "Panel"
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.visible = false
	_pause_panel.theme = UI_THEME.theme()
	_pause_layer.add_child(_pause_panel)
	# Camera3D bukan parent Control; ukuran root overlay harus mengikuti viewport secara eksplisit.
	_pause_panel.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): _pause_panel.size = get_viewport().get_visible_rect().size)

	var dim := UI_THEME.backdrop(Color(0.0, 0.0, 0.0, 0.4), 8.0)
	dim.name = "Dim"
	_pause_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	_pause_panel.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	frame.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "JEDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", UI_THEME.title_font())
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", UI_THEME.GOLD)
	box.add_child(title)

	_resume_button = Button.new()
	_resume_button.name = "Resume"
	_resume_button.text = "Lanjutkan (Esc)"
	_resume_button.custom_minimum_size = Vector2(260.0, 52.0)
	# Tanpa fokus keyboard: Space/Enter tidak menekan tombol tersembunyi setelah lanjut.
	_resume_button.focus_mode = Control.FOCUS_NONE
	_resume_button.pressed.connect(resume_game)
	box.add_child(_resume_button)
	UI_THEME.hover_button(_resume_button)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
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


## Kontrol permainan memakai _unhandled_input: klik/gerak pada GUI (tombol Lanjutkan) tidak sampai ke sini.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if is_paused() or not _captured:
		return
	if event is InputEventMouseMotion:
		if _drop_next_motion:
			_drop_next_motion = false
			return
		_rotate((event as InputEventMouseMotion).screen_relative * mouse_sensitivity)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)


func _zoom(amount: float) -> void:
	set_zoom_distance(_ideal_distance + amount)


## Tambah guncangan kamera (trauma 0..1, menumpuk, meluruh). Menggeser kamera (h/v_offset, meter) dan memutar sedikit (roll).
func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, MAX_SHAKE)


## Guncangan = noise halus (bukan acak per frame) dengan kekuatan trauma^2, dikali slider "Guncangan kamera".
func _apply_shake(delta: float) -> void:
	var intensity := Vfx.shake_scale
	if _shake <= 0.0 or intensity <= 0.0:
		_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
		h_offset = 0.0
		v_offset = 0.0
		if _roll_applied:
			_roll_applied = false
			global_basis = _base_basis
		return
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	_shake_clock += delta
	var strength := _shake * _shake * intensity
	var t := _shake_clock * SHAKE_FREQUENCY
	h_offset = _noise(t, 0.0) * strength * SHAKE_METERS
	v_offset = _noise(t, 17.3) * strength * SHAKE_METERS * 0.8
	_roll_applied = true
	global_basis = _base_basis * Basis(Vector3.BACK, deg_to_rad(_noise(t, 41.7) * strength * SHAKE_ROLL_DEGREES))
	last_shake_offset = Vector3(h_offset, v_offset, strength)


## Dua sinus tak-selaras -> deret halus dalam [-1, 1] (tanpa alokasi).
func _noise(t: float, seed_offset: float) -> float:
	return 0.62 * sin(t + seed_offset) + 0.38 * sin(t * 2.37 + seed_offset * 1.9)


func _process(delta: float) -> void:
	if is_paused():
		return
	if is_physics_processing():
		# Subclass (collision camera) places the camera in _physics_process; this frame loop only drives the shake.
		_apply_shake(delta)
		return
	_update_stick(delta)
	_follow_focus(delta)
	_place(delta)
	_apply_shake(delta)


## The collision subclass turns _process off in its _ready; the shake needs it per rendered frame (physics ticks are coarser).
func _enable_shake_driver() -> void:
	if is_physics_processing() and not is_processing():
		set_process(true)


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
	_base_basis = Basis.looking_at(-direction, Vector3.UP)
	global_basis = _base_basis


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
