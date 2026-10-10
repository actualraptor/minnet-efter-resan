class_name StaffGrip
extends SkeletonModifier3D
## Solves Freyja's arms to the staff while a StaffRig performance is active:
##   1. torso posture (lean/twist keyed in the clip) is added to spine + chest;
##   2. the right arm is solved to the rear grip, the left to the front grip (or
##      to the free-hand target when the left hand lets go);
##   3. each hand is oriented so its grip axis lies along the shaft (thumb toward
##      the head) and the fist, not the wrist, sits on the shaft.
## Analytic two-bone IK with an elbow pole, in skeleton space. Everything is
## blended by the rig's weight, so hands reach and release deliberately.

@export var roll_right_deg := 0.0
@export var roll_left_deg := 0.0

## The VRoid hand bone's local frame (both hands, T-pose rest): +Y runs along the
## fingers, X along the knuckle line (right hand: index side +X, left hand: -X),
## +Z is the palm normal. Wrist -> centre of the curled fist, in that frame: out
## along the fingers to the knuckles and a little to the palm side.
const FIST_R := Vector3(-0.004, 0.064, 0.026)
const FIST_L := Vector3(0.004, 0.064, 0.026)
## Left hand T-pose rest basis in model space (x = -Z, y = +X, z = down), used to
## author the free hand's orientation as euler offsets from "arm out, palm down".
const REST_L := Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))

var rig: StaffRig
var reach_error := {"R": 0.0, "L": 0.0}   # metres, last frame (diagnostic)
var _arm := {}
var _spine := -1
var _chest := -1


func setup(staff_rig: StaffRig) -> bool:
	rig = staff_rig
	var sk := get_skeleton()
	if sk == null:
		return false
	for s in ["L", "R"]:
		var side := "Left" if s == "L" else "Right"
		var ids := [sk.find_bone(side + "UpperArm"), sk.find_bone(side + "LowerArm"), sk.find_bone(side + "Hand")]
		if ids.has(-1):
			return false
		_arm[s] = ids
	_spine = sk.find_bone("Spine")
	_chest = sk.find_bone("Chest")
	return true


func _process_modification_with_delta(_delta: float) -> void:
	if rig == null or not rig.is_active() or rig.clip == null:
		return
	var sk := get_skeleton()
	var st := rig.sample()
	if st.is_empty():
		return
	var w := smoothstep(0.0, 1.0, rig.weight)
	_posture(sk, st.lean as Vector3, w)
	rig.evaluate()
	var mb := Basis(Vector3.UP, rig.model.global_rotation.y)
	var u := rig.shaft_up
	# Right (staff) hand on the rear grip.
	var pole_r := mb * Vector3(-0.35, -1.0, -0.25)
	var fist_r := rig.rear_fist
	var hb_r := _fit_grip(sk, "R", fist_r, u, mb, pole_r, true, roll_right_deg)
	_solve(sk, "R", fist_r - hb_r * FIST_R, hb_r, pole_r, w, fist_r)
	# Left hand: grips the front marker, or opens out to the free-hand target.
	var gl := rig.grip_left
	var fl := rig.free_left
	if gl > 0.001:
		var pole_l := mb * Vector3(0.35, -1.0, -0.25)
		var fist_l := rig.front_fist
		var hb_l := _fit_grip(sk, "L", fist_l, u, mb, pole_l, false, roll_left_deg)
		_solve(sk, "L", fist_l - hb_l * FIST_L, hb_l, pole_l, gl, fist_l)
	if fl > 0.001:
		var fb := mb * Basis.from_euler((st.fr as Vector3) * (PI / 180.0)) * REST_L
		var target: Vector3 = rig.anchor * (st.fh as Vector3)
		_solve(sk, "L", target, fb, mb * Vector3(0.45, -1.0, 0.0), fl, target)
	_set_hands(gl, fl)


func _set_hands(gl: float, fl: float) -> void:
	var player := rig.get_parent()
	var hp = player.get("hands") if player else null
	if hp == null:
		return
	hp.set_pose("R", "grip")
	hp.set_pose("L", "grip" if gl > 0.4 else ("open" if fl > 0.2 else "relaxed"))


## Hand frame for gripping the shaft: the knuckle line lies along the shaft with
## the index side toward the head, and the fingers run perpendicular to it. The
## finger direction follows the forearm (a neutral wrist) once an elbow is known,
## otherwise it points across the body.
func _grip_basis(u: Vector3, forearm: Vector3, mb: Basis, right: bool, roll_deg: float) -> Basis:
	var across := mb * (Vector3(1.0, 0.0, 0.2) if right else Vector3(-1.0, 0.0, 0.2))
	var f0 := (across - u * across.dot(u)).normalized()
	var f := f0
	var fp := forearm - u * forearm.dot(u)
	if fp.length() > 0.001:
		var s := smoothstep(0.35, 0.75, fp.length() / maxf(forearm.length(), 1e-4))
		f = f0.lerp(fp.normalized(), s)
		f = (f - u * f.dot(u)).normalized()
	var x := u if right else -u
	var b := Basis(x, f, x.cross(f))
	if roll_deg != 0.0:
		b = Basis(u, deg_to_rad(roll_deg)) * b
	return b


## Solve the grip basis for a fist on the shaft: first pass with the default
## finger direction to find where the elbow falls, then align the fingers with
## the forearm that results.
func _fit_grip(sk: Skeleton3D, side: String, fist: Vector3, u: Vector3, mb: Basis, pole: Vector3, right: bool, roll_deg: float) -> Basis:
	var fo := FIST_R if right else FIST_L
	var b0 := _grip_basis(u, Vector3.ZERO, mb, right, roll_deg)
	var wrist0 := fist - b0 * fo
	var e := _elbow_world(sk, side, wrist0, pole)
	return _grip_basis(u, wrist0 - e, mb, right, roll_deg)


## Elbow position (world) the two-bone solve would use for this wrist target.
func _elbow_world(sk: Skeleton3D, side: String, wrist_w: Vector3, pole_w: Vector3) -> Vector3:
	var ids: Array = _arm[side]
	var inv := sk.global_transform.affine_inverse()
	var s := sk.get_bone_global_pose(ids[0]).origin
	var e := sk.get_bone_global_pose(ids[1]).origin
	var wr := sk.get_bone_global_pose(ids[2]).origin
	var l1 := (e - s).length()
	var l2 := (wr - e).length()
	var to_t := inv * wrist_w - s
	var d := clampf(to_t.length(), 0.06, l1 + l2 - 0.002)
	var dir := to_t.normalized()
	var pole := inv.basis * pole_w
	pole = pole - dir * pole.dot(dir)
	if pole.length() < 1e-4:
		pole = (e - s) - dir * (e - s).dot(dir)
	pole = pole.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	return sk.global_transform * (s + dir * a + pole * h)


func _posture(sk: Skeleton3D, lean: Vector3, w: float) -> void:
	if lean == Vector3.ZERO or w <= 0.001:
		return
	var e := lean * (PI / 180.0) * w
	if _spine >= 0:
		sk.set_bone_pose_rotation(_spine, sk.get_bone_pose_rotation(_spine) * Quaternion.from_euler(e * 0.4))
	if _chest >= 0:
		sk.set_bone_pose_rotation(_chest, sk.get_bone_pose_rotation(_chest) * Quaternion.from_euler(e * 0.6))


## Two-bone IK: wrist to `wrist_w` (world), hand to `hand_b` (world basis),
## elbow toward `pole_w`; blended by `w`. `fist_w` is only for diagnostics.
func _solve(sk: Skeleton3D, side: String, wrist_w: Vector3, hand_b: Basis, pole_w: Vector3, w: float, fist_w: Vector3) -> void:
	if w <= 0.001:
		return
	var ids: Array = _arm[side]
	var inv := sk.global_transform.affine_inverse()
	var t_s := inv * wrist_w
	var hb := inv.basis * hand_b
	var gu := sk.get_bone_global_pose(ids[0])
	var gl := sk.get_bone_global_pose(ids[1])
	var gh := sk.get_bone_global_pose(ids[2])
	var s := gu.origin
	var e := gl.origin
	var wr := gh.origin
	var l1 := (e - s).length()
	var l2 := (wr - e).length()
	var to_t := t_s - s
	var d := clampf(to_t.length(), 0.06, l1 + l2 - 0.002)
	var dir := to_t.normalized()
	var pole := inv.basis * pole_w
	pole = pole - dir * pole.dot(dir)
	if pole.length() < 1e-4:
		pole = (e - s) - dir * (e - s).dot(dir)
	pole = pole.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var e2 := s + dir * a + pole * h
	var w2 := s + dir * d
	reach_error[side] = (to_t.length() - d)
	var q_u := Quaternion((e - s).normalized(), (e2 - s).normalized())
	var nu := Basis(q_u) * gu.basis
	var dir_l := q_u * (wr - e).normalized()
	var q_l := Quaternion(dir_l, (w2 - e2).normalized())
	var nl := Basis(q_l) * Basis(q_u) * gl.basis
	var tu := Transform3D(gu.basis.slerp(nu, w), s)
	var tl := Transform3D(gl.basis.slerp(nl, w), e.lerp(e2, w))
	var th := Transform3D(gh.basis.slerp(hb, w), wr.lerp(w2, w))
	sk.set_bone_global_pose(ids[0], tu)
	sk.set_bone_global_pose(ids[1], tl)
	sk.set_bone_global_pose(ids[2], th)
