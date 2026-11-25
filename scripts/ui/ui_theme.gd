extends RefCounted
## Shared player-facing UI look: fonts, colors, icons and one cached Theme built from licensed Kenney/game-icons art.
## Usage (preload, no class_name): const UiTheme := preload("res://scripts/ui/ui_theme.gd"); control.theme = UiTheme.theme().
## Theme type variations for consumers: HpBar/StaminaBar/BossBar (ProgressBar), PrimaryButton (Button),
## HudPanel/Pill (PanelContainer), TitleLabel/HeadingLabel/MutedLabel (Label).

const FONT_TITLE := "res://assets/third_party/fonts/cinzel/Cinzel-Variable.ttf"
const FONT_BODY := "res://assets/third_party/fonts/nunito/Nunito-Variable.ttf"
const BORDERS := "res://assets/third_party/kenney/fantasy_ui_borders/"
const ADV := "res://assets/third_party/kenney/ui_pack_adventure/"
const KEYS := "res://assets/third_party/kenney/input_prompts/keyboard_mouse/"
const ICON_DIR := "res://assets/third_party/game_icons/"

const GOLD := Color("E8C468")
const TEXT := Color("F3E9D2")
const MUTED := Color("A9B3BD")
const DANGER := Color("E5605A")
const HP := Color("D9484E")
const STAMINA := Color("F5A623")
const GOOD := Color("8FD694")
const PANEL_DARK := Color(0.055, 0.075, 0.105, 0.94)
const FRAME := Color("C9B88A")

## Type scale (8 px grid friendly).
const SIZE_SMALL := 14
const SIZE_BODY := 18
const SIZE_HEADING := 24
const SIZE_TITLE := 40

const ICONS := {
	&"hp": "zeromancer_heart-plus",
	&"stamina": "lorc_lightning-trio",
	&"potion": "delapouite_health-potion",
	&"artifact_forest": "lorc_rune-stone",
	&"artifact_energy": "lorc_crystal-growth",
	&"artifact_summit": "delapouite_mountain-cave",
	&"puzzle": "delapouite_puzzle",
	&"compass": "lorc_compass",
	&"boss": "delapouite_rock-golem",
	&"save": "delapouite_save",
	&"hit": "delapouite_crosshair",
	&"objective": "delapouite_flag-objective",
	&"checkpoint": "lorc_campfire",
	&"dock": "delapouite_sailboat",
}

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font
static var _icon_cache: Dictionary = {}
static var _key_cache: Dictionary = {}
static var _divider_cache: Dictionary = {}


static func title_font() -> Font:
	if _title_font == null:
		_title_font = _variable_font(FONT_TITLE, 700)
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = _variable_font(FONT_BODY, 700)
	return _body_font


static func icon(id: StringName) -> Texture2D:
	if not _icon_cache.has(id):
		var file: String = ICONS.get(id, "")
		_icon_cache[id] = load(ICON_DIR + file + ".svg") as Texture2D if file != "" else null
	return _icon_cache[id]


## Keyboard key art for a key name as printed by OS.get_keycode_string ("E", "Q", "Space"); null when no art exists.
static func key_texture(key_name: String) -> Texture2D:
	var file := key_name.to_lower().replace(" ", "_")
	if not _key_cache.has(file):
		var path := KEYS + "keyboard_%s.png" % file
		_key_cache[file] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _key_cache[file]


## Ornamental horizontal divider (line, centred knot, line) as a plain HBox; tint through its color.
static func divider(height := 18.0, tint := GOLD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for mirrored in [false, true]:
		var rect := NinePatchRect.new()
		rect.texture = _divider_texture(mirrored)
		rect.patch_margin_left = 0 if not mirrored else 30
		rect.patch_margin_right = 30 if not mirrored else 0
		rect.custom_minimum_size = Vector2(0.0, height)
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rect.self_modulate = tint
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)
	return row


static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


# ---- Motion -----------------------------------------------------------------------------------------------------
# One full-screen black fade layer lives on the SceneTree root so it survives scene replacement. Headless runs (QA,
# regressions) skip all motion: state changes stay synchronous and no frame is spent waiting on a tween.

const FADE_LAYER := 200
const FADE_OUT_TIME := 0.3
const FADE_IN_TIME := 0.4
const REVEAL_TIME := 0.2
const HOVER_TIME := 0.1
const FADE_BLUR_RADIUS := 9.0

static var _fade_layer: CanvasLayer
static var _fade_rect: ColorRect
static var _fade_blur: ColorRect
static var _fade_tween: Tween
static var _blur_shader: Shader

const BLUR_SHADER := "res://shaders/ui_backdrop_blur.gdshader"


## Full-rect dimmer that blurs whatever was drawn beneath it (screen texture) and tints it. Its alpha (modulate.a, driven
## by reveal/dismiss or a parent's modulate) is the blur amount: 0 = sharp scene, 1 = full blur + tint. Add it as the first
## child of an overlay so panels/text stay sharp above it. Headless runs get a flat tint rect (no shader, no renderer).
## One cached Shader; one tiny ShaderMaterial per backdrop. Nothing runs per frame and a hidden backdrop costs nothing.
static func backdrop(tint: Color, radius_px := 7.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Backdrop"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not animated():
		rect.color = tint
		return rect
	if _blur_shader == null:
		_blur_shader = load(BLUR_SHADER) as Shader
	var material := ShaderMaterial.new()
	material.shader = _blur_shader
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"radius_px", radius_px)
	rect.material = material
	rect.color = Color.WHITE
	return rect


## Final application teardown only; scene replacement keeps the shared theme and transition layer alive.
static func release_resources() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	if is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade_rect = null
	_fade_blur = null
	_blur_shader = null
	_theme = null
	_title_font = null
	_body_font = null
	_icon_cache.clear()
	_key_cache.clear()
	_divider_cache.clear()


static func animated() -> bool:
	return DisplayServer.get_name() != "headless"


static func _fade_node(tree: SceneTree) -> ColorRect:
	if is_instance_valid(_fade_rect):
		return _fade_rect
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "UiFade"
	_fade_layer.layer = FADE_LAYER
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# Blur sits under the black so a transition blurs the scene while it darkens; hidden (no screen copy) at alpha 0.
	_fade_blur = backdrop(Color(0.0, 0.0, 0.0, 0.0), FADE_BLUR_RADIUS)
	_fade_blur.modulate.a = 0.0
	_fade_blur.visible = false
	_fade_layer.add_child(_fade_blur)
	_fade_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child.call_deferred(_fade_layer)
	return _fade_rect

static func _fade_to(tree: SceneTree, alpha: float, seconds: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	var rect := _fade_node(tree)
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	# While heading to black the layer eats clicks (double-click guard); on the way back input flows again.
	rect.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	if not animated() or seconds <= 0.0:
		rect.color.a = alpha
		_fade_blur.modulate.a = alpha
		_fade_blur.visible = alpha > 0.0
		return
	_fade_blur.visible = true
	_fade_tween = tree.create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_trans(trans).set_ease(ease_type)
	_fade_tween.tween_property(rect, "color:a", alpha, seconds)
	_fade_tween.tween_property(_fade_blur, "modulate:a", alpha, seconds)
	var blur := _fade_blur
	_fade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(blur):
			blur.visible = alpha > 0.0)
	await _fade_tween.finished

## Eases the screen to black and returns once fully black (immediately when headless). Pair with fade_in.
static func fade_out(tree: SceneTree, seconds := FADE_OUT_TIME) -> void:
	await _fade_to(tree, 1.0, seconds, Tween.TRANS_SINE, Tween.EASE_IN)


## Eases back from black after `wait_frames` rendered frames (lets a fresh scene settle before it is revealed). Safe to
## start without awaiting from an object that is about to be freed.
static func fade_in(tree: SceneTree, seconds := FADE_IN_TIME, wait_frames := 0) -> void:
	for i in wait_frames:
		await tree.process_frame
	await _fade_to(tree, 0.0, seconds, Tween.TRANS_SINE, Tween.EASE_OUT)


## Fades `control` in while `content` (default: the control) eases from slightly small to full size. Runs on one reused
## tween per control; call only after show().
static func reveal(control: Control, content: Control = null, seconds := REVEAL_TIME) -> void:
	var old: Variant = control.get_meta(&"reveal_tween") if control.has_meta(&"reveal_tween") else null
	# Rapid close->open: resume from the current alpha/scale so the blur never pops back to sharp.
	var resuming: bool = old is Tween and (old as Tween).is_valid() and control.visible
	if old is Tween:
		(old as Tween).kill()
	if content == null:
		content = control
	if not animated() or not control.is_inside_tree():
		control.modulate.a = 1.0
		content.scale = Vector2.ONE
		return
	content.pivot_offset_ratio = Vector2(0.5, 0.5)
	if not resuming:
		control.modulate.a = 0.0
		content.scale = Vector2(0.94, 0.94)
	var tween := control.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, seconds)
	tween.tween_property(content, "scale", Vector2.ONE, seconds)
	control.set_meta(&"reveal_tween", tween)


## Fades `control` out, hides it and restores its look; `on_done` runs afterwards. Instant when nothing is animated.
static func dismiss(control: Control, content: Control = null, seconds := REVEAL_TIME * 0.75, on_done := Callable()) -> void:
	var old: Variant = control.get_meta(&"reveal_tween") if control.has_meta(&"reveal_tween") else null
	if old is Tween:
		(old as Tween).kill()
	if content == null:
		content = control
	if not animated() or not control.is_inside_tree() or not control.visible:
		control.hide()
		control.modulate.a = 1.0
		content.scale = Vector2.ONE
		if on_done.is_valid():
			on_done.call()
		return
	var tween := control.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, seconds)
	tween.tween_property(content, "scale", Vector2(0.97, 0.97), seconds)
	tween.chain().tween_callback(func() -> void:
		control.hide()
		control.modulate.a = 1.0
		content.scale = Vector2.ONE
		if on_done.is_valid():
			on_done.call())
	control.set_meta(&"reveal_tween", tween)


## Subtle hover feedback for a button: grows 3 % and brightens, eased; one reused tween per button.
static func hover_button(button: Button) -> void:
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))


static func _hover(button: Button, on: bool) -> void:
	if not animated() or not button.is_inside_tree():
		return
	var old: Variant = button.get_meta(&"hover_tween") if button.has_meta(&"hover_tween") else null
	if old is Tween:
		(old as Tween).kill()
	var on_it := on and not button.disabled
	var tween := button.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.03, 1.03) if on_it else Vector2.ONE, HOVER_TIME)
	tween.tween_property(button, "self_modulate", Color(1.15, 1.15, 1.15) if on_it else Color.WHITE, HOVER_TIME)
	button.set_meta(&"hover_tween", tween)


# ---------------------------------------------------------------------------------------------------------------------

const WGHT_TAG := 0x77676874  # OpenType axis tag "wght"

static func _variable_font(path: String, weight: int) -> Font:
	var font := FontVariation.new()
	font.base_font = load(path) as Font
	font.variation_opentype = {WGHT_TAG: weight}
	return font


static func _divider_texture(mirrored: bool) -> Texture2D:
	if not _divider_cache.has(mirrored):
		var image := (load(BORDERS + "Divider/divider-003.png") as Texture2D).get_image()
		if mirrored:
			image.flip_x()
		_divider_cache[mirrored] = ImageTexture.create_from_image(image)
	return _divider_cache[mirrored]


## Square 24 px check box art (framed dark box; gold tick when checked), built once.
static func _check_icon(on: bool) -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var edge := x < 2 or y < 2 or x > 21 or y > 21
			var inner := x >= 5 and y >= 5 and x <= 18 and y <= 18
			if edge:
				image.set_pixel(x, y, FRAME)
			elif on and inner:
				image.set_pixel(x, y, GOLD)
			else:
				image.set_pixel(x, y, Color(0.03, 0.05, 0.08, 0.95))
	return ImageTexture.create_from_image(image)


## Dark filled 9-slice: Kenney frame pixels in `frame`, the interior of the matching filled panel in `fill`.
static func _framed(index: String, fill: Color, frame: Color, margin: int, content_h: float, content_v: float) -> StyleBoxTexture:
	var border := (load(BORDERS + "Border/panel-border-%s.png" % index) as Texture2D).get_image()
	var panel := (load(BORDERS + "Panel/panel-%s.png" % index) as Texture2D).get_image()
	border.convert(Image.FORMAT_RGBA8)
	panel.convert(Image.FORMAT_RGBA8)
	var out := Image.create(panel.get_width(), panel.get_height(), false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			if border.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, frame)
			elif panel.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, fill)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(out)
	box.set_texture_margin_all(margin)
	box.content_margin_left = content_h
	box.content_margin_right = content_h
	box.content_margin_top = content_v
	box.content_margin_bottom = content_v
	return box


static func _flat(fill: Color, border: Color, radius: int, border_width: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func _bar_box(path: String, tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(ADV + path) as Texture2D
	box.set_texture_margin_all(7.0)
	box.modulate_color = tint
	return box


static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = SIZE_BODY

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_font_size("font_size", "TitleLabel", SIZE_TITLE)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_color("font_outline_color", "TitleLabel", Color(0.0, 0.0, 0.0, 0.75))
	t.set_constant("outline_size", "TitleLabel", 4)
	t.set_type_variation(&"HeadingLabel", &"Label")
	t.set_font("font", "HeadingLabel", title_font())
	t.set_font_size("font_size", "HeadingLabel", SIZE_HEADING)
	t.set_color("font_color", "HeadingLabel", GOLD)
	t.set_type_variation(&"MutedLabel", &"Label")
	t.set_font_size("font_size", "MutedLabel", SIZE_SMALL)
	t.set_color("font_color", "MutedLabel", MUTED)

	# Panels
	var panel := _framed("002", PANEL_DARK, FRAME, 16, 24.0, 20.0)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation(&"HudPanel", &"PanelContainer")
	t.set_stylebox("panel", "HudPanel", _framed("001", Color(0.05, 0.07, 0.1, 0.8), FRAME, 14, 14.0, 10.0))
	t.set_type_variation(&"Pill", &"PanelContainer")
	t.set_stylebox("panel", "Pill", _flat(Color(0.04, 0.06, 0.09, 0.78), Color(FRAME, 0.5), 6, 1, 12.0, 4.0))

	# Buttons
	var states := {
		"normal": [Color(0.10, 0.13, 0.18, 0.96), Color(FRAME, 0.8)],
		"hover": [Color(0.20, 0.25, 0.32, 0.98), GOLD],
		"pressed": [Color(0.06, 0.08, 0.11, 1.0), Color(GOLD, 0.7)],
		"disabled": [Color(0.08, 0.09, 0.11, 0.85), Color(0.35, 0.37, 0.4, 0.7)],
	}
	for state: String in states:
		t.set_stylebox(state, "Button", _framed("001", states[state][0], states[state][1], 14, 16.0, 8.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", SIZE_BODY)
	t.set_constant("icon_max_width", "Button", 24)
	t.set_constant("h_separation", "Button", 8)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.55))
	t.set_type_variation(&"PrimaryButton", &"Button")
	var primary := {
		"normal": [Color(0.30, 0.21, 0.07, 0.97), GOLD],
		"hover": [Color(0.44, 0.31, 0.09, 0.99), Color("FFE08A")],
		"pressed": [Color(0.20, 0.14, 0.05, 1.0), GOLD],
		"disabled": [Color(0.12, 0.1, 0.07, 0.85), Color(0.4, 0.37, 0.3, 0.7)],
	}
	for state: String in primary:
		t.set_stylebox(state, "PrimaryButton", _framed("001", primary[state][0], primary[state][1], 14, 16.0, 8.0))
	t.set_color("font_color", "PrimaryButton", Color("FFE9A8"))
	t.set_color("font_hover_color", "PrimaryButton", Color.WHITE)

	# Progress bars (rounded Kenney capsule art; fills tinted per variation)
	for variation in [[&"HpBar", "progress_red_small.png", Color.WHITE], [&"StaminaBar", "progress_white_small.png", STAMINA], [&"BossBar", "progress_red_small.png", Color.WHITE]]:
		t.set_type_variation(variation[0], &"ProgressBar")
		t.set_stylebox("background", variation[0], _bar_box("progress_transparent_small.png", Color.WHITE))
		t.set_stylebox("fill", variation[0], _bar_box(variation[1], variation[2]))
	t.set_stylebox("background", "ProgressBar", _bar_box("progress_transparent_small.png", Color.WHITE))
	t.set_stylebox("fill", "ProgressBar", _bar_box("progress_white_small.png", GOLD))
	t.set_font_size("font_size", "ProgressBar", SIZE_SMALL)

	# Slider
	t.set_stylebox("slider", "HSlider", _flat(Color(0.02, 0.03, 0.05, 0.9), Color(FRAME, 0.6), 3, 1, 0.0, 4.0))
	t.set_stylebox("grabber_area", "HSlider", _flat(Color(GOLD, 0.85), GOLD, 3, 0, 0.0, 4.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color("FFE08A"), GOLD, 3, 0, 0.0, 4.0))
	var grabber := load(ADV + "checkbox_beige_empty.png") as Texture2D
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	t.set_icon("grabber_disabled", "HSlider", grabber)
	t.set_constant("center_grabber", "HSlider", 1)

	# Check box
	var empty := _check_icon(false)
	var checked := _check_icon(true)
	for icon_name in ["unchecked", "unchecked_disabled", "radio_unchecked"]:
		t.set_icon(icon_name, "CheckBox", empty)
	for icon_name in ["checked", "checked_disabled", "radio_checked"]:
		t.set_icon(icon_name, "CheckBox", checked)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_constant("h_separation", "CheckBox", 8)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	t.set_font_size("font_size", "CheckBox", SIZE_BODY)

	# Line edit
	var edit := _flat(Color(0.03, 0.05, 0.08, 0.95), Color(FRAME, 0.7), 4, 1, 12.0, 6.0)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("read_only", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.03, 0.05, 0.08, 0.95), GOLD, 4, 2, 12.0, 6.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.6))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	t.set_font_size("font_size", "LineEdit", SIZE_BODY)
	return t
