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

const COLLIDER_DATA := "res://data/characters/body_colliders.json"


## [{bone, kind, radius, height, offset, covers}] from data/characters/body_colliders.json.
static func colliders() -> Array:
	var d: Variant = DialogueRunner._read_json(COLLIDER_DATA)
	return (d as Dictionary).get("colliders", []) if d is Dictionary else []


## Names of garment meshes (anything on the character with an outfit material,
## larger than a trinket) that no collider volume covers: the gear rule. Empty = ok.
static func uncovered_garments(model: Node) -> Array[String]:
	var d: Variant = DialogueRunner._read_json(COLLIDER_DATA)
	var keys: Dictionary = (d as Dictionary).get("garment_keys", {}) if d is Dictionary else {}
	var covered := {}
	for c in colliders():
		for k in c.get("covers", []):
			covered[str(k)] = true
	var out: Array[String] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var outfit := false
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null and m.resource_name.begins_with("M_Outfit_"):
				outfit = true
		if not outfit or mi.get_aabb().size.length() < 0.12 or str(mi.name) == "Staff":
			continue
		var key := ""
		for prefix in keys:
			if not str(prefix).begins_with("_") and str(mi.name).begins_with(str(prefix)):
				key = str(keys[prefix])
				break
		if key == "" or not covered.has(key):
			out.append(str(mi.name))
	return out


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
	for c in colliders():
		var bone := skel.find_bone(str(c["bone"]))
		if bone < 0:
			continue
		var length := 0.2
		for ch in skel.get_bone_children(bone):
			length = skel.get_bone_rest(ch).origin.length()
			break
		var col: SpringBoneCollision3D
		if c["kind"] == "capsule":
			var cap := SpringBoneCollisionCapsule3D.new()
			cap.radius = float(c["radius"])
			cap.height = float(c["height"])
			col = cap
		else:
			var sph := SpringBoneCollisionSphere3D.new()
			sph.radius = float(c["radius"])
			col = sph
		col.name = "Col_" + str(c["bone"])
		sim.add_child(col)
		col.bone_name = str(c["bone"])
		col.position_offset = Vector3(0, length * float(c["offset"]), 0)
	return sim
