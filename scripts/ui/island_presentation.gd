extends CanvasLayer
## Player-facing presentation for the island game: HUD, compass, prompts, boss bar, main menu / new run, shipwreck intro,
## pause audio volume, completion outro and bounded audio (music, ambience, SFX).
## Usage (parent): add to tree, then setup(game, player, session, interactor, boss); show_menu(); listen to new_run_requested.
## Audio is assembled from licensed repo files only; its mix has not been human-audited.

signal new_run_requested(seed: int, procedural: bool)

const K := "res://assets/third_party/kenney/"
const R := "res://assets/third_party/audio/rpg_sfx_rubberduck/"
const T := "res://assets/third_party/audio/tinysized_vehicle/"
const MUSIC_EXPLORE := "res://assets/third_party/audio/music/children_soundtrack_2.ogg"
const MUSIC_BOSS := "res://assets/third_party/audio/music/CleytonRX-Battle-RPG-Theme.mp3"
const MUSIC_BOSS_PHASE2 := "res://assets/third_party/audio/music/CleytonRX-Battle-RPG-Theme-Var.ogg"
const AMBIENCE_FOREST := "res://assets/third_party/audio/ambience/Forest_Ambience.mp3"
const AMBIENCE_SEA := "res://assets/third_party/audio/ambience/VistulaShort.mp3"

const AUDIO_CONFIG := "user://audio_preferences.cfg"

const SFX_POOL_SIZE := 8
const ARTIFACTS_NEEDED := 3
## Ids owned by scripts/objectives/*.gd (ARTIFACT_ID) and puzzle_progress keys they write.
const OBJECTIVE_ARTIFACTS := {"Pilar Simbol": &"forest_artifact", "Jalur Energi": &"energy_artifact", "Puncak": &"summit_artifact"}
const PUZZLE_KEYS: Array[StringName] = [&"symbol_pillars", &"energy_path"]
const GATEKEEPER_DEFEATED_KEY := &"gatekeeper_defeated"
const GATE_ANCHOR_LABEL := "Gerbang Pulau"
const SPAWN_ANCHOR_LABEL := "Titik Awal"
const VIEWPOINT_ANCHOR_LABEL := "Titik Pandang"
const SEED_MIN := -2147483648
const SEED_MAX := 2147483647

const COL_DEEP := Color("1B365D")
const COL_SEA := Color("005A9C")
const COL_SHALLOW := Color("60C1E5")
const COL_FOAM := Color("A0E0EF")
const COL_SAND := Color("FFEFC4")
const COL_HP := Color("930031")
const COL_STAMINA := Color("FFA500")
const COL_POTION := Color("BEDEFF")
const COL_GOLD := Color("FFF2A7")
const COL_MOSS := Color("637545")

const INTRO_TEXT := "Badai merobek kapalmu di tengah malam. Saat fajar kau terbangun di pasir pulau yang tidak ada di peta mana pun, dikelilingi puing kayu dan layar yang robek.\n\nCatatan awak kapal menyebut sebuah gerbang kuno di sisi lain pulau. Ia hanya terbuka bagi pemegang tiga artefak, dan penjaganya tidak pernah tidur.\n\nTemukan ketiga artefak, bangunkan sang penjaga, lalu pulanglah."
const OUTRO_TEXT := "Penjaga Gerbang runtuh dan cahaya di intinya padam. Gerbang kuno terbuka perlahan, menampakkan jalan menuju lautan lepas.\n\nKau melangkah melewatinya. Di belakangmu, pulau kembali sunyi."

# ---- run options (menu) -----------------------------------------------------------------------------------------
var run_seed := 12345
var run_procedural := true

# ---- bound objects ---------------------------------------------------------------------------------------------
var _game: Node
var _player: Node
var _session: Node
var _interactor: Node
var _boss: Node
var _camera: Node

var _built := false
var _theme: Theme
var _hud: Control
var _overlay: CanvasLayer
var _menu_panel: Control
var _intro_panel: Control
var _end_panel: Control
var _menu_start: Button
var _menu_block: Dictionary = {}
var _end_block: Dictionary = {}
var _end_stats: Label
var _intro_done := false
var _overlay_open := false
var _completed := false
var _pause_hooked := false
var _volume := 0.8
var _volume_sliders: Array[HSlider] = []

# HUD widgets
var _hp_bar: ProgressBar
var _hp_label: Label
var _st_bar: ProgressBar
var _potion_label: Label
var _artifact_label: Label
var _objective_label: Label
var _controls_label: Label
var _compass: Compass
var _prompt_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _flash: ColorRect
var _dead_label: Label
var _boss_panel: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_status: Label

# state
var _targets: Array[Dictionary] = []
var _target_timer := 0.0
var _poll_timer := 0.0
var _boss_timer := 0.0
var _boss_active := false
var _boss_phase := 1
var _boss_state := ""
var _run_time := 0.0
var _base_artifacts := 0
var _base_potions := 0
var _base_kills := 0
var _base_puzzle_hash := 0
var _base_puzzle_done := 0
var _base_checkpoint: StringName = &""

# audio
var _events: Dictionary = {}
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_started: Array[int] = []
var _music: AudioStreamPlayer
var _music_path := ""
var _music_tween: Tween
var _forest: AudioStreamPlayer
var _sea: AudioStreamPlayer
var _step_timer := 0.0
var _prev_floor := true
var _air_time := 0.0
var _prev_action: StringName = &"idle"
var _rng := RandomNumberGenerator.new()


class Compass extends Control:
	var cardinals: Array = []
	var markers: Array = []
	var font: Font

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		var half := cx - 16.0
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.106, 0.212, 0.365, 0.6))
		draw_rect(Rect2(0.0, h - 2.0, w, 2.0), Color(0.627, 0.878, 0.937, 0.7))
		draw_line(Vector2(cx, h - 9.0), Vector2(cx, h), Color.WHITE, 2.0)
		if font == null:
			return
		for c: Array in cardinals:
			var a: float = c[0]
			if absf(a) > PI * 0.5:
				continue
			draw_string(font, Vector2(cx + a / (PI * 0.5) * half - 8.0, 21.0), c[1], HORIZONTAL_ALIGNMENT_CENTER, 16.0, 16, Color(1.0, 0.937, 0.769, 0.85))
		# Every marker gets a tick; only the nearest three get a label, placed greedily without overlapping.
		var taken: Array[Vector2] = []
		var labeled := 0
		for m: Array in markers:
			var a: float = clampf(m[0], -PI * 0.5, PI * 0.5)
			var x := cx + a / (PI * 0.5) * half
			var col: Color = m[3]
			var y := h * 0.5 - 2.0
			var s := 5.0 if labeled < 3 else 3.5
			draw_colored_polygon(PackedVector2Array([Vector2(x, y - s - 1.0), Vector2(x + s, y), Vector2(x, y + s + 1.0), Vector2(x - s, y)]), col if labeled < 3 else Color(col, 0.6))
			if labeled >= 3:
				continue
			var text: String = "%s %dm" % [String(m[1]).left(14), m[2]]
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
			var left := clampf(x - tw * 0.5, 3.0, w - tw - 3.0)
			var overlaps := false
			for r in taken:
				if left < r.y + 6.0 and left + tw > r.x - 6.0:
					overlaps = true
					break
			if overlaps:
				continue
			taken.append(Vector2(left, left + tw))
			labeled += 1
			draw_string(font, Vector2(left, h - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, col)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	add_to_group(&"island_presentation")
	_rng.randomize()
	_ensure_built()


# ======================================================================================================================
# Public API
# ======================================================================================================================

## Binds game objects. Any argument may be null (the matching feature is skipped). Safe to call once per run.
func setup(game: Node, player: Node, session: Node, interactor: Node, boss: Node) -> void:
	_ensure_built()
	_game = game
	_player = player
	_session = session
	_interactor = interactor
	_boss = boss
	_camera = game.get_node_or_null(^"Camera3D") if game != null else null
	if _camera == null or not _camera.has_method(&"get_pause_panel"):
		_camera = get_viewport().get_camera_3d()
	_connect_player()
	_connect_session()
	_connect_interactor()
	_connect_boss()
	_hook_pause_panel()
	_snapshot_session()
	_refresh_targets()
	_hide_debug_labels()
	_update_controls_hint()


## Opens the main menu: pauses the SceneTree, releases the mouse, hides the HUD underneath.
func show_menu() -> void:
	_ensure_built()
	_close_overlays()
	_menu_start.text = "Lanjutkan" if _intro_done else "Mulai Petualangan"
	_set_block(_menu_block, run_seed, run_procedural)
	_menu_panel.show()
	_enter_overlay()
	_music_to(MUSIC_EXPLORE)
	play_event(&"menu_open")


## Closes any overlay and plays: first shows the shipwreck intro (once per instance) when show_intro, else resumes.
func begin_play(show_intro := true) -> void:
	_ensure_built()
	_close_overlays()
	if show_intro and not _intro_done:
		_intro_panel.show()
		_enter_overlay()
		return
	_resume()


## Outro screen with run stats and New Run; pauses the tree and releases the mouse.
func show_completion() -> void:
	_ensure_built()
	if _completed and _end_panel.visible:
		return
	_completed = true
	_close_overlays()
	_end_stats.text = _stats_text()
	_set_block(_end_block, run_seed, run_procedural)
	_end_panel.show()
	_enter_overlay()
	_boss_panel.hide()
	_music_to(MUSIC_EXPLORE)
	play_event(&"fanfare")


## Sets the seed/procedural values shown in the menu (the parent calls this with the active run's values).
func set_run_options(seed_value: int, procedural: bool) -> void:
	run_seed = clampi(seed_value, SEED_MIN, SEED_MAX)
	run_procedural = procedural


## Short on-screen message.
func toast(text: String, seconds := 3.0) -> void:
	_ensure_built()
	_toast_label.text = text
	_toast_label.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_toast_label.hide)


## Registers (or replaces) the clip for an audio event, e.g. register_sfx(&"puzzle_solved", "res://....ogg", -4.0).
func register_sfx(event: StringName, stream_path: String, volume_db := -6.0) -> void:
	_events[event] = {"paths": [stream_path], "db": volume_db, "pitch": Vector2(0.97, 1.03), "cd": 0.0}


## Plays a registered event through the bounded SFX pool. Unknown events are ignored.
func play_event(event: StringName, extra_db := 0.0) -> void:
	if _quitting:
		return
	var spec: Dictionary = _events.get(event, {})
	if spec.is_empty():
		return
	var now := Time.get_ticks_msec()
	var cooldown: float = spec["cd"]
	if cooldown > 0.0 and now - int(_last_played.get(event, -100000)) < int(cooldown * 1000.0):
		return
	var paths: Array = spec["paths"]
	var path: String = paths[_rng.randi_range(0, paths.size() - 1)]
	var stream := _load_stream(path)
	if stream == null:
		return
	_last_played[event] = now
	var player := _free_sfx_player()
	player.stream = stream
	player.volume_db = float(spec["db"]) + extra_db
	var pitch: Vector2 = spec["pitch"]
	player.pitch_scale = _rng.randf_range(pitch.x, pitch.y)
	player.play()
	_sfx_started[_sfx.find(player)] = now


# ======================================================================================================================
# Build
# ======================================================================================================================

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_load_volume()
	_build_theme()
	_build_audio()
	_build_hud()
	_overlay = CanvasLayer.new()
	_overlay.name = "Overlays"
	_overlay.layer = 110
	add_child(_overlay)
	_build_menu()
	_build_intro()
	_build_completion()
	_apply_volume()


func _build_theme() -> void:
	_theme = Theme.new()
	# Engine default font: Kenney Future renders "K" like "H", which is unreadable in Indonesian text.
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", COL_SAND)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.set_content_margin_all(10)
		box.border_color = COL_FOAM
		match state:
			"normal":
				box.bg_color = COL_SEA
			"hover":
				box.bg_color = COL_SHALLOW
				box.set_border_width_all(2)
			"pressed":
				box.bg_color = COL_DEEP
			"disabled":
				box.bg_color = Color(0.2, 0.25, 0.3)
			"focus":
				box.bg_color = Color(0, 0, 0, 0)
				box.set_border_width_all(2)
		_theme.set_stylebox(state, "Button", box)
	_theme.set_color("font_color", "Button", Color.WHITE)
	_theme.set_color("font_hover_color", "Button", COL_DEEP)
	_theme.set_font_size("font_size", "Button", 20)
	_theme.set_stylebox("panel", "PanelContainer", _panel_style(Color(COL_DEEP, 0.8)))
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.05, 0.1, 0.18)
	line.set_corner_radius_all(4)
	line.set_content_margin_all(8)
	line.border_color = COL_FOAM
	line.set_border_width_all(1)
	_theme.set_stylebox("normal", "LineEdit", line)
	_theme.set_stylebox("focus", "LineEdit", line)
	_theme.set_color("font_color", "LineEdit", Color.WHITE)
	_theme.set_color("font_color", "CheckBox", COL_SAND)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())


func _panel_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	box.border_color = Color(COL_FOAM, 0.5)
	box.set_border_width_all(1)
	return box


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220.0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _label(text: String, size := 18, color := COL_SAND, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	return label


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.theme = _theme
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_flash = ColorRect.new()
	_flash.color = Color(COL_HP, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stats := PanelContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(stats)
	stats.position = Vector2(16.0, 16.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	stats.add_child(col)
	var hp_row := HBoxContainer.new()
	col.add_child(hp_row)
	hp_row.add_child(_label("HP", 16, COL_POTION))
	_hp_bar = _bar(COL_HP, 18.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hp_bar)
	_hp_label = _label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_label.custom_minimum_size.x = 62.0
	hp_row.add_child(_hp_label)
	var st_row := HBoxContainer.new()
	col.add_child(st_row)
	st_row.add_child(_label("ST", 16, COL_GOLD))
	_st_bar = _bar(COL_STAMINA, 12.0)
	_st_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_st_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st_row.add_child(_st_bar)
	_potion_label = _label("", 17, COL_POTION)
	col.add_child(_potion_label)
	_artifact_label = _label("", 17, COL_GOLD)
	col.add_child(_artifact_label)
	_objective_label = _label("", 15, COL_SAND)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size.x = 290.0
	col.add_child(_objective_label)

	_compass = Compass.new()
	_compass.font = _theme.default_font if _theme.default_font != null else ThemeDB.fallback_font
	_compass.custom_minimum_size = Vector2(420.0, 42.0)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_compass)
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -210.0
	_compass.offset_right = 210.0
	_compass.offset_top = 12.0
	_compass.offset_bottom = 54.0

	_boss_panel = PanelContainer.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_boss_panel)
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -250.0
	_boss_panel.offset_right = 250.0
	_boss_panel.offset_top = 66.0
	_boss_panel.offset_bottom = 134.0
	var boss_col := VBoxContainer.new()
	_boss_panel.add_child(boss_col)
	_boss_name = _label("Penjaga Gerbang", 20, COL_FOAM, HORIZONTAL_ALIGNMENT_CENTER)
	boss_col.add_child(_boss_name)
	_boss_bar = _bar(COL_STAMINA, 16.0)
	_boss_bar.custom_minimum_size.x = 480.0
	boss_col.add_child(_boss_bar)
	_boss_status = _label("", 14, COL_SAND, HORIZONTAL_ALIGNMENT_CENTER)
	boss_col.add_child(_boss_status)
	_boss_panel.hide()

	_toast_label = _label("", 22, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.add_theme_color_override("font_outline_color", COL_DEEP)
	_toast_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.offset_top = 150.0
	_toast_label.hide()

	_prompt_label = _label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.add_theme_color_override("font_outline_color", COL_DEEP)
	_prompt_label.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_prompt_label)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.offset_top = -150.0
	_prompt_label.hide()

	_dead_label = _label("Kau tumbang... bangkit di checkpoint.", 28, COL_SAND, HORIZONTAL_ALIGNMENT_CENTER)
	_dead_label.add_theme_color_override("font_outline_color", COL_HP)
	_dead_label.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_dead_label)
	_dead_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dead_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dead_label.hide()

	_controls_label = _label("", 13, Color(COL_SAND, 0.75))
	_hud.add_child(_controls_label)
	_controls_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controls_label.offset_left = 16.0
	_controls_label.offset_bottom = -12.0
	_hud.hide()


func _overlay_root(opaque: bool) -> Control:
	var root := Control.new()
	root.theme = _theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(COL_DEEP, 1.0) if opaque else Color(0.02, 0.05, 0.1, 0.82)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if opaque:
		var band := ColorRect.new()
		band.color = Color(COL_SEA, 0.55)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(band)
		band.anchor_top = 0.62
		band.anchor_right = 1.0
		band.anchor_bottom = 1.0
	root.hide()
	return root


func _center_column(root: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


func _button(parent: Node, text: String, action: Callable, sound := &"click") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300.0, 48.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		play_event(sound)
		action.call())
	button.mouse_entered.connect(play_event.bind(&"hover"))
	parent.add_child(button)
	return button


func _seed_block(parent: Node) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(_label("Seed", 18, COL_FOAM))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(170.0, 40.0)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "bilangan bulat"
	edit.max_length = 11
	row.add_child(edit)
	var dice := _button(row, "Acak", func() -> void: edit.text = str(_rng.randi_range(0, 999999)))
	dice.custom_minimum_size = Vector2(90.0, 40.0)
	var check := CheckBox.new()
	check.text = "Pulau prosedural dari seed"
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(_on: bool) -> void: play_event(&"click"))
	parent.add_child(check)
	var error := _label("", 15, Color("FF8A8A"))
	parent.add_child(error)
	return {"edit": edit, "check": check, "error": error}


func _set_block(block: Dictionary, seed_value: int, procedural: bool) -> void:
	(block["edit"] as LineEdit).text = str(seed_value)
	(block["check"] as CheckBox).button_pressed = procedural
	(block["error"] as Label).text = ""


## Returns {"ok": bool, "seed": int, "procedural": bool}; shows an error on the block when invalid.
func _read_block(block: Dictionary) -> Dictionary:
	var text := (block["edit"] as LineEdit).text.strip_edges()
	var error := block["error"] as Label
	if not text.is_valid_int() or text.length() > 11 or text.to_int() < SEED_MIN or text.to_int() > SEED_MAX:
		error.text = "Seed harus bilangan bulat antara %d dan %d." % [SEED_MIN, SEED_MAX]
		play_event(&"error")
		return {"ok": false}
	error.text = ""
	return {"ok": true, "seed": text.to_int(), "procedural": (block["check"] as CheckBox).button_pressed}


func _build_menu() -> void:
	_menu_panel = _overlay_root(true)
	var box := _center_column(_menu_panel, 420.0)
	box.add_child(_label("THE LOST ISLAND", 52, COL_SAND, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("Terdampar. Temukan tiga artefak. Bangunkan sang penjaga.", 17, COL_FOAM, HORIZONTAL_ALIGNMENT_CENTER))
	_menu_block = _seed_block(box)
	_menu_start = _button(box, "Mulai Petualangan", _on_start_pressed, &"confirm")
	_button(box, "Run Baru dengan Seed Ini", _on_menu_new_run)
	var vol := _volume_row(box)
	vol.alignment = BoxContainer.ALIGNMENT_CENTER
	_button(box, "Keluar", request_quit, &"back")
	box.add_child(_label("Seed/prosedural diterapkan saat Mulai (bila diubah) atau Run Baru.", 13, Color(COL_SAND, 0.7), HORIZONTAL_ALIGNMENT_CENTER))


func _build_intro() -> void:
	_intro_panel = _overlay_root(false)
	var box := _center_column(_intro_panel, 640.0)
	var panel := PanelContainer.new()
	box.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(_label("KAPAL KARAM", 34, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var text := _label(INTRO_TEXT, 19)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var controls := _label("", 15, COL_FOAM)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.name = "Controls"
	col.add_child(controls)
	_button(col, "Mulai Menjelajah", func() -> void:
		_intro_done = true
		_close_overlays()
		_resume(), &"confirm").size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _build_completion() -> void:
	_end_panel = _overlay_root(true)
	var box := _center_column(_end_panel, 560.0)
	box.add_child(_label("LEVEL 1 SELESAI", 44, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var text := _label(OUTRO_TEXT, 19, COL_SAND, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	_end_stats = _label("", 17, COL_FOAM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_end_stats)
	_end_block = _seed_block(box)
	_button(box, "Run Baru", func() -> void: _emit_new_run(_end_block), &"confirm")
	_button(box, "Menu Utama", func() -> void:
		_completed = false
		show_menu(), &"back")
	_button(box, "Keluar", request_quit, &"back")


func _volume_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(_label("Volume", 18, COL_FOAM))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _volume
	slider.custom_minimum_size = Vector2(190.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_volume_changed)
	slider.drag_ended.connect(func(_changed: bool) -> void: play_event(&"click"))
	row.add_child(slider)
	_volume_sliders.append(slider)
	return row


func _hook_pause_panel() -> void:
	if _pause_hooked or _camera == null or not _camera.has_method(&"get_resume_button"):
		return
	var resume: Button = _camera.get_resume_button()
	if resume == null or resume.get_parent() == null:
		return
	_pause_hooked = true
	var box := resume.get_parent()
	var row := _volume_row(box)
	row.theme = _theme
	box.move_child(row, resume.get_index() + 1)
	var menu := Button.new()
	menu.text = "Menu Utama"
	menu.custom_minimum_size = Vector2(240.0, 48.0)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void:
		play_event(&"click")
		show_menu())
	box.add_child(menu)
	box.move_child(menu, row.get_index() + 1)
	resume.pressed.connect(play_event.bind(&"click"))


# ======================================================================================================================
# Overlay flow
# ======================================================================================================================

func _enter_overlay() -> void:
	_overlay_open = true
	_hud.hide()
	if _camera != null and _camera.has_method(&"pause_game"):
		_camera.pause_game()
		_camera.get_pause_panel().visible = false
	else:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_overlays() -> void:
	_overlay_open = false
	_menu_panel.hide()
	_intro_panel.hide()
	_end_panel.hide()


func _resume() -> void:
	_hud.show()
	if _camera != null and _camera.has_method(&"resume_game"):
		_camera.resume_game()
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _boss_active:
		_music_to(MUSIC_EXPLORE)


func _on_start_pressed() -> void:
	var read := _read_block(_menu_block)
	if not read["ok"]:
		return
	if read["seed"] != run_seed or read["procedural"] != run_procedural:
		_emit_new_run(_menu_block)
		return
	begin_play(true)


func _on_menu_new_run() -> void:
	_emit_new_run(_menu_block)


var _quitting := false


## Single bounded shutdown path for every "Keluar" button: stops tweens and all audio, drops stream references,
## disables the UI against repeat requests, waits ~0.5 s for the audio thread to drain, then quits the tree.
func request_quit() -> void:
	if _quitting:
		return
	_quitting = true
	set_process(false)
	for button in find_children("*", "Button", true, false):
		(button as Button).disabled = true
	if _music_tween != null:
		_music_tween.kill()
	if _toast_tween != null:
		_toast_tween.kill()
	var players: Array[AudioStreamPlayer] = [_music, _forest, _sea]
	players.append_array(_sfx)
	for p in players:
		p.stop()
		p.stream = null
	_cache.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.5, true).timeout
	get_tree().quit()


func _emit_new_run(block: Dictionary) -> void:
	var read := _read_block(block)
	if not read["ok"]:
		return
	run_seed = read["seed"]
	run_procedural = read["procedural"]
	_intro_done = false
	_completed = false
	new_run_requested.emit(run_seed, run_procedural)


func _input(event: InputEvent) -> void:
	# While a presentation overlay is up, Esc must not toggle the camera pause (it would unpause behind the menu).
	if _overlay_open and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


func _stats_text() -> String:
	var seconds := int(_run_time)
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	var kills: int = _session.killed_enemy_ids.size() if _session != null else 0
	var potions: int = _player.potion_count if _player != null and "potion_count" in _player else 0
	return "Waktu %02d:%02d  •  Artefak %d/%d  •  Musuh kalah %d  •  Ramuan tersisa %d" % [seconds / 60, seconds % 60, artifacts, ARTIFACTS_NEEDED, kills, potions]


# ======================================================================================================================
# Signals from game objects
# ======================================================================================================================

func _connect_player() -> void:
	if _player == null:
		return
	_connect_once(_player, &"attack_started", _on_attack_started)
	_connect_once(_player, &"attack_hit", _on_attack_hit)
	_connect_once(_player, &"damage_taken", _on_damage_taken)
	_connect_once(_player, &"died", _on_player_died)
	_connect_once(_player, &"action_refused", _on_action_refused)
	_connect_once(_player, &"potion_drunk", _on_potion_drunk)
	_connect_once(_player, &"potion_cancelled", _on_potion_cancelled)


func _connect_session() -> void:
	if _session == null:
		return
	_connect_once(_session, &"status_changed", _poll_session)
	_connect_once(_session, &"respawned", _on_respawned)
	_connect_once(_session, &"checkpoint_changed", _on_checkpoint)


func _connect_interactor() -> void:
	if _interactor != null:
		_connect_once(_interactor, &"target_changed", _on_target_changed)


func _connect_boss() -> void:
	if _boss == null:
		return
	_connect_once(_boss, &"encounter_started", _on_boss_started)
	_connect_once(_boss, &"encounter_won", _on_boss_won)
	_connect_once(_boss, &"completed", _on_boss_completed)


func _connect_once(node: Object, signal_name: StringName, callable: Callable) -> void:
	if node.has_signal(signal_name) and not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


func _on_attack_started() -> void:
	play_event(&"swing")


func _on_attack_hit(_target: Node, _amount: int) -> void:
	play_event(&"hit")


func _on_damage_taken(_amount: int, blocked: bool) -> void:
	play_event(&"block_hit" if blocked else &"hurt")
	_flash.color = Color(COL_HP, 0.0 if blocked else 0.35)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)


func _on_player_died() -> void:
	play_event(&"death")
	_boss_panel.hide()
	if _boss_active:
		_boss_active = false
		_music_to(MUSIC_EXPLORE)


func _on_action_refused(_action: StringName) -> void:
	play_event(&"error")


func _on_potion_drunk(healed: int) -> void:
	play_event(&"potion")
	if healed > 0:
		toast("+%d HP" % healed, 1.5)


func _on_potion_cancelled() -> void:
	play_event(&"error")


func _on_respawned() -> void:
	play_event(&"respawn")
	toast("Kembali ke checkpoint.", 2.5)


func _on_checkpoint(_id: StringName) -> void:
	_poll_session()


func _on_target_changed(target: Node) -> void:
	if target != null:
		play_event(&"target")


func _on_boss_started() -> void:
	_boss_active = true
	_boss_phase = 1
	_boss_state = ""
	_boss_panel.show()
	_music_to(MUSIC_BOSS)
	play_event(&"boss_roar")
	toast("Penjaga Gerbang terbangun!", 3.0)


func _on_boss_won() -> void:
	_boss_active = false
	_boss_panel.hide()
	_music_to(MUSIC_EXPLORE)
	play_event(&"boss_defeated")
	play_event(&"gate_open")
	toast("Penjaga runtuh. Gerbang terbuka — lewati untuk keluar.", 5.0)


func _on_boss_completed() -> void:
	if not _completed:
		show_completion()


# ======================================================================================================================
# Per-frame
# ======================================================================================================================

func _process(delta: float) -> void:
	if _overlay_open and (not get_tree().paused or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		# A late camera _ready/resume_game must not unpause or recapture behind a menu.
		_enter_overlay()
	if _overlay_open or _game == null:
		return
	if get_tree().paused:
		return
	_run_time += delta
	_update_resources()
	_update_prompt()
	_update_compass(delta)
	_poll_timer += delta
	if _poll_timer >= 0.3:
		_poll_timer = 0.0
		_poll_session()
		_hide_debug_labels()
	_boss_timer += delta
	if _boss_timer >= 0.12:
		_boss_timer = 0.0
		_poll_boss()
	_poll_player_audio(delta)
	_dead_label.visible = _player != null and _player.has_method(&"is_dead") and _player.is_dead()
	if Input.is_action_just_pressed(&"interact") and _interactor != null and _interactor.get_prompt() != "":
		play_event(&"interact")


func _update_resources() -> void:
	if _player == null:
		return
	var health: Node = _player.get_health() if _player.has_method(&"get_health") else null
	if health != null:
		_hp_bar.max_value = health.max_health
		_hp_bar.value = health.current_health
		_hp_label.text = "%d/%d" % [health.current_health, health.max_health]
	if "stamina" in _player:
		_st_bar.max_value = _player.max_stamina
		_st_bar.value = _player.stamina
	if "potion_count" in _player:
		_potion_label.text = "Ramuan  %d/%d   [%s]" % [_player.potion_count, _player.max_potions, _action_text(&"potion")]
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	_artifact_label.text = "Artefak  %d/%d" % [artifacts, ARTIFACTS_NEEDED]


func _update_prompt() -> void:
	var prompt: String = _interactor.get_prompt() if _interactor != null else ""
	_prompt_label.visible = prompt != ""
	if prompt != "":
		_prompt_label.text = prompt.replace("[E]", "[%s]" % _action_text(&"interact"))


func _action_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if DisplayServer.get_name() == "headless":
				return OS.get_keycode_string(code)
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "Klik Kiri"
				MOUSE_BUTTON_RIGHT:
					return "Klik Kanan"
	return "?"


func _update_controls_hint() -> void:
	var hint := "%s%s%s%s gerak • %s lari • %s serang • %s blok • %s berguling • %s ramuan • %s interaksi • Esc jeda" % [
		_action_text(&"move_forward"), _action_text(&"move_left"), _action_text(&"move_backward"), _action_text(&"move_right"),
		_action_text(&"sprint"), _action_text(&"attack"), _action_text(&"block"), _action_text(&"dodge"),
		_action_text(&"potion"), _action_text(&"interact")]
	_controls_label.text = hint
	var intro_controls := _intro_panel.find_child("Controls", true, false) as Label
	if intro_controls != null:
		intro_controls.text = hint


# ---- compass / hints ------------------------------------------------------------------------------------------------

func _refresh_targets() -> void:
	_targets.clear()
	var raw: Array[Dictionary] = []
	var terrain_node: Node = null
	if _game != null:
		var terrain: Node = null
		if "terrain" in _game:
			terrain = _game.get("terrain") as Node
		if terrain == null or not terrain.has_method(&"get_compass_targets"):
			terrain = _game.get_node_or_null(^"World")
		if terrain == null or not terrain.has_method(&"get_compass_targets"):
			terrain = _game.find_child("IslandTerrain", true, false)
		if terrain != null and terrain.has_method(&"get_compass_targets"):
			terrain_node = terrain
			for entry: Dictionary in terrain.get_compass_targets():
				var pos: Vector3 = entry.get("position", Vector3.INF)
				if pos != Vector3.INF:
					var label := String(entry.get("label", "Tujuan"))
					raw.append({"label": label, "pos": pos, "region": String(entry.get("region", "")), "hint": String(entry.get("hint", "")), "node": null, "id": _artifact_id(label, entry.get("artifact_id", &""))})
	for node in get_tree().get_nodes_in_group(&"compass_target"):
		var n3 := node as Node3D
		if n3 == null or not n3.is_inside_tree() or _target_done(n3):
			continue
		var label := String(n3.get_meta(&"label", n3.name))
		raw.append({"label": label, "pos": n3.global_position, "region": String(n3.get_meta(&"region", "")), "hint": String(n3.get_meta(&"hint", "")), "node": n3, "id": _artifact_id(label, n3.get_meta(&"artifact_id", &""))})
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	var gate_phase := artifacts >= ARTIFACTS_NEEDED
	var won := _boss_won()
	var gate_anchor := {}
	for t: Dictionary in raw:
		var label: String = t["label"]
		if label == GATE_ANCHOR_LABEL:
			gate_anchor = t
			continue
		if label == SPAWN_ANCHOR_LABEL or (gate_phase and label == VIEWPOINT_ANCHOR_LABEL):
			continue
		var id: StringName = t["id"]
		if id != &"" and _session != null and _session.is_collected(id):
			continue  # collected objective and its terrain anchor are no longer goals
		_targets.append(t)
	if not gate_phase:
		return
	# Three artifacts: the only goal is the gate until the boss is won, then the pier.
	_targets.clear()
	var boss3d := _boss as Node3D
	var gate_pos: Vector3 = gate_anchor.get("pos", Vector3.INF)
	var gate_node: Node3D = null
	if boss3d != null and boss3d.is_inside_tree():
		gate_node = boss3d
		gate_pos = boss3d.global_position
	if won:
		# The pier is the terrain's real dock_end anchor, not the gate/boss anchor.
		var dock_end: Variant = terrain_node.anchor_positions.get(&"dock_end", null) if terrain_node != null and "anchor_positions" in terrain_node else null
		if dock_end is Vector3:
			_targets.append({"label": "Dermaga", "pos": terrain_node.to_global(dock_end) if terrain_node.is_inside_tree() else dock_end, "region": "", "hint": "Gerbang terbuka. Menuju dermaga untuk pulang.", "node": null, "id": &""})
		return
	if gate_pos == Vector3.INF:
		return
	_targets.append({"label": "Gerbang", "pos": gate_pos, "region": "", "hint": "Tiga artefak terkumpul. Menuju gerbang.", "node": gate_node, "id": &""})


## Stable id of the artifact behind a compass target: explicit artifact_id from the owner, else the central table
## keyed by the exact label both the terrain anchors and the module markers use.
func _artifact_id(label: String, explicit: Variant) -> StringName:
	if String(explicit) != "":
		return StringName(String(explicit))
	return OBJECTIVE_ARTIFACTS.get(label, &"")


func _boss_won() -> bool:
	if _boss_dead():
		return true
	return _session != null and _session.puzzle_progress.get(GATEKEEPER_DEFEATED_KEY, false) == true


func _target_done(node: Node) -> bool:
	if node.has_method(&"is_done"):
		return node.is_done()
	return bool(node.get_meta(&"done", false))


func _boss_dead() -> bool:
	if _boss == null:
		return false
	var health := _boss.get_node_or_null(^"Health")
	return health != null and health.is_dead


func _update_compass(delta: float) -> void:
	_target_timer += delta
	if _target_timer >= 0.7:
		_target_timer = 0.0
		_refresh_targets()
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	var origin: Vector3 = (_player as Node3D).global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	fwd = fwd.normalized()
	right = right.normalized()
	var cardinals: Array = []
	for c in [[Vector3(0, 0, -1), "U"], [Vector3(1, 0, 0), "T"], [Vector3(0, 0, 1), "S"], [Vector3(-1, 0, 0), "B"]]:
		cardinals.append([atan2(c[0].dot(right), c[0].dot(fwd)), c[1]])
	var found: Array = []
	for t in _targets:
		var node: Node3D = t["node"]
		var pos: Vector3 = node.global_position if node != null and is_instance_valid(node) else t["pos"]
		var d := pos - origin
		var flat := Vector3(d.x, 0.0, d.z)
		var dist := flat.length()
		if dist < 1.5:
			continue
		# Real module nodes win over terrain anchors standing at the same spot.
		found.append({"t": t, "pos": pos, "dist": dist, "key": dist - (3.0 if node != null else 0.0), "angle": atan2(flat.dot(right), flat.dot(fwd))})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["key"] < b["key"])
	var kept: Array = []
	for f: Dictionary in found:
		var is_dup := false
		for k: Dictionary in kept:
			var same_label: bool = k["t"]["label"] == f["t"]["label"]
			var same_spot := Vector2(k["pos"].x - f["pos"].x, k["pos"].z - f["pos"].z).length() < 8.0
			if same_label or same_spot:
				is_dup = true
				break
		if not is_dup:
			kept.append(f)
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
	var markers: Array = []
	var nearest := {}
	var nearest_d := INF
	for f: Dictionary in kept:
		var label: String = f["t"]["label"]
		markers.append([f["angle"], label, int(f["dist"]), COL_GOLD if label == "Gerbang" or label == "Dermaga" else COL_FOAM])
		if f["dist"] < nearest_d:
			nearest_d = f["dist"]
			nearest = f["t"]
	_compass.cardinals = cardinals
	_compass.markers = markers
	_compass.queue_redraw()
	_objective_label.text = _objective_text(nearest, nearest_d)


func _objective_text(nearest: Dictionary, dist: float) -> String:
	if _completed:
		return ""
	if _boss_active:
		return "Kalahkan Penjaga Gerbang. Baca telegraph, hindari, lalu serang."
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	var puzzles := _count_done(_session.puzzle_progress) if _session != null else 0
	var lines: Array[String] = []
	if not nearest.is_empty():
		var text: String = nearest["hint"] if nearest["hint"] != "" else "Menuju %s" % nearest["label"]
		if nearest["region"] != "":
			text += " (%s)" % nearest["region"]
		lines.append("%s — %d m" % [text, int(dist)])
	elif artifacts < ARTIFACTS_NEEDED:
		lines.append("Jelajahi pulau, selesaikan puzzle, cari artefak.")
	else:
		lines.append("Semua artefak terkumpul. Menuju gerbang.")
	if puzzles > 0:
		lines.append("Puzzle selesai: %d/%d" % [puzzles, PUZZLE_KEYS.size()])
	return "\n".join(lines)


func _hide_debug_labels() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var label := enemy.get_node_or_null(^"HealthLabel") as Label3D
		if label != null and label.visible:
			label.visible = false


# ---- session polling -----------------------------------------------------------------------------------------------

func _snapshot_session() -> void:
	if _session == null:
		return
	_base_artifacts = _session.count_kind(&"artifact")
	_base_potions = _session.count_kind(&"potion")
	_base_kills = _session.killed_enemy_ids.size()
	_base_puzzle_hash = _puzzle_hash(_session.puzzle_progress)
	_base_puzzle_done = _count_done(_session.puzzle_progress)
	_base_checkpoint = _session.checkpoint_id


## Counts ONLY the two real puzzles; shortcut, sockets and boss flags in puzzle_progress are not puzzles.
func _count_done(progress: Variant) -> int:
	var n := 0
	if progress is Dictionary:
		for key: StringName in PUZZLE_KEYS:
			if (progress as Dictionary).get(key, false) == true:
				n += 1
	return n


func _puzzle_hash(progress: Variant) -> int:
	var states: Array[bool] = []
	if progress is Dictionary:
		for key: StringName in PUZZLE_KEYS:
			states.append((progress as Dictionary).get(key, false) == true)
	return states.hash()


func _poll_session() -> void:
	if _session == null:
		return
	var artifacts: int = _session.count_kind(&"artifact")
	var potions: int = _session.count_kind(&"potion")
	var kills: int = _session.killed_enemy_ids.size()
	var puzzle_hash := _puzzle_hash(_session.puzzle_progress)
	var done := _count_done(_session.puzzle_progress)
	if artifacts > _base_artifacts:
		play_event(&"artifact")
		toast("Artefak %d/%d ditemukan" % [artifacts, ARTIFACTS_NEEDED], 3.5)
		if artifacts >= ARTIFACTS_NEEDED:
			toast("Ketiga artefak terkumpul. Gerbang menunggu.", 4.5)
		_refresh_targets()
	elif potions > _base_potions:
		play_event(&"pickup_potion")
		toast("Ramuan diambil", 1.5)
	if kills > _base_kills:
		play_event(&"enemy_defeated")
	if done > _base_puzzle_done:
		play_event(&"puzzle_solved")
		toast("Puzzle terpecahkan", 3.0)
		_refresh_targets()
	elif puzzle_hash != _base_puzzle_hash:
		play_event(&"puzzle_step")
	if _session.checkpoint_id != _base_checkpoint:
		if _session.checkpoint_id != &"":
			play_event(&"checkpoint")
			toast("Checkpoint tersimpan", 2.0)
		_base_checkpoint = _session.checkpoint_id
	_base_artifacts = artifacts
	_base_potions = potions
	_base_kills = kills
	_base_puzzle_hash = puzzle_hash
	_base_puzzle_done = done


# ---- boss ------------------------------------------------------------------------------------------------------------

func _poll_boss() -> void:
	if _boss == null:
		return
	var status: Variant
	if _boss.has_method(&"get_hud_state"):
		status = _boss.get_hud_state()
	elif _boss.has_method(&"get_status"):
		status = _boss.get_status()
	else:
		return
	var health := _boss.get_node_or_null(^"Health")
	var hp := -1.0
	var max_hp := 1.0
	var state := ""
	var phase := _boss_phase
	if health != null:
		hp = health.current_health
		max_hp = health.max_health
	if status is Dictionary:
		var dict: Dictionary = status
		if dict.has("hp"):
			hp = float(dict["hp"])
		if dict.has("max_hp"):
			max_hp = maxf(1.0, float(dict["max_hp"]))
		state = String(dict.get("state", dict.get("text", "")))
		phase = int(dict.get("phase", phase))
		if dict.has("name") and String(dict["name"]) != "":
			_boss_name.text = String(dict["name"])
		if dict.has("active") and not _boss_active and bool(dict["active"]) and not _boss_dead():
			_on_boss_started()
	elif status is String:
		state = status
	if not _boss_active:
		return
	if hp >= 0.0:
		_boss_bar.max_value = max_hp
		_boss_bar.value = hp
	else:
		_boss_bar.visible = false
	_boss_status.text = "Fase %d" % phase if status is Dictionary else state
	if phase > _boss_phase:
		_boss_phase = phase
		play_event(&"boss_roar")
		toast("Inti Penjaga menyala lebih terang!", 3.0)
		_music_to(MUSIC_BOSS_PHASE2)
	if state != _boss_state:
		if state != "" and not state.to_lower() in ["idle", "recover", "recovery", "dead", "sleep", "sleeping", "ready"]:
			play_event(&"boss_attack")
		_boss_state = state


# ======================================================================================================================
# Audio
# ======================================================================================================================

func _build_audio() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx.append(p)
		_sfx_started.append(0)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.volume_db = -12.0
	add_child(_music)
	_forest = _loop_player("AmbienceForest", AMBIENCE_FOREST, -14.0)
	_sea = _loop_player("AmbienceSea", AMBIENCE_SEA, -16.0)
	_register_defaults()
	_music_to(MUSIC_EXPLORE)


func _loop_player(node_name: String, path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = db
	add_child(p)
	var stream := _load_stream(path)
	if stream != null:
		p.stream = stream
		p.play()
	return p


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream != null and "loop" in stream and path.begins_with("res://assets/third_party/audio/") and (path.contains("/music/") or path.contains("/ambience/")):
		stream.loop = true
	_cache[path] = stream
	return stream


func _free_sfx_player() -> AudioStreamPlayer:
	var oldest := 0
	for i in _sfx.size():
		if not _sfx[i].playing:
			return _sfx[i]
		if _sfx_started[i] < _sfx_started[oldest]:
			oldest = i
	return _sfx[oldest]  # bounded: steal the oldest voice


func _music_to(path: String) -> void:
	if _quitting:
		return
	if path == _music_path or _music == null:
		return
	_music_path = path
	var stream := _load_stream(path)
	if stream == null:
		return
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween()
	var boss := path != MUSIC_EXPLORE
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -50.0, 0.6)
	_music_tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.play())
	_music_tween.tween_property(_music, "volume_db", -9.0 if boss else -12.0, 1.0)


func _seq(prefix: String, first: int, last: int, suffix: String, digits := 2) -> Array:
	var out: Array = []
	for i in range(first, last + 1):
		out.append(prefix + str(i).pad_zeros(digits) + suffix)
	return out


func _def(event: StringName, paths: Array, db: float, pitch := Vector2(0.95, 1.05), cooldown := 0.0) -> void:
	_events[event] = {"paths": paths, "db": db, "pitch": pitch, "cd": cooldown}


func _register_defaults() -> void:
	var ui := K + "interface_sounds/"
	_def(&"click", _seq(ui + "click_", 1, 3, ".ogg", 3), -8.0, Vector2(1, 1), 0.05)
	_def(&"hover", [ui + "tick_001.ogg", ui + "tick_002.ogg"], -20.0, Vector2(1, 1), 0.06)
	_def(&"confirm", _seq(ui + "confirmation_", 1, 2, ".ogg", 3), -6.0, Vector2(1, 1))
	_def(&"back", [ui + "back_001.ogg"], -8.0, Vector2(1, 1))
	_def(&"error", [ui + "error_004.ogg"], -9.0, Vector2(1, 1), 0.2)
	_def(&"menu_open", [ui + "open_001.ogg"], -8.0, Vector2(1, 1))
	_def(&"target", [ui + "tick_004.ogg"], -20.0, Vector2(1, 1), 0.2)
	_def(&"fanfare", [ui + "confirmation_004.ogg", R + "spell_01.ogg"], -4.0, Vector2(1, 1))
	_def(&"step", _seq(K + "rpg_audio/footstep", 0, 9, ".ogg", 2), -14.0, Vector2(0.9, 1.1), 0.1)
	_def(&"jump", [T + "boots-leather-jump-01.wav"], -8.0)
	_def(&"land", [T + "boots-leather-step-01.wav"], -5.0, Vector2(0.8, 0.95), 0.2)
	_def(&"swing", [T + "tin-whistle-whoosh-01.wav", T + "tin-whistle-whoosh-02.wav"], -10.0, Vector2(0.9, 1.15), 0.08)
	_def(&"hit", _seq(T + "sword-clash-", 1, 5, ".wav"), -6.0, Vector2(0.95, 1.1), 0.06)
	_def(&"hurt", [R + "creature_hurt_01.ogg", R + "creature_hurt_02.ogg"], -4.0, Vector2(0.9, 1.0), 0.15)
	_def(&"block_up", [K + "rpg_audio/metalClick.ogg"], -8.0, Vector2(0.95, 1.05), 0.2)
	_def(&"block_hit", _seq(R + "metal_", 1, 3, ".ogg"), -4.0, Vector2(0.95, 1.05), 0.1)
	_def(&"dodge", _seq(K + "rpg_audio/cloth", 1, 4, ".ogg", 1), -6.0, Vector2(0.95, 1.1), 0.15)
	_def(&"drink_start", [T + "bottle-glass-uncork-01.wav"], -6.0, Vector2(1, 1))
	_def(&"potion", [T + "water-pour-01.wav"], -6.0, Vector2(1, 1))
	_def(&"death", [R + "creature_die_01.ogg"], -2.0, Vector2(0.9, 1.0))
	_def(&"respawn", [R + "spell_02.ogg"], -8.0, Vector2(1, 1))
	_def(&"pickup_potion", _seq(R + "item_misc_", 1, 2, ".ogg"), -6.0)
	_def(&"artifact", _seq(R + "item_gem_", 1, 4, ".ogg"), -2.0, Vector2(0.95, 1.0))
	_def(&"checkpoint", [R + "spell_01.ogg"], -8.0, Vector2(1, 1))
	_def(&"puzzle_step", _seq(R + "stones_", 1, 4, ".ogg"), -6.0, Vector2(0.95, 1.05), 0.12)
	_def(&"puzzle_solved", _seq(R + "lock_", 1, 3, ".ogg"), -4.0)
	_def(&"interact", [K + "rpg_audio/handleSmallLeather.ogg"], -10.0, Vector2(0.95, 1.05), 0.2)
	_def(&"enemy_defeated", [R + "creature_die_01.ogg"], -8.0, Vector2(0.75, 0.9), 0.1)
	_def(&"boss_roar", [R + "creature_roar_01.ogg", R + "creature_roar_02.ogg"], -2.0, Vector2(0.7, 0.85), 1.0)
	_def(&"boss_attack", [T + "metal-hammer-hit-01.wav", T + "metal-hammer-hit-02.wav"], -5.0, Vector2(0.7, 0.9), 0.35)
	_def(&"boss_defeated", [R + "creature_roar_03.ogg"], -2.0, Vector2(0.6, 0.75), 1.0)
	_def(&"gate_open", [K + "rpg_audio/doorOpen_1.ogg"], -3.0, Vector2(0.7, 0.8), 1.0)


## Edge-triggered movement/combat sounds from real player state (no polling of audio itself; no spam).
func _poll_player_audio(delta: float) -> void:
	if _player == null or not _player is CharacterBody3D:
		return
	var body := _player as CharacterBody3D
	var on_floor := body.is_on_floor()
	if _prev_floor and not on_floor and body.velocity.y > 1.0:
		play_event(&"jump")
	if not on_floor:
		_air_time += delta
	elif not _prev_floor:
		if _air_time > 0.3:
			play_event(&"land")
		_air_time = 0.0
	_prev_floor = on_floor
	var action: StringName = _player.get_action_state() if _player.has_method(&"get_action_state") else &"idle"
	if action != _prev_action:
		match action:
			&"dodge":
				play_event(&"dodge")
			&"block":
				play_event(&"block_up")
			&"drink":
				play_event(&"drink_start")
		_prev_action = action
	if on_floor and (action == &"move" or action == &"sprint"):
		_step_timer -= delta
		if _step_timer <= 0.0:
			play_event(&"step")
			_step_timer = 0.3 if action == &"sprint" else 0.44
	else:
		_step_timer = 0.0


# ---- volume ------------------------------------------------------------------------------------------------------------

func _load_volume() -> void:
	var config := ConfigFile.new()
	if config.load(AUDIO_CONFIG) == OK:
		var value: Variant = config.get_value("audio", "master", _volume)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			_volume = clampf(float(value), 0.0, 1.0)


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, _volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(_volume, 0.001)))


func _on_volume_changed(value: float) -> void:
	_volume = value
	for slider in _volume_sliders:
		if not is_equal_approx(slider.value, value):
			slider.set_value_no_signal(value)
	_apply_volume()
	var config := ConfigFile.new()
	config.set_value("audio", "master", _volume)
	config.save(AUDIO_CONFIG)
