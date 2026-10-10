class_name SkirtLegFollow
extends SkeletonModifier3D
## Skirts in games don't rely on collision alone: before the spring bones run,
## each skirt chain is partly swung with the nearer thigh (about the hip joint),
## so a lifted knee carries the front of the skirt forward instead of pushing
## through it. The spring simulator then adds sway on top, and the leg colliders
## only have to catch what is left.

@export var strength := 0.9

var _chains: Array = []        # [bone, weight_left, weight_right, dir (hip rest space)]
var _hips := -1
var _thighs: Array[int] = []


func setup() -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	_hips = sk.find_bone("Hips")
	var l := sk.find_bone("LeftUpperLeg")
	var r := sk.find_bone("RightUpperLeg")
	if _hips < 0 or l < 0 or r < 0:
		return false
	_thighs = [l, r]
	var hips_o := sk.get_bone_global_rest(_hips).origin
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if not (n.begins_with("skirt_") and n.ends_with("_1")) or sk.get_bone_parent(i) != _hips:
			continue
		var d := sk.get_bone_global_rest(i).origin - hips_o
		d.y = 0.0
		if d.length() < 1e-4:
			continue
		d = d.normalized()
		var wl := clampf(0.5 + d.x * 2.0, 0.0, 1.0)          # character left is +X
		_chains.append([i, wl, 1.0 - wl, d])
	return not _chains.is_empty()


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _chains.is_empty():
		return
	var hp := sk.get_bone_global_pose(_hips)
	var q_h := hp.basis.get_rotation_quaternion() * sk.get_bone_global_rest(_hips).basis.get_rotation_quaternion().inverse()
	var legs: Array = []
	for t in _thighs:
		var tp := sk.get_bone_global_pose(t)
		var q_t := tp.basis.get_rotation_quaternion() * sk.get_bone_global_rest(t).basis.get_rotation_quaternion().inverse()
		var q_rel := q_h.inverse() * q_t                       # thigh swing in hip space
		# Where the knee went (hip space, horizontal): only push cloth that way.
		var down := Vector3(0, -0.4, 0)
		var push := q_rel * down - down
		push.y = 0.0
		legs.append([tp.origin, q_rel, push])
	var hp_inv := hp.affine_inverse()
	for c in _chains:
		var g := sk.get_bone_global_pose(c[0])
		var dir: Vector3 = c[3]
		for k in 2:
			var push: Vector3 = legs[k][2]
			var reach := push.length()
			if reach < 0.005:
				continue
			# Outward only: a chain follows the knee in proportion to how much the
			# knee moves toward its side of the skirt, never pulled inward.
			var toward := maxf(0.0, (push / reach).dot(dir))
			var w: float = c[1 + k] * strength * toward * clampf(reach / 0.18, 0.0, 1.0)
			if w <= 0.001:
				continue
			var q_eff: Quaternion = q_h * Quaternion.IDENTITY.slerp(legs[k][1], w) * q_h.inverse()
			var pivot: Vector3 = legs[k][0]
			g = Transform3D(Basis(q_eff) * g.basis, pivot + q_eff * (g.origin - pivot))
		var local := hp_inv * g
		sk.set_bone_pose_position(c[0], local.origin)
		sk.set_bone_pose_rotation(c[0], local.basis.get_rotation_quaternion())
