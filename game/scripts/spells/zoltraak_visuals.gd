class_name ZoltraakVisuals
extends RefCounted
## Shared look of the two Zoltraak families. WHITE is the modern spell: a pure
## white HDR core with a thin cool falloff and a speckled blue rim. BLACK is the
## original killing magic: a black body with a faint violet fringe.

enum Kind { WHITE, BLACK }

const SHADER := preload("res://shaders/zoltraak_beam.gdshader")
static var _noise: NoiseTexture2D


static func kind_of(spell: SpellDefinition) -> Kind:
	return Kind.BLACK if spell != null and spell.visual == &"black" else Kind.WHITE


static func noise() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.seed = 4242
		n.frequency = 0.045
		n.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.generate_mipmaps = true
		_noise.noise = n
	return _noise


static func seal_tint(kind: Kind) -> Color:
	return Color(0.78, 0.9, 1.0) if kind == Kind.WHITE else Color(0.55, 0.32, 0.9)


static func accent(kind: Kind) -> Color:
	return Color(0.75, 0.88, 1.0) if kind == Kind.WHITE else Color(0.4, 0.2, 0.7)


static func beam_material(kind: Kind, length: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("length_m", length)
	if kind == Kind.WHITE:
		m.set_shader_parameter("core_color", Vector3(1.0, 1.0, 1.0))
		m.set_shader_parameter("core_energy", 3.0)
		m.set_shader_parameter("rim_color", Vector3(0.2, 0.3, 1.0))
		m.set_shader_parameter("rim_energy", 1.3)
		m.set_shader_parameter("core_width", 0.8)
		m.set_shader_parameter("outline_start", 0.9)
		m.set_shader_parameter("dark", 0.0)
	else:
		m.set_shader_parameter("core_color", Vector3(0.0, 0.0, 0.0))
		m.set_shader_parameter("core_energy", 1.0)
		m.set_shader_parameter("rim_color", Vector3(0.5, 0.25, 1.0))
		m.set_shader_parameter("rim_energy", 1.6)
		m.set_shader_parameter("core_width", 0.62)
		m.set_shader_parameter("dark", 1.0)
		m.set_shader_parameter("grain", 1.5)
	return m


## A beam body lying along local +Z from the origin, `length` long.
const HALO := preload("res://shaders/beam_halo.gdshader")
const HALO_R := 2.1


static func _cyl_mesh(length: float, radius: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = maxf(length, 0.05)
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = true
	cm.cap_bottom = true
	return cm


static func _halo(length: float, radius: float, kind: Kind) -> MeshInstance3D:
	var h := MeshInstance3D.new()
	h.name = "Halo"
	h.mesh = _cyl_mesh(length, radius * HALO_R)
	var m := ShaderMaterial.new()
	m.shader = HALO
	m.set_shader_parameter("length_m", length)
	if kind == Kind.WHITE:
		m.set_shader_parameter("color", Vector3(0.5, 0.65, 1.0))
		m.set_shader_parameter("energy", 0.4)
		m.set_shader_parameter("falloff", 2.8)
	else:
		m.set_shader_parameter("color", Vector3(0.5, 0.22, 1.0))
		m.set_shader_parameter("energy", 0.95)
		m.set_shader_parameter("falloff", 2.0)
	# Drawn before the beam body, so the body (white core, or the black one)
	# sits on top of its own halo instead of being lightened by it.
	m.render_priority = -2
	h.material_override = m
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.extra_cull_margin = 2.0
	return h


const OUTLINE_SCALE := 1.05


static func _solid_material(kind: Kind) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED     # opaque: never see-through
	m.cull_mode = BaseMaterial3D.CULL_BACK
	if kind == Kind.WHITE:
		m.albedo_color = Color(3.0, 3.0, 3.1)                 # HDR white, blooms
	else:
		m.albedo_color = Color(0.0, 0.0, 0.0)
	return m


static func _outline_material(kind: Kind) -> StandardMaterial3D:
	# Inverted-hull edge: a slightly larger shell drawn behind the body, so the
	# beam always has a crisp coloured silhouette from any angle.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = Color(0.12, 0.25, 1.0) if kind == Kind.WHITE else Color(0.5, 0.22, 1.2)
	return m


## A SOLID beam lying along local +Z from the origin: an opaque body with closed
## ends (so it is a filled volume from the front, the back or the side, never a
## hollow shell), an inverted-hull outline and a soft additive halo.
static func make_beam(length: float, radius: float, kind: Kind) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh(length, radius)
	mi.material_override = _solid_material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = Vector3(0, 0, length * 0.5)
	mi.extra_cull_margin = 2.0
	var ol := MeshInstance3D.new()
	ol.name = "Outline"
	ol.mesh = _cyl_mesh(length, radius * OUTLINE_SCALE)
	ol.material_override = _outline_material(kind)
	ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ol.extra_cull_margin = 2.0
	mi.add_child(ol)
	mi.add_child(_halo(length, radius, kind))
	return mi


static func set_beam_length(mi: MeshInstance3D, length: float, radius: float) -> void:
	var cm := mi.mesh as CylinderMesh
	cm.height = maxf(length, 0.05)
	cm.top_radius = radius
	cm.bottom_radius = radius
	mi.position = Vector3(0, 0, length * 0.5)
	var ol := mi.get_node_or_null("Outline") as MeshInstance3D
	if ol:
		var om := ol.mesh as CylinderMesh
		om.height = maxf(length, 0.05) * 1.0
		om.top_radius = radius * OUTLINE_SCALE
		om.bottom_radius = radius * OUTLINE_SCALE
	var halo := mi.get_node_or_null("Halo") as MeshInstance3D
	if halo:
		var hm := halo.mesh as CylinderMesh
		hm.height = maxf(length, 0.05)
		hm.top_radius = radius * HALO_R
		hm.bottom_radius = radius * HALO_R
		(halo.material_override as ShaderMaterial).set_shader_parameter("length_m", length)
