extends Node3D
## Shared combat VFX hub. One instance lives under the SceneTree root (created lazily by the static helpers) and owns
## fixed pools built once: CPUParticles3D bursts (Kenney particle pack, CC0), flat slash arcs and ground rings
## (own procedural shaders). Nothing is allocated while playing: callers only reposition/restart pooled nodes.
## Compatibility renderer safe: unshaded materials, no lights, no compute.
##
## Usage: const Vfx := preload("res://scripts/vfx/combat_vfx.gd"); Vfx.hit_spark(self, pos, dir, false)

const SCRIPT_PATH := "res://scripts/vfx/combat_vfx.gd"
const HUB_NAME := &"CombatVfxHub"
const TEX := "res://assets/third_party/kenney/particle_pack/"

enum Kind { SPARK, FLASH, GLOW, DUST, DEBRIS, SMOKE, HEAL }

const GOLD := Color(1.0, 0.82, 0.3)
const STEEL := Color(0.5, 0.82, 1.0)
const HURT_RED := Color(1.0, 0.18, 0.1)
const ENEMY_ORANGE := Color(1.0, 0.85, 0.35)
const HEAL_GREEN := Color(0.62, 1.0, 0.78)

## amount / lifetime / size (m) / velocity range / spread (deg) / gravity y / additive / grow (end scale / start scale) /
## pool length / base color / texture / emission radius
const KIND_CFG := {
	Kind.SPARK: {"tex": "star_06", "amount": 12, "life": 0.36, "size": 0.42, "vmin": 3.0, "vmax": 7.0, "spread": 70.0,
		"gravity": -9.0, "add": false, "end": 0.0, "start": 1.0, "pool": 6, "radius": 0.05},
	Kind.FLASH: {"tex": "star_06", "amount": 1, "life": 0.14, "size": 1.9, "vmin": 0.0, "vmax": 0.0, "spread": 0.0,
		"gravity": 0.0, "add": false, "end": 0.2, "start": 1.0, "pool": 6, "radius": 0.0},
	Kind.GLOW: {"tex": "light_01", "amount": 1, "life": 0.22, "size": 2.3, "vmin": 0.0, "vmax": 0.0, "spread": 0.0,
		"gravity": 0.0, "add": false, "end": 0.3, "start": 0.7, "pool": 6, "radius": 0.0},
	Kind.DUST: {"tex": "smoke_04", "amount": 9, "life": 0.65, "size": 0.95, "vmin": 0.8, "vmax": 2.4, "spread": 85.0,
		"gravity": 0.6, "add": false, "end": 1.6, "start": 0.5, "pool": 5, "radius": 0.5},
	Kind.DEBRIS: {"tex": "dirt_01", "amount": 8, "life": 0.6, "size": 0.45, "vmin": 3.0, "vmax": 6.5, "spread": 55.0,
		"gravity": -18.0, "add": false, "end": 0.2, "start": 1.0, "pool": 3, "radius": 0.4},
	Kind.SMOKE: {"tex": "smoke_07", "amount": 6, "life": 0.9, "size": 1.1, "vmin": 0.4, "vmax": 1.3, "spread": 60.0,
		"gravity": 0.9, "add": false, "end": 1.5, "start": 0.6, "pool": 3, "radius": 0.3},
	Kind.HEAL: {"tex": "star_04", "amount": 18, "life": 1.0, "size": 0.55, "vmin": 0.7, "vmax": 1.6, "spread": 20.0,
		"gravity": 1.2, "add": false, "end": 0.0, "start": 1.0, "pool": 2, "radius": 0.55},
}

## Drawn after world transparents (telegraph boxes, rings) so effects stay readable inside them.
const FX_PRIORITY := 40
const SLASH_LIFT_DEG := 18.0
const SLASH_POOL := 6
const RING_POOL := 6
const ARC_SEGMENTS := 28

const SLASH_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float flip = 1.0;
uniform float half_angle = 1.2;
void vertex() {
	float angle = mix(-half_angle, half_angle, UV.x);
	float inner = 1.0 - 0.75 * pow(sin(3.14159265 * UV.x), 0.8);
	float r = mix(inner, 1.0, UV.y);
	VERTEX = vec3(sin(angle) * r, 0.0, cos(angle) * r);
}
void fragment() {
	float t = flip > 0.0 ? UV.x : 1.0 - UV.x;
	float behind = progress * 1.3 - t;
	float trail = clamp(1.0 - behind / 0.6, 0.0, 1.0);
	float mask = step(0.0, behind) * trail * trail;
	float edge = pow(UV.y, 1.6);
	float fade = 1.0 - smoothstep(0.5, 1.0, progress);
	ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.7);
	ALPHA = clamp(mask * fade * (0.35 + 0.9 * edge), 0.0, 1.0) * color.a;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float thickness = 0.2;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float ring = smoothstep(1.0 - thickness - 0.08, 1.0 - thickness, d) * (1.0 - smoothstep(0.93, 1.0, d));
	ALBEDO = color.rgb;
	ALPHA = ring * alpha * color.a;
}
"""


## Screen flash: edge vignette with a faint centre tint (keeps enemy telegraphs readable). Alpha-mixed, not additive:
## additive red on the bright island ground saturates to yellow-white and stops reading as damage.
const SCREEN_FLASH_TIME := 0.25
## One pulse per gap: <= 2.5 flashes/s, under the 3 Hz photosensitivity guideline.
const SCREEN_FLASH_GAP := 0.4
const FLASH_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float intensity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.3, length(p * vec2(0.85, 1.0)));
	COLOR = vec4(tint.rgb, clamp((0.05 + 0.8 * edge) * intensity, 0.0, 0.8));
}
"""

## Extra sounds layered on top of the presentation's own hit/block/hurt/death events (clip -> dB, pitch).
const SOUND_VOICES := 4
const SOUNDS := {
	&"finisher": [
		{"path": "res://assets/third_party/audio/rpg_sfx_rubberduck/stones_03.ogg", "db": -4.0, "pitch": 0.62},
		{"path": "res://assets/third_party/audio/rpg_sfx_rubberduck/wood_03.ogg", "db": -8.0, "pitch": 0.72},
	],
	&"guard_break": [
		{"path": "res://assets/third_party/kenney/rpg_audio/metalPot3.ogg", "db": -2.0, "pitch": 0.8},
		{"path": "res://assets/third_party/audio/rpg_sfx_rubberduck/chain_02.ogg", "db": -5.0, "pitch": 0.9},
	],
}


class Timed:
	extends RefCounted
	var node: MeshInstance3D
	var material: ShaderMaterial
	var age := 0.0
	var duration := 0.0
	var active := false
	var radius := 1.0
	var start_thickness := 0.3


var _emitters: Dictionary = {}
var _cursor: Dictionary = {}
var _slashes: Array[Timed] = []
var _rings: Array[Timed] = []
var _slash_next := 0
var _ring_next := 0
var _active_timed := 0
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_mat: ShaderMaterial
var _flash_active := false
var _flash_age := 0.0
var _flash_strength := 1.0
var _flash_started_ms := -100000
var _voices: Array[AudioStreamPlayer] = []
var _voice_next := 0
var _sound_layers: Dictionary = {}


# ----------------------------------------------------------------------------------------------- static API

static var _hub: Node3D
## Player preferences (Pengaturan > Guncangan kamera / Hit-stop); written by game_preferences.gd, read by camera and hit_stop.
static var shake_scale := 1.0
static var hit_stop_enabled := true
static var _stop_token := 0


## Null when the hub is not yet in the tree (it joins one frame after the first call) or `from` is outside the tree.
## Owners call it once from _ready so the first real effect is never dropped.
static func hub_for(from: Node) -> Node3D:
	if from == null or not from.is_inside_tree():
		return null
	if is_instance_valid(_hub):
		return _hub if _hub.is_inside_tree() else null
	var created := Node3D.new()
	created.name = HUB_NAME
	created.set_script(load(SCRIPT_PATH))
	created.call(&"build")
	_hub = created
	from.get_tree().root.add_child.call_deferred(created)
	return null


## Particle burst. `dir` is the emission axis (world space), `tint` multiplies the kind's texture, `size_scale` scales the quads.
static func burst(from: Node, kind: int, pos: Vector3, dir := Vector3.UP, tint := Color.WHITE, size_scale := 1.0) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._burst(kind, pos, dir, tint, size_scale)


## Flat crescent swept around +Z of `yaw`. `radius` in metres, `arc_deg` total angle, `roll_deg` tilts the arc plane
## (90 = vertical chop), `flip` reverses the sweep direction.
static func slash(from: Node, pos: Vector3, yaw: float, radius: float, arc_deg: float, tint: Color, duration: float,
		roll_deg := 0.0, flip := false) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._slash(pos, yaw, radius, arc_deg, tint, duration, roll_deg, flip)


## Expanding ground ring (y is the ring height).
static func ring(from: Node, pos: Vector3, radius: float, tint: Color, duration: float, thickness := 0.3) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._ring(pos, radius, tint, duration, thickness)


static func hit_spark(from: Node, pos: Vector3, dir: Vector3, big: bool, tint := GOLD) -> void:
	burst(from, Kind.FLASH, pos, Vector3.UP, tint.lightened(0.4), 1.5 if big else 1.0)
	burst(from, Kind.SPARK, pos, dir, tint, 1.5 if big else 1.0)
	if big:
		burst(from, Kind.SPARK, pos, dir + Vector3.UP, Color.WHITE, 1.2)
		burst(from, Kind.GLOW, pos, Vector3.UP, tint, 1.4)


static func dust_puff(from: Node, pos: Vector3, tint := Color(0.78, 0.72, 0.62, 0.7), size_scale := 1.0) -> void:
	burst(from, Kind.DUST, pos, Vector3.UP, tint, size_scale)


static func ground_impact(from: Node, pos: Vector3, radius: float, tint: Color) -> void:
	ring(from, pos + Vector3(0.0, 0.1, 0.0), radius, tint, 0.4)
	burst(from, Kind.DUST, pos + Vector3(0.0, 0.15, 0.0), Vector3.UP, Color(0.78, 0.72, 0.62, 0.8), radius * 0.45)
	burst(from, Kind.DEBRIS, pos + Vector3(0.0, 0.2, 0.0), Vector3.UP, Color(0.5, 0.46, 0.42), 1.0)
	burst(from, Kind.GLOW, pos + Vector3(0.0, 0.4, 0.0), Vector3.UP, tint, radius * 0.5)


static func poof(from: Node, pos: Vector3, tint := Color(0.7, 0.68, 0.7, 0.8)) -> void:
	burst(from, Kind.SMOKE, pos, Vector3.UP, tint, 1.0)
	burst(from, Kind.DUST, pos, Vector3.UP, tint, 1.2)
	burst(from, Kind.GLOW, pos, Vector3.UP, Color(1.0, 0.9, 0.7), 1.2)
	burst(from, Kind.HEAL, pos, Vector3.UP, Color(0.75, 0.9, 1.0), 1.0)

## Camera shake (trauma 0..1, additive, decays). Falls off with distance when `at` is given. No-op without a shaking camera.
## The player-facing intensity (Guncangan kamera slider, `shake_scale`) is applied by the camera, not here.
static func shake(from: Node, amount: float, at := Vector3.INF) -> void:
	if from == null or not from.is_inside_tree():
		return
	var cam := from.get_viewport().get_camera_3d()
	if cam == null or not cam.has_method(&"add_shake"):
		return
	var falloff := 1.0
	if at != Vector3.INF:
		falloff = clampf(1.0 - cam.global_position.distance_to(at) / 40.0, 0.0, 1.0)
	cam.call(&"add_shake", amount * falloff)


## Brief time dip on a landed hit. Skipped headless so QA timing stays deterministic, while another stop is running,
## while paused and when the player turned hit-stop off. The restore timer ignores time scale; `reset_transients` also
## restores it (pause, scene exit) and invalidates the pending timer.
static func hit_stop(from: Node, duration: float, time_scale := 0.05) -> void:
	if not hit_stop_enabled or from == null or not from.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if Engine.time_scale < 1.0 or from.get_tree().paused:
		return
	Engine.time_scale = time_scale
	_stop_token += 1
	var token := _stop_token
	from.get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == _stop_token:
			Engine.time_scale = 1.0)


## Puts back everything that must not outlive a gameplay moment: time scale and the screen flash.
## Called when the game pauses and when the camera leaves the tree.
static func reset_transients() -> void:
	_stop_token += 1
	Engine.time_scale = 1.0
	if is_instance_valid(_hub) and _hub.has_method(&"clear_screen_flash"):
		_hub.call(&"clear_screen_flash")


## Short edge vignette + faint full-screen tint (<= SCREEN_FLASH_TIME real seconds, one pulse per SCREEN_FLASH_GAP so it
## never strobes). `tint` red for damage, pale blue for a guard break.
static func screen_flash(from: Node, tint: Color, strength := 1.0) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._screen_flash(tint, strength)


## Sword/stone layered body for a finisher plus pitch-varied clang for guard break (assets: kenney rpg_audio CC0,
## rubberduck rpg_sfx CC0, already in the project). Skipped silently when the hub is not ready.
static func sound(from: Node, id: StringName) -> void:
	var hub := hub_for(from)
	if hub != null:
		hub._sound(id)


## Shatter effect for a broken guard: white-blue ring, radial steel shards and a bright flash, clearly unlike a block spark.
static func guard_break(from: Node, pos: Vector3, forward: Vector3) -> void:
	var ground := Vector3(pos.x, 0.0, pos.z)
	ring(from, ground + Vector3(0.0, 0.1, 0.0), 2.8, Color(0.75, 0.92, 1.0), 0.45, 0.22)
	ring(from, pos, 1.6, Color(1.0, 1.0, 1.0), 0.3, 0.12)
	burst(from, Kind.FLASH, pos, Vector3.UP, Color(0.85, 0.95, 1.0), 2.4)
	burst(from, Kind.GLOW, pos, Vector3.UP, Color(0.6, 0.85, 1.0), 2.2)
	burst(from, Kind.SPARK, pos, forward + Vector3.UP * 0.3, Color(0.8, 0.95, 1.0), 1.8)
	burst(from, Kind.SPARK, pos, Vector3.UP, Color.WHITE, 1.5)
	burst(from, Kind.DEBRIS, pos, Vector3.UP + forward * 0.4, Color(0.7, 0.85, 1.0), 1.1)



# ------------------------------------------------------------------------------------------------- instance

func build() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for kind in KIND_CFG:
		_build_pool(kind)
	var arc := _arc_mesh()
	for i in SLASH_POOL:
		_slashes.append(_make_timed(arc, SLASH_SHADER))
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	for i in RING_POOL:
		_rings.append(_make_timed(plane, RING_SHADER))
	_build_screen_flash()
	_build_audio()
	set_process(false)


func _exit_tree() -> void:
	# Never leave the game slowed if the tree is torn down mid hit-stop.
	if _hub == self:
		_stop_token += 1
		Engine.time_scale = 1.0
		_hub = null
	# Playing voices/streams held past exit are reported as leaked instances.
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_sound_layers.clear()


## Shutdown: stop() only queues mixer-side deletion, so a sound still playing at exit is reported as a leaked playback.
## Stop every voice, drop the streams, then give the mixer real time (bounded) to reclaim them. Awaited by Game.quit_run.
func release_audio() -> void:
	var refs: Array[WeakRef] = []
	for layers: Array in _sound_layers.values():
		for layer: Dictionary in layers:
			refs.append(weakref(layer["stream"]))
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_sound_layers.clear()
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		var pending := false
		for ref in refs:
			if ref.get_ref() != null:
				pending = true
		if not pending:
			return
		OS.delay_msec(10)
		await get_tree().process_frame


func _process(delta: float) -> void:
	_active_timed = 0
	for item in _slashes:
		if item.active:
			_advance(item, delta, true)
	for item in _rings:
		if item.active:
			_advance(item, delta, false)
	if _flash_active:
		# Wall clock: a hit-stop (time_scale ~0) must neither freeze nor stretch the flash beyond SCREEN_FLASH_TIME.
		_flash_age = float(Time.get_ticks_msec() - _flash_started_ms) / 1000.0
		var t := _flash_age / SCREEN_FLASH_TIME
		if t >= 1.0:
			clear_screen_flash()
		else:
			var env := t / 0.14 if t < 0.14 else pow(1.0 - (t - 0.14) / 0.86, 2.0)
			_flash_mat.set_shader_parameter(&"intensity", _flash_strength * env)
			_active_timed += 1
	if _active_timed == 0:
		set_process(false)


func _screen_flash(tint: Color, strength: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _flash_started_ms < int(SCREEN_FLASH_GAP * 1000.0):
		return
	_flash_started_ms = now
	_flash_age = 0.0
	_flash_strength = clampf(strength, 0.0, 1.0)
	_flash_active = true
	_flash_rect.visible = true
	_flash_mat.set_shader_parameter(&"tint", tint)
	_flash_mat.set_shader_parameter(&"intensity", 0.0)
	set_process(true)


func clear_screen_flash() -> void:
	_flash_active = false
	if _flash_rect != null:
		_flash_rect.visible = false


func _build_screen_flash() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "ScreenFlash"
	_flash_layer.layer = 0  # below the HUD/overlay layers (>= 1), above the 3D view
	add_child(_flash_layer)
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = shader
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.material = _flash_mat
	_flash_rect.visible = false
	_flash_layer.add_child(_flash_rect)


func _ready() -> void:
	# Needs the viewport, so it cannot run in build() (hub is not in the tree yet).
	if _flash_rect != null:
		_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_audio() -> void:
	for i in SOUND_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		add_child(player)
		_voices.append(player)
		# A finished voice keeps its playback object alive; drop it so no stream is held at shutdown.
		player.finished.connect(func() -> void: player.stream = null)
	for id in SOUNDS:
		var layers: Array = []
		for layer: Dictionary in SOUNDS[id]:
			var stream := load(layer["path"]) as AudioStream
			if stream != null:
				layers.append({"stream": stream, "db": layer["db"], "pitch": layer["pitch"]})
		_sound_layers[id] = layers


func _sound(id: StringName) -> void:
	for layer: Dictionary in _sound_layers.get(id, []):
		var voice := _voices[_voice_next]
		_voice_next = (_voice_next + 1) % SOUND_VOICES
		voice.stream = layer["stream"]
		voice.volume_db = layer["db"]
		voice.pitch_scale = layer["pitch"] * randf_range(0.96, 1.04)
		voice.play()


func _advance(item: Timed, delta: float, is_slash: bool) -> void:
	item.age += delta
	var p := clampf(item.age / item.duration, 0.0, 1.0)
	if p >= 1.0:
		item.active = false
		item.node.visible = false
		return
	_active_timed += 1
	if is_slash:
		item.material.set_shader_parameter(&"progress", p)
	else:
		var eased := 1.0 - pow(1.0 - p, 3.0)
		var r := item.radius * lerpf(0.15, 1.0, eased)
		item.node.scale = Vector3(r, 1.0, r)
		item.material.set_shader_parameter(&"alpha", 1.0 - p * p)
		item.material.set_shader_parameter(&"thickness", lerpf(item.start_thickness, 0.08, p))


func _make_timed(mesh: Mesh, code: String) -> Timed:
	var item := Timed.new()
	var shader := Shader.new()
	shader.code = code
	item.material = ShaderMaterial.new()
	item.material.shader = shader
	item.material.render_priority = FX_PRIORITY
	item.node = MeshInstance3D.new()
	item.node.mesh = mesh
	item.node.material_override = item.material
	item.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.node.top_level = true
	item.node.visible = false
	add_child(item.node)
	return item


func _slash(pos: Vector3, yaw: float, radius: float, arc_deg: float, tint: Color, duration: float,
		roll_deg: float, flip: bool) -> void:
	var item := _slashes[_slash_next]
	_slash_next = (_slash_next + 1) % SLASH_POOL
	# Lift the leading edge so the crescent faces the (above-and-behind) game camera instead of lying edge-on.
	var lift := 0.0 if absf(roll_deg) > 60.0 else -deg_to_rad(SLASH_LIFT_DEG)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift) * Basis(Vector3.BACK, deg_to_rad(roll_deg)) \
		* Basis.from_scale(Vector3(radius, 1.0, radius))
	item.node.global_transform = Transform3D(basis, pos)
	item.node.visible = true
	item.material.set_shader_parameter(&"color", tint)
	item.material.set_shader_parameter(&"flip", -1.0 if flip else 1.0)
	item.material.set_shader_parameter(&"half_angle", deg_to_rad(clampf(arc_deg, 20.0, 340.0)) * 0.5)
	item.material.set_shader_parameter(&"progress", 0.0)
	item.age = 0.0
	item.duration = maxf(duration, 0.05)
	item.active = true
	set_process(true)


func _ring(pos: Vector3, radius: float, tint: Color, duration: float, thickness: float) -> void:
	var item := _rings[_ring_next]
	_ring_next = (_ring_next + 1) % RING_POOL
	item.radius = radius
	item.start_thickness = thickness
	item.node.global_transform = Transform3D(Basis.from_scale(Vector3(radius * 0.15, 1.0, radius * 0.15)), pos)
	item.node.visible = true
	item.material.set_shader_parameter(&"color", tint)
	item.material.set_shader_parameter(&"alpha", 1.0)
	item.material.set_shader_parameter(&"thickness", thickness)
	item.age = 0.0
	item.duration = maxf(duration, 0.05)
	item.active = true
	set_process(true)


func _burst(kind: int, pos: Vector3, dir: Vector3, tint: Color, size_scale: float) -> void:
	var pool: Array = _emitters[kind]
	var index: int = _cursor[kind]
	_cursor[kind] = (index + 1) % pool.size()
	var emitter := pool[index] as CPUParticles3D
	emitter.global_position = pos
	emitter.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	emitter.color = tint
	var cfg: Dictionary = KIND_CFG[kind]
	emitter.scale_amount_min = size_scale * 0.7
	emitter.scale_amount_max = size_scale * 1.15
	emitter.restart()
	emitter.emitting = true
	if int(cfg["amount"]) == 1:
		emitter.angle_min = randf_range(0.0, 360.0)
		emitter.angle_max = emitter.angle_min


func _build_pool(kind: int) -> void:
	var cfg: Dictionary = KIND_CFG[kind]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(cfg["size"])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if cfg["add"]:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.render_priority = FX_PRIORITY
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(TEX + String(cfg["tex"]) + ".png")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.particles_anim_h_frames = 1
	material.particles_anim_v_frames = 1
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	material.no_depth_test = false
	quad.material = material
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.6, Color(1, 1, 1, 0.85))
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, float(cfg["start"])))
	curve.add_point(Vector2(1.0, float(cfg["end"])))
	var list: Array = []
	for i in int(cfg["pool"]):
		var e := CPUParticles3D.new()
		e.amount = int(cfg["amount"])
		e.lifetime = float(cfg["life"])
		e.one_shot = true
		e.explosiveness = 1.0
		e.emitting = false
		e.local_coords = false
		e.mesh = quad
		e.direction = Vector3.UP
		e.spread = float(cfg["spread"])
		e.initial_velocity_min = float(cfg["vmin"])
		e.initial_velocity_max = float(cfg["vmax"])
		e.gravity = Vector3(0.0, float(cfg["gravity"]), 0.0)
		e.color_ramp = ramp
		e.scale_amount_curve = curve
		e.angle_min = 0.0
		e.angle_max = 360.0
		var radius := float(cfg["radius"])
		if radius > 0.0:
			e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			e.emission_sphere_radius = radius
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
		list.append(e)
	_emitters[kind] = list
	_cursor[kind] = 0


## Strip of ARC_SEGMENTS quads; the slash shader's vertex() bends it into a crescent (u along the arc, v inner -> outer).
func _arc_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in ARC_SEGMENTS + 1:
		var u := float(i) / float(ARC_SEGMENTS)
		verts.append(Vector3(u, 0.0, 0.0))
		uvs.append(Vector2(u, 0.0))
		verts.append(Vector3(u, 0.0, 1.0))
		uvs.append(Vector2(u, 1.0))
	for i in ARC_SEGMENTS:
		var a := i * 2
		indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 1.0, 2.0))
	return mesh
