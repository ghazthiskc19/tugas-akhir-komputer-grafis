extends Control
## Full-screen island map. Pure presentation: never touches tree.paused or mouse mode (the controller owns pause, cursor and
## the M/Esc input). Contract: setup(terrain, player, session) once after add_child, then open()/close(); close_requested is
## emitted by the close button only. North is -Z (top), east is +X (right).
## The coastline/relief image is rendered once in setup from terrain.height_at; while hidden nothing is processed or redrawn.
## Route lines are the terrain's generated route centrelines (schematic, not a shortest-path navigator). Live enemy positions
## are never shown; the faint rings only mark the fixed guard areas of the layout.

signal close_requested

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const TERRAIN := preload("res://scripts/world/island_terrain.gd")
const SESSION := preload("res://scripts/world/session_progress.gd")

const IMAGE_SIZE := 250  # 1 px per metre over the 250 m island
const REFRESH_INTERVAL := 0.1
const MARGIN := 12.0
const TOP_BAR := 52.0
const ARTIFACTS: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]
const KEY_DEFEATED := &"gatekeeper_defeated"

const SEA_DEEP := Color("0a1a2b")
const SEA_SHALLOW := Color("1d4660")
const FOAM := Color("8fb8c4")
const ROUTE_GOLD := Color(0.91, 0.77, 0.41, 0.85)
const ROUTE_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const GRID := Color(0.78, 0.72, 0.54, 0.09)

## [key, title, icon id, objective artifact/flag or "" ]
const OBJECTIVES := [
	[&"symbol", "Pilar Simbol", &"artifact_forest", &"forest_artifact"],
	[&"energy", "Jalur Energi", &"artifact_energy", &"energy_artifact"],
	[&"summit", "Puncak", &"artifact_summit", &"summit_artifact"],
	[&"boss", "Penjaga Gerbang", &"boss", &"gatekeeper_defeated"],
	[&"dock_end", "Dermaga", &"dock", &"gatekeeper_defeated"],
]
const SHORT_NAMES := {
	&"spawn": "Awal", &"symbol": "Simbol", &"energy": "Energi", &"summit": "Puncak", &"boss": "Penjaga",
	&"dock_end": "Dermaga", &"camp": "Kemah",
}
const FOOTPRINT_KEYS: Array[StringName] = [&"symbol", &"energy", &"summit", &"boss"]

var _terrain: TERRAIN
var _player: Node3D
var _session: SESSION

var _texture: ImageTexture
var _map_rect := Rect2()
var _route_lines: Array[PackedVector2Array] = []
var _landmarks: Array[Dictionary] = []  # {key, pos: Vector2 (x,z), icon, objective: bool}
var _extra_checkpoints: Array[Vector2] = []
var _guard_areas: Array[Vector2] = []
var _dock_line := PackedVector2Array()
var _camp := Vector2.ZERO
var _done: Dictionary = {}
var _player_pos := Vector2.ZERO
var _player_yaw := 0.0
var _player_valid := false
var _checkpoint_pos := Vector2.ZERO
var _checkpoint_valid := false
var _elapsed := 0.0

var _title: Label
var _hint: Label
var _close_button: Button
var _panel: PanelContainer
var _seed_label: Label
var _rows: Dictionary = {}  # key -> {icon: TextureRect, name: Label, detail: Label}


func _init() -> void:
	visible = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS  # stays live while the controller pauses the tree
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()


func setup(terrain: Node3D, player: Node3D, session: Node) -> void:
	_terrain = terrain as TERRAIN
	_player = player
	_session = session as SESSION
	_collect_layout()
	_texture = _render_terrain()
	_build_ui()
	resized.connect(_relayout)
	_relayout()


func open() -> void:
	_refresh()
	visible = true
	set_process(true)
	_close_button.grab_focus()
	queue_redraw()


func close() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_INTERVAL:
		return
	_elapsed = 0.0
	_refresh()
	queue_redraw()


# ---- Data ---------------------------------------------------------------------------------------------------------
func _collect_layout() -> void:
	var anchors: Dictionary = _terrain.anchor_positions
	_landmarks.clear()
	_landmarks.append({"key": &"spawn", "pos": _xz(anchors[&"spawn"]), "icon": &"compass", "objective": false})
	for entry in OBJECTIVES:
		var key: StringName = entry[0]
		if anchors.has(key):
			_landmarks.append({"key": key, "pos": _xz(anchors[key]), "icon": entry[2], "objective": true})
	_extra_checkpoints.clear()
	for key in [&"foothill_checkpoint", &"boss_checkpoint"]:
		if anchors.has(key):
			_extra_checkpoints.append(_xz(anchors[key]))
	_camp = _xz(_terrain.get_camp_position())
	_dock_line = PackedVector2Array()
	if anchors.has(&"dock_start") and anchors.has(&"dock_end"):
		_dock_line.append(_xz(anchors[&"dock_start"]))
		_dock_line.append(_xz(anchors[&"dock_end"]))
	_guard_areas.clear()
	for enc: Dictionary in _terrain.layout.get("encounters", []):
		_guard_areas.append(_xz(enc["position"]))


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _render_terrain() -> ImageTexture:
	var n := IMAGE_SIZE
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var half := float(n) * 0.5
	for j in n:
		for i in n:
			heights[j * n + i] = _terrain.height_at(float(i) + 0.5 - half, float(j) + 0.5 - half)
	var water: float = TERRAIN.WATER_Y
	var top: float = TERRAIN.MAX_HEIGHT
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			var col: Color
			if h < water:
				col = SEA_DEEP.lerp(SEA_SHALLOW, clampf((h + 6.0) / (6.0 + water), 0.0, 1.0))
			else:
				var t := clampf((h - water) / (top - water), 0.0, 1.0)
				if h < 0.3:
					col = Color("c9b583")
				elif t < 0.45:
					col = Color("4c7a47").lerp(Color("7a8a4e"), t / 0.45)
				else:
					col = Color("7a8a4e").lerp(Color("b9b0a0"), (t - 0.45) / 0.55)
				# Hillshade from the north-west so slopes read without a heightmap legend.
				var hw := heights[j * n + maxi(i - 1, 0)]
				var hn := heights[maxi(j - 1, 0) * n + i]
				var shade := clampf((h - hw + h - hn) * 0.12, -0.35, 0.35)
				col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
				var near_water := false
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ni: int = i + off.x
					var nj: int = j + off.y
					if ni < 0 or nj < 0 or ni >= n or nj >= n or heights[nj * n + ni] < water:
						near_water = true
						break
				if near_water:
					col = col.lerp(FOAM, 0.55)
			img.set_pixel(i, j, col)
	return ImageTexture.create_from_image(img)


# ---- UI -----------------------------------------------------------------------------------------------------------
func _build_ui() -> void:
	_title = Label.new()
	_title.text = "PETA PULAU"
	_title.add_theme_font_override(&"font", UiTheme.title_font())
	_title.add_theme_font_size_override(&"font_size", UiTheme.SIZE_HEADING)
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	add_child(_title)

	_hint = Label.new()
	_hint.text = "M / Esc untuk menutup"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override(&"font_size", UiTheme.SIZE_SMALL)
	_hint.add_theme_color_override(&"font_color", UiTheme.MUTED)
	add_child(_hint)

	_close_button = Button.new()
	_close_button.text = "Tutup"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(_close_button)
	UiTheme.hover_button(_close_button)

	_panel = PanelContainer.new()
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 5)
	margin.add_child(box)

	_seed_label = _make_label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	box.add_child(_seed_label)
	box.add_child(UiTheme.divider(12.0))
	for entry in OBJECTIVES:
		box.add_child(_make_row(entry[0], entry[1], entry[2]))
	box.add_child(UiTheme.divider(12.0))
	box.add_child(_make_row(&"camp", "Perkemahan", &"checkpoint"))
	box.add_child(_make_row(&"save", "Titik simpan aktif", &"save"))
	box.add_child(UiTheme.divider(12.0))
	var notes := _make_label("Segitiga emas: posisimu. Garis emas: jalur skematik pulau, bukan rute tercepat. "
		+ "Lingkaran merah samar: area jaga tetap; posisi musuh tidak ditampilkan. Tidak ada perjalanan cepat.",
		12, UiTheme.MUTED)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.custom_minimum_size.x = 120.0
	box.add_child(notes)
	var seed_text := "Seed: %d (%s)" % [_terrain.requested_seed, "acak" if _terrain.procedural else "tetap"]
	_seed_label.text = seed_text


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _make_row(key: StringName, title: String, icon_id: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var icon := TextureRect.new()
	icon.texture = UiTheme.icon(icon_id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var name_label := _make_label(title, UiTheme.SIZE_SMALL, UiTheme.TEXT)
	var detail := _make_label("", 12, UiTheme.MUTED)
	texts.add_child(name_label)
	texts.add_child(detail)
	_rows[key] = {"icon": icon, "name": name_label, "detail": detail}
	return row


func _relayout() -> void:
	if _panel == null:
		return
	var s := size
	_title.position = Vector2(MARGIN + 4.0, 8.0)
	_close_button.size = Vector2(104.0, 36.0)
	_close_button.position = Vector2(s.x - MARGIN - 104.0, 8.0)
	_hint.size = Vector2(220.0, 22.0)
	_hint.position = Vector2(_close_button.position.x - 230.0, 15.0)
	var panel_w := clampf(s.x * 0.27, 250.0, 340.0)
	_panel.position = Vector2(s.x - panel_w - MARGIN, TOP_BAR)
	_panel.size = Vector2(panel_w, s.y - TOP_BAR - MARGIN)
	var avail := Vector2(s.x - panel_w - MARGIN * 3.0, s.y - TOP_BAR - MARGIN)
	var side := maxf(minf(avail.x, avail.y), 64.0)
	_map_rect = Rect2(Vector2(MARGIN + (avail.x - side) * 0.5, TOP_BAR + (avail.y - side) * 0.5), Vector2(side, side))
	_route_lines.clear()
	for route: StringName in _terrain.route_names():
		var line := PackedVector2Array()
		for p: Vector3 in _terrain.get_route_points(route):
			line.append(_to_map(Vector2(p.x, p.z)))
		_route_lines.append(line)
	if visible:
		queue_redraw()


func _to_map(world_xz: Vector2) -> Vector2:
	var half := float(IMAGE_SIZE) * 0.5
	var u := clampf((world_xz.x + half) / float(IMAGE_SIZE), 0.0, 1.0)
	var v := clampf((world_xz.y + half) / float(IMAGE_SIZE), 0.0, 1.0)
	return _map_rect.position + Vector2(u, v) * _map_rect.size


# ---- Live state ---------------------------------------------------------------------------------------------------
func _refresh() -> void:
	var collected: Dictionary = _session.collected_ids
	var progress: Dictionary = _session.puzzle_progress
	var defeated: bool = progress.get(KEY_DEFEATED, false) == true
	var got := 0
	for id in ARTIFACTS:
		if collected.has(id):
			got += 1
	_player_valid = _player != null and is_instance_valid(_player)
	if _player_valid:
		var local := _terrain.to_local(_player.global_position)
		_player_pos = Vector2(local.x, local.z)
		_player_yaw = _player.global_rotation.y
	_checkpoint_valid = _session.checkpoint_transform != Transform3D.IDENTITY
	if _checkpoint_valid:
		var cp := _terrain.to_local(_session.checkpoint_transform.origin)
		_checkpoint_pos = Vector2(cp.x, cp.z)

	for entry in OBJECTIVES:
		var key: StringName = entry[0]
		var flag: StringName = entry[3]
		var finished: bool = defeated if flag == KEY_DEFEATED else collected.has(flag)
		_done[key] = finished
		var detail: String
		if key == &"boss":
			detail = "Dikalahkan" if finished else "Artefak %d/3" % got
		elif key == &"dock_end":
			detail = "Terbuka" if finished else "Terkunci"
		else:
			detail = "Selesai" if finished else "Belum selesai"
		_set_row(key, finished, detail, _distance_to(key))

	_set_row(&"camp", false, "Titik pemulihan", _player_pos.distance_to(_camp) if _player_valid else -1.0)
	var save_detail := "Belum ada"
	if _checkpoint_valid:
		save_detail = String(_session.checkpoint_id) if _session.checkpoint_id != &"" else "Aktif"
	_set_row(&"save", false, save_detail, _player_pos.distance_to(_checkpoint_pos) if _player_valid and _checkpoint_valid else -1.0)


func _distance_to(key: StringName) -> float:
	if not _player_valid:
		return -1.0
	for lm in _landmarks:
		if lm["key"] == key:
			return _player_pos.distance_to(lm["pos"])
	return -1.0


func _set_row(key: StringName, finished: bool, detail: String, distance: float) -> void:
	var row: Dictionary = _rows[key]
	var text := detail if distance < 0.0 else "%s  ·  %d m" % [detail, roundi(distance)]
	var detail_label: Label = row["detail"]
	if detail_label.text != text:
		detail_label.text = text
	var color := UiTheme.GOOD if finished else UiTheme.MUTED
	detail_label.add_theme_color_override(&"font_color", color)
	(row["name"] as Label).add_theme_color_override(&"font_color", UiTheme.GOOD if finished else UiTheme.TEXT)
	(row["icon"] as TextureRect).modulate = UiTheme.GOOD if finished else Color.WHITE


# ---- Drawing ------------------------------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.06, 0.97))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, TOP_BAR - 4.0)), Color(0.055, 0.075, 0.105, 0.9))
	if _texture == null:
		return
	draw_texture_rect(_texture, _map_rect, false)
	var ppm := _map_rect.size.x / float(IMAGE_SIZE)
	for k in range(-100, 101, 50):
		var a := _to_map(Vector2(k, -125.0))
		var b := _to_map(Vector2(k, 125.0))
		draw_line(a, b, GRID, 1.0)
		draw_line(_to_map(Vector2(-125.0, k)), _to_map(Vector2(125.0, k)), GRID, 1.0)

	for key in FOOTPRINT_KEYS:
		var rect: Rect2 = _terrain.get_module_footprint(key)
		var top_left := _to_map(rect.position)
		var bottom_right := _to_map(rect.end)
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(UiTheme.GOLD, 0.35), false, 1.5)
	for pos in _guard_areas:
		draw_arc(_to_map(pos), 8.0 * ppm, 0.0, TAU, 28, Color(UiTheme.DANGER, 0.35), 1.5)

	if _dock_line.size() == 2:
		draw_line(_to_map(_dock_line[0]), _to_map(_dock_line[1]), Color(0.82, 0.68, 0.45, 0.9), maxf(3.0 * ppm, 2.0))
	for line in _route_lines:
		draw_polyline(line, ROUTE_SHADOW, 5.0, true)
	for line in _route_lines:
		draw_polyline(line, ROUTE_GOLD, 2.5, true)

	var icon_size := clampf(_map_rect.size.x * 0.06, 20.0, 30.0)
	for pos in _extra_checkpoints:
		_draw_marker(_to_map(pos), &"checkpoint", "", false, icon_size * 0.7)
	var active_checkpoint_near_spawn := _checkpoint_valid and _checkpoint_pos.distance_to(Vector2(0.0, 85.0)) <= 10.0
	var active_checkpoint_near_camp := _checkpoint_valid and _checkpoint_pos.distance_to(_camp) <= 10.0
	_draw_marker(_to_map(_camp), &"checkpoint", "" if active_checkpoint_near_camp else SHORT_NAMES[&"camp"], false, icon_size)
	for lm in _landmarks:
		var key: StringName = lm["key"]
		var label: String = SHORT_NAMES.get(key, "")
		if key == &"spawn" and active_checkpoint_near_spawn:
			label = ""
		_draw_marker(_to_map(lm["pos"]), lm["icon"], label, _done.get(key, false), icon_size)
	if _checkpoint_valid:
		var p := _to_map(_checkpoint_pos)
		draw_arc(p, icon_size * 0.8, 0.0, TAU, 24, UiTheme.GOLD, 2.0)
		var font := UiTheme.body_font()
		var checkpoint_label := p + Vector2(-30.0, icon_size * 0.8 + 14.0)
		draw_string_outline(font, checkpoint_label, "Simpan", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(font, checkpoint_label, "Simpan", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, UiTheme.GOLD)
	if _player_valid:
		_draw_player(_to_map(_player_pos), clampf(_map_rect.size.x * 0.025, 9.0, 13.0))
	draw_rect(_map_rect, UiTheme.FRAME, false, 2.0)
	_draw_compass_and_scale(ppm)


func _draw_marker(pos: Vector2, icon_id: StringName, label: String, finished: bool, icon_size: float) -> void:
	var tint := UiTheme.GOOD if finished else UiTheme.GOLD
	draw_circle(pos, icon_size * 0.62, Color(0.04, 0.06, 0.09, 0.85))
	draw_arc(pos, icon_size * 0.62, 0.0, TAU, 24, tint, 1.5)
	var tex := UiTheme.icon(icon_id)
	if tex != null:
		draw_texture_rect(tex, Rect2(pos - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, tint)
	if finished:
		var c := pos + Vector2(icon_size * 0.5, -icon_size * 0.5)
		var r := icon_size * 0.28
		draw_circle(c, r, UiTheme.GOOD)
		var check := PackedVector2Array([c + Vector2(-0.5, 0.0) * r, c + Vector2(-0.1, 0.45) * r, c + Vector2(0.55, -0.4) * r])
		draw_polyline(check, Color(0.04, 0.1, 0.05), 2.0)
	if label != "":
		var font := UiTheme.body_font()
		var at := pos + Vector2(-40.0, icon_size * 0.62 + 13.0)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, UiTheme.TEXT if not finished else UiTheme.GOOD)


func _draw_player(pos: Vector2, r: float) -> void:
	# Forward in world space is (sin yaw, cos yaw) in (x, z); screen y grows toward +z (south), so it maps directly.
	var dir := Vector2(sin(_player_yaw), cos(_player_yaw))
	var side := Vector2(-dir.y, dir.x)
	var tip := pos + dir * r * 1.5
	var left := pos - dir * r * 0.9 + side * r * 0.9
	var right := pos - dir * r * 0.9 - side * r * 0.9
	var tri := PackedVector2Array([tip, left, pos - dir * r * 0.35, right])
	draw_colored_polygon(tri, UiTheme.GOLD)
	draw_polyline(PackedVector2Array([tip, left, pos - dir * r * 0.35, right, tip]), Color(0.0, 0.9, 1.0), 3.0, true)


func _draw_compass_and_scale(ppm: float) -> void:
	var font := UiTheme.body_font()
	var c := _map_rect.position + Vector2(22.0, 34.0)
	draw_line(c + Vector2(0, 14), c + Vector2(0, -12), UiTheme.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(-5, -8), c + Vector2(5, -8)]), UiTheme.GOLD)
	draw_string_outline(font, c + Vector2(-10, -20), "U", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 14, 4, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-10, -20), "U", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 14, UiTheme.GOLD)
	var base := _map_rect.position + Vector2(14.0, _map_rect.size.y - 18.0)
	var length := 50.0 * ppm
	draw_line(base, base + Vector2(length, 0), Color(0, 0, 0, 0.9), 5.0)
	draw_line(base, base + Vector2(length, 0), UiTheme.TEXT, 2.0)
	draw_string_outline(font, base + Vector2(0, -6), "50 m", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 4, Color(0, 0, 0, 0.9))
	draw_string(font, base + Vector2(0, -6), "50 m", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UiTheme.TEXT)
