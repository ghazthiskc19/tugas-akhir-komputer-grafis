extends Node3D
## Subtle sprint feedback: foot dust + a short speed streak. Two CPUParticles3D (Compatibility-safe, world-space),
## built once in setup(); afterwards only `emitting` is toggled. No screen flash, no FOV change.

const DUST_COLOR := Color(0.78, 0.72, 0.62, 0.55)
const STREAK_COLOR := Color(1.0, 1.0, 1.0, 0.35)

var _dust: CPUParticles3D
var _streak: CPUParticles3D


## Call once after the node entered the tree owner (the player). The player faces +Z, so "behind" is -Z.
func setup() -> void:
	_dust = _make_emitter(&"SprintDust", _dust_mesh(), 20, 0.45)
	_dust.position = Vector3(0.0, 0.08, -0.15)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 0.22
	_dust.direction = Vector3(0.0, 1.0, -0.6)
	_dust.spread = 35.0
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 1.1
	_dust.gravity = Vector3(0.0, 0.3, 0.0)
	_dust.scale_amount_min = 0.7
	_dust.scale_amount_max = 1.3
	_dust.scale_amount_curve = _curve(0.5, 1.0)
	_dust.color_ramp = _fade_ramp(DUST_COLOR)
	_streak = _make_emitter(&"SprintStreak", _streak_mesh(), 8, 0.18)
	_streak.position = Vector3(0.0, 0.95, -0.2)
	_streak.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_streak.emission_sphere_radius = 0.3
	_streak.direction = Vector3(0.0, 0.0, -1.0)
	_streak.spread = 4.0
	_streak.initial_velocity_min = 1.5
	_streak.initial_velocity_max = 2.5
	_streak.gravity = Vector3.ZERO
	_streak.color_ramp = _fade_ramp(STREAK_COLOR)


func set_active(active: bool) -> void:
	if _dust == null or _dust.emitting == active:
		return
	_dust.emitting = active
	_streak.emitting = active


func _make_emitter(emitter_name: StringName, mesh: Mesh, amount: int, lifetime: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = emitter_name
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.local_coords = false
	emitter.emitting = false
	emitter.mesh = mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter


func _material(billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


func _dust_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)
	mesh.material = _material(true)
	return mesh


func _streak_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.55)
	mesh.material = _material(false)
	return mesh


func _fade_ramp(color: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	return ramp


func _curve(from: float, to: float) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, from))
	curve.add_point(Vector2(1.0, to))
	return curve
