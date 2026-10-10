class_name CharacterPhysics
extends RefCounted
## Secondary motion via Godot's built-in SpringBoneSimulator3D (no add-ons).
## Bone chains authored in the rig are named <group>_<k>_<n> (e.g. hairB_3_1..4,
## skirt_5_1..3, cape_2_1..2); every chain whose prefix matches a group below
## gets a spring setting, and body capsules/spheres keep hair and cloth from
## passing through legs, hips, torso, arms and head.

## stiffness: how strongly it returns to the animated pose; drag: damping;
## gravity: pull down (m/s^2-ish); radius: chain thickness for collisions.
const GROUPS := {
	"hairB_": {"stiffness": 1.0, "drag": 0.5, "gravity": 3.2, "radius": 0.025},
	"hairS_": {"stiffness": 1.2, "drag": 0.45, "gravity": 1.6, "radius": 0.02},
	"skirt_": {"stiffness": 12.0, "drag": 0.75, "gravity": 2.0, "radius": 0.02},
	"cape_": {"stiffness": 1.8, "drag": 0.4, "gravity": 0.6, "radius": 0.02},
}

## bone, kind, radius, height (capsule), offset along bone (0..1 of its length)
const COLLIDERS := [
	# Thighs measured from the tights: ~0.09 m radius at the top, ~0.06 above the knee.
	["thigh.L", "capsule", 0.085, 0.24, 0.25], ["thigh.R", "capsule", 0.085, 0.24, 0.25],
	["thigh.L", "capsule", 0.068, 0.3, 0.62], ["thigh.R", "capsule", 0.068, 0.3, 0.62],
	["shin.L", "capsule", 0.06, 0.36, 0.5], ["shin.R", "capsule", 0.06, 0.36, 0.5],
	["spine", "capsule", 0.13, 0.26, 0.5], ["chest", "capsule", 0.135, 0.24, 0.5],
	["upper_arm.L", "capsule", 0.055, 0.3, 0.5], ["upper_arm.R", "capsule", 0.055, 0.3, 0.5],
	["head", "sphere", 0.115, 0.0, 0.35],
	# Humanoid (VRoid) rig.
	# Measured on the VRoid tights: ~0.08 m radius at the top, 0.065 mid, 0.045 knee
	# (+ ~1 cm so the chains, which sit inside the lining, keep the cloth clear).
	["LeftUpperLeg", "capsule", 0.09, 0.2, 0.22], ["RightUpperLeg", "capsule", 0.09, 0.2, 0.22],
	["LeftUpperLeg", "capsule", 0.075, 0.22, 0.62], ["RightUpperLeg", "capsule", 0.075, 0.22, 0.62],
	["LeftLowerLeg", "sphere", 0.06, 0.0, 0.0], ["RightLowerLeg", "sphere", 0.06, 0.0, 0.0],   # knees
	["LeftLowerLeg", "capsule", 0.055, 0.34, 0.45], ["RightLowerLeg", "capsule", 0.055, 0.34, 0.45],
	["Spine", "capsule", 0.12, 0.2, 0.5], ["Chest", "capsule", 0.125, 0.2, 0.5],
	["UpperChest", "capsule", 0.12, 0.18, 0.5],
	["LeftUpperArm", "capsule", 0.05, 0.26, 0.5], ["RightUpperArm", "capsule", 0.05, 0.26, 0.5],
	["Head", "sphere", 0.105, 0.0, 0.4],
]


static func setup(model: Node) -> SpringBoneSimulator3D:
	var skel: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel == null:
		return null
	var chains: Array = []  # [prefix, length, group]
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		for g in GROUPS:
			if n.begins_with(g) and n.ends_with("_1"):
				var prefix := n.trim_suffix("_1")
				var length := 1
				while skel.find_bone("%s_%d" % [prefix, length + 1]) >= 0:
					length += 1
				chains.append([prefix, length, g])
	if chains.is_empty():
		return null
	# Skirt chains first follow the thighs (see SkirtLegFollow), then simulate.
	var follow := SkirtLegFollow.new()
	follow.name = "SkirtLegFollow"
	skel.add_child(follow)
	if not follow.setup():
		follow.queue_free()
	var sim := SpringBoneSimulator3D.new()
	sim.name = "SecondaryMotion"
	skel.add_child(sim)
	sim.setting_count = chains.size()
	for i in chains.size():
		var prefix: String = chains[i][0]
		var g: Dictionary = GROUPS[chains[i][2]]
		sim.set_root_bone_name(i, prefix + "_1")
		sim.set_end_bone_name(i, "%s_%d" % [prefix, chains[i][1]])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, 0.06)
		sim.set_stiffness(i, g["stiffness"])
		sim.set_drag(i, g["drag"])
		sim.set_gravity(i, g["gravity"])
		sim.set_radius(i, g["radius"])
		sim.set_enable_all_child_collisions(i, true)
	for c in COLLIDERS:
		var bone := skel.find_bone(c[0])
		if bone < 0:
			continue
		var length := 0.2
		for ch in skel.get_bone_children(bone):
			length = skel.get_bone_rest(ch).origin.length()
			break
		var col: SpringBoneCollision3D
		if c[1] == "capsule":
			var cap := SpringBoneCollisionCapsule3D.new()
			cap.radius = c[2]
			cap.height = c[3]
			col = cap
		else:
			var sph := SpringBoneCollisionSphere3D.new()
			sph.radius = c[2]
			col = sph
		col.name = "Col_" + c[0]
		sim.add_child(col)
		col.bone_name = c[0]
		col.position_offset = Vector3(0, length * c[4], 0)
	return sim
