class_name MeadowTerrain
extends StaticBody3D
## Generates the rolling meadow: render mesh, heightmap collision and the data
## other systems query (height, normal, path mask). Deterministic from SEED.

static var instance: MeadowTerrain

@export var material: ShaderMaterial

var _n: int
var _heights := PackedFloat32Array()
var _pad_height := 0.0
var _noise_low := FastNoiseLite.new()
var _noise_mid := FastNoiseLite.new()
var _noise_rim := FastNoiseLite.new()


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group("terrain")
	collision_layer = 1 | 16
	collision_mask = 0
	if material == null:
		material = WorldMaterials.terrain()
	_setup_noise()
	_build_heights()
	_build_mesh()
	_build_collision()


func _setup_noise() -> void:
	_noise_low.seed = WorldLayout.SEED
	_noise_low.frequency = 0.016
	_noise_low.fractal_octaves = 3
	_noise_mid.seed = WorldLayout.SEED + 7
	_noise_mid.frequency = 0.06
	_noise_mid.fractal_octaves = 2
	_noise_rim.seed = WorldLayout.SEED + 13
	_noise_rim.frequency = 0.022
	_noise_rim.fractal_octaves = 4


func _raw_height(x: float, z: float) -> float:
	var h := _noise_low.get_noise_2d(x, z) * 2.2 + _noise_mid.get_noise_2d(x, z) * 0.35
	# The back meadow gently rises so it reads as a slope you look across.
	h += smoothstep(-6.0, -40.0, z) * 1.4
	var r := Vector2(x, z).length()
	var rim := smoothstep(44.0, 80.0, r)
	h += rim * rim * (11.0 + _noise_rim.get_noise_2d(x, z) * 9.0)
	h += smoothstep(85.0, 110.0, r) * 10.0
	return h


func _build_heights() -> void:
	_n = int(WorldLayout.TERRAIN_HALF * 2.0 / WorldLayout.TERRAIN_STEP) + 1
	_heights.resize(_n * _n)
	_pad_height = _raw_height(WorldLayout.COTTAGE_POS.x, WorldLayout.COTTAGE_POS.z)
	var c := WorldLayout.COTTAGE_POS
	var hx := WorldLayout.COTTAGE_HALF.x
	var hz := WorldLayout.COTTAGE_HALF.y
	for iz in _n:
		for ix in _n:
			var x := -WorldLayout.TERRAIN_HALF + ix * WorldLayout.TERRAIN_STEP
			var z := -WorldLayout.TERRAIN_HALF + iz * WorldLayout.TERRAIN_STEP
			var h := _raw_height(x, z)
			# Flatten a pad for the cottage with a soft shoulder.
			var dx := maxf(absf(x - c.x) - hx, 0.0)
			var dz := maxf(absf(z - c.z) - hz, 0.0)
			var pad := 1.0 - smoothstep(0.0, 5.0, sqrt(dx * dx + dz * dz))
			h = lerpf(h, _pad_height, pad)
			# Paths are slightly worn into the ground.
			h -= WorldLayout.path_amount(x, z) * 0.07
			_heights[iz * _n + ix] = h


func pad_height() -> float:
	return _pad_height


func _grid(ix: int, iz: int) -> float:
	return _heights[clampi(iz, 0, _n - 1) * _n + clampi(ix, 0, _n - 1)]


## Bilinear height consistent with the rendered mesh and collision.
func height_at(x: float, z: float) -> float:
	var fx := (x + WorldLayout.TERRAIN_HALF) / WorldLayout.TERRAIN_STEP
	var fz := (z + WorldLayout.TERRAIN_HALF) / WorldLayout.TERRAIN_STEP
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var tx := fx - ix
	var tz := fz - iz
	# Match triangle split used by the mesh (diagonal from (0,0) to (1,1)).
	var h00 := _grid(ix, iz)
	var h11 := _grid(ix + 1, iz + 1)
	if tx > tz:
		var h10 := _grid(ix + 1, iz)
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	var h01 := _grid(ix, iz + 1)
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func normal_at(x: float, z: float) -> Vector3:
	var e := WorldLayout.TERRAIN_STEP
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func _build_mesh() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(_n * _n)
	normals.resize(_n * _n)
	colors.resize(_n * _n)
	uvs.resize(_n * _n)
	var vary := FastNoiseLite.new()
	vary.seed = WorldLayout.SEED + 3
	vary.frequency = 0.045
	for iz in _n:
		for ix in _n:
			var x := -WorldLayout.TERRAIN_HALF + ix * WorldLayout.TERRAIN_STEP
			var z := -WorldLayout.TERRAIN_HALF + iz * WorldLayout.TERRAIN_STEP
			var i := iz * _n + ix
			verts[i] = Vector3(x, _heights[i], z)
			var e := WorldLayout.TERRAIN_STEP
			normals[i] = Vector3(_grid(ix - 1, iz) - _grid(ix + 1, iz), 2.0 * e, _grid(ix, iz - 1) - _grid(ix, iz + 1)).normalized()
			var r := Vector2(x, z).length()
			colors[i] = Color(WorldLayout.path_amount(x, z), vary.get_noise_2d(x, z) * 0.5 + 0.5, smoothstep(44.0, 90.0, r), 1.0)
			uvs[i] = Vector2(x, z)
	for iz in _n - 1:
		for ix in _n - 1:
			var a := iz * _n + ix
			var b := a + 1
			var c := a + _n
			var d := c + 1
			idx.append_array([a, b, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = _n
	shape.map_depth = _n
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i in _heights.size():
		scaled[i] = _heights[i] / WorldLayout.TERRAIN_STEP
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.name = "TerrainCollision"
	cs.shape = shape
	cs.scale = Vector3.ONE * WorldLayout.TERRAIN_STEP
	add_child(cs)
