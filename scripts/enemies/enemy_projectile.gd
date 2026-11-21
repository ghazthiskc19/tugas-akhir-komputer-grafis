extends Node3D
## Enemy bolt: straight line, never homing. Every physics step sweeps previous -> next position (ray) plus a
## sphere overlap at the new position against world (layer 1) and player (layer 2). The shooter's own body is
## excluded; allied enemies and every hurtbox are not in the mask, so there is no friendly fire.

const WORLD_MASK := 1
const PLAYER_MASK := 2

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
		var overlaps := space.intersect_shape(_overlap, 1)
		global_position = next
		if not overlaps.is_empty():
			collider = overlaps[0]["collider"] as Node
	if collider != null:
		_impact(collider)


func _impact(collider: Node) -> void:
	set_physics_process(false)
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
