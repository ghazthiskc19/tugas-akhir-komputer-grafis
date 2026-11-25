extends Node3D
## Enemy bolt: straight line, never homing. Every physics step sweeps previous -> next position (ray) plus a
## sphere overlap at the new position against world (layer 1) and player (layer 2). The shooter's own body is
## excluded; allied enemies and every hurtbox are not in the mask, so there is no friendly fire.

const WORLD_MASK := 1
const PLAYER_MASK := 2
const Vfx := preload("res://scripts/vfx/combat_vfx.gd")
const GLOW_TEXTURE := "res://assets/third_party/kenney/particle_pack/light_01.png"
const BOLT_COLOR := Color(1.0, 0.45, 0.12)

## Shared by every bolt: one glow quad and one trail quad/ramp (no per-shot resource creation).
static var _glow_mesh: QuadMesh
static var _trail_mesh: QuadMesh
static var _trail_ramp: Gradient
static var _trail_curve: Curve

var velocity := Vector3.ZERO
var damage := 10
var lifetime := 2.0
var radius := 0.2
var shooter: Object
var shooter_rid: RID

var _age := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _sphere := SphereShape3D.new()
var _overlap := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	add_to_group(&"enemy_projectiles")
	_ray.collision_mask = WORLD_MASK | PLAYER_MASK
	_ray.exclude = [shooter_rid]
	_sphere.radius = radius
	_overlap.shape = _sphere
	_overlap.collision_mask = WORLD_MASK | PLAYER_MASK
	_overlap.exclude = [shooter_rid]
	_build_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		Vfx.burst(self, Vfx.Kind.GLOW, global_position, Vector3.UP, BOLT_COLOR, 0.5)
		queue_free()
		return
	var previous := global_position
	var next := previous + velocity * delta
	var space := get_world_3d().direct_space_state
	_ray.from = previous
	_ray.to = next
	var hit := space.intersect_ray(_ray)
	var collider: Node = null
	if not hit.is_empty():
		global_position = hit["position"]
		collider = hit["collider"] as Node
	else:
		_overlap.transform = Transform3D(Basis.IDENTITY, next)
		var overlaps := space.intersect_shape(_overlap, 8)
		global_position = next
		# A bolt radius may touch player and wall together; cover always wins, independent of query order.
		for overlap in overlaps:
			var candidate := overlap["collider"] as CollisionObject3D
			if candidate != null and (candidate.collision_layer & WORLD_MASK) != 0:
				collider = candidate
				break
			if collider == null:
				collider = overlap["collider"] as Node
	if collider != null:
		_impact(collider)


func _impact(collider: Node) -> void:
	set_physics_process(false)
	Vfx.burst(self, Vfx.Kind.FLASH, global_position, Vector3.UP, BOLT_COLOR.lightened(0.4), 0.9)
	Vfx.burst(self, Vfx.Kind.SPARK, global_position, -velocity, BOLT_COLOR, 1.0)
	Vfx.burst(self, Vfx.Kind.DUST, global_position, Vector3.UP, Color(0.5, 0.45, 0.4, 0.6), 0.45)
	var node := collider
	while node != null:
		if node.has_method("receive_damage"):
			node.receive_damage(damage)
			break
		node = node.get_parent()
	queue_free()


func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius * 0.6
	capsule.height = radius * 4.0
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.1)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	# Capsule's long axis is Y; point it along the travel direction.
	if velocity.length() > 0.01:
		var forward := velocity.normalized()
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var look := Basis.looking_at(forward, up)
		mesh.basis = look * Basis(Vector3.RIGHT, PI / 2.0)
	add_child(_make_glow())
	add_child(_make_trail())


static func _shared_quad(size: float, billboard: BaseMaterial3D.BillboardMode) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = Vfx.FX_PRIORITY
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(GLOW_TEXTURE)
	material.billboard_mode = billboard
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	quad.material = material
	return quad


func _make_glow() -> MeshInstance3D:
	if _glow_mesh == null:
		_glow_mesh = _shared_quad(1.0, BaseMaterial3D.BILLBOARD_ENABLED)
		(_glow_mesh.material as StandardMaterial3D).albedo_color = Color(BOLT_COLOR, 0.9)
	var glow := MeshInstance3D.new()
	glow.mesh = _glow_mesh
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.scale = Vector3.ONE * (radius * 5.0)
	return glow


## World-space ember trail: the emitter stays at the bolt while particles keep their spawn positions behind it.
func _make_trail() -> CPUParticles3D:
	if _trail_mesh == null:
		_trail_mesh = _shared_quad(0.32, BaseMaterial3D.BILLBOARD_PARTICLES)
		_trail_ramp = Gradient.new()
		_trail_ramp.set_color(0, Color(1.0, 0.8, 0.45, 0.9))
		_trail_ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		_trail_curve = Curve.new()
		_trail_curve.add_point(Vector2(0.0, 1.0))
		_trail_curve.add_point(Vector2(1.0, 0.1))
	var trail := CPUParticles3D.new()
	trail.amount = 14
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.mesh = _trail_mesh
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = radius * 0.5
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3.ZERO
	trail.color_ramp = _trail_ramp
	trail.scale_amount_curve = _trail_curve
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trail
