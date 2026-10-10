class_name RigNames
extends RefCounted
## Bone lookup that works on both of Freyja's rigs: the original procedural rig
## (hips, thigh.L, hand.R ...) and the VRoid humanoid rig (Hips, LeftUpperLeg,
## RightHand ...). Systems ask for the legacy name; the humanoid name is used
## when the legacy bone doesn't exist.

const HUMANOID := {
	"hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
	"shoulder.L": "LeftShoulder", "shoulder.R": "RightShoulder",
	"upper_arm.L": "LeftUpperArm", "upper_arm.R": "RightUpperArm",
	"forearm.L": "LeftLowerArm", "forearm.R": "RightLowerArm",
	"hand.L": "LeftHand", "hand.R": "RightHand",
	"thigh.L": "LeftUpperLeg", "thigh.R": "RightUpperLeg",
	"shin.L": "LeftLowerLeg", "shin.R": "RightLowerLeg",
	"foot.L": "LeftFoot", "foot.R": "RightFoot",
}


static func find(skel: Skeleton3D, legacy: String) -> int:
	var i := skel.find_bone(legacy)
	if i < 0 and HUMANOID.has(legacy):
		i = skel.find_bone(HUMANOID[legacy])
	return i


static func resolve(skel: Skeleton3D, legacy: String) -> String:
	var i := find(skel, legacy)
	return skel.get_bone_name(i) if i >= 0 else legacy


static func is_humanoid(skel: Skeleton3D) -> bool:
	return skel.find_bone("Hips") >= 0 and skel.find_bone("hips") < 0
