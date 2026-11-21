extends Node
## Local control preferences, applied from the real pause menu; not combat balancing or a save game.

const FIELDS := {
	&"move_speed": {"title": "Kecepatan gerak", "default": 6.0, "min": 3.0, "max": 10.0, "step": 0.25, "format": "%.2f m/s"},
	&"sprint_speed": {"title": "Kecepatan sprint", "default": 9.0, "min": 3.0, "max": 16.0, "step": 0.25, "format": "%.2f m/s"},
	&"swing_duration": {"title": "Durasi swing", "default": 0.2, "min": 0.1, "max": 0.6, "step": 0.01, "format": "%.2f s"},
	&"mouse_sensitivity": {"title": "Sensitivitas mouse", "default": 0.003, "min": 0.0005, "max": 0.008, "step": 0.0001, "format": "%.4f"},
	&"camera_distance": {"title": "Jarak kamera awal", "default": 11.4, "min": 4.0, "max": 14.0, "step": 0.1, "format": "%.2f m"},
}

@export var player_path: NodePath
@export var camera_path: NodePath
@export var config_path := "user://control_preferences.cfg"

var _player: Node
var _camera: Camera3D
var _menu: VBoxContainer
var _settings: PanelContainer
var _sliders: Dictionary[StringName, HSlider] = {}
var _readouts: Dictionary[StringName, Label] = {}
var _status: Label
var _values: Dictionary[StringName, float] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node(player_path)
	_camera = get_node(camera_path) as Camera3D
	_load_preferences()
	_build_menu()
	_apply_values()

func _load_preferences() -> void:
	var config := ConfigFile.new()
	var error := config.load(config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Pengaturan tidak dapat dibaca; memakai default (%s)." % error_string(error))
	for field: StringName in FIELDS:
		var spec: Dictionary = FIELDS[field]
		var raw: Variant = config.get_value("controls",field,spec["default"]) if error == OK else spec["default"]
		var value: float = float(raw) if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT else spec["default"]
		_values[field] = clampf(value,spec["min"],spec["max"]) if is_finite(value) else spec["default"]
	_values[&"sprint_speed"] = maxf(_values[&"move_speed"],_values[&"sprint_speed"])

func _build_menu() -> void:
	var panel: Control = _camera.get_pause_panel()
	_menu = _camera.get_resume_button().get_parent() as VBoxContainer
	var open := Button.new()
	open.name = "OpenPreferences"
	open.text = "Pengaturan"
	open.custom_minimum_size.y = 44
	open.pressed.connect(open_settings)
	_menu.add_child(open)

	_settings = PanelContainer.new()
	_settings.name = "ControlPreferences"
	panel.add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings.offset_left = -310
	_settings.offset_right = 310
	_settings.offset_top = -235
	_settings.offset_bottom = 235
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	_settings.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "PENGATURAN KONTROL"
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	for field: StringName in FIELDS:
		var spec: Dictionary = FIELDS[field]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		column.add_child(row)
		var label := Label.new()
		label.text = spec["title"]
		label.custom_minimum_size.x = 175
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = String(field)
		slider.min_value = spec["min"]
		slider.max_value = spec["max"]
		slider.step = spec["step"]
		slider.custom_minimum_size = Vector2(235,32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		_sliders[field] = slider
		var readout := Label.new()
		readout.custom_minimum_size.x = 85
		row.add_child(readout)
		_readouts[field] = readout
		slider.value_changed.connect(_on_slider.bind(field))
	_status = Label.new()
	_status.text = "Terapkan untuk menyimpan; durasi baru berlaku pada ayunan berikutnya."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",10)
	column.add_child(buttons)
	_button(buttons,"Terapkan",apply_and_save)
	_button(buttons,"Reset Default",reset_defaults)
	_button(buttons,"Kembali",close_settings)
	_settings.hide()

func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(140,42)
	button.pressed.connect(action)
	parent.add_child(button)

func _on_slider(value: float, field: StringName) -> void:
	_readouts[field].text = FIELDS[field]["format"] % value
	if field == &"move_speed" and _sliders[&"sprint_speed"].value < value:
		_sliders[&"sprint_speed"].value = value
	elif field == &"sprint_speed" and value < _sliders[&"move_speed"].value:
		_sliders[field].value = _sliders[&"move_speed"].value

func open_settings() -> void:
	_camera.pause_game()
	for field: StringName in FIELDS:
		_sliders[field].set_value_no_signal(_values[field])
		_readouts[field].text = FIELDS[field]["format"] % _values[field]
	_menu.hide()
	_settings.show()

func close_settings() -> void:
	_settings.hide()
	_menu.show()

func reset_defaults() -> void:
	for field: StringName in FIELDS:
		_sliders[field].set_value_no_signal(FIELDS[field]["default"])
		_readouts[field].text = FIELDS[field]["format"] % FIELDS[field]["default"]
	_status.text = "Default dipilih. Klik Terapkan untuk menyimpan."

func _apply_values() -> void:
	_player.base_speed = _values[&"move_speed"]
	_player.sprint_speed = _values[&"sprint_speed"]
	_player.set_attack_duration(_values[&"swing_duration"])
	_camera.mouse_sensitivity = _values[&"mouse_sensitivity"]
	_camera.set_zoom_distance(_values[&"camera_distance"])

func apply_and_save() -> void:
	var config := ConfigFile.new()
	for field: StringName in FIELDS:
		_values[field] = _sliders[field].value
		config.set_value("controls",field,_values[field])
	_apply_values()
	var error := config.save(config_path)
	_status.text = "Tersimpan di perangkat ini. Kembali lalu Lanjutkan untuk mencoba." if error == OK else "Aktif, tetapi gagal menyimpan: %s" % error_string(error)
