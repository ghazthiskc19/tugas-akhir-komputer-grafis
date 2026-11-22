extends RefCounted
## Authored animation library for the Penjaga Gerbang (rock_golem.glb, a skinned T-pose rig that ships with NO clips).
## Every clip is bone-rotation keyframes built here on the real skeleton, plus Pivot position/rotation tracks for body
## drop/lean (the legs are separate root bones, so the torso is lowered by moving the Pivot).
##
## Pose language (degrees, skeleton space, golem faces +Z, its LEFT arm is +X): a bone delta is
## q = Ry(y) * Rx(x) * Rz(z) (Z applied first). Arm hanging = Rz(-75) on the left upper arm, Rz(+75) on the right; raising an
## arm = bigger z; forward swing = Ry; flexing a hanging arm forward = Rx negative. Left/right poses are mirrored
## automatically (x kept, y and z negated). Legs: thigh Rx(-a) moves the knee forward, shin Rx(+2a), feet are kept flat.
## Deltas are cumulative down each chain (a child inherits its parent delta), and converted to the local bone rotation:
##   local = (Dp * Gp)^-1 * (d * Dp * Gb)   with G = global rest basis and Dp the parent's cumulative delta.
## All clips write ALL bone tracks, so switching clips never leaves a stale pose behind.

const MODEL_SCALE := 0.45
const LEG_UPPER := 2.82
const LEG_LOWER := 3.39
const BONES := {
	"pelvis": "Bone", "head": "Bone.010",
	"uL": "Bone.003", "fL": "Bone.005", "wL": "Bone.007",
	"uR": "Bone.004", "fR": "Bone.006", "wR": "Bone.008",
	"tL": "Bone.024", "sL": "Bone.026", "bL": "Bone.030",
	"tR": "Bone.025", "sR": "Bone.027", "bR": "Bone.031",
}
## Pose keys that exist in a stored pose; mirrored "A" keys expand to both sides in _expand().
const WALK := &"walk"
const IDLE := &"idle"
const DORMANT := &"dormant"
const WAKE := &"wake"
const ROAR := &"roar"
const SWEEP_WINDUP := &"sweep_windup"
const SWEEP_STRIKE := &"sweep_strike"
const SWEEP_RECOVER := &"sweep_recover"
const SLAM_WINDUP := &"slam_windup"
const SLAM_STRIKE := &"slam_strike"
const SLAM_RECOVER := &"slam_recover"
const CHARGE_WINDUP := &"charge_windup"
const CHARGE_RUN := &"charge_run"
const CHARGE_RECOVER := &"charge_recover"
const DEATH := &"death"


## Pose building blocks -----------------------------------------------------------------------------------------------

## Crouch of `a` degrees at the thighs (knees forward, shins back, feet flat); lowers the Pivot so the soles stay on the ground.
static func crouch(a: float) -> Dictionary:
	var drop := (LEG_UPPER + LEG_LOWER) * (1.0 - cos(deg_to_rad(a))) * MODEL_SCALE
	return {"tA": Vector3(-a, 0.0, 0.0), "sA": Vector3(2.0 * a, 0.0, 0.0), "pivot": Vector3(0.0, -drop, 0.0)}


static func merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate()
	for key in extra:
		result[key] = extra[key]
	return result


static func _idle_pose(breath := 0.0) -> Dictionary:
	return {
		"pelvis": Vector3(3.0 + breath, 0.0, 0.0), "head": Vector3(-3.0 - breath, 0.0, 0.0),
		"uA": Vector3(-6.0, 0.0, -74.0 + breath), "fA": Vector3(-22.0, 0.0, 0.0), "wA": Vector3(-8.0, 0.0, 0.0),
	}


static func _dormant_pose(breath := 0.0) -> Dictionary:
	return merge(crouch(58.0), {
		"pelvis": Vector3(34.0 + breath, 0.0, 0.0), "head": Vector3(38.0 + breath, 0.0, 0.0),
		"uA": Vector3(-30.0, 0.0, -66.0), "fA": Vector3(-34.0, 0.0, 0.0), "wA": Vector3(-20.0, 0.0, 0.0),
	})


static func _sweep_windup_pose() -> Dictionary:
	return merge(crouch(12.0), {
		"pelvis": Vector3(4.0, 34.0, 0.0), "head": Vector3(-2.0, -22.0, 0.0),
		"uL": Vector3(0.0, 92.0, -14.0), "fL": Vector3(0.0, 8.0, 0.0), "wL": Vector3(0.0, 0.0, 0.0),
		"uR": Vector3(-30.0, 0.0, 62.0), "fR": Vector3(-55.0, 0.0, 0.0), "wR": Vector3(-10.0, 0.0, 0.0),
	})


static func _sweep_strike_pose() -> Dictionary:
	return merge(crouch(14.0), {
		"pelvis": Vector3(8.0, -42.0, 0.0), "head": Vector3(0.0, 24.0, 0.0),
		"uL": Vector3(0.0, -100.0, -8.0), "fL": Vector3(0.0, -6.0, 0.0), "wL": Vector3(0.0, 0.0, 0.0),
		"uR": Vector3(-35.0, 0.0, 58.0), "fR": Vector3(-60.0, 0.0, 0.0), "wR": Vector3(-10.0, 0.0, 0.0),
	})


static func _slam_windup_pose() -> Dictionary:
	return merge(crouch(10.0), {
		"pelvis": Vector3(-20.0, 0.0, 0.0), "head": Vector3(-14.0, 0.0, 0.0),
		"uA": Vector3(-22.0, 0.0, 98.0), "fA": Vector3(-28.0, 0.0, 0.0), "wA": Vector3(-10.0, 0.0, 0.0),
	})


static func _slam_strike_pose() -> Dictionary:
	return merge(crouch(34.0), {
		"pelvis": Vector3(44.0, 0.0, 0.0), "head": Vector3(-26.0, 0.0, 0.0),
		"uA": Vector3(-62.0, 0.0, -84.0), "fA": Vector3(-18.0, 0.0, 0.0), "wA": Vector3(-6.0, 0.0, 0.0),
	})


static func _charge_windup_pose() -> Dictionary:
	return merge(crouch(46.0), {
		"pelvis": Vector3(34.0, 0.0, 0.0), "head": Vector3(-34.0, 0.0, 0.0),
		"uA": Vector3(48.0, 0.0, -48.0), "fA": Vector3(-10.0, 0.0, 0.0), "wA": Vector3(0.0, 0.0, 0.0),
	})


## One stride sample of a gait. phase 0..1; the left and right legs are opposite.
static func _gait_pose(phase: float, stride: float, knee: float, base_crouch: float, lean: float, arm_swing: float, head_level: float) -> Dictionary:
	var s := sin(phase * TAU)
	var c := cos(phase * TAU)
	var pose := crouch(base_crouch)
	var left_lift := maxf(0.0, c) * knee
	var right_lift := maxf(0.0, -c) * knee
	pose["tL"] = Vector3(-base_crouch - stride * s, 0.0, 0.0)
	pose["tR"] = Vector3(-base_crouch + stride * s, 0.0, 0.0)
	pose["sL"] = Vector3(2.0 * base_crouch + left_lift, 0.0, 0.0)
	pose["sR"] = Vector3(2.0 * base_crouch + right_lift, 0.0, 0.0)
	pose.erase("tA")
	pose.erase("sA")
	var bob := absf(c) * 0.12
	pose["pivot"] = Vector3(0.0, (pose["pivot"] as Vector3).y + bob - 0.06, 0.0)
	pose["pelvis"] = Vector3(lean, 0.0, 0.0)
	pose["head"] = Vector3(head_level, 0.0, 0.0)
	pose["uL"] = Vector3(arm_swing * s - 6.0, 0.0, -70.0)
	pose["uR"] = Vector3(-arm_swing * s - 6.0, 0.0, 70.0)
	pose["fA"] = Vector3(-35.0, 0.0, 0.0)
	pose["wA"] = Vector3(-10.0, 0.0, 0.0)
	return pose


## Clip definitions -----------------------------------------------------------------------------------------------------

static func clips() -> Dictionary:
	var idle_a := _idle_pose(0.0)
	var idle_b := _idle_pose(2.2)
	var dormant_a := _dormant_pose(0.0)
	var dormant_b := _dormant_pose(2.5)
	var out := {}
	out[IDLE] = {"length": 3.2, "loop": true, "keys": [[0.0, idle_a], [1.6, idle_b], [3.2, idle_a]]}
	out[DORMANT] = {"length": 4.0, "loop": true, "keys": [[0.0, dormant_a], [2.0, dormant_b], [4.0, dormant_a]]}
	out[WAKE] = {"length": 3.6, "loop": false, "keys": [
		[0.0, dormant_a],
		[0.35, merge(dormant_a, {"head": Vector3(34.0, 6.0, 0.0), "wA": Vector3(-34.0, 0.0, 0.0)})],
		[0.7, merge(dormant_a, {"head": Vector3(44.0, -8.0, 0.0), "uA": Vector3(-38.0, 0.0, -60.0)})],
		[1.2, merge(_dormant_pose(), {"head": Vector3(24.0, 0.0, 0.0), "pelvis": Vector3(28.0, 0.0, 0.0)})],
		[1.9, merge(crouch(24.0), {"pelvis": Vector3(16.0, 0.0, 0.0), "head": Vector3(8.0, 0.0, 0.0),
			"uA": Vector3(-20.0, 0.0, -66.0), "fA": Vector3(-30.0, 0.0, 0.0), "wA": Vector3(-14.0, 0.0, 0.0)})],
		[2.5, merge(crouch(6.0), {"pelvis": Vector3(-20.0, 0.0, 0.0), "head": Vector3(-34.0, 0.0, 0.0),
			"uA": Vector3(-6.0, 0.0, -28.0), "fA": Vector3(-46.0, 0.0, 0.0), "wA": Vector3(-20.0, 0.0, 0.0)})],
		[2.85, merge(crouch(4.0), {"pelvis": Vector3(-24.0, 0.0, 0.0), "head": Vector3(-38.0, 0.0, 0.0),
			"uA": Vector3(-6.0, 0.0, -18.0), "fA": Vector3(-52.0, 0.0, 0.0), "wA": Vector3(-24.0, 0.0, 0.0)})],
		[3.6, idle_a],
	]}
	out[ROAR] = {"length": 1.1, "loop": false, "keys": [
		[0.0, idle_a],
		[0.3, merge(crouch(10.0), {"pelvis": Vector3(14.0, 0.0, 0.0), "head": Vector3(14.0, 0.0, 0.0),
			"uA": Vector3(-20.0, 0.0, -56.0), "fA": Vector3(-40.0, 0.0, 0.0), "wA": Vector3(-14.0, 0.0, 0.0)})],
		[0.62, merge(crouch(4.0), {"pelvis": Vector3(-24.0, 0.0, 0.0), "head": Vector3(-40.0, 0.0, 0.0),
			"uA": Vector3(-6.0, 0.0, -14.0), "fA": Vector3(-54.0, 0.0, 0.0), "wA": Vector3(-26.0, 0.0, 0.0)})],
		[0.85, merge(crouch(4.0), {"pelvis": Vector3(-26.0, 0.0, 0.0), "head": Vector3(-42.0, 0.0, 0.0),
			"uA": Vector3(-6.0, 0.0, -12.0), "fA": Vector3(-56.0, 0.0, 0.0), "wA": Vector3(-26.0, 0.0, 0.0)})],
		[1.1, idle_a],
	]}
	var walk_keys := []
	for i in 9:
		walk_keys.append([1.2 * i / 8.0, _gait_pose(float(i) / 8.0, 26.0, 36.0, 6.0, 6.0, 18.0, -6.0)])
	out[WALK] = {"length": 1.2, "loop": true, "keys": walk_keys}
	out[SWEEP_WINDUP] = {"length": 1.0, "loop": false, "keys": [
		[0.0, idle_a],
		[0.45, merge(_sweep_windup_pose(), {"uL": Vector3(0.0, 40.0, -40.0)})],
		[1.0, _sweep_windup_pose()],
	]}
	out[SWEEP_STRIKE] = {"length": 0.3, "loop": false, "keys": [
		[0.0, _sweep_windup_pose()],
		[0.18, merge(_sweep_strike_pose(), {"uL": Vector3(0.0, -35.0, -8.0), "pelvis": Vector3(6.0, -14.0, 0.0)})],
		[0.3, _sweep_strike_pose()],
	]}
	out[SWEEP_RECOVER] = {"length": 1.0, "loop": false, "keys": [
		[0.0, _sweep_strike_pose()],
		[0.35, merge(_sweep_strike_pose(), {"pelvis": Vector3(10.0, -36.0, 0.0), "uL": Vector3(0.0, -96.0, -12.0)})],
		[1.0, idle_a],
	]}
	out[SLAM_WINDUP] = {"length": 1.0, "loop": false, "keys": [
		[0.0, idle_a],
		[0.5, merge(crouch(18.0), {"pelvis": Vector3(14.0, 0.0, 0.0), "head": Vector3(8.0, 0.0, 0.0),
			"uA": Vector3(-14.0, 0.0, 20.0), "fA": Vector3(-50.0, 0.0, 0.0), "wA": Vector3(-8.0, 0.0, 0.0)})],
		[1.0, _slam_windup_pose()],
	]}
	out[SLAM_STRIKE] = {"length": 0.25, "loop": false, "keys": [
		[0.0, _slam_windup_pose()],
		[0.12, merge(_slam_strike_pose(), {"uA": Vector3(-30.0, 0.0, 20.0), "pelvis": Vector3(10.0, 0.0, 0.0)})],
		[0.25, _slam_strike_pose()],
	]}
	var slam_rest := _slam_strike_pose()
	out[SLAM_RECOVER] = {"length": 2.4, "loop": false, "keys": [
		[0.0, slam_rest],
		[0.15, merge(slam_rest, {"pelvis": Vector3(40.0, 0.0, 0.0), "uA": Vector3(-58.0, 0.0, -86.0)})],
		[0.3, slam_rest],
		[1.6, merge(slam_rest, {"pelvis": Vector3(46.0, 0.0, 0.0), "head": Vector3(-28.0, 0.0, 0.0)})],
		[2.4, idle_a],
	]}
	var charge_wind := _charge_windup_pose()
	out[CHARGE_WINDUP] = {"length": 1.0, "loop": false, "keys": [
		[0.0, idle_a],
		[0.5, merge(charge_wind, {"pelvis": Vector3(18.0, 0.0, 0.0), "uA": Vector3(20.0, 0.0, -60.0)})],
		[0.85, merge(charge_wind, {"pelvis": Vector3(36.0, 0.0, 0.0)})],
		[1.0, charge_wind],
	]}
	var run_keys := []
	for i in 9:
		run_keys.append([0.56 * i / 8.0, _gait_pose(float(i) / 8.0, 42.0, 70.0, 22.0, 30.0, 48.0, -30.0)])
	out[CHARGE_RUN] = {"length": 0.56, "loop": true, "keys": run_keys}
	out[CHARGE_RECOVER] = {"length": 1.0, "loop": false, "keys": [
		[0.0, _gait_pose(0.0, 30.0, 40.0, 22.0, 30.0, 30.0, -30.0)],
		[0.3, merge(crouch(28.0), {"pelvis": Vector3(36.0, 0.0, 0.0), "head": Vector3(10.0, 0.0, 0.0),
			"uA": Vector3(20.0, 0.0, -50.0), "fA": Vector3(-30.0, 0.0, 0.0)})],
		[0.7, merge(crouch(26.0), {"pelvis": Vector3(38.0, 0.0, 0.0), "head": Vector3(14.0, 0.0, 0.0),
			"uA": Vector3(-10.0, 0.0, -66.0), "fA": Vector3(-32.0, 0.0, 0.0)})],
		[1.0, idle_a],
	]}
	out[DEATH] = {"length": 3.4, "loop": false, "keys": [
		[0.0, idle_a],
		[0.45, merge(crouch(22.0), {"pelvis": Vector3(14.0, 0.0, 0.0), "head": Vector3(26.0, 0.0, 0.0),
			"uA": Vector3(-16.0, 0.0, -50.0), "fA": Vector3(-24.0, 0.0, 0.0)})],
		[1.2, merge(crouch(66.0), {"pelvis": Vector3(36.0, 0.0, 0.0), "head": Vector3(46.0, 0.0, 0.0),
			"uA": Vector3(10.0, 0.0, -80.0), "fA": Vector3(-14.0, 0.0, 0.0)})],
		[1.9, merge(crouch(54.0), {"pelvis": Vector3(14.0, 0.0, 0.0), "head": Vector3(28.0, 0.0, 0.0),
			"uA": Vector3(0.0, 0.0, -90.0), "fA": Vector3(-6.0, 0.0, 0.0),
			"pivot_rot": Vector3(-18.0, 0.0, 0.0)})],
		[2.7, merge(crouch(24.0), {"pelvis": Vector3(-8.0, 0.0, 0.0), "head": Vector3(-20.0, 0.0, 0.0),
			"uA": Vector3(0.0, 0.0, -32.0), "fA": Vector3(0.0, 0.0, 0.0), "wA": Vector3(0.0, 0.0, 0.0),
			"pivot_rot": Vector3(-72.0, 0.0, 0.0), "pivot": Vector3(0.0, 0.7, -0.2)})],
		[3.4, merge(crouch(8.0), {"pelvis": Vector3(-4.0, 0.0, 0.0), "head": Vector3(-14.0, 0.0, 0.0),
			"uA": Vector3(0.0, 0.0, -22.0), "fA": Vector3(0.0, 0.0, 0.0), "wA": Vector3(0.0, 0.0, 0.0),
			"pivot_rot": Vector3(-87.0, 0.0, 0.0), "pivot": Vector3(0.0, 0.55, -0.1)})],
	]}
	return out


## Library construction ---------------------------------------------------------------------------------------------

## Expands mirrored/shared keys ("uA", "tA", ...) to explicit left/right deltas (right = x kept, y and z negated for arms/head;
## thighs/shins identical on both sides) and derives flat feet from thigh + shin when no foot pose is given.
static func _expand(pose: Dictionary) -> Dictionary:
	var out := {}
	for key: String in pose:
		var value = pose[key]
		if key.length() == 2 and key.ends_with("A"):
			out[key.substr(0, 1) + "L"] = value
			var v := value as Vector3
			if key.begins_with("t") or key.begins_with("s") or key.begins_with("b"):
				out[key.substr(0, 1) + "R"] = v
			else:
				out[key.substr(0, 1) + "R"] = Vector3(v.x, -v.y, -v.z)
		else:
			out[key] = value
	for side in ["L", "R"]:
		if not out.has("b" + side):
			var thigh: Vector3 = out.get("t" + side, Vector3.ZERO)
			var shin: Vector3 = out.get("s" + side, Vector3.ZERO)
			out["b" + side] = Vector3(-(thigh.x + shin.x), 0.0, 0.0)
	return out


static func _quat(euler_deg: Vector3) -> Quaternion:
	return (Quaternion(Vector3.UP, deg_to_rad(euler_deg.y)) * Quaternion(Vector3.RIGHT, deg_to_rad(euler_deg.x))
		* Quaternion(Vector3.BACK, deg_to_rad(euler_deg.z)))


## `skeleton_path`/`pivot_path` are relative to the AnimationPlayer root. Returns null and fills `errors` on a missing bone.
static func build_library(skeleton: Skeleton3D, skeleton_path: NodePath, pivot_path: NodePath, errors: PackedStringArray) -> AnimationLibrary:
	var bone_index := {}
	for key: String in BONES:
		var index := skeleton.find_bone(BONES[key])
		if index < 0:
			errors.append("Golem: bone '%s' tidak ada" % BONES[key])
			return null
		bone_index[key] = index
	var animated_by_index := {}
	for key: String in bone_index:
		animated_by_index[bone_index[key]] = key
	var ordered: Array = bone_index.keys()
	var library := AnimationLibrary.new()
	var definitions := clips()
	for clip_name: StringName in definitions:
		var definition: Dictionary = definitions[clip_name]
		var animation := Animation.new()
		animation.length = definition["length"]
		animation.loop_mode = Animation.LOOP_LINEAR if definition["loop"] else Animation.LOOP_NONE
		var tracks := {}
		for key: String in ordered:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, BONES[key]]))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			tracks[key] = track
		var pivot_pos := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(pivot_pos, pivot_path)
		var pivot_rot := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(pivot_rot, pivot_path)
		for entry: Array in definition["keys"]:
			var time: float = entry[0]
			var pose := _expand(entry[1])
			var cumulative: Array[Quaternion] = []
			cumulative.resize(skeleton.get_bone_count())
			for index in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(index)
				var parent_delta := cumulative[parent] if parent >= 0 else Quaternion.IDENTITY
				var parent_global := skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
				var key: String = animated_by_index.get(index, "")
				var delta := _quat(pose.get(key, Vector3.ZERO)) if key != "" else Quaternion.IDENTITY
				var total := delta * parent_delta
				cumulative[index] = total
				if key == "":
					continue
				var own_global := skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
				var local := ((parent_delta * parent_global).inverse() * (total * own_global)).normalized()
				animation.rotation_track_insert_key(tracks[key], time, local)
			var pos: Vector3 = pose.get("pivot", Vector3.ZERO)
			animation.position_track_insert_key(pivot_pos, time, pos)
			animation.rotation_track_insert_key(pivot_rot, time, _quat(pose.get("pivot_rot", Vector3.ZERO)))
		library.add_animation(clip_name, animation)
	return library
