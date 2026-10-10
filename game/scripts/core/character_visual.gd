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
