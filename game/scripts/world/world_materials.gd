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
static var _leaf_tex: ImageTexture


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


## A cluster of painted leaves on transparent background (generated, no asset).
## Red channel carries per-leaf shading so the shader can tint it.
static func leaf_texture() -> ImageTexture:
	if _leaf_tex:
		return _leaf_tex
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := Vector2(size, size) * 0.5
	for i in 26:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * size * 0.3
		var base := c + Vector2(cos(ang), sin(ang)) * dist
		var dir := Vector2(cos(ang), sin(ang)).rotated(rng.randf_range(-0.7, 0.7))
		var length := rng.randf_range(0.17, 0.27) * size
		var width := length * rng.randf_range(0.32, 0.42)
		var shade := rng.randf_range(0.45, 1.0)
		var side := Vector2(-dir.y, dir.x)
		var x0 := int(max(0, min(base.x, base.x + dir.x * length) - width))
		var x1 := int(min(size - 1, max(base.x, base.x + dir.x * length) + width))
		var y0 := int(max(0, min(base.y, base.y + dir.y * length) - width))
		var y1 := int(min(size - 1, max(base.y, base.y + dir.y * length) + width))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var rel := Vector2(x, y) - base
				var t := rel.dot(dir) / length
				if t < 0.0 or t > 1.0:
					continue
				var half := width * sin(t * PI) * (1.0 - 0.25 * t)
				var s := rel.dot(side)
				if absf(s) > half:
					continue
				# Midrib darker, upper half lighter: reads as a painted leaf.
				var v := shade * (0.82 + 0.18 * smoothstep(0.0, 1.0, s / max(half, 0.001) * 0.5 + 0.5))
				v *= 1.0 - 0.25 * exp(-pow(s / max(half * 0.12, 0.5), 2.0))
				var prev := img.get_pixel(x, y)
				if prev.a < 0.5 or rng.randf() < 0.0:
					img.set_pixel(x, y, Color(v, v, v, 1.0))
				else:
					img.set_pixel(x, y, Color(maxf(prev.r * 0.92, v), v, v, 1.0))
	img.generate_mipmaps()
	_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


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
	if low.contains("leafcards"):
		var lc := ShaderMaterial.new()
		lc.shader = FOLIAGE
		lc.set_shader_parameter("albedo", src.albedo_color.lightened(0.06))
		lc.set_shader_parameter("is_leaf", 1.0)
		lc.set_shader_parameter("sway", 0.09)
		lc.set_shader_parameter("use_leaf_tex", true)
		lc.set_shader_parameter("leaf_tex", leaf_texture())
		if low.contains("birch"):
			lc.set_shader_parameter("tint_light", Color(0.85, 0.92, 0.5))
		out = lc
	elif low.contains("leaves") or low.contains("bushflower") or low.contains("bark") or low.contains("moss"):
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
