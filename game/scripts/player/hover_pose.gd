class_name HoverPose
extends SkeletonModifier3D
## The body in the air. Replaces whatever the standing/walking animation does to
## the legs with a suspended, relaxed pose (knees softly bent, toes pointed, one
## leg a little ahead) that straightens and trails as she picks up speed, and
## counter-bends the spine, neck and head against the forward lean so she keeps
## looking where she is going. The legs lag acceleration and drift gently while
## idle.

var amount := 0.0                       # 0 = animation untouched, 1 = hover legs
var velocity := Vector3.ZERO            # horizontal, in the model's frame (x her left, z forward)
var body_pitch := 0.0                   # forward lean of the whole body (radians)
var speed01 := 0.0                      # 0..1 of full boost speed
var climb := 0.0                        # vertical speed (m/s, + up)

var _bones := {}
var _rest := {}
var _upper := {}
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
	for n in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
		var j := sk.find_bone(n)
		if j >= 0:
			_upper[n] = j
	return true


func _process_modification_with_delta(delta: float) -> void:
	if amount <= 0.001 or _bones.is_empty():
		return
	var sk := get_skeleton()
	_t += delta
	var sp := clampf(speed01, 0.0, 1.0)
	# Legs lag the body: forward travel trails them back, sideways drift lifts
	# them out the opposite way.
	var want := Vector2(clampf(velocity.z, -8.0, 8.0), clampf(velocity.x, -3.0, 3.0))
	_trail = _trail.lerp(want, 1.0 - exp(-4.5 * delta))
	var calm := 1.0 - sp
	var sway := sin(_t * 1.6) * 2.0 * calm
	var bob2 := sin(_t * 2.3 + 1.0) * 1.5 * calm
	for side in ["Left", "Right"]:
		var sgn := 1.0 if side == "Left" else -1.0
		var lead := (-7.0 if side == "Left" else 6.0) * calm       # one leg a little ahead
		# While the body is flat the legs trail straight behind along its axis; the
		# thigh keeps a slight extension and the knee almost straightens.
		var thigh_pitch := lead + _trail.x * 4.5 * (1.0 - 0.55 * sp) + sway * sgn - 9.0 * sp
		var thigh_roll := sgn * (2.5 + clampf(absf(_trail.y), 0.0, 3.0)) * (1.0 - 0.5 * sp) - _trail.y * 1.5
		var knee := lerpf(20.0, 6.0, sp) + (4.0 if side == "Right" else 0.0) * calm + bob2 + clampf(climb, 0.0, 4.0) * 1.5
		var foot := lerpf(30.0, 52.0, sp) + _trail.x * 1.0 * calm
		_apply(sk, side + "UpperLeg", Vector3(deg_to_rad(thigh_pitch), 0.0, deg_to_rad(thigh_roll)))
		_apply(sk, side + "LowerLeg", Vector3(deg_to_rad(knee), 0.0, 0.0))
		_apply(sk, side + "Foot", Vector3(deg_to_rad(foot), 0.0, 0.0))
	# Counter the forward lean: arch the back a little and lift neck and head so
	# the gaze stays forward (the look-at modifiers finish the job).
	var th := body_pitch * amount
	if absf(th) > 0.01:
		_bend(sk, "Spine", -th * 0.08)
		_bend(sk, "Chest", -th * 0.10)
		_bend(sk, "UpperChest", -th * 0.10)
		_bend(sk, "Neck", -th * 0.16)
		_bend(sk, "Head", -th * 0.12)


func _bend(sk: Skeleton3D, bone: String, angle: float) -> void:
	if not _upper.has(bone):
		return
	var i: int = _upper[bone]
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, angle))


func _apply(sk: Skeleton3D, bone: String, euler: Vector3) -> void:
	var i: int = _bones[bone]
	var target: Quaternion = (_rest[bone] as Quaternion) * Quaternion.from_euler(euler)
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(target, amount))
