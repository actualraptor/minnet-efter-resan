class_name WorldMaterials
extends RefCounted
## Builds the shared runtime materials (noise textures are generated, so there
## are no external texture assets to license) and converts imported prop
## materials to the stylised shaders by material name.

const TERRAIN := preload("res://shaders/terrain.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")

static var _patch_noise: NoiseTexture2D
static var _detail_noise: NoiseTexture2D
static var _foliage_cache: Dictionary = {}


static func patch_noise() -> NoiseTexture2D:
	if _patch_noise == null:
		_patch_noise = _noise(256, 0.012, 3, 11)
	return _patch_noise


static func detail_noise() -> NoiseTexture2D:
	if _detail_noise == null:
		_detail_noise = _noise(256, 0.05, 4, 23)
	return _detail_noise


static func _noise(size: int, freq: float, octaves: int, noise_seed: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t


static func terrain() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN
	m.set_shader_parameter("patch_noise", patch_noise())
	m.set_shader_parameter("detail_noise", detail_noise())
	return m


static func grass() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS
	m.set_shader_parameter("patch_noise", patch_noise())
	return m


## Walks an imported prop and swaps foliage/bark materials for the wind
## shader; other materials get softer, warmer settings.
static func stylise(root: Node) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			if src is BaseMaterial3D:
				mi.set_surface_override_material(s, _convert(src as BaseMaterial3D))
	for c in root.get_children():
		stylise(c)


static func _convert(src: BaseMaterial3D) -> Material:
	var n := src.resource_name
	var key := n + str(src.albedo_color)
	if _foliage_cache.has(key):
		return _foliage_cache[key]
	var out: Material
	var low := n.to_lower()
	if low.contains("leaves") or low.contains("bushflower") or low.contains("bark") or low.contains("moss"):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE
		var leaf := low.contains("leaves") or low.contains("bushflower")
		m.set_shader_parameter("albedo", src.albedo_color)
		m.set_shader_parameter("is_leaf", 1.0 if leaf else 0.0)
		m.set_shader_parameter("sway", 0.07 if leaf else 0.015)
		if low.contains("bushflower") or low.contains("moss"):
			m.set_shader_parameter("tint_light", src.albedo_color.lightened(0.15))
			m.set_shader_parameter("tint_dark", src.albedo_color.darkened(0.25))
		if low.contains("birch"):
			m.set_shader_parameter("tint_light", Color(0.85, 0.92, 0.5))
		if low.contains("pine"):
			m.set_shader_parameter("tint_light", Color(0.45, 0.66, 0.42))
			m.set_shader_parameter("tint_dark", Color(0.14, 0.27, 0.2))
		out = m
	else:
		var b := src.duplicate() as BaseMaterial3D
		b.roughness = maxf(b.roughness, 0.7)
		if low.contains("glow"):
			b.emission_energy_multiplier = 1.4
		out = b
	_foliage_cache[key] = out
	return out
