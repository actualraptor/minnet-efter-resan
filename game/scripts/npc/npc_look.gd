class_name NpcLook
extends RefCounted
## Makes one shared VRoid sample body into a particular person without new art:
## tints for hair and clothes (MToon `_Color` / `_ShadeColor`), a forward stoop
## baked into the humanoid animation clips, and a pair of round spectacles.

const WHITE := Color(1, 1, 1, 1)


static func apply(model: Node3D, hair_tint: Color, cloth_tint: Color, stoop_deg: float, glasses: bool, long_skirt := Color(0, 0, 0, 0), shawl := Color(0, 0, 0, 0)) -> void:
	if hair_tint != WHITE or cloth_tint != WHITE:
		for n in model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if not (src is ShaderMaterial):
					continue
				var key := src.resource_name.to_upper()
				var tint := WHITE
				if key.contains("HAIR") and hair_tint != WHITE:
					tint = hair_tint
				elif key.contains("CLOTH") and cloth_tint != WHITE:
					tint = cloth_tint
				if tint == WHITE:
					continue
				var m := (src as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_shader_parameter("_Color", _mul(m.get_shader_parameter("_Color"), tint))
				m.set_shader_parameter("_ShadeColor", _mul(m.get_shader_parameter("_ShadeColor"), tint))
				mi.set_surface_override_material(i, m)
	if absf(stoop_deg) > 0.01:
		_stoop(model, stoop_deg)
	if glasses:
		_glasses(model)
	if long_skirt.a > 0.0:
		_garment(model, "Hips", long_skirt, 0.17, 0.3, 0.74, Vector3(0, -0.36, 0.0))
	if shawl.a > 0.0:
		_garment(model, "UpperChest" if _has_bone(model, "UpperChest") else "Chest", shawl, 0.1, 0.25, 0.3, Vector3(0, 0.0, 0.0))


static func _mul(v: Variant, tint: Color) -> Color:
	var c: Color = v if v is Color else Color(1, 1, 1, 1)
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)


## Leans the trunk forward in every clip the model has (about the character's
## X axis; the humanoid rest bones are axis-aligned).
static func _stoop(model: Node3D, deg: float) -> void:
	var anim := CharacterVisual.find_animation_player(model)
	if anim == null:
		return
	var lean := {"Spine": 0.35, "Chest": 0.4, "UpperChest": 0.25}
	var counter := {"Neck": -0.3, "Head": -0.2}
	for lib_name in anim.get_animation_library_list():
		var lib := anim.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			var a := lib.get_animation(clip_name)
			for t in a.get_track_count():
				if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
					continue
				var bone := String(a.track_get_path(t).get_concatenated_subnames())
				var share: float = lean.get(bone, counter.get(bone, 0.0))
				if share == 0.0:
					continue
				var tilt := Quaternion(Vector3.RIGHT, deg_to_rad(deg * share))
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, tilt * (a.track_get_key_value(t, k) as Quaternion))


static func _has_bone(model: Node3D, bone: String) -> bool:
	for n in model.find_children("*", "Skeleton3D", true, false):
		return (n as Skeleton3D).find_bone(bone) >= 0
	return false


## A simple cloth cone hung from a bone (a long skirt over the sample's short
## one, a shawl over the shoulders).
static func _garment(model: Node3D, bone: String, color: Color, top_r: float, bottom_r: float, height: float, offset: Vector3) -> void:
	var sk: Skeleton3D = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	if sk == null or sk.find_bone(bone) < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	sk.add_child(att)
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	cm.radial_segments = 20
	cm.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = offset
	att.add_child(mi)


static func _glasses(model: Node3D) -> void:
	var sk: Skeleton3D = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	if sk == null or sk.find_bone("Head") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.78, 0.62, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.35
	var head := sk.get_bone_global_rest(sk.find_bone("Head"))
	var eyes: Array[Vector3] = []
	for eye in ["LeftEye", "RightEye"]:
		var bi := sk.find_bone(eye)
		eyes.append(head.affine_inverse() * sk.get_bone_global_rest(bi).origin if bi >= 0 else Vector3(0.035 if eye == "LeftEye" else -0.035, 0.1, 0.0))
	for p in eyes:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0225
		tm.outer_radius = 0.0275
		ring.mesh = tm
		ring.material_override = gold
		ring.position = p + Vector3(0, 0, 0.085)
		ring.rotation_degrees = Vector3(90, 0, 0)
		att.add_child(ring)
	var mid := (eyes[0] + eyes[1]) * 0.5
	var bridge := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.003
	bm.bottom_radius = 0.003
	bm.height = maxf(absf(eyes[0].x - eyes[1].x) - 0.055, 0.004)
	bridge.mesh = bm
	bridge.material_override = gold
	bridge.position = mid + Vector3(0, 0.008, 0.087)
	bridge.rotation_degrees = Vector3(0, 0, 90)
	att.add_child(bridge)
