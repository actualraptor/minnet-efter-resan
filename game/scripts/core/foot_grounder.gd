class_name FootGrounder
extends SkeletonModifier3D
## Keeps her feet on the ground. The locomotion clips were recorded on flat
## floor and plant each foot at a slightly different height, so on their own the
## feet hover a few centimetres up (and float over dips, sink into rises).
## Per frame this modifier:
##   1. raycasts the floor under each animated ankle,
##   2. learns each foot's planted height from the animation (running minimum),
##   3. lowers the pelvis so the lower stance foot can reach the floor,
##   4. solves two-bone IK (thigh/shin) to put each ankle at its floor height,
##   5. tilts a planted foot to the slope.
## It fades out while airborne so jumps and falls play untouched.

@export var ankle_height := 0.085      ## rest-pose ankle height above the sole
@export var max_pelvis_drop := 0.22
@export var collision_mask := 1

var body: CharacterBody3D
var _legs: Array = []                  # [[thigh, shin, foot], ...]
var _hips := -1
var _plant_ref: Array[float] = [0.1, 0.1]
var _pelvis := 0.0
var _weight := 0.0
var _axis_prev: Array[Vector3] = [Vector3.RIGHT, Vector3.RIGHT]


func setup(b: CharacterBody3D) -> bool:
	body = b
	var sk := get_skeleton()
	if sk == null:
		return false
	_hips = sk.find_bone("hips")
	_legs.clear()
	for s in ["L", "R"]:
		var ids := [sk.find_bone("thigh." + s), sk.find_bone("shin." + s), sk.find_bone("foot." + s)]
		if ids.has(-1):
			return false
		_legs.append(ids)
	return _hips >= 0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or body == null or _legs.size() != 2:
		return
	var want_w := 1.0 if body.is_on_floor() else 0.0
	_weight = move_toward(_weight, want_w, delta * (6.0 if want_w > _weight else 10.0))
	if _weight <= 0.001:
		_pelvis = 0.0
		return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var origin_y := body.global_position.y
	var anim: Array[Vector3] = []
	var desired: Array[float] = []
	var normals: Array[Vector3] = []
	var plant: Array[float] = []
	for i in 2:
		var a: Vector3 = xf * sk.get_bone_global_pose(_legs[i][2]).origin
		var h := a.y - origin_y
		# Running minimum that slowly relaxes upward: the clip's planted height.
		_plant_ref[i] = minf(h, _plant_ref[i] + delta * 0.04)
		var lift := maxf(0.0, h - _plant_ref[i])
		var hit := _floor(a)
		var g: float = hit.get("y", origin_y)
		normals.append(hit.get("n", Vector3.UP))
		desired.append(g + ankle_height + lift)
		plant.append(1.0 - clampf(lift / 0.05, 0.0, 1.0))
		anim.append(a)
	# Lower the pelvis just enough for the lower foot to reach (never raise it:
	# a foot that must go up is handled by bending the knee).
	var off := minf(0.0, minf(desired[0] - anim[0].y, desired[1] - anim[1].y))
	off = maxf(off, -max_pelvis_drop)
	_pelvis = lerpf(_pelvis, off, 1.0 - exp(-14.0 * delta))
	var drop := _pelvis * _weight
	var hips_pose := sk.get_bone_global_pose(_hips)
	hips_pose.origin += inv.basis * Vector3(0.0, drop, 0.0)
	sk.set_bone_global_pose(_hips, hips_pose)
	for i in 2:
		var cur := anim[i] + Vector3(0.0, drop, 0.0)
		var target := Vector3(cur.x, lerpf(cur.y, desired[i], _weight), cur.z)
		var up_local := (inv.basis * normals[i]).normalized()
		_solve_leg(sk, i, inv * target, up_local, plant[i] * _weight)


func _floor(at: Vector3) -> Dictionary:
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.55, at + Vector3.DOWN * 0.6, collision_mask, [body.get_rid()])
	var r := space.intersect_ray(q)
	if r.is_empty():
		return {}
	var n: Vector3 = r.normal
	if n.y < 0.55:  # walls and steep edges: ignore the tilt
		n = Vector3.UP
	return {"y": (r.position as Vector3).y, "n": n}


## Analytic two-bone IK in skeleton space (thigh -> shin -> foot), keeping the
## knee in its animated bend plane and the foot's animated orientation, then
## tilting the foot by `tilt` toward the floor normal.
func _solve_leg(sk: Skeleton3D, i: int, t: Vector3, floor_up: Vector3, tilt: float) -> void:
	var ia: int = _legs[i][0]
	var ib: int = _legs[i][1]
	var ic: int = _legs[i][2]
	var A := sk.get_bone_global_pose(ia)
	var B := sk.get_bone_global_pose(ib)
	var C := sk.get_bone_global_pose(ic)
	var a := A.origin
	var b := B.origin
	var c := C.origin
	var lab := a.distance_to(b)
	var lcb := b.distance_to(c)
	var lat := clampf(a.distance_to(t), 0.01, (lab + lcb) * 0.999)
	var ac := (c - a).normalized()
	var ab := (b - a).normalized()
	var ba := -ab
	var bc := (c - b).normalized()
	var at := (t - a).normalized()
	var ac_ab0 := acos(clampf(ac.dot(ab), -1.0, 1.0))
	var ba_bc0 := acos(clampf(ba.dot(bc), -1.0, 1.0))
	var ac_at0 := acos(clampf(ac.dot(at), -1.0, 1.0))
	var ac_ab1 := acos(clampf((lcb * lcb - lab * lab - lat * lat) / (-2.0 * lab * lat), -1.0, 1.0))
	var ba_bc1 := acos(clampf((lat * lat - lab * lab - lcb * lcb) / (-2.0 * lab * lcb), -1.0, 1.0))
	var axis0 := ac.cross(ab)
	if axis0.length() < 1e-5:
		axis0 = _axis_prev[i]
	else:
		axis0 = axis0.normalized()
		_axis_prev[i] = axis0
	var r0 := Quaternion(axis0, ac_ab1 - ac_ab0)
	var r1 := Quaternion(axis0, ba_bc1 - ba_bc0)
	var r2 := Quaternion.IDENTITY
	var axis1 := ac.cross(at)
	if axis1.length() > 1e-6:
		r2 = Quaternion(axis1.normalized(), ac_at0)
	var qa := r2 * r0
	var qb := r2 * r1 * r0
	var b_new := a + qa * (b - a)
	var c_new := b_new + qb * (c - b)
	A.basis = Basis(qa) * A.basis
	B.basis = Basis(qb) * B.basis
	B.origin = b_new
	sk.set_bone_global_pose(ia, A)
	sk.set_bone_global_pose(ib, B)
	var foot_basis := C.basis
	if tilt > 0.001 and floor_up.dot(Vector3.UP) < 0.9999:
		var q_tilt := Quaternion(Vector3.UP, floor_up)
		foot_basis = Basis(Quaternion.IDENTITY.slerp(q_tilt, tilt)) * foot_basis
	sk.set_bone_global_pose(ic, Transform3D(foot_basis, c_new))
