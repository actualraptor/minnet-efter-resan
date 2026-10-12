class_name CharacterVisual
extends RefCounted
## Prepares imported character GLBs: converts their materials to the shared soft
## toon shader and configures looping animations.

const TOON := preload("res://shaders/toon_character.gdshader")
const LOOPING := ["Idle", "Walk", "Run", "Fall", "Talk", "Sit", "Knit", "Wave", "IdleStaff", "WalkStaff", "RunStaff", "Hop"]


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var a := find_animation_player(c)
		if a:
			return a
	return null


## Quaternius Universal Animation Library (CC0), retargeted by Godot's humanoid
## import (both skeletons map to SkeletonProfileHumanoid as %GeneralSkeleton):
## game clip name -> library clip.
## A list joins clips into one (enter -> action -> exit).
const UAL_CLIPS := {
	"Idle": "Idle", "Walk": "Walk_Formal", "Run": "Jog_Fwd", "Jump": "Jump_Start",
	"Fall": "Jump", "Land": "Jump_Land", "Talk": "Idle_Talking",
	"Cast": ["Spell_Simple_Enter", "Spell_Simple_Shoot", "Spell_Simple_Exit"],
	# Pulling the staff out of thin air (see StaffSummon.VARIANTS for timing).
	"Summon": "PickUp_Table", "SummonReach": "Interact",
	# A household wipe: the reach, with the arm swept side to side (see _wipe_motion).
	"Wipe": "Interact",
	# Holding something upright in the right hand (the statue of her).
	"Torch": "Idle_Torch",
	"SummonFlick": ["Spell_Simple_Enter", "Spell_Simple_Exit"], "SummonTwirl": "PickUp_Table",
}


## Clips mirrored left<->right so the gesture is done by the staff hand (right).
const MIRRORED := ["Cast"]


## Mirror a humanoid clip across the sagittal plane: swap Left/Right bone tracks
## and reflect rotations (x, -y, -z, w) and positions (-x). Valid for skeletons
## whose rest bones are axis-aligned (Godot's humanoid-normalized VRM rest).
static func _mirror(a: Animation) -> Animation:
	var out := Animation.new()
	out.length = a.length
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		var path := String(a.track_get_path(t))
		var sub := path.get_slice(":", 1) if path.contains(":") else ""
		var swapped := sub
		if sub.begins_with("Left"):
			swapped = "Right" + sub.substr(4)
		elif sub.begins_with("Right"):
			swapped = "Left" + sub.substr(5)
		var np := NodePath(path.get_slice(":", 0) + ":" + swapped) if sub != "" else NodePath(path)
		var ot := out.add_track(ty)
		out.track_set_path(ot, np)
		for k in a.track_get_key_count(t):
			var time := a.track_get_key_time(t, k)
			var v = a.track_get_key_value(t, k)
			match ty:
				Animation.TYPE_ROTATION_3D:
					var q: Quaternion = v
					out.rotation_track_insert_key(ot, time, Quaternion(q.x, -q.y, -q.z, q.w))
				Animation.TYPE_POSITION_3D:
					var p: Vector3 = v
					out.position_track_insert_key(ot, time, Vector3(-p.x, p.y, p.z))
				_:
					out.track_insert_key(ot, time, v)
	return out


## Replace clips with the shared humanoid library where the skeleton supports it.
static func use_humanoid_library(root: Node) -> bool:
	var anim := find_animation_player(root)
	var sk: Skeleton3D = null
	for s in root.find_children("*", "Skeleton3D", true, false):
		sk = s
		break
	if anim == null or sk == null or sk.name != &"GeneralSkeleton":
		return false
	var src_scene := load("res://assets/animations/ual/ual1.glb") as PackedScene
	if src_scene == null:
		return false
	var src := src_scene.instantiate()
	var src_lib := (src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation_library("")
	var lib := anim.get_animation_library("")
	for game_name in UAL_CLIPS:
		var spec = UAL_CLIPS[game_name]
		var parts: Array = spec if spec is Array else [spec]
		var c := _join(parts.map(func(n): return src_lib.get_animation(n)))
		if c == null:
			continue
		if game_name == "Run":
			_soften_posture(c, sk, 0.45)
		if game_name == "Wipe":
			_wipe_motion(c)
		if game_name in MIRRORED:
			c = _mirror(c)
		if lib.has_animation(game_name):
			lib.remove_animation(game_name)
		lib.add_animation(game_name, c)
	src.free()
	return true


## Sweeps the right arm side to side about the vertical axis over a trimmed reach,
## so one gesture reads as wiping a surface down.
static func _wipe_motion(a: Animation) -> void:
	a.length = minf(a.length, 1.5)
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		if String(a.track_get_path(t).get_concatenated_subnames()) != "RightUpperArm":
			continue
		for k in a.track_get_key_count(t):
			var u := a.track_get_key_time(t, k) / a.length
			var swing := sin(u * TAU * 2.5) * deg_to_rad(24.0) * sin(clampf(u, 0.0, 1.0) * PI)
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Quaternion(Vector3.UP, swing) * q)


## Concatenate clips with identical track layouts into one.
static func _join(clips: Array) -> Animation:
	if clips.is_empty() or clips.has(null):
		return null
	if clips.size() == 1:
		return (clips[0] as Animation).duplicate() as Animation
	var out := Animation.new()
	var t0 := 0.0
	for a: Animation in clips:
		for t in a.get_track_count():
			var path := a.track_get_path(t)
			var ty := a.track_get_type(t)
			var ot := out.find_track(path, ty)
			if ot < 0:
				ot = out.add_track(ty)
				out.track_set_path(ot, path)
			for k in a.track_get_key_count(t):
				var time := t0 + a.track_get_key_time(t, k)
				var v = a.track_get_key_value(t, k)
				match ty:
					Animation.TYPE_ROTATION_3D:
						out.rotation_track_insert_key(ot, time, v)
					Animation.TYPE_POSITION_3D:
						out.position_track_insert_key(ot, time, v)
					Animation.TYPE_SCALE_3D:
						out.scale_track_insert_key(ot, time, v)
					_:
						out.track_insert_key(ot, time, v)
		t0 += a.length
	out.length = t0
	return out


## The library jog leans like a sprinter; keep `keep` of the spine/neck/head
## bend (blending each key toward the bone's rest rotation).
static func _soften_posture(a: Animation, sk: Skeleton3D, keep: float) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(t).get_concatenated_subnames())
		if bone not in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
			continue
		var bi := sk.find_bone(bone)
		if bi < 0:
			continue
		var rest := sk.get_bone_rest(bi).basis.get_rotation_quaternion()
		for k in a.track_get_key_count(t):
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, rest.slerp(q, keep))


static func prepare(root: Node) -> void:
	if root == null:
		return
	_convert_materials(root)
	var anim := find_animation_player(root)
	if anim:
		for lib_name in anim.get_animation_library_list():
			var lib := anim.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				if anim_name in LOOPING:
					lib.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		if anim.has_animation(&"Idle"):
			anim.play(&"Idle")


static func _convert_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			mi.set_surface_override_material(s, convert_material(src))
	for c in node.get_children():
		_convert_materials(c)


static func convert_material(src: Material) -> Material:
	if not (src is BaseMaterial3D):
		return src
	var b := src as BaseMaterial3D
	var lname := b.resource_name.to_lower()
	if lname.contains("unlit") or lname.contains("eye"):
		var u := b.duplicate() as BaseMaterial3D
		u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return u
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.resource_name = b.resource_name
	m.set_shader_parameter("albedo", b.albedo_color)
	if b.albedo_texture:
		m.set_shader_parameter("albedo_texture", b.albedo_texture)
		m.set_shader_parameter("use_texture", true)
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			var cut := b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5
			m.set_shader_parameter("alpha_scissor", cut)
	if lname.contains("crystal") or lname.contains("glow"):
		m.set_shader_parameter("emission_strength", 0.9)
	m.set_shader_parameter("ramp_softness", 0.22)
	if lname.begins_with("m_outfit_"):
		# Cloth: a softer light/shadow edge reads as fabric folds, not facets.
		m.set_shader_parameter("ramp_softness", 0.32)
	if lname.contains("skin"):
		# Anime skin: soft, pale shadows; don't let golden light turn it orange.
		m.set_shader_parameter("shadow_tint", Color(1.0, 0.86, 0.86))
		m.set_shader_parameter("shadow_floor", 0.86)
		m.set_shader_parameter("warmth_cancel", 0.55)
		m.set_shader_parameter("light_scale", 0.55)
		m.set_shader_parameter("ramp_softness", 0.3)
	if lname.contains("hair"):
		# Silver hair needs visible form: darker base, lavender shadows, soft ramp.
		m.set_shader_parameter("albedo", b.albedo_color.darkened(0.1))
		m.set_shader_parameter("shadow_tint", Color(0.55, 0.52, 0.78))
		m.set_shader_parameter("ramp_softness", 0.4)
		m.set_shader_parameter("light_scale", 0.5)
		m.set_shader_parameter("rim_strength", 0.5)
		m.set_shader_parameter("sheen", 0.14)
	return m
