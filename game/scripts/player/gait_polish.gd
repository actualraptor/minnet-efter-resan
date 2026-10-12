class_name GaitPolish
extends SkeletonModifier3D
## Procedural finishing layer for the walk and run, applied after the animation
## and before the foot grounder (so the grounder keeps the feet planted):
##   * pelvic tilt: the pelvis drops a touch on the swing side and the chest
##     counter-rolls, so the torso reads as carried over the stance leg instead
##     of sliding along rigid;
##   * a trace of lateral weight shift (spine lean toward the stance foot);
##   * head stabilisation: neck and head cancel most of the torso's roll so the
##     gaze stays level;
##   * a slow breath so a standing pose is never a statue.
## The stance side comes from the animated feet themselves (the lower foot), so
## no gait phase has to be tracked and it stays in step with any clip.

var amount := 0.0         # 0..1, set by the player: ground locomotion only
var speed01 := 0.0        # 0 = still, 1 = walk, 2 = run (ground speed / walk speed)
var staff_in_hand := false
## Forward acceleration (m/s^2, negative = braking) and yaw rate (rad/s): the body
## answers them a beat before the legs do (push-off lean, braking settle, torso
## leading a turn).
var accel := 0.0
var turn := 0.0

var _accel_s := 0.0
var _turn_s := 0.0

var _b := {}
var _s := 0.0             # smoothed stance signal, -1 (left stance) .. +1 (right stance)
var _t := 0.0


func setup() -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	for n in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftFoot", "RightFoot"]:
		var i := sk.find_bone(n)
		if i < 0:
			return false
		_b[n] = i
	return true


func _process_modification_with_delta(delta: float) -> void:
	if amount <= 0.001 or _b.is_empty():
		return
	var sk := get_skeleton()
	_t += delta
	var lf := sk.get_bone_global_pose(_b["LeftFoot"]).origin.y
	var rf := sk.get_bone_global_pose(_b["RightFoot"]).origin.y
	# Positive when the left foot is the higher one (swing) = right foot stance.
	var raw := clampf((lf - rf) / 0.12, -1.0, 1.0)
	_s = lerpf(_s, raw, 1.0 - exp(-14.0 * delta))
	var mv := clampf(speed01, 0.0, 1.0) * (1.0 - 0.25 * clampf(speed01 - 1.0, 0.0, 1.0))
	var k := amount * mv
	var d2r := PI / 180.0
	# Rolls are about the body's forward axis (local Z; the VRoid rest bones are
	# axis-aligned, facing +Z with her left at +X).
	var hips_roll := -_s * 2.8 * k * d2r              # swing-side hip drops
	var chest_roll := _s * 2.0 * k * d2r              # torso stays carried upright
	var lean := _s * 0.7 * k * d2r                    # a trace of weight shift
	_roll(sk, "Hips", hips_roll)
	_roll(sk, "Spine", chest_roll * 0.5 + lean)
	_roll(sk, "Chest", chest_roll * 0.5)
	# Head stays level: cancel most of what the pelvis and torso rolled.
	var carried := hips_roll + chest_roll + lean
	_roll(sk, "Neck", -carried * 0.45)
	_roll(sk, "Head", -carried * 0.4)
	# Intent: the torso answers acceleration and turning before the legs do.
	_accel_s = lerpf(_accel_s, clampf(accel, -5.0, 4.0), 1.0 - exp(-7.0 * delta))
	_turn_s = lerpf(_turn_s, clampf(turn, -5.0, 5.0), 1.0 - exp(-6.0 * delta))
	var gait_on := amount * clampf(speed01 + 0.3, 0.0, 1.0)
	if _accel_s > 0.0:
		_pitch(sk, "Spine", _accel_s * 0.9 * d2r * gait_on)      # push off: chest drives forward
		_pitch(sk, "Chest", _accel_s * 0.7 * d2r * gait_on)
		_pitch(sk, "Neck", -_accel_s * 0.8 * d2r * gait_on)       # the gaze stays up
		_pitch(sk, "Head", -_accel_s * 0.6 * d2r * gait_on)
	else:
		var brake_k := clampf(-_accel_s / 4.6, 0.0, 1.0) * gait_on
		_pitch(sk, "Spine", -brake_k * 3.0 * d2r)                  # weight settles back
		_pitch(sk, "Chest", -brake_k * 2.5 * d2r)
		_pitch(sk, "Hips", brake_k * 2.0 * d2r)                    # pelvis tucks under
	# Torso leads into a turn: the chest and shoulders yaw ahead of the pelvis.
	var lead := _turn_s * 1.6 * d2r * gait_on
	_yaw(sk, "Spine", lead * 0.4)
	_yaw(sk, "Chest", lead * 0.6)
	_yaw(sk, "Neck", lead * 0.5)
	_yaw(sk, "Head", lead * 0.5)
	# Breath: a slow swell of the upper chest, strongest standing still.
	var breath := sin(_t * 1.35) * 0.55 * d2r * amount * (1.0 - 0.7 * clampf(speed01, 0.0, 1.0))
	_pitch(sk, "UpperChest", breath)
	_pitch(sk, "Neck", -breath * 0.5)


func _roll(sk: Skeleton3D, bone: String, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var i: int = _b[bone]
	sk.set_bone_pose_rotation(i, Quaternion(Vector3.BACK, angle) * sk.get_bone_pose_rotation(i))


func _yaw(sk: Skeleton3D, bone: String, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var i: int = _b[bone]
	sk.set_bone_pose_rotation(i, Quaternion(Vector3.UP, angle) * sk.get_bone_pose_rotation(i))


func _pitch(sk: Skeleton3D, bone: String, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var i: int = _b[bone]
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, angle))
