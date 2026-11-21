extends RefCounted
## Authored "drink potion" clip for Rig_Medium (KayKit ships no drink clip: General/Tools/Simulation have none;
## General.Use_Item only nudges the hand and tips the head). Pure bone-rotation keyframes on the real skeleton, upper body only:
## the LEFT arm (the sword stays in the right hand) rises to the mouth, the head tips back and drinks, then everything
## returns to the idle pose. Each key is `idle_pose_at_t0 * Quaternion.from_euler(delta)` (local post-multiply), so the clip
## starts and ends exactly on the idle pose. Arm deltas were solved numerically so handslot.l reaches (0.08, 1.22, 0.45)
## in model space (in front of the face) on the Rogue skeleton.

const LENGTH := 1.5
const RAISE_TIME := 0.4
const DRINK_START := 0.6
const DRINK_END := 1.05
const LOWER_START := 1.2

## Euler (x, y, z) deltas at the fully raised pose.
const RAISED := {
	"upperarm.l": Vector3(-0.1631, -0.2789, -1.1627),
	"lowerarm.l": Vector3(-0.0250, -0.1673, -0.6612),
	"hand.l": Vector3(-0.0312, -0.0993, -0.1648),
}
## Extra deltas while the bottle is tipped: head back (negative X tips the face up), slight chest lean back.
const DRINKING := {
	"head": Vector3(-0.30, 0.0, 0.0),
	"chest": Vector3(-0.07, 0.0, 0.0),
}
## Bottle pose in handslot.l space: +Y points toward the mouth, origin sits 0.12 m below the grip.
const BOTTLE_DIRECTION := Vector3(-0.5918, 0.8025, 0.0767)
const BOTTLE_SCALE := 0.45
const BOTTLE_GRIP := 0.12


static func bottle_transform() -> Transform3D:
	var direction := BOTTLE_DIRECTION.normalized()
	var basis := Basis(Quaternion(Vector3.UP, direction)).scaled(Vector3.ONE * BOTTLE_SCALE)
	return Transform3D(basis, -direction * BOTTLE_GRIP)


## `idle` must be the player's idle clip (tracks "<skeleton_path>:<bone>"). Returns null and fills `errors` if a bone track is missing.
static func build(idle: Animation, skeleton_path: NodePath, errors: PackedStringArray) -> Animation:
	var animation := Animation.new()
	animation.length = LENGTH
	animation.loop_mode = Animation.LOOP_NONE
	var bones: Array[String] = []
	for bone: String in RAISED:
		bones.append(bone)
	for bone: String in DRINKING:
		bones.append(bone)
	for bone in bones:
		var path := NodePath("%s:%s" % [skeleton_path, bone])
		var idle_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if idle_track < 0:
			errors.append("Klip idle tidak punya track rotasi %s untuk klip minum" % path)
			return null
		var base := idle.rotation_track_interpolate(idle_track, 0.0)
		var raised: Vector3 = RAISED.get(bone, Vector3.ZERO)
		var drinking: Vector3 = DRINKING.get(bone, Vector3.ZERO)
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		animation.rotation_track_insert_key(track, 0.0, base)
		animation.rotation_track_insert_key(track, RAISE_TIME, base * Quaternion.from_euler(raised))
		animation.rotation_track_insert_key(track, DRINK_START, base * Quaternion.from_euler(raised + drinking))
		animation.rotation_track_insert_key(track, DRINK_END, base * Quaternion.from_euler(raised + drinking))
		animation.rotation_track_insert_key(track, LOWER_START, base * Quaternion.from_euler(raised))
		animation.rotation_track_insert_key(track, LENGTH, base)
	return animation
