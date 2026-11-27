extends CanvasLayer
## Player-facing presentation for the island game: HUD, compass, prompts, boss bar, main menu (new run + disk Continue),
## save/pause UX, shipwreck intro, volume, completion outro and bounded audio (music, ambience, SFX).
## Usage (parent): add to tree, then setup(game, player, session, interactor, boss); show_menu() or begin_play(false);
## listen to new_run_requested. Game contract used (all optional via has_method): has_saved_run() -> bool,
## continue_saved_run() -> void (called deferred), save_run() -> bool, begin_run() -> void, get_world_anchor(id) -> Vector3.
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
const SLIDE_PX := 18.0
const TOAST_TOP := 208.0
const BOSS_TOP := 88.0

# Mixer dB targets, measured from the shipped clips' RMS levels.
const SILENT_DB := -50.0
const MUSIC_DB := -12.0
const MUSIC_BOSS_DB := -11.0
const FOREST_DB := 12.0
const SEA_DB := -23.0
const DUCK_PAUSE_MUSIC_DB := -7.0
const DUCK_PAUSE_AMBIENCE_DB := -10.0
const DUCK_BOSS_AMBIENCE_DB := -8.0
const LOW_HP_RATIO := 0.3
const LOW_STAMINA_RATIO := 0.25
const TOAST_QUEUE_MAX := 3
const ARTIFACT_SOURCES := {&"forest_artifact": "Pilar Simbol", &"energy_artifact": "Jalur Energi", &"summit_artifact": "Puncak"}

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const IslandMap := preload("res://scripts/ui/island_map.gd")
const GamePreferences := preload("res://scripts/ui/game_preferences.gd")
const MAP_RELEASE_ACTIONS: Array[StringName] = [&"move_forward", &"move_backward", &"move_left", &"move_right", &"sprint", &"attack", &"block", &"dodge", &"potion", &"interact"]
const ARTIFACT_ORDER: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]
const ARTIFACT_ICONS := {&"forest_artifact": &"artifact_forest", &"energy_artifact": &"artifact_energy", &"summit_artifact": &"artifact_summit"}

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
var _hud: Control
var _overlay: CanvasLayer
var _menu_panel: Control
var _intro_panel: Control
var _end_panel: Control
var _menu_start: Button
var _menu_block: Dictionary = {}
var _end_block: Dictionary = {}
var _end_stat_values: Array[Label] = []
var _intro_done := false
var _overlay_open := false
var _completed := false
var _pause_hooked := false
var _volume := 0.8
var _volume_sliders: Array[HSlider] = []
var _run_active := false  ## true once a run really began (begin_run) and is not completed; gates quit-save
var _menu_continue: Button
var _menu_save: Button
var _menu_status: Label
var _pause_status: Label
var _status_labels: Array[Label] = []
var _volume_labels: Array[Label] = []
var _armed_key := ""
var _quit_unsaved_armed := false
var _hit_mark: TextureRect
var _hit_tween: Tween

# island map (paused full-screen overlay opened with M during active play)
var _map: Control
var _map_open := false
var _map_prev_mouse_mode := Input.MOUSE_MODE_CAPTURED

# HUD widgets
var _hp_bar: ProgressBar
var _hp_label: Label
var _st_bar: ProgressBar
var _potion_label: Label
var _potion_key: Dictionary = {}
var _puzzle_label: Label
var _artifact_label: Label
var _artifact_slots: Array[TextureRect] = []
var _slot_on: Array[bool] = [false, false, false]
var _announced: Dictionary = {}
var _objective_label: Label
var _controls_label: Label
var _compass: Compass
var _prompt_panel: Control
var _prompt_label: Label
var _prompt_key: Dictionary = {}
var _toast_panel: Control
var _toast_icon: TextureRect
var _toast_label: Label
var _toast_tween: Tween
var _boss_tween: Tween
var _busy := false  ## a screen transition or run replacement is in flight; further menu actions are ignored
var _flash: ColorRect
var _dead_panel: Control
var _boss_panel: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_status: Label
var _shown_hp := -1
var _shown_hp_max := -1
var _shown_potions := -1
var _shown_artifacts := -1
var _shown_puzzles := -1

# HUD feedback state
var _vignette: TextureRect
var _hp_ghost: Ghost
var _st_ghost: Ghost
var _boss_ghost: Ghost
var _objective_head: Label
var _potion_icon: TextureRect
var _toast_sub: Label
var _toast_queue: Array[Dictionary] = []
var _toast_active := false
var _alert_time := 0.0
var _hp_ratio := 1.0
var _hurt_level := 0.0
var _hp_hit := 0.0
var _hp_heal := 0.0
var _st_prev := -1.0
var _st_flash := 0.0
var _st_denied := 0.0
var _music_level := SILENT_DB
var _music_target := SILENT_DB
var _music_goal_db := MUSIC_DB
var _music_pending: AudioStream
var _pause_duck := 0.0
var _boss_duck := 0.0
var _ambience_in := 0.0

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


## Damage trail behind a bar fill. Drops hold briefly before draining toward the real value.
class Ghost extends ColorRect:
	const HOLD := 0.35
	var shown := 1.0
	var hold := 0.0
	var _last := 1.0
	func _init(tint: Color) -> void:
		color = tint
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hide()
	func track(bar: ProgressBar, ratio: float, delta: float, rate: float) -> void:
		if ratio >= shown:
			shown = ratio
			hold = HOLD
		else:
			if ratio < _last:
				hold = HOLD
			if hold > 0.0:
				hold -= delta
			else:
				shown = maxf(ratio, shown - rate * delta)
		_last = ratio
		if shown - ratio < 0.004:
			hide()
			return
		var w := bar.size.x
		var x0 := 13.0 + (w - 13.0) * ratio if ratio > 0.0 else 0.0
		var x1 := 13.0 + (w - 13.0) * shown
		position = Vector2(x0, 4.0)
		size = Vector2(maxf(x1 - x0, 1.0), maxf(bar.size.y - 8.0, 2.0))
		show()
class Compass extends Control:
	var cardinals: Array = []  ## [angle to the view axis, letter]
	var markers: Array = []  ## [angle, label, distance, color, icon id]
	var _back: StyleBox

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_back = UiTheme.theme().get_stylebox("panel", "HudPanel")

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		var half := cx - 24.0
		var body := UiTheme.body_font()
		draw_style_box(_back, Rect2(Vector2.ZERO, size))
		if not cardinals.is_empty():
			# Minor ticks every 15 degrees, anchored to north so they slide with the heading.
			var north: float = cardinals[0][0]
			for k in 24:
				var a := wrapf(north + k * PI / 12.0, -PI, PI)
				if absf(a) > PI * 0.5:
					continue
				var x := cx + a / (PI * 0.5) * half
				draw_line(Vector2(x, h - 12.0), Vector2(x, h - 6.0), Color(UiTheme.FRAME, 0.45), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 5.0, h - 4.0), Vector2(cx + 5.0, h - 4.0), Vector2(cx, h - 11.0)]), UiTheme.GOLD)
		for c: Array in cardinals:
			var a: float = c[0]
			if absf(a) > PI * 0.5:
				continue
			var north_letter: bool = c[1] == "U"
			var col := UiTheme.GOLD if north_letter else UiTheme.TEXT
			var fs := 20 if north_letter else 16
			var pos := Vector2(cx + a / (PI * 0.5) * half - 10.0, 24.0)
			draw_string_outline(body, pos, c[1], HORIZONTAL_ALIGNMENT_CENTER, 20.0, fs, 4, Color(0.0, 0.0, 0.0, 0.8))
			draw_string(body, pos, c[1], HORIZONTAL_ALIGNMENT_CENTER, 20.0, fs, col)
		# Every marker gets an icon; only the nearest three get a label, placed greedily without overlapping.
		var taken: Array[Vector2] = []
		var labeled := 0
		for m: Array in markers:
			var a: float = clampf(m[0], -PI * 0.5, PI * 0.5)
			var x := cx + a / (PI * 0.5) * half
			var col: Color = m[3]
			var near := labeled < 3
			var px := 22.0 if near else 16.0
			var tex := UiTheme.icon(m[4])
			var top := 4.0 if near else 8.0
			if tex != null:
				draw_circle(Vector2(x, top + px * 0.5), px * 0.5 + 3.0, Color(0.0, 0.0, 0.0, 0.5 if near else 0.3))
				draw_texture_rect(tex, Rect2(x - px * 0.5, top, px, px), false, col if near else Color(col, 0.7))
			if not near:
				continue
			var text: String = "%s %dm" % [String(m[1]).left(14), m[2]]
			var tw := body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
			var left := clampf(x - tw * 0.5, 18.0, w - tw - 18.0)
			var overlaps := false
			for r in taken:
				if left < r.y + 6.0 and left + tw > r.x - 6.0:
					overlaps = true
					break
			if overlaps:
				continue
			taken.append(Vector2(left, left + tw))
			labeled += 1
			draw_string_outline(body, Vector2(left, h - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 3, Color(0.0, 0.0, 0.0, 0.8))
			draw_string(body, Vector2(left, h - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, col)


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
	_build_map()


## Opens the main menu: pauses the SceneTree, releases the mouse, hides the HUD underneath.
func show_menu() -> void:
	_ensure_built()
	_close_overlays()
	_armed_key = ""
	_menu_start.text = "Kembali ke Permainan" if _intro_done else "Mulai Petualangan"
	_refresh_menu_state()
	_set_block(_menu_block, run_seed, run_procedural)
	_menu_panel.show()
	_reveal(_menu_panel)
	_enter_overlay()
	_music_to(MUSIC_EXPLORE)
	play_event(&"menu_open")


## Closes any overlay and plays: first shows the shipwreck intro (once per instance) when show_intro, else resumes.
func begin_play(show_intro := true) -> void:
	_ensure_built()
	_close_overlays()
	if show_intro and not _intro_done:
		_intro_panel.show()
		_reveal(_intro_panel)
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
	_fill_stats()
	_set_block(_end_block, run_seed, run_procedural)
	_end_panel.show()
	_reveal(_end_panel, 0.7)
	_enter_overlay()
	_hide_boss_panel(true)
	_music_to(MUSIC_EXPLORE)
	play_event(&"fanfare")


## Sets the seed/procedural values shown in the menu (the parent calls this with the active run's values).
func set_run_options(seed_value: int, procedural: bool) -> void:
	run_seed = clampi(seed_value, SEED_MIN, SEED_MAX)
	run_procedural = procedural


## Queued toast; milestones add a muted second line and larger icon without replacing each other.
func toast(text: String, seconds := 3.0, icon_id: StringName = &"", subtitle := "", big := false) -> void:
	_ensure_built()
	var item := {"text": text, "seconds": seconds, "icon": icon_id, "sub": subtitle, "big": big}
	if not _toast_active:
		_toast_show(item)
		return
	if _toast_queue.is_empty() and _toast_label.text == text and _toast_sub.text == subtitle:
		_toast_show(item)
		return
	_toast_queue.append(item)
	while _toast_queue.size() > TOAST_QUEUE_MAX:
		_toast_queue.pop_front()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(_toast_done)


func _toast_show(item: Dictionary) -> void:
	var big: bool = item["big"]
	var icon_id: StringName = item["icon"]
	_toast_label.text = item["text"]
	_toast_label.add_theme_font_size_override("font_size", UiTheme.SIZE_HEADING if big else UiTheme.SIZE_BODY)
	_toast_label.add_theme_color_override("font_color", UiTheme.GOLD if big else UiTheme.TEXT)
	if big:
		_toast_label.add_theme_font_override("font", UiTheme.title_font())
	else:
		_toast_label.remove_theme_font_override("font")
	_toast_sub.text = item["sub"]
	_toast_sub.visible = item["sub"] != ""
	_toast_icon.texture = UiTheme.icon(icon_id) if icon_id != &"" else null
	_toast_icon.visible = icon_id != &""
	var px := 52.0 if big else 32.0
	_toast_icon.custom_minimum_size = Vector2(px, px)
	var entering := not _toast_active or _toast_panel.modulate.a < 1.0
	_toast_active = true
	_toast_panel.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	if entering and UiTheme.animated():
		_toast_panel.modulate.a = 0.0
		_toast_tween.set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
		_toast_tween.tween_method(_slide_strip.bind(_toast_panel, TOAST_TOP), -SLIDE_PX, 0.0, 0.3)
		_toast_tween.set_parallel(false)
	else:
		_toast_panel.modulate.a = 1.0
		_slide_strip(0.0, _toast_panel, TOAST_TOP)
	_toast_tween.tween_interval(float(item["seconds"]))
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_toast_done)
	if big:
		_pop(_toast_icon, UiTheme.GOLD.lightened(0.4), 1.5)


func _toast_done() -> void:
	_toast_active = false
	_toast_panel.hide()
	if not _toast_queue.is_empty():
		_toast_show(_toast_queue.pop_front())


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


func _label(text: String, size := UiTheme.SIZE_BODY, color := UiTheme.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	if size != UiTheme.SIZE_BODY:
		label.add_theme_font_size_override("font_size", size)
	if color != UiTheme.TEXT:
		label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	return label


## Dark outline so text stays readable straight over bright terrain.
func _outlined(label: Label, outline := 4) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", outline)
	return label


func _icon_rect(id: StringName, px: float, tint := Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiTheme.icon(id)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = tint
	return rect


func _bar(variation: StringName, height: float, width := 0.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Key art (or "[Key]" text when no art exists) for an input prompt.
func _key_cap(px: float) -> Dictionary:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(px, px)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.hide()
	box.add_child(tex)
	var text := _label("", UiTheme.SIZE_SMALL, UiTheme.GOLD)
	box.add_child(text)
	return {"box": box, "tex": tex, "text": text}


func _set_key(cap: Dictionary, key_name: String) -> void:
	var tex := UiTheme.key_texture(key_name)
	(cap["tex"] as TextureRect).texture = tex
	(cap["tex"] as TextureRect).visible = tex != null
	(cap["text"] as Label).text = "[%s]" % key_name
	(cap["text"] as Label).visible = tex == null


## Full-width strip anchored to a screen edge that centres one child and shrinks to it.
func _centered_strip(child: Control, top: bool, offset: float) -> Control:
	var strip := CenterContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(strip)
	if top:
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		strip.offset_top = offset
		strip.offset_bottom = offset
	else:
		strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
		strip.offset_top = -offset
		strip.offset_bottom = -offset
	strip.add_child(child)
	return strip


## Moves a top-anchored strip `delta` pixels from its resting offset (both offsets, so the size is untouched).
func _slide_strip(delta: float, strip: Control, base: float) -> void:
	strip.offset_top = base + delta
	strip.offset_bottom = base + delta


func _show_boss_panel() -> void:
	if _boss_tween != null:
		_boss_tween.kill()
	var entering := not _boss_panel.visible or _boss_panel.modulate.a < 1.0
	_boss_panel.show()
	if not entering or not UiTheme.animated():
		_boss_panel.modulate.a = 1.0
		_slide_strip(0.0, _boss_panel, BOSS_TOP)
		return
	_boss_panel.modulate.a = 0.0
	_boss_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_boss_tween.tween_property(_boss_panel, "modulate:a", 1.0, 0.35)
	_boss_tween.tween_method(_slide_strip.bind(_boss_panel, BOSS_TOP), -SLIDE_PX, 0.0, 0.4)


func _hide_boss_panel(immediate := false) -> void:
	if _boss_tween != null:
		_boss_tween.kill()
	if immediate or not _boss_panel.visible or not UiTheme.animated():
		_boss_panel.hide()
		_boss_panel.modulate.a = 1.0
		_slide_strip(0.0, _boss_panel, BOSS_TOP)
		return
	_boss_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_boss_tween.tween_property(_boss_panel, "modulate:a", 0.0, 0.3)
	_boss_tween.tween_method(_slide_strip.bind(_boss_panel, BOSS_TOP), 0.0, -SLIDE_PX, 0.3)
	_boss_tween.chain().tween_callback(_hide_boss_panel.bind(true))


func _hud_panel(variation: StringName = &"HudPanel") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.theme = UiTheme.theme()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_flash = ColorRect.new()
	_flash.color = Color(UiTheme.HP, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vignette_gradient := Gradient.new()
	vignette_gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	vignette_gradient.colors = PackedColorArray([Color(UiTheme.HP, 0.0), Color(UiTheme.HP, 0.0), Color(UiTheme.HP, 0.6)])
	var vignette_texture := GradientTexture2D.new()
	vignette_texture.gradient = vignette_gradient
	vignette_texture.fill = GradientTexture2D.FILL_RADIAL
	vignette_texture.fill_from = Vector2(0.5, 0.5)
	vignette_texture.fill_to = Vector2(1.0, 0.5)
	vignette_texture.width = 256
	vignette_texture.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = vignette_texture
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_hud.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Vitals cluster (top-left): HP, stamina, potion + puzzle, artifact slots, objective.
	var stats := _hud_panel()
	_hud.add_child(stats)
	stats.position = Vector2(16.0, 16.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	stats.add_child(col)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.add_child(_icon_rect(&"hp", 24.0, UiTheme.HP.lightened(0.2)))
	_hp_bar = _bar(&"HpBar", 24.0, 264.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hp_bar)
	_hp_label = _outlined(_label("", UiTheme.SIZE_SMALL, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 3)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_bar.add_child(_hp_label)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_ghost = Ghost.new(Color(1.0, 0.88, 0.58, 0.9))
	_hp_bar.add_child(_hp_ghost)
	_hp_bar.move_child(_hp_ghost, 0)
	col.add_child(hp_row)

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 8)
	st_row.add_child(_icon_rect(&"stamina", 24.0, UiTheme.STAMINA))
	_st_bar = _bar(&"StaminaBar", 16.0)
	_st_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_st_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_st_ghost = Ghost.new(Color(1.0, 0.95, 0.8, 0.85))
	_st_bar.add_child(_st_ghost)
	_st_bar.move_child(_st_ghost, 0)
	st_row.add_child(_st_bar)
	col.add_child(st_row)

	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	_potion_icon = _icon_rect(&"potion", 24.0, Color("9ED2FF"))
	items.add_child(_potion_icon)
	_potion_label = _label("", UiTheme.SIZE_BODY)
	items.add_child(_potion_label)
	_potion_key = _key_cap(24.0)
	items.add_child(_potion_key["box"])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(spacer)
	items.add_child(_icon_rect(&"puzzle", 24.0, UiTheme.TEXT))
	_puzzle_label = _label("", UiTheme.SIZE_BODY)
	items.add_child(_puzzle_label)
	col.add_child(items)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	for id: StringName in ARTIFACT_ORDER:
		var slot := _hud_panel(&"Pill")
		slot.custom_minimum_size = Vector2(40.0, 40.0)
		var glyph := _icon_rect(ARTIFACT_ICONS[id], 24.0, Color(1.0, 1.0, 1.0, 0.18))
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(glyph)
		slots.add_child(slot)
		_artifact_slots.append(glyph)
	_artifact_label = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	_artifact_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(_artifact_label)
	col.add_child(slots)

	var goal := HBoxContainer.new()
	goal.add_theme_constant_override("separation", 8)
	var flag := _icon_rect(&"objective", 24.0, UiTheme.GOLD)
	flag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	goal.add_child(flag)
	var goal_text := VBoxContainer.new()
	goal_text.add_theme_constant_override("separation", 2)
	goal.add_child(goal_text)
	_objective_head = _outlined(_label("", UiTheme.SIZE_BODY, UiTheme.GOLD), 2)
	_objective_head.custom_minimum_size.x = 232.0
	_objective_head.clip_text = true
	_objective_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_text.add_child(_objective_head)
	_objective_label = _label("", UiTheme.SIZE_SMALL + 1)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size.x = 232.0
	goal_text.add_child(_objective_label)
	col.add_child(goal)

	_compass = Compass.new()
	_compass.custom_minimum_size = Vector2(480.0, 56.0)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_compass)
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -240.0
	_compass.offset_right = 240.0
	_compass.offset_top = 16.0
	_compass.offset_bottom = 72.0

	var boss_box := _hud_panel()
	boss_box.custom_minimum_size.x = 520.0
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 16)
	boss_box.add_child(boss_row)
	boss_row.add_child(_icon_rect(&"boss", 56.0, UiTheme.GOLD))
	var boss_col := VBoxContainer.new()
	boss_col.add_theme_constant_override("separation", 4)
	boss_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_row.add_child(boss_col)
	_boss_name = _label("Penjaga Gerbang", UiTheme.SIZE_HEADING, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.add_theme_font_override("font", UiTheme.title_font())
	boss_col.add_child(_boss_name)
	_boss_bar = _bar(&"BossBar", 20.0)
	boss_col.add_child(_boss_bar)
	_boss_status = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	boss_col.add_child(_boss_status)
	_boss_panel = _centered_strip(boss_box, true, BOSS_TOP)
	_boss_panel.hide()

	var toast_box := _hud_panel()
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 12)
	toast_box.add_child(toast_row)
	_toast_icon = _icon_rect(&"objective", 32.0, UiTheme.GOLD)
	toast_row.add_child(_toast_icon)
	var toast_col := VBoxContainer.new()
	toast_col.add_theme_constant_override("separation", 0)
	toast_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toast_row.add_child(toast_col)
	_toast_label = _label("", UiTheme.SIZE_BODY, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	toast_col.add_child(_toast_label)
	_toast_sub = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_toast_sub.hide()
	toast_col.add_child(_toast_sub)
	_toast_panel = _centered_strip(toast_box, true, TOAST_TOP)
	_toast_panel.hide()

	var prompt_box := _hud_panel()
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 12)
	prompt_box.add_child(prompt_row)
	_prompt_key = _key_cap(40.0)
	prompt_row.add_child(_prompt_key["box"])
	_prompt_label = _label("", UiTheme.SIZE_HEADING)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_label)
	_prompt_panel = _centered_strip(prompt_box, false, 168.0)
	_prompt_panel.hide()

	var dead_box := _hud_panel()
	var dead_label := _label("Kau tumbang... bangkit di checkpoint.", UiTheme.SIZE_HEADING, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	dead_label.add_theme_font_override("font", UiTheme.title_font())
	dead_box.add_child(dead_label)
	var dead_center := CenterContainer.new()
	dead_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(dead_center)
	dead_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dead_center.add_child(dead_box)
	_dead_panel = dead_center
	_dead_panel.hide()

	var controls_box := _hud_panel(&"Pill")
	_controls_label = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	controls_box.add_child(_controls_label)
	_hud.add_child(controls_box)
	controls_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls_box.offset_left = 16.0
	controls_box.offset_bottom = -16.0
	_hud.hide()

	_hit_mark = _icon_rect(&"hit", 48.0)
	_hud.add_child(_hit_mark)
	_hit_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hit_mark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hit_mark.grow_vertical = Control.GROW_DIRECTION_BOTH
	var shadow := _icon_rect(&"hit", 48.0, Color(0.0, 0.0, 0.0, 0.9))
	shadow.show_behind_parent = true
	_hit_mark.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = -3.0
	shadow.offset_top = -3.0
	shadow.offset_right = 3.0
	shadow.offset_bottom = 3.0
	_hit_mark.modulate.a = 0.0


func _overlay_root(opaque: bool) -> Control:
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if opaque:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.03, 0.05, 0.09))
		gradient.set_color(1, Color(0.07, 0.17, 0.23))
		var sky := GradientTexture2D.new()
		sky.gradient = gradient
		sky.fill_from = Vector2(0.0, 0.0)
		sky.fill_to = Vector2(0.0, 1.0)
		sky.width = 8
		sky.height = 256
		var back := TextureRect.new()
		back.texture = sky
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(back)
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var mark := _icon_rect(&"compass", 600.0, Color(UiTheme.GOLD, 0.07))
		root.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mark.offset_left = -300.0
		mark.offset_right = 300.0
		mark.offset_top = -300.0
		mark.offset_bottom = 300.0
	else:
		var dim := UiTheme.backdrop(Color(0.02, 0.04, 0.08, 0.55), 7.0)
		root.add_child(dim)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.hide()
	return root


## Centred ornate panel holding a VBox of the given content width.
func _framed_column(root: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	root.set_meta(&"content", panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TitleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(parent: Node, text: String, action: Callable, sound := &"click", primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(func() -> void:
		play_event(sound)
		action.call())
	button.mouse_entered.connect(play_event.bind(&"hover"))
	UiTheme.hover_button(button)
	parent.add_child(button)
	return button


func _seed_block(parent: Node) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var caption := _label("Seed", UiTheme.SIZE_BODY, UiTheme.MUTED)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(160.0, 40.0)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "bilangan bulat"
	edit.max_length = 11
	row.add_child(edit)
	var dice := _button(row, "Acak", func() -> void: edit.text = str(_rng.randi_range(0, 999999)))
	dice.custom_minimum_size = Vector2(88.0, 40.0)
	var check := CheckBox.new()
	check.text = "Pulau prosedural dari seed"
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(_on: bool) -> void: play_event(&"click"))
	parent.add_child(check)
	var error := _label("", UiTheme.SIZE_SMALL, UiTheme.DANGER)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var box := _framed_column(_menu_panel, 440.0)
	var pretitle := _label("THE", UiTheme.SIZE_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pretitle.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(pretitle)
	var heading := _title("LOST ISLAND")
	heading.add_theme_font_size_override("font_size", 56)
	box.add_child(heading)
	var tagline := _label("Terdampar. Temukan tiga artefak. Bangunkan sang penjaga.", UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(tagline)
	box.add_child(UiTheme.divider())
	_menu_continue = _button(box, "Lanjutkan dari Simpanan", _on_continue_pressed, &"confirm")
	_menu_status = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_menu_status)
	_status_labels.append(_menu_status)
	_menu_save = _button(box, "Simpan Progres Sekarang", _on_save_pressed, &"confirm")
	_menu_save.icon = UiTheme.icon(&"save")
	_menu_block = _seed_block(box)
	_menu_start = _button(box, "Mulai Petualangan", _on_start_pressed, &"confirm", true)
	_button(box, "Run Baru dengan Seed Ini", _on_menu_new_run)
	var vol := _volume_row(box)
	vol.alignment = BoxContainer.ALIGNMENT_CENTER
	_button(box, "Keluar", request_quit, &"back")
	var note := _label("Seed/prosedural diterapkan saat Mulai (bila diubah) atau Run Baru. Simpanan lama baru tergantikan setelah run baru tersimpan.", UiTheme.SIZE_SMALL, Color(UiTheme.MUTED, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_panel.add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.offset_left = 160.0
	note.offset_right = -160.0
	note.offset_top = -48.0
	note.offset_bottom = -16.0


func _build_intro() -> void:
	_intro_panel = _overlay_root(false)
	var col := _framed_column(_intro_panel, 592.0)
	col.add_theme_constant_override("separation", 16)
	col.add_child(_title("KAPAL KARAM"))
	col.add_child(UiTheme.divider())
	var text := _label(INTRO_TEXT, UiTheme.SIZE_BODY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var controls := _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.name = "Controls"
	col.add_child(controls)
	_button(col, "Mulai Menjelajah", func() -> void:
		_transition(func() -> void:
			_intro_done = true
			_close_overlays()
			_resume()), &"confirm", true)


func _stat_cell(icon_id: StringName, caption: String) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	var glyph := _icon_rect(icon_id, 32.0, UiTheme.GOLD)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(glyph)
	var value := _label("", UiTheme.SIZE_HEADING, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_override("font", UiTheme.title_font())
	cell.add_child(value)
	cell.add_child(_label(caption, UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_end_stat_values.append(value)
	return cell


func _build_completion() -> void:
	_end_panel = _overlay_root(true)
	var box := _framed_column(_end_panel, 520.0)
	box.add_child(_title("LEVEL 1 SELESAI"))
	box.add_child(UiTheme.divider())
	var text := _label(OUTRO_TEXT, UiTheme.SIZE_BODY, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(_stat_cell(&"compass", "Waktu"))
	stats.add_child(_stat_cell(&"artifact_energy", "Artefak"))
	stats.add_child(_stat_cell(&"hit", "Musuh kalah"))
	stats.add_child(_stat_cell(&"potion", "Ramuan tersisa"))
	box.add_child(stats)
	_end_block = _seed_block(box)
	_status_labels.append(_end_block["error"])
	_button(box, "Run Baru", func() -> void: _emit_new_run(_end_block), &"confirm", true)
	_button(box, "Menu Utama", func() -> void:
		_transition(func() -> void:
			_completed = false
			show_menu()), &"back")
	_button(box, "Keluar", request_quit, &"back")


func _volume_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var caption := _label("Volume", UiTheme.SIZE_BODY, UiTheme.MUTED)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _volume
	slider.custom_minimum_size = Vector2(120.0, 24.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_volume_changed)
	slider.drag_ended.connect(func(_changed: bool) -> void: play_event(&"click"))
	row.add_child(slider)
	_volume_sliders.append(slider)
	var pct := _label(_volume_text(), UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size.x = 56.0
	pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pct)
	_volume_labels.append(pct)
	return row


func _volume_text() -> String:
	return "Senyap" if _volume <= 0.001 else "%d%%" % roundi(_volume * 100.0)


func _refresh_volume_labels() -> void:
	var muted := _volume <= 0.001
	for label in _volume_labels:
		label.text = _volume_text()
		label.add_theme_color_override("font_color", UiTheme.DANGER if muted else UiTheme.MUTED)


func _hook_pause_panel() -> void:
	if _pause_hooked or _camera == null or not _camera.has_method(&"get_resume_button"):
		return
	var resume: Button = _camera.get_resume_button()
	if resume == null or resume.get_parent() == null:
		return
	_pause_hooked = true
	var box := resume.get_parent()
	var row := _volume_row(box)
	box.move_child(row, resume.get_index() + 1)
	var feel := GamePreferences.build_feel_rows(box)
	box.move_child(feel, row.get_index() + 1)
	var save := Button.new()
	save.text = "Simpan Progres"
	save.icon = UiTheme.icon(&"save")
	save.custom_minimum_size = Vector2(240.0, 48.0)
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_on_save_pressed)
	UiTheme.hover_button(save)
	box.add_child(save)
	box.move_child(save, feel.get_index() + 1)
	_pause_status = _label("", UiTheme.SIZE_SMALL, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_pause_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_status.custom_minimum_size.x = 240.0
	box.add_child(_pause_status)
	box.move_child(_pause_status, save.get_index() + 1)
	_status_labels.append(_pause_status)
	var menu := Button.new()
	menu.text = "Menu Utama"
	menu.custom_minimum_size = Vector2(240.0, 48.0)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void:
		play_event(&"click")
		_transition(show_menu))
	UiTheme.hover_button(menu)
	box.add_child(menu)
	box.move_child(menu, _pause_status.get_index() + 1)
	resume.pressed.connect(play_event.bind(&"click"))
	var panel: Control = _camera.get_pause_panel()
	panel.visibility_changed.connect(func() -> void:
		if panel.visible and not _overlay_open:
			var saved := _save_exists()
			_pause_status.text = "Simpanan ditemukan di disk." if saved else "Belum ada simpanan di disk."
			_pause_status.add_theme_color_override("font_color", UiTheme.GOOD if saved else UiTheme.DANGER))


# ======================================================================================================================
# Overlay flow
# ======================================================================================================================

## Fade-through-black wrapper for user-driven screen changes: out, `change` while black, in. Re-entrant clicks are ignored
## for the duration; headless runs apply `change` at once.
func _transition(change: Callable) -> void:
	if _busy or _quitting:
		return
	if not UiTheme.animated():
		change.call()
		return
	_busy = true
	await UiTheme.fade_out(get_tree())
	change.call()
	await UiTheme.fade_in(get_tree())
	_busy = false


func _reveal(root: Control, seconds := UiTheme.REVEAL_TIME) -> void:
	UiTheme.reveal(root, root.get_meta(&"content") as Control if root.has_meta(&"content") else null, seconds)


func _enter_overlay() -> void:
	if _map_open:
		_close_map(false)
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
	_run_active = not _completed
	if _run_active and _game != null and _game.has_method(&"begin_run"):
		_game.begin_run()
	_hud.show()
	if _camera != null and _camera.has_method(&"resume_game"):
		_camera.resume_game()
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _boss_active:
		_music_to(MUSIC_EXPLORE)


func _save_exists() -> bool:
	return _game != null and _game.has_method(&"has_saved_run") and bool(_game.has_saved_run())


func _say(block: Dictionary, text: String, good := false) -> void:
	var label := block["error"] as Label
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.GOOD if good else UiTheme.DANGER)


## Two-step guard: with a disk save present, starting a different run needs a second press with the same inputs.
func _confirm_replace(block: Dictionary, read: Dictionary) -> bool:
	var key := "%d/%s" % [read["seed"], read["procedural"]]
	if _armed_key == key:
		return true
	_armed_key = key
	_say(block, "Ada simpanan di disk. Run baru akan menggantikannya begitu tersimpan. Tekan sekali lagi untuk memulai.")
	play_event(&"error")
	return false


func _on_start_pressed() -> void:
	var read := _read_block(_menu_block)
	if not read["ok"]:
		return
	if read["seed"] != run_seed or read["procedural"] != run_procedural:
		_emit_new_run(_menu_block)
		return
	if not _intro_done and _save_exists() and not _confirm_replace(_menu_block, read):
		return
	_transition(begin_play.bind(true))


func _on_menu_new_run() -> void:
	_emit_new_run(_menu_block)


## Loads the disk save through the game (deferred: it replaces the running game instance).
func _on_continue_pressed() -> void:
	if not _save_exists():
		_refresh_menu_state()
		_set_save_status("Tidak ada simpanan yang valid.", false)
		play_event(&"error")
		return
	if _busy:
		return
	_busy = true
	_menu_continue.disabled = true
	_set_save_status("Memuat simpanan...", true)
	_game.call_deferred(&"continue_saved_run")


func _refresh_menu_state() -> void:
	var saved := _save_exists()
	_menu_continue.disabled = not saved
	_menu_save.visible = _run_active and not _completed
	_set_save_status("Simpanan ditemukan di disk." if saved else "Belum ada simpanan di disk.", saved)


func _set_save_status(text: String, good: bool) -> void:
	for label in _status_labels:
		label.text = text
		label.add_theme_color_override("font_color", UiTheme.GOOD if good else UiTheme.DANGER)


## Manual save from the pause panel or the in-run main menu; always reports success or failure.
func _on_save_pressed() -> void:
	var ok := false
	if _game != null and _game.has_method(&"save_run"):
		ok = bool(_game.save_run())
	var stamp := Time.get_time_string_from_system()
	_set_save_status(("Progres tersimpan ke disk (%s)." % stamp) if ok else "GAGAL menyimpan progres. Coba lagi sebelum keluar.", ok)
	play_event(&"confirm" if ok else &"error")
	if _menu_continue != null:
		_menu_continue.disabled = not _save_exists()


var _quitting := false


## Shared by menu/pause buttons and the window close request. Save before teardown; an unstarted menu never writes.
## Stop playback before its nodes disappear, then let the game release the scene and shared effects before tree.quit.
func request_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	if _run_active and not _completed and _game != null and _game.has_method(&"save_run"):
		if not bool(_game.save_run()) and not _quit_unsaved_armed:
			_quit_unsaved_armed = true
			show_menu()
			_set_save_status("GAGAL menyimpan progres. Tekan Keluar sekali lagi untuk keluar TANPA menyimpan.", false)
			play_event(&"error")
			return
	_quitting = true
	var audio_references := _release_playback()
	for button in find_children("*", "Button", true, false):
		(button as Button).disabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tree := get_tree()
	tree.paused = true
	await _drain_playback(audio_references, true)
	if is_instance_valid(_game) and _game.has_method(&"quit_run"):
		_game.quit_run(exit_code)
	else:
		tree.quit(exit_code)


## Also runs for scene replacement and external SceneTree.quit (--quit-after included), not only UI-driven exit.
func _exit_tree() -> void:
	# External quit has no more main-loop frames. Wait for a real mixer pass to enqueue playback destruction;
	# AudioServer's final cleanup then reclaims those entries. Ordinary shutdown already drained them below.
	_drain_playback(_release_playback(), false)


func _release_playback() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for stream: Variant in _cache.values():
		if stream is AudioStream:
			references.append(weakref(stream))
	_quitting = true
	set_process(false)
	for tween in [_music_tween, _toast_tween, _hit_tween, _boss_tween]:
		if tween != null:
			tween.kill()
	_music_tween = null
	_toast_tween = null
	_hit_tween = null
	_boss_tween = null
	var players: Array[AudioStreamPlayer] = [_music, _forest, _sea]
	players.append_array(_sfx)
	for audio in players:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
	_cache.clear()
	return references


## stop() only queues mixer-side deletion. Simulation timers (especially --fixed-fps) cannot fence the audio thread.
## Observe our released resources instead, yielding real CPU time and main-thread reclamation frames. A stalled driver
## cannot hold shutdown forever; the deadline is monotonic wall time, bounded even with extreme reported latency.
func _drain_playback(references: Array[WeakRef], allow_frames: bool) -> void:
	var started: int = Time.get_ticks_usec()
	var latency: float = AudioServer.get_output_latency() + AudioServer.get_time_to_next_mix()
	var deadline: int = started + clampi(ceili(latency * 4000000.0), 500000, 2000000)
	while _audio_references_pending(references):
		if Time.get_ticks_usec() >= deadline:
			push_warning("Audio playback cleanup exceeded its wall-clock shutdown deadline.")
			return
		if not allow_frames:
			var last_mix: int = Time.get_ticks_usec() - ceili(AudioServer.get_time_since_last_mix() * 1000000.0)
			if last_mix > started:
				# Driver timestamps can be recorded before mixing; this barrier waits until that pass finishes.
				AudioServer.lock()
				AudioServer.unlock()
				return
		var sleep_usec: int = clampi(ceili(AudioServer.get_time_to_next_mix() * 1000000.0), 2000, 10000)
		OS.delay_usec(sleep_usec)
		if allow_frames:
			await get_tree().process_frame


func _audio_references_pending(references: Array[WeakRef]) -> bool:
	for reference in references:
		if reference.get_ref() != null:
			return true
	return false


func _emit_new_run(block: Dictionary) -> void:
	if _busy:
		return
	var read := _read_block(block)
	if not read["ok"]:
		return
	if _save_exists() and not _confirm_replace(block, read):
		return
	run_seed = read["seed"]
	run_procedural = read["procedural"]
	_intro_done = false
	_completed = false
	_run_active = false
	_busy = true
	new_run_requested.emit(run_seed, run_procedural)


func _notification(what: int) -> void:
	# Focus loss with the map open: leave the safe paused state with the camera's pause panel, never an unpaused map.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _map_open:
		_close_map(false)
		if _camera != null and _camera.has_method(&"pause_game"):
			_camera.pause_game()


func _build_map() -> void:
	if _map != null or _game == null:
		return
	var terrain: Variant = _game.get(&"terrain")
	if not terrain is Node3D:
		return
	_map = IslandMap.new()
	_map.name = "IslandMap"
	add_child(_map)
	_map.setup(terrain, _player, _session)
	_map.hide()
	_map.close_requested.connect(func() -> void:
		if _map_open:
			play_event(&"click")
			_close_map(true))


func _camera_pause_visible() -> bool:
	return _camera != null and _camera.has_method(&"get_pause_panel") and _camera.get_pause_panel().visible


func _player_dead() -> bool:
	return _player != null and _player.has_method(&"is_dead") and _player.is_dead()


func _can_open_map() -> bool:
	return _map != null and not _map_open and _run_active and not _overlay_open and not _busy \
		and not _quitting and not _completed and not get_tree().paused and not _camera_pause_visible() \
		and not _dead_panel.visible and not _player_dead()


func _open_map() -> void:
	_map_open = true
	_map_prev_mouse_mode = Input.mouse_mode
	for action in MAP_RELEASE_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	if _camera != null and _camera.has_method(&"pause_game"):
		_camera.pause_game()
		_camera.get_pause_panel().visible = false
	else:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.hide()
	_map.open()
	UiTheme.reveal(_map)
	play_event(&"click")


## Closes the map. resume = true only for the map's own close (M, Esc, close button): restores the prior active play;
## false when another overlay or the camera pause took over, which then stays in charge of the paused state.
func _close_map(resume: bool) -> void:
	if not _map_open:
		return
	_map_open = false
	_map.close()
	_map.modulate.a = 1.0
	if not _overlay_open:
		_hud.show()
	if not resume or _overlay_open or _camera_pause_visible():
		return
	if _camera != null and _camera.has_method(&"resume_game"):
		_camera.resume_game()
	else:
		get_tree().paused = false
		Input.mouse_mode = _map_prev_mouse_mode


func _input(event: InputEvent) -> void:
	if _quitting:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if _map_open and (key.keycode == KEY_ESCAPE or code == KEY_M or key.keycode == KEY_M):
				_close_map(true)
				get_viewport().set_input_as_handled()
				return
			if (code == KEY_M or key.keycode == KEY_M) and _can_open_map():
				_open_map()
				get_viewport().set_input_as_handled()
				return
	# While a presentation overlay is up, Esc must not toggle the camera pause (it would unpause behind the menu).
	if _overlay_open and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


func _fill_stats() -> void:
	var seconds := int(_run_time)
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	var kills: int = _session.killed_enemy_ids.size() if _session != null else 0
	var potions: int = _player.potion_count if _player != null and "potion_count" in _player else 0
	var values := ["%02d:%02d" % [seconds / 60, seconds % 60], "%d/%d" % [artifacts, ARTIFACTS_NEEDED], str(kills), str(potions)]
	for i in mini(values.size(), _end_stat_values.size()):
		_end_stat_values[i].text = values[i]


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


func _on_attack_hit(target: Node, _amount: int) -> void:
	var dead: bool = target != null and "is_dead" in target and target.is_dead
	var is_boss: bool = target != null and _boss != null and target.get_parent() == _boss
	play_event(&"hit", 2.0 if dead else 0.0)
	if not dead and not is_boss:
		play_event(&"enemy_hit")  # small enemies have no hurt voice of their own; boss keeps its own audio
	if _hit_mark != null:
		_hit_mark.modulate = UiTheme.GOLD if dead else Color.WHITE
		if _hit_tween != null:
			_hit_tween.kill()
		_hit_tween = create_tween()
		_hit_tween.tween_property(_hit_mark, "modulate:a", 0.0, 0.22 if dead else 0.14)


func _on_damage_taken(amount: int, blocked: bool) -> void:
	play_event(&"block_hit" if blocked else &"hurt")
	if blocked:
		_st_flash = 1.0
		return
	_hurt_level = clampf(0.32 + float(amount) / 90.0, 0.32, 0.55)
	_hp_hit = 1.0
	_flash.color = Color(UiTheme.HP, 0.08)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.3)
func _on_action_refused(action: StringName) -> void:
	play_event(&"error")
	if action == &"dodge" or action == &"block":
		_st_denied = 1.0


func _on_player_died() -> void:
	play_event(&"death")
	_hide_boss_panel()
	if _boss_active:
		_boss_active = false
		_music_to(MUSIC_EXPLORE)



func _on_potion_drunk(healed: int) -> void:
	play_event(&"potion")
	if healed > 0:
		toast("+%d HP" % healed, 1.5, &"hp")


func _on_potion_cancelled() -> void:
	play_event(&"error")


func _on_respawned() -> void:
	play_event(&"respawn")
	toast("Kembali ke checkpoint.", 2.5, &"checkpoint")


func _on_checkpoint(_id: StringName) -> void:
	_poll_session()


func _on_target_changed(target: Node) -> void:
	if target != null:
		play_event(&"target")


func _on_boss_started() -> void:
	_boss_active = true
	_boss_phase = 1
	_boss_state = ""
	_show_boss_panel()
	_music_to(MUSIC_BOSS)
	play_event(&"boss_roar")
	toast("Penjaga Gerbang terbangun!", 3.0, &"boss")


func _on_boss_won() -> void:
	_boss_active = false
	_hide_boss_panel()
	_music_to(MUSIC_EXPLORE)
	play_event(&"boss_defeated")
	play_event(&"gate_open")
	toast("Penjaga runtuh. Gerbang terbuka — lewati untuk keluar.", 5.0, &"dock")


func _on_boss_completed() -> void:
	if not _completed:
		show_completion()


# ======================================================================================================================
# Per-frame
# ======================================================================================================================

func _process(delta: float) -> void:
	_update_mix(delta)
	_update_alert(delta)
	if _map_open:
		if _overlay_open or _camera_pause_visible():
			_close_map(false)
		elif not get_tree().paused or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _overlay_open and (not get_tree().paused or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		# A late camera _ready/resume_game must not unpause or recapture behind a menu.
		_enter_overlay()
	if _overlay_open or _game == null:
		return
	if get_tree().paused:
		return
	_run_time += delta
	_update_resources()
	_update_alert(delta)
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
	_dead_panel.visible = _player != null and _player.has_method(&"is_dead") and _player.is_dead()
	if Input.is_action_just_pressed(&"interact") and _interactor != null and _interactor.get_prompt() != "":
		play_event(&"interact")


func _update_resources() -> void:
	if _player == null:
		return
	var health: Node = _player.get_health() if _player.has_method(&"get_health") else null
	if health != null:
		var cur := int(health.current_health)
		var hp_max := int(health.max_health)
		_hp_bar.max_value = hp_max
		_hp_bar.value = cur
		_hp_ratio = float(cur) / maxf(float(hp_max), 1.0)
		if cur != _shown_hp or hp_max != _shown_hp_max:
			_shown_hp = cur
			_shown_hp_max = hp_max
			_hp_label.text = "%d/%d" % [cur, hp_max]
	if "stamina" in _player:
		_st_bar.max_value = _player.max_stamina
		_st_bar.value = _player.stamina
	if "potion_count" in _player and _player.potion_count != _shown_potions:
		_shown_potions = _player.potion_count
		_potion_label.text = "%d/%d" % [_player.potion_count, _player.max_potions]
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	if artifacts != _shown_artifacts:
		_shown_artifacts = artifacts
		_artifact_label.text = "Artefak %d/%d" % [artifacts, ARTIFACTS_NEEDED]
		_artifact_label.add_theme_color_override("font_color", UiTheme.GOLD if artifacts >= ARTIFACTS_NEEDED else UiTheme.MUTED)
	for i in ARTIFACT_ORDER.size():
		var got: bool = _session != null and _session.is_collected(ARTIFACT_ORDER[i])
		if got != _slot_on[i]:
			_slot_on[i] = got
			_artifact_slots[i].modulate = UiTheme.GOLD if got else Color(1.0, 1.0, 1.0, 0.18)
	var puzzles := _count_done(_session.puzzle_progress) if _session != null else 0
	if puzzles != _shown_puzzles:
		_shown_puzzles = puzzles
		_puzzle_label.text = "%d/%d" % [puzzles, PUZZLE_KEYS.size()]



func _update_alert(delta: float) -> void:
	_alert_time += delta
	_hurt_level = maxf(0.0, _hurt_level - delta * 1.8)
	_st_flash = maxf(0.0, _st_flash - delta * 4.0)
	_st_denied = maxf(0.0, _st_denied - delta * 3.0)
	var pulse := 0.0
	if _hp_ratio > 0.0 and _hp_ratio <= LOW_HP_RATIO:
		var severity := 1.0 if _hp_ratio <= 0.15 else 0.55
		pulse = severity * (0.4 + 0.45 * (0.5 + 0.5 * sin(_alert_time * TAU * 0.8)))
	_vignette.modulate.a = maxf(_hurt_level * 0.9, pulse)
	var stamina_ratio: float = _st_bar.value / maxf(_st_bar.max_value, 1.0)
	var tint := Color(1.0, 0.5, 0.45) if stamina_ratio < LOW_STAMINA_RATIO else Color.WHITE
	if _st_flash > 0.0:
		tint = tint.lerp(Color(1.7, 1.7, 1.7), _st_flash * 0.8)
	if _st_denied > 0.0:
		tint = tint.lerp(Color(2.0, 0.3, 0.3), _st_denied)
	_st_bar.self_modulate = tint


func _pop(control: Control, tint: Color, scale_to: float) -> void:
	if not UiTheme.animated() or not control.is_inside_tree():
		return
	control.pivot_offset = control.get_combined_minimum_size() * 0.5
	control.scale = Vector2.ONE * scale_to
	control.modulate = tint
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", Color.WHITE, 0.55)

func _update_prompt() -> void:
	var prompt: String = _interactor.get_prompt() if _interactor != null else ""
	_prompt_panel.visible = prompt != ""
	if prompt != "":
		var text := prompt.trim_prefix("[E]").strip_edges()
		if _prompt_label.text != text:
			_prompt_label.text = text


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
	var hint := "%s%s%s%s gerak • %s lari • %s serang • %s blok • %s berguling • %s ramuan • %s interaksi • M peta • Esc jeda" % [
		_action_text(&"move_forward"), _action_text(&"move_left"), _action_text(&"move_backward"), _action_text(&"move_right"),
		_action_text(&"sprint"), _action_text(&"attack"), _action_text(&"block"), _action_text(&"dodge"),
		_action_text(&"potion"), _action_text(&"interact")]
	_controls_label.text = hint
	_set_key(_potion_key, _action_text(&"potion"))
	_set_key(_prompt_key, _action_text(&"interact"))
	var intro_controls := _intro_panel.find_child("Controls", true, false) as Label
	if intro_controls != null:
		intro_controls.text = hint


# ---- compass / hints ------------------------------------------------------------------------------------------------

func _refresh_targets() -> void:
	_targets.clear()
	var raw: Array[Dictionary] = []
	var generated_regions: Dictionary = {}
	if _game != null:
		var terrain: Node = null
		if "terrain" in _game:
			terrain = _game.get("terrain") as Node
		if terrain == null or not terrain.has_method(&"get_compass_targets"):
			terrain = _game.get_node_or_null(^"World")
		if terrain == null or not terrain.has_method(&"get_compass_targets"):
			terrain = _game.find_child("IslandTerrain", true, false)
		if terrain != null and terrain.has_method(&"get_compass_targets"):
			for entry: Dictionary in terrain.get_compass_targets():
				var pos: Vector3 = entry.get("position", Vector3.INF)
				if pos != Vector3.INF:
					var label := String(entry.get("label", "Tujuan"))
					generated_regions[label] = String(entry.get("region", ""))
					raw.append({"label": label, "pos": pos, "region": String(entry.get("region", "")), "hint": String(entry.get("hint", "")), "node": null, "id": _artifact_id(label, entry.get("artifact_id", &""))})
	for node in get_tree().get_nodes_in_group(&"compass_target"):
		var n3 := node as Node3D
		if n3 == null or not n3.is_inside_tree() or _target_done(n3):
			continue
		var label := String(n3.get_meta(&"label", n3.name))
		# A module owns its live position/hint, but its authored lab biome cannot override the generated island.
		var region: String = generated_regions.get(label, String(n3.get_meta(&"region", "")))
		raw.append({"label": label, "pos": n3.global_position, "region": region, "hint": String(n3.get_meta(&"hint", "")), "node": n3, "id": _artifact_id(label, n3.get_meta(&"artifact_id", &""))})
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
	elif gate_pos == Vector3.INF:
		gate_pos = _game_anchor(&"boss")
	if won:
		var dock_end := _game_anchor(&"dock_end")
		if dock_end != Vector3.INF:
			_targets.append({"label": "Dermaga", "pos": dock_end, "region": "", "hint": "Gerbang terbuka. Menuju dermaga untuk pulang.", "node": null, "id": &""})
		return
	if gate_pos == Vector3.INF:
		return
	_targets.append({"label": "Gerbang", "pos": gate_pos, "region": "", "hint": "Tiga artefak terkumpul. Menuju gerbang.", "node": gate_node, "id": &""})


## World-space position of a game anchor (seeded layout), or Vector3.INF when the game does not provide it.
func _game_anchor(id: StringName) -> Vector3:
	if _game == null or not _game.has_method(&"get_world_anchor"):
		return Vector3.INF
	var pos: Variant = _game.get_world_anchor(id)
	return pos if pos is Vector3 else Vector3.INF


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
		var target_node: Variant = t["node"]
		var node: Node3D = target_node as Node3D if is_instance_valid(target_node) else null
		var pos: Vector3 = node.global_position if node != null else t["pos"]
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
		var gold: bool = label == "Gerbang" or label == "Dermaga"
		markers.append([f["angle"], label, int(f["dist"]), UiTheme.GOLD if gold else UiTheme.TEXT, _marker_icon(label, f["t"]["id"])])
		if f["dist"] < nearest_d:
			nearest_d = f["dist"]
			nearest = f["t"]
	_compass.cardinals = cardinals
	_compass.markers = markers
	_compass.queue_redraw()
	var parts := _objective_parts(nearest, nearest_d)
	_objective_head.text = parts[0]
	_objective_label.text = parts[1]
	_objective_label.visible = parts[1] != ""


## Compass icon for a target: its artifact art, the gate guardian, the pier, else a flag.
func _marker_icon(label: String, id: StringName) -> StringName:
	if ARTIFACT_ICONS.has(id):
		return ARTIFACT_ICONS[id]
	if label == "Gerbang":
		return &"boss"
	if label == "Dermaga":
		return &"dock"
	return &"objective"


func _objective_parts(nearest: Dictionary, dist: float) -> Array:
	if _completed:
		return ["", ""]
	if _boss_active:
		return ["Kalahkan Penjaga Gerbang", "Baca telegraph, hindari, lalu serang."]
	var artifacts: int = _session.count_kind(&"artifact") if _session != null else 0
	if nearest.is_empty():
		return ["Jelajahi pulau", "Selesaikan puzzle dan cari artefak."] if artifacts < ARTIFACTS_NEEDED else ["Artefak lengkap", "Menuju gerbang."]
	var hint: String = nearest["hint"] if nearest["hint"] != "" else "Menuju %s" % nearest["label"]
	if nearest["region"] != "":
		hint += " (%s)" % nearest["region"]
	return ["%s — %d m" % [nearest["label"], int(dist)], hint]


func _objective_text(nearest: Dictionary, _dist: float) -> String:
	return _objective_parts(nearest, 10.0)[1]


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
	_announced.clear()
	for id in ARTIFACT_ORDER:
		if _session.is_collected(id):
			_announced[id] = true


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
		var found_icon := &"artifact_forest"
		var found_from := ""
		for id in ARTIFACT_ORDER:
			if _session.is_collected(id) and not _announced.has(id):
				_announced[id] = true
				found_icon = ARTIFACT_ICONS[id]
				match id:
					&"forest_artifact":
						found_from = "Pilar Simbol"
					&"energy_artifact":
						found_from = "Jalur Energi"
					&"summit_artifact":
						found_from = "Puncak"
		toast("Artefak %d/%d ditemukan" % [artifacts, ARTIFACTS_NEEDED], 3.5, found_icon, "Ditemukan di " + found_from, true)
		if artifacts >= ARTIFACTS_NEEDED:
			toast("Ketiga artefak terkumpul. Gerbang menunggu.", 4.5, &"boss")
		_refresh_targets()
	elif potions > _base_potions:
		play_event(&"pickup_potion")
		toast("Ramuan diambil", 1.5, &"potion")
	if kills > _base_kills:
		play_event(&"enemy_defeated")
	if done > _base_puzzle_done:
		play_event(&"puzzle_solved")
		toast("Puzzle terpecahkan", 3.0, &"puzzle")
		_refresh_targets()
	elif puzzle_hash != _base_puzzle_hash:
		play_event(&"puzzle_step")
	if _session.checkpoint_id != _base_checkpoint:
		if _session.checkpoint_id != &"":
			play_event(&"checkpoint")
			toast("Checkpoint aktif", 2.0, &"checkpoint")
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
		toast("Inti Penjaga menyala lebih terang!", 3.0, &"boss")
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
	_music.volume_db = SILENT_DB
	add_child(_music)
	_forest = _loop_player("AmbienceForest", AMBIENCE_FOREST, FOREST_DB)
	_sea = _loop_player("AmbienceSea", AMBIENCE_SEA, SEA_DB)
	_register_defaults()
	_music_to(MUSIC_EXPLORE)


func _loop_player(node_name: String, path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = SILENT_DB
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
	_music_goal_db = MUSIC_DB if path == MUSIC_EXPLORE else MUSIC_BOSS_DB
	if _music.playing:
		_music_pending = stream
		_music_target = SILENT_DB
	else:
		_music_pending = null
		_music.stream = stream
		_music.play()
		_music_target = _music_goal_db


func _update_mix(delta: float) -> void:
	if _quitting or _music == null:
		return
	_music_level = move_toward(_music_level, _music_target, (75.0 if _music_target < _music_level else 30.0) * delta)
	if _music_pending != null and _music_level <= SILENT_DB + 1.0:
		_music.stream = _music_pending
		_music_pending = null
		_music.play()
		_music_target = _music_goal_db
	var pause_mix := 1.0 if get_tree().paused or _map_open else 0.0
	_pause_duck = move_toward(_pause_duck, pause_mix, delta / 0.35)
	_boss_duck = move_toward(_boss_duck, 1.0 if _boss_active else 0.0, delta / 1.2)
	_ambience_in = move_toward(_ambience_in, 1.0, delta / 3.0)
	var ambience_db := (1.0 - _ambience_in) * 40.0 + DUCK_PAUSE_AMBIENCE_DB * _pause_duck + DUCK_BOSS_AMBIENCE_DB * _boss_duck
	_music.volume_db = _music_level + DUCK_PAUSE_MUSIC_DB * _pause_duck
	_forest.volume_db = maxf(FOREST_DB + ambience_db, SILENT_DB)
	_sea.volume_db = maxf(SEA_DB + ambience_db, SILENT_DB)


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
	_def(&"enemy_hit", [R + "creature_hurt_01.ogg", R + "creature_hurt_02.ogg"], -14.0, Vector2(0.7, 0.85), 0.12)
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
	_refresh_volume_labels()
	var config := ConfigFile.new()
	config.set_value("audio", "master", _volume)
	config.save(AUDIO_CONFIG)
