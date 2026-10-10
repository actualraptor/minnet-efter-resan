class_name HoverPose
extends SkeletonModifier3D
## Legs for hovering. Replaces whatever the standing/walking animation does to
## the legs with a suspended, relaxed pose (knees softly bent, toes pointed,
## one leg a little ahead), so the lift never reads as "a standing animation
## raised off the ground". The legs trail slightly behind acceleration and
## drift gently while idle.

var amount := 0.0                       # 0 = animation untouched, 1 = hover legs
var velocity := Vector3.ZERO            # horizontal, in the model's frame (x her left, z forward)

var _bones := {}
var _rest := {}
var _t := 0.0
var _trail := Vector2.ZERO


func setup() -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	for s in ["Left", "Right"]:
		for part in ["UpperLeg", "LowerLeg", "Foot"]:
			var i := sk.find_bone(s + part)
			if i < 0:
				return false
			_bones[s + part] = i
			_rest[s + part] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	return true


func _process_modification_with_delta(delta: float) -> void:
	if amount <= 0.001 or _bones.is_empty():
		return
	var sk := get_skeleton()
	_t += delta
	# Legs lag the body: forward travel trails them back, sideways drift lifts
	# them out the opposite way.
	var want := Vector2(clampf(velocity.z, -4.0, 4.0), clampf(velocity.x, -3.0, 3.0))
	_trail = _trail.lerp(want, 1.0 - exp(-4.5 * delta))
	var sway := sin(_t * 1.6) * 2.0
	var bob2 := sin(_t * 2.3 + 1.0) * 1.5
	for side in ["Left", "Right"]:
		var sgn := 1.0 if side == "Left" else -1.0
		var lead := -7.0 if side == "Left" else 6.0            # one leg a little ahead
		var thigh_pitch := lead + _trail.x * 4.5 + sway * sgn
		var thigh_roll := sgn * (2.5 + clampf(absf(_trail.y), 0.0, 3.0)) - _trail.y * 1.5
		var knee := 20.0 + clampf(absf(_trail.x), 0.0, 4.0) * 3.0 + (4.0 if side == "Right" else 0.0) + bob2
		var foot := 30.0 + _trail.x * 1.5
		_apply(sk, side + "UpperLeg", Vector3(deg_to_rad(thigh_pitch), 0.0, deg_to_rad(thigh_roll)))
		_apply(sk, side + "LowerLeg", Vector3(deg_to_rad(knee), 0.0, 0.0))
		_apply(sk, side + "Foot", Vector3(deg_to_rad(foot), 0.0, 0.0))


func _apply(sk: Skeleton3D, bone: String, euler: Vector3) -> void:
	var i: int = _bones[bone]
	var target: Quaternion = (_rest[bone] as Quaternion) * Quaternion.from_euler(euler)
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(target, amount))
