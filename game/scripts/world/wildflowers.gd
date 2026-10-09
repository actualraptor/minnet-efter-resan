class_name Wildflowers
extends Node3D
## Decorative, always-bloomed wildflower drifts (separate from the mage's
## FlowerField so quest logic only counts what she grew). Dense along fences,
## path verges and rocks; deliberately sparse in Jonas's old meadow so the
## Field of Flowers visibly changes it.

const SHADER := preload("res://shaders/flower.gdshader")

@export var radius := 62.0
@export var drift_count := 260


func _ready() -> void:
	var terrain := MeadowTerrain.instance
	if terrain == null:
		return
	var ids: Array = FlowerMeshBuilder.VARIANTS.keys()
	var buckets: Array = []
	for i in ids.size():
		buckets.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldLayout.SEED + 909
	var noise := FastNoiseLite.new()
	noise.seed = WorldLayout.SEED + 31
	noise.frequency = 0.05
	# Anchors that should feel lush, like the reference: verges, fences, the yard.
	var anchors: Array[Vector2] = []
	for p in WorldLayout.PATH_MAIN:
		anchors.append(p)
	for x in range(-9, 12, 3):
		anchors.append(Vector2(x, 3.4))
	anchors.append_array([Vector2(-6, -1), Vector2(6, -1.5), Vector2(-11, -6), Vector2(12, -8)])
	var drifts := 0
	var tries := 0
	while drifts < drift_count and tries < drift_count * 6:
		tries += 1
		var c: Vector2
		if rng.randf() < 0.45:
			c = anchors[rng.randi() % anchors.size()] + Vector2(rng.randfn(0, 2.5), rng.randfn(0, 2.5))
		else:
			var a := rng.randf() * TAU
			c = Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * radius
		if noise.get_noise_2d(c.x, c.y) < -0.15 and rng.randf() < 0.6:
			continue
		var meadow_d := c.distance_to(Vector2(WorldLayout.GARDEN_MEADOW.x, WorldLayout.GARDEN_MEADOW.z))
		if meadow_d < WorldLayout.GARDEN_MEADOW_RADIUS + 2.0 and rng.randf() < 0.92:
			continue
		drifts += 1
		var vi := rng.randi() % ids.size()
		var n := rng.randi_range(6, 26)
		var spread := rng.randf_range(0.6, 2.0)
		for k in n:
			var p := c + Vector2(rng.randfn(0, spread * 0.5), rng.randfn(0, spread * 0.5))
			if WorldLayout.path_amount(p.x, p.y) > 0.3 or WorldLayout.cottage_rect_contains(Vector3(p.x, 0, p.y), 0.6):
				continue
			var nrm := terrain.normal_at(p.x, p.y)
			if nrm.y < 0.8:
				continue
			var v := vi if rng.randf() < 0.85 else rng.randi() % ids.size()
			var basis := FlowerField._basis_from_up(nrm.lerp(Vector3.UP, 0.6).normalized(), rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 1.9))
			buckets[v].append([Transform3D(basis, Vector3(p.x, terrain.height_at(p.x, p.y) - 0.01, p.y)), rng.randf()])
	for i in ids.size():
		var list: Array = buckets[i]
		if list.is_empty():
			continue
		var vdef: Dictionary = FlowerMeshBuilder.VARIANTS[ids[i]]
		var mesh := FlowerMeshBuilder.build(ids[i])
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("head_height", vdef["head"])
		mat.set_shader_parameter("petal_a", vdef["a"])
		mat.set_shader_parameter("petal_b", vdef["b"])
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k][0])
			mm.set_instance_custom_data(k, Color(-1000.0, list[k][1], 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Wild_" + ids[i]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
