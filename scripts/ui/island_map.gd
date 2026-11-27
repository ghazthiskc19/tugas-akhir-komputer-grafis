extends Control
## Full-screen island map. Pure presentation: never touches tree.paused or mouse mode (the controller owns pause, cursor and
## the M/Esc input). Contract: setup(terrain, player, session) once after add_child, then open()/close(); close_requested is
## emitted by the close button only. North is -Z (top), east is +X (right).
## The height field is sampled once in setup (terrain.height_at) into a texture; a canvas shader colours it per pixel
## (hillshade, coastline ink line, foam), so while hidden nothing is processed or redrawn.
## Route lines are the terrain's generated route centrelines (schematic, not a shortest-path navigator). Live enemy positions
## are never shown; the faint rings only mark the fixed guard areas of the layout.
## Labels are small outlined chips placed greedily around their marker, avoiding every other marker and chip; a chip that
## had to move away from its marker is tied back with a leader line. Markers that would overlap are nudged apart.

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

const TERRAIN_SHADER := preload("res://shaders/ui_island_map.gdshader")
const LABEL_SIZE := 12
const CHIP_HEIGHT := 18.0
const ROUTE_GOLD := Color(0.91, 0.77, 0.41, 0.9)
const ROUTE_SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const GRID := Color(0.78, 0.72, 0.54, 0.08)
const BACKDROP := Color(0.02, 0.035, 0.06, 0.97)
const SAVE_MERGE_DISTANCE := 10.0

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
var _markers: Array[Dictionary] = []  # {key, world, true, shown, icon, size, label}
var _chip := StyleBoxFlat.new()
var _terrain_rect: TextureRect
var _pulse: Control
var _legend: Control

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
	_texture = _render_heights()
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
	_pulse.queue_redraw()
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


## Height field, one texel per metre, sampled at texel centres. Half floats are filterable on every renderer.
func _render_heights() -> ImageTexture:
	var n := IMAGE_SIZE
	var half := float(n) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RF)
	for j in n:
		for i in n:
			img.set_pixel(i, j, Color(_terrain.height_at(float(i) + 0.5 - half, float(j) + 0.5 - half), 0.0, 0.0))
	img.convert(Image.FORMAT_RH)
	return ImageTexture.create_from_image(img)



# ---- UI -----------------------------------------------------------------------------------------------------------
func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter(&"heights", _texture)
	material.set_shader_parameter(&"water", TERRAIN.WATER_Y)
	material.set_shader_parameter(&"top", TERRAIN.MAX_HEIGHT)
	_terrain_rect = TextureRect.new()
	_terrain_rect.texture = _texture
	_terrain_rect.material = material
	_terrain_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_terrain_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_terrain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_rect.show_behind_parent = true
	add_child(_terrain_rect)
	_chip.bg_color = Color(0.03, 0.05, 0.08, 0.86)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(5)
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
	_legend = Control.new()
	_legend.custom_minimum_size = Vector2(0.0, 92.0)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.draw.connect(_draw_legend)
	box.add_child(_legend)
	var notes := _make_label("Posisi musuh tidak ditampilkan. Tidak ada perjalanan cepat; garis adalah jalur skematik, bukan rute tercepat.",
		12, UiTheme.MUTED)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.custom_minimum_size.x = 120.0
	box.add_child(notes)
	_seed_label.text = "Seed: %d (%s)" % [_terrain.requested_seed, "acak" if _terrain.procedural else "tetap"]
	_pulse = Control.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.draw.connect(_draw_player_layer)
	add_child(_pulse)
	_pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	_terrain_rect.position = _map_rect.position
	_terrain_rect.size = _map_rect.size
	_route_lines.clear()
	for route: StringName in _terrain.route_names():
		var line := PackedVector2Array()
		for p: Vector3 in _terrain.get_route_points(route):
			line.append(_to_map(Vector2(p.x, p.z)))
		_route_lines.append(line)
	_layout_markers()
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
func _icon_size() -> float:
	return clampf(_map_rect.size.x * 0.06, 20.0, 30.0)


func _make_marker(key: StringName, world: Vector2, icon: StringName, marker_size: float, label: String) -> Dictionary:
	var at := _to_map(world)
	return {"key": key, "world": world, "at": at, "shown": at, "icon": icon, "size": marker_size, "label": label}


## Builds the marker list and pushes overlapping markers apart (later markers move away from earlier ones; the true spot is
## then marked with a dot and a short tie line).
func _layout_markers() -> void:
	_markers.clear()
	if _terrain == null or _map_rect.size.x <= 0.0:
		return
	var icon := _icon_size()
	for lm in _landmarks:
		_markers.append(_make_marker(lm["key"], lm["pos"], lm["icon"], icon, SHORT_NAMES.get(lm["key"], "")))
	_markers.append(_make_marker(&"camp", _camp, &"checkpoint", icon, SHORT_NAMES[&"camp"]))
	for pos in _extra_checkpoints:
		_markers.append(_make_marker(&"extra", pos, &"checkpoint", icon * 0.7, ""))
	for i in range(1, _markers.size()):
		var a: Dictionary = _markers[i]
		for _pass in 3:
			for j in i:
				var b: Dictionary = _markers[j]
				var min_distance: float = (float(a["size"]) + float(b["size"])) * 0.62 + 4.0
				var offset: Vector2 = a["shown"] - b["shown"]
				var distance := offset.length()
				if distance < min_distance:
					var dir := offset / distance if distance > 0.5 else Vector2.from_angle(float(i) * 2.4 - 1.0)
					a["shown"] = b["shown"] + dir * min_distance


static func _circle_rect(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


static func _dashed(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in points.size() - 1:
		var a := points[i]
		var seg := a.distance_to(points[i + 1])
		if seg < 0.001:
			continue
		var dir := (points[i + 1] - a) / seg
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				ci.draw_line(a + dir * pos, a + dir * (pos + step), color, width, true)
			pos += step
			left -= step
			if left <= 0.0001:
				on = not on
				left = dash if on else gap


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, TOP_BAR - 4.0)), Color(0.055, 0.075, 0.105, 0.9))
	if _texture == null:
		return
	var ppm := _map_rect.size.x / float(IMAGE_SIZE)
	for k in range(-100, 101, 50):
		draw_line(_to_map(Vector2(k, -125.0)), _to_map(Vector2(k, 125.0)), GRID, 1.0)
		draw_line(_to_map(Vector2(-125.0, k)), _to_map(Vector2(125.0, k)), GRID, 1.0)
	_draw_edge_shade()

	for key in FOOTPRINT_KEYS:
		var rect: Rect2 = _terrain.get_module_footprint(key)
		var top_left := _to_map(rect.position)
		var bottom_right := _to_map(rect.end)
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(UiTheme.GOLD, 0.35), false, 1.5)
	for pos in _guard_areas:
		var center := _to_map(pos)
		draw_circle(center, 8.0 * ppm, Color(UiTheme.DANGER, 0.07))
		draw_arc(center, 8.0 * ppm, 0.0, TAU, 28, Color(UiTheme.DANGER, 0.4), 1.5, true)

	if _dock_line.size() == 2:
		draw_line(_to_map(_dock_line[0]), _to_map(_dock_line[1]), Color(0.82, 0.68, 0.45, 0.9), maxf(3.0 * ppm, 2.0))
	for line in _route_lines:
		draw_polyline(line, ROUTE_SHADOW, 4.5, true)
	for line in _route_lines:
		_dashed(self, line, ROUTE_GOLD, 2.2, 9.0, 5.0)

	var icon := _icon_size()
	for m in _markers:
		_draw_marker(m)
	var obstacles: Array[Rect2] = []
	for m in _markers:
		obstacles.append(_circle_rect(m["shown"], float(m["size"]) * 0.62 + 2.0))
	if _player_valid:
		obstacles.append(_circle_rect(_to_map(_player_pos), _player_radius() * 1.8))
	var items: Array[Dictionary] = []
	var host_key: StringName = &""
	if _checkpoint_valid:
		var ring_pos := _to_map(_checkpoint_pos)
		var best_distance := SAVE_MERGE_DISTANCE
		for m in _markers:
			var distance := _checkpoint_pos.distance_to(m["world"])
			if (m["key"] == &"spawn" or m["key"] == &"camp") and distance <= best_distance:
				best_distance = distance
				host_key = m["key"]
				ring_pos = m["shown"]
		draw_arc(ring_pos, icon * 0.8, 0.0, TAU, 24, UiTheme.GOLD, 2.0, true)
		if host_key == &"":
			obstacles.append(_circle_rect(ring_pos, icon * 0.8 + 2.0))
			items.append({"pos": ring_pos, "radius": icon * 0.8 + 1.0, "text": "Simpan", "tint": UiTheme.GOLD})
	for m in _markers:
		var text: String = m["label"]
		if text == "":
			continue
		if m["key"] == host_key:
			text += " · Simpan"
		var tint := UiTheme.GOOD if _done.get(m["key"], false) else UiTheme.TEXT
		items.append({"pos": m["shown"], "radius": float(m["size"]) * 0.62 + 1.5, "text": text, "tint": tint})
	for label in _place_labels(items, obstacles):
		_draw_label(label)

	draw_rect(_map_rect.grow(3.0), Color(UiTheme.FRAME, 0.3), false, 1.0)
	draw_rect(_map_rect, UiTheme.FRAME, false, 2.0)
	_draw_compass_and_scale(ppm)


func _draw_edge_shade() -> void:
	var r := _map_rect
	var w := 36.0
	var c0 := Color(0.02, 0.03, 0.05, 0.5)
	var c1 := Color(0.02, 0.03, 0.05, 0.0)
	var colors := PackedColorArray([c0, c0, c1, c1])
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + w), Vector2(r.position.x, r.position.y + w)]), colors)
	draw_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.end.y - w), Vector2(r.position.x, r.end.y - w)]), colors)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.position.x, r.end.y), Vector2(r.position.x + w, r.end.y), Vector2(r.position.x + w, r.position.y)]), colors)
	draw_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y), r.end, Vector2(r.end.x - w, r.end.y), Vector2(r.end.x - w, r.position.y)]), colors)


func _draw_marker(m: Dictionary) -> void:
	var pos: Vector2 = m["shown"]
	var icon_size: float = m["size"]
	var finished: bool = _done.get(m["key"], false)
	var tint := UiTheme.GOOD if finished else UiTheme.GOLD
	if pos.distance_to(m["at"]) > 1.0:
		draw_line(m["at"], pos, Color(tint, 0.8), 1.5, true)
		draw_circle(m["at"], 2.5, tint)
	draw_circle(pos, icon_size * 0.62, Color(0.04, 0.06, 0.09, 0.88))
	draw_arc(pos, icon_size * 0.62, 0.0, TAU, 24, tint, 1.5, true)
	var tex := UiTheme.icon(m["icon"])
	if tex != null:
		draw_texture_rect(tex, Rect2(pos - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, tint)
	if finished:
		var c := pos + Vector2(icon_size * 0.5, -icon_size * 0.5)
		var r := icon_size * 0.28
		draw_circle(c, r, UiTheme.GOOD)
		var check := PackedVector2Array([c + Vector2(-0.5, 0.0) * r, c + Vector2(-0.1, 0.45) * r, c + Vector2(0.55, -0.4) * r])
		draw_polyline(check, Color(0.04, 0.1, 0.05), 2.0)


## Greedy label placement: each label takes the first spot (nearest ring, fixed direction order) that overlaps no marker,
## no earlier label and stays inside the map; otherwise the least-overlapping spot. Items are {pos, radius, text, tint}.
func _place_labels(items: Array[Dictionary], obstacles: Array[Rect2]) -> Array[Dictionary]:
	var font := UiTheme.body_font()
	var bounds := _map_rect.grow(-2.0)
	var taken: Array[Rect2] = obstacles.duplicate()
	var placed: Array[Dictionary] = []
	for item in items:
		var text: String = item["text"]
		var chip := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + 12.0, CHIP_HEIGHT)
		var p: Vector2 = item["pos"]
		var radius: float = item["radius"]
		var best := Rect2()
		var best_cost := INF
		var best_ring := 0
		for ring in 5:
			for rect in _label_candidates(p, radius, 3.0 + ring * 14.0, chip):
				var cost := 0.0 if bounds.encloses(rect) else 5000.0
				for other in taken:
					cost += rect.intersection(other).get_area()
				if cost < best_cost:
					best_cost = cost
					best = rect
					best_ring = ring
				if best_cost == 0.0:
					break
			if best_cost == 0.0:
				break
		taken.append(best.grow(2.0))
		placed.append({"rect": best, "anchor": p, "radius": radius, "leader": best_ring > 0, "text": text, "tint": item["tint"]})
	return placed


static func _label_candidates(p: Vector2, r: float, gap: float, chip: Vector2) -> Array[Rect2]:
	var d := r * 0.7 + gap
	return [
		Rect2(Vector2(p.x - chip.x * 0.5, p.y + r + gap), chip),
		Rect2(Vector2(p.x - chip.x * 0.5, p.y - r - gap - chip.y), chip),
		Rect2(Vector2(p.x + r + gap, p.y - chip.y * 0.5), chip),
		Rect2(Vector2(p.x - r - gap - chip.x, p.y - chip.y * 0.5), chip),
		Rect2(Vector2(p.x + d, p.y + d), chip),
		Rect2(Vector2(p.x - d - chip.x, p.y + d), chip),
		Rect2(Vector2(p.x + d, p.y - d - chip.y), chip),
		Rect2(Vector2(p.x - d - chip.x, p.y - d - chip.y), chip),
	]


func _draw_label(label: Dictionary) -> void:
	var rect: Rect2 = label["rect"]
	var tint: Color = label["tint"]
	var anchor: Vector2 = label["anchor"]
	if label["leader"]:
		var near := Vector2(clampf(anchor.x, rect.position.x, rect.end.x), clampf(anchor.y, rect.position.y, rect.end.y))
		var from := anchor + (near - anchor).normalized() * float(label["radius"])
		draw_line(from, near, Color(0.0, 0.0, 0.0, 0.8), 3.0, true)
		draw_line(from, near, Color(UiTheme.GOLD, 0.9), 1.5, true)
	_chip.border_color = Color(tint, 0.6)
	draw_style_box(_chip, rect)
	var font := UiTheme.body_font()
	var baseline := rect.position.y + (rect.size.y - font.get_height(LABEL_SIZE)) * 0.5 + font.get_ascent(LABEL_SIZE)
	draw_string_outline(font, Vector2(rect.position.x, baseline), label["text"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LABEL_SIZE, 3, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(font, Vector2(rect.position.x, baseline), label["text"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LABEL_SIZE, tint)


func _player_radius() -> float:
	return clampf(_map_rect.size.x * 0.025, 9.0, 13.0)


## Live layer redrawn every frame while the map is open: halo, expanding pulse ring (0.6 Hz, no flashing) and the arrow.
func _draw_player_layer() -> void:
	if not _player_valid or _texture == null:
		return
	var pos := _to_map(_player_pos)
	var r := _player_radius()
	var phase := fmod(Time.get_ticks_msec() * 0.001 / 1.6, 1.0)
	_pulse.draw_circle(pos, r * 1.45, Color(0.02, 0.05, 0.08, 0.7))
	_pulse.draw_arc(pos, r * (1.3 + 1.8 * phase), 0.0, TAU, 32, Color(0.0, 0.9, 1.0, (1.0 - phase) * 0.8), 2.0, true)
	# Forward in world space is (sin yaw, cos yaw) in (x, z); screen y grows toward +z (south), so it maps directly.
	var dir := Vector2(sin(_player_yaw), cos(_player_yaw))
	var side := Vector2(-dir.y, dir.x)
	var tip := pos + dir * r * 1.5
	var left := pos - dir * r * 0.9 + side * r * 0.9
	var right := pos - dir * r * 0.9 - side * r * 0.9
	var tail := pos - dir * r * 0.35
	_pulse.draw_colored_polygon(PackedVector2Array([tip, left, tail, right]), UiTheme.GOLD)
	_pulse.draw_polyline(PackedVector2Array([tip, left, tail, right, tip]), Color(0.0, 0.9, 1.0), 2.5, true)


func _draw_legend() -> void:
	var font := UiTheme.body_font()
	var w := _legend.size.x
	var tx := 34.0
	var y := 12.0
	var step := 21.0
	_legend.draw_colored_polygon(PackedVector2Array([Vector2(24.0, y - 8.0), Vector2(16.0, y + 6.0), Vector2(24.0, y + 2.0), Vector2(32.0, y + 6.0)]), UiTheme.GOLD)
	_legend.draw_polyline(PackedVector2Array([Vector2(24.0, y - 8.0), Vector2(16.0, y + 6.0), Vector2(24.0, y + 2.0), Vector2(32.0, y + 6.0), Vector2(24.0, y - 8.0)]), Color(0.0, 0.9, 1.0), 1.5, true)
	_legend.draw_string(font, Vector2(tx + 8.0, y + 5.0), "Posisimu", HORIZONTAL_ALIGNMENT_LEFT, w - tx, LABEL_SIZE, UiTheme.TEXT)
	y += step
	_dashed(_legend, PackedVector2Array([Vector2(12.0, y), Vector2(36.0, y)]), ROUTE_GOLD, 2.2, 6.0, 3.5)
	_legend.draw_string(font, Vector2(tx + 8.0, y + 5.0), "Jalur skematik", HORIZONTAL_ALIGNMENT_LEFT, w - tx, LABEL_SIZE, UiTheme.TEXT)
	y += step
	_legend.draw_circle(Vector2(24.0, y), 8.0, Color(UiTheme.DANGER, 0.07))
	_legend.draw_arc(Vector2(24.0, y), 8.0, 0.0, TAU, 20, Color(UiTheme.DANGER, 0.55), 1.5, true)
	_legend.draw_string(font, Vector2(tx + 8.0, y + 5.0), "Area jaga tetap", HORIZONTAL_ALIGNMENT_LEFT, w - tx, LABEL_SIZE, UiTheme.TEXT)
	y += step
	_legend.draw_arc(Vector2(24.0, y), 8.0, 0.0, TAU, 20, UiTheme.GOLD, 2.0, true)
	_legend.draw_string(font, Vector2(tx + 8.0, y + 5.0), "Titik simpan aktif", HORIZONTAL_ALIGNMENT_LEFT, w - tx, LABEL_SIZE, UiTheme.TEXT)


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
