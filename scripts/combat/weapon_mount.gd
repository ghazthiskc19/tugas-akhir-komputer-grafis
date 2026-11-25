class_name WeaponMount
extends Node
## Attaches a KayKit weapon to a hand bone when the scene starts. Do NOT bake the BoneAttachment3D into the .tscn:
## nodes parented under an imported GLB's Skeleton3D were silently missing from the exported (binary) packed scenes,
## so the player and every guard walked around unarmed in the exe while the editor looked fine.

## Path (relative to this node's parent) of the node that contains the Skeleton3D.
@export var model_path: NodePath = ^"Model"
@export var weapon: PackedScene
@export var bone_name := "handslot.r"
@export var weapon_scale := 1.0


func _ready() -> void:
	var model := get_parent().get_node_or_null(model_path)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D if model != null else null
	if skeleton == null or weapon == null or skeleton.find_bone(bone_name) < 0:
		push_error("WeaponMount %s: Skeleton3D/bone/weapon tidak ditemukan" % get_path())
		return
	var slot := BoneAttachment3D.new()
	slot.name = "WeaponSlot"
	slot.bone_name = bone_name
	skeleton.add_child(slot)
	var instance := weapon.instantiate() as Node3D
	instance.name = "Weapon"
	instance.scale = Vector3.ONE * weapon_scale
	slot.add_child(instance)
