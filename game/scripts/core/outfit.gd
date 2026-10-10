class_name Outfit
extends RefCounted
## Dresses a humanoid character (e.g. an imported VRM) in a tailored outfit
## (art/blender/outfit/build_freyja_outfit.py; docs/design/CLOTHING_PIPELINE.md).
##
##   1. Adds the outfit's extra bones (skirt_k_n, cape_k_n) to the character
##      skeleton, with rests matching the outfit's.
##   2. Moves the garment meshes onto the character skeleton and rebinds their
##      skins by bone name against the character's own rest pose (works even if
##      the importer re-oriented bone rests), after aligning the two model spaces.
##   3. Hides body triangles that opaque fitted garments cover (UV mask).
##   4. Sets up spring-bone secondary motion for the hanging garments, with
##      colliders on the legs, hips, torso and upper arms.

## stiffness: return to the animated pose; drag: damping; gravity: sag;
## radius: chain thickness for collisions.
const SPRINGS := {
	"skirt_": {"stiffness": 3.2, "drag": 0.55, "gravity": 2.2, "radius": 0.02},
	"cape_": {"stiffness": 2.4, "drag": 0.6, "gravity": 0.8, "radius": 0.02},
}
## bone, radius, length, offset along the bone (0..1); capsules unless length 0.
const COLLIDERS := [
	["LeftUpperLeg", 0.095, 0.22, 0.25], ["RightUpperLeg", 0.095, 0.22, 0.25],
	["LeftUpperLeg", 0.078, 0.26, 0.65], ["RightUpperLeg", 0.078, 0.26, 0.65],
	["LeftLowerLeg", 0.055, 0.32, 0.45], ["RightLowerLeg", 0.055, 0.32, 0.45],
	["Hips", 0.13, 0.0, 0.0], ["Spine", 0.12, 0.18, 0.5], ["Chest", 0.13, 0.2, 0.5],
	["LeftUpperArm", 0.05, 0.22, 0.5], ["RightUpperArm", 0.05, 0.22, 0.5],
]


static func find_skeleton(root: Node) -> Skeleton3D:
	for s in root.find_children("*", "Skeleton3D", true, false):
		return s
	return null


## Returns the SpringBoneSimulator3D driving the outfit (or null).
## strip_avatar_clothing: remove the avatar's own garments (VRoid tags them *_CLOTH).
static func dress(character: Node3D, outfit_scene: PackedScene, body_mask: Texture2D = null, strip_avatar_clothing := true, simulate := true, use_toon := true) -> SpringBoneSimulator3D:
	var skel := find_skeleton(character)
	var outfit := outfit_scene.instantiate() as Node3D
	var oskel := find_skeleton(outfit)
	if skel == null or oskel == null:
		push_error("Outfit: missing skeleton")
		return null
	# Outfit model space -> character skeleton space, from matching joints.
	var align := _alignment(oskel, skel)
	# 1. extra bones.
	for i in oskel.get_bone_count():
		var n := oskel.get_bone_name(i)
		if skel.find_bone(n) >= 0:
			continue
		var source_parent := oskel.get_bone_parent(i)
		var pi := skel.find_bone(oskel.get_bone_name(source_parent)) if source_parent >= 0 else -1
		if source_parent >= 0 and pi < 0:
			continue
		var g_rest := align * oskel.get_bone_global_rest(i)
		var local := skel.get_bone_global_rest(pi).affine_inverse() * g_rest if pi >= 0 else g_rest
		var bi := skel.get_bone_count()
		skel.add_bone(n)
		skel.set_bone_parent(bi, pi)
		skel.set_bone_rest(bi, local)
		skel.set_bone_pose(bi, local)
	# 2. garments onto the character skeleton.
	var garments: Array[MeshInstance3D] = []
	for mi in outfit.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var mesh_to_skel := _rel(oskel, outfit).affine_inverse() * _rel(m, outfit)
		var skin := Skin.new()
		for b in m.skin.get_bind_count():
			var bname := m.skin.get_bind_name(b)
			if bname == &"":
				bname = oskel.get_bone_name(m.skin.get_bind_bone(b))
			var ti := skel.find_bone(bname)
			if ti < 0:
				push_warning("Outfit: bone %s missing on character" % bname)
				continue
			skin.add_named_bind(bname, skel.get_bone_global_rest(ti).affine_inverse() * align * mesh_to_skel)
		m.get_parent().remove_child(m)
		m.owner = null
		skel.add_child(m)
		m.transform = Transform3D.IDENTITY
		m.skin = skin
		m.skeleton = m.get_path_to(skel)
		garments.append(m)
		# Same toon look as every other character in the game.
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if use_toon:
			for si in m.mesh.get_surface_count():
				m.set_surface_override_material(si, CharacterVisual.convert_material(m.get_active_material(si)))
	outfit.queue_free()
	# 3. hide covered skin (and the avatar's own clothes).
	if body_mask or strip_avatar_clothing:
		_mask_body(skel, body_mask.get_image() if body_mask else null, garments, strip_avatar_clothing)
	# 4. secondary motion.
	return _springs(skel) if simulate else null


## Transform of `node` relative to `root` (works outside the scene tree).
static func _rel(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _alignment(from_skel: Skeleton3D, to_skel: Skeleton3D) -> Transform3D:
	var names := ["Hips", "LeftUpperLeg", "RightUpperLeg", "Head", "LeftUpperArm", "RightUpperArm"]
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	for n in names:
		var i := from_skel.find_bone(n)
		var j := to_skel.find_bone(n)
		if i >= 0 and j >= 0:
			a.append(from_skel.get_bone_global_rest(i).origin)
			b.append(to_skel.get_bone_global_rest(j).origin)
	if a.size() < 3:
		return Transform3D.IDENTITY
	# Yaw + uniform scale + translation (both are upright humanoids).
	var ca := Vector3.ZERO
	var cb := Vector3.ZERO
	for k in a.size():
		ca += a[k]
		cb += b[k]
	ca /= a.size()
	cb /= b.size()
	var la := Vector3(a[1] - a[2])
	var lb := Vector3(b[1] - b[2])
	la.y = 0.0
	lb.y = 0.0
	var yaw := atan2(la.x, la.z) - atan2(lb.x, lb.z)
	var sa := 0.0
	var sb := 0.0
	for k in a.size():
		sa += (a[k] - ca).length()
		sb += (b[k] - cb).length()
	var sc := sb / maxf(sa, 1e-6)
	var basis := Basis(Vector3.UP, -yaw).scaled(Vector3.ONE * sc)
	return Transform3D(basis, cb - basis * ca)


static func _mask_body(skel: Skeleton3D, mask: Image, garments: Array[MeshInstance3D], strip: bool) -> void:
	var w := 1
	var h := 1
	if mask:
		if mask.is_compressed():
			mask.decompress()
		w = mask.get_width()
		h = mask.get_height()
	for mi in skel.get_parent().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m in garments:
			continue
		if m.mesh == null or not (m.mesh is ArrayMesh):
			continue
		var src := m.mesh as ArrayMesh
		var relevant := false
		for s in src.get_surface_count():
			var sm := src.surface_get_material(s)
			var sn := String(sm.resource_name).to_upper() if sm else ""
			if (strip and sn.contains("_CLOTH")) or (mask != null and sn.get_slice(" (", 0).ends_with("_SKIN") and sn.contains("BODY")):
				relevant = true
		if not relevant:
			continue
		var dst := ArrayMesh.new()
		for b in src.get_blend_shape_count():
			dst.add_blend_shape(src.get_blend_shape_name(b))
		dst.blend_shape_mode = src.blend_shape_mode
		var dropped := 0
		var touched := false
		for s in src.get_surface_count():
			var mat := src.surface_get_material(s)
			var mname := String(mat.resource_name).to_upper() if mat else ""
			if strip and mname.contains("_CLOTH"):
				touched = true
				dropped += 1
				continue
			var arrays := src.surface_get_arrays(s)
			# The mask is in the body texture's UV space: body skin only, never the face.
			var is_skin := mask != null and mname.get_slice(" (", 0).ends_with("_SKIN") and mname.contains("BODY")
			if is_skin and arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_INDEX] != null:
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var keep := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					var c := (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0
					var px := mask.get_pixel(clampi(int(c.x * w), 0, w - 1), clampi(int(c.y * h), 0, h - 1))
					if px.r < 0.5:
						dropped += 1
						continue
					keep.append(idx[t])
					keep.append(idx[t + 1])
					keep.append(idx[t + 2])
				arrays[Mesh.ARRAY_INDEX] = keep
				touched = true
			var bs := src.surface_get_blend_shape_arrays(s)
			dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, bs, {}, src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			dst.surface_set_material(dst.get_surface_count() - 1, mat)
		if touched and dropped > 0:
			m.mesh = dst
			print("Outfit: removed %d covered skin triangles / clothing surfaces on %s" % [dropped, m.name])


static func _springs(skel: Skeleton3D) -> SpringBoneSimulator3D:
	var chains: Array = []
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		for g in SPRINGS:
			if n.begins_with(g) and n.ends_with("_1"):
				var prefix := n.trim_suffix("_1")
				var length := 1
				while skel.find_bone("%s_%d" % [prefix, length + 1]) >= 0:
					length += 1
				chains.append([prefix, length, g])
	if chains.is_empty():
		return null
	var sim := SpringBoneSimulator3D.new()
	sim.name = "OutfitSprings"
	skel.add_child(sim)
	sim.setting_count = chains.size()
	for i in chains.size():
		var prefix: String = chains[i][0]
		var g: Dictionary = SPRINGS[chains[i][2]]
		sim.set_root_bone_name(i, prefix + "_1")
		sim.set_end_bone_name(i, "%s_%d" % [prefix, chains[i][1]])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, 0.05)
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
		if float(c[2]) > 0.0:
			var cap := SpringBoneCollisionCapsule3D.new()
			cap.radius = c[1]
			cap.height = c[2]
			col = cap
		else:
			var sph := SpringBoneCollisionSphere3D.new()
			sph.radius = c[1]
			col = sph
		sim.add_child(col)
		col.bone_name = c[0]
		col.position_offset = Vector3(0, length * float(c[3]), 0)
	return sim
