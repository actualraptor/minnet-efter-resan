class_name GrassField
extends Node3D
## Scatters wind-blown grass clumps over the terrain in chunked MultiMeshes so
## distant chunks are culled. Skips paths, the cottage pad and steep ground.

@export var material: ShaderMaterial
@export var radius := 78.0
@export var chunk_size := 12.0
@export var density := 4.2 ## clumps per square metre
@export var visibility_end := 62.0

var _clump_mesh: ArrayMesh


func _ready() -> void:
	if material == null:
		material = WorldMaterials.grass()
	_clump_mesh = _build_clump_mesh()
	if material:
		_clump_mesh.surface_set_material(0, material)
	_scatter()


func _build_clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldLayout.SEED + 101
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := 12
	for b in blades:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.22
		var root := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var h := rng.randf_range(0.2, 0.42)
		var w := rng.randf_range(0.022, 0.04)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0.0, sin(face)) * w
		var lean := Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(0.05, 0.2)
		var segs := 3
		var prev_l := root - side
		var prev_r := root + side
		for s in range(1, segs + 1):
			var t := float(s) / segs
			var center := root + Vector3(0.0, h * t, 0.0) + lean * t * t
			var width := 1.0 - t * 0.92
			var l := center - side * width
			var rr := center + side * width
			var t0 := float(s - 1) / segs
			_quad(st, prev_l, prev_r, rr, l, t0, t)
			prev_l = l
			prev_r = rr
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, t0: float, t1: float) -> void:
	for v in [[a, t0], [b, t0], [c, t1], [a, t0], [c, t1], [d, t1]]:
		st.set_color(Color(1, 1, 1, v[1]))
		st.add_vertex(v[0])


func _scatter() -> void:
	var terrain := MeadowTerrain.instance
	if terrain == null:
		push_warning("GrassField: no terrain")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldLayout.SEED + 202
	var chunks_per_side := int(ceil(radius * 2.0 / chunk_size))
	for cz in chunks_per_side:
		for cx in chunks_per_side:
			var origin := Vector2(-radius + cx * chunk_size, -radius + cz * chunk_size)
			var center := origin + Vector2.ONE * chunk_size * 0.5
			if center.length() > radius + chunk_size * 0.7:
				continue
			var xforms: Array[Transform3D] = []
			var tints: Array[float] = []
			var count := int(chunk_size * chunk_size * density)
			for i in count:
				var x := origin.x + rng.randf() * chunk_size
				var z := origin.y + rng.randf() * chunk_size
				if Vector2(x, z).length() > radius:
					continue
				var path := WorldLayout.path_amount(x, z)
				if path > 0.45 and rng.randf() < path * 1.4:
					continue
				if WorldLayout.cottage_rect_contains(Vector3(x, 0, z), 0.15):
					continue
				var n := terrain.normal_at(x, z)
				if n.y < 0.7:
					continue
				var y := terrain.height_at(x, z)
				var s := rng.randf_range(0.65, 1.15) * (1.0 - path * 0.6)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
				xforms.append(Transform3D(basis, Vector3(x - center.x, y - 0.02, z - center.y)))
				tints.append(rng.randf())
			if xforms.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = _clump_mesh
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
				mm.set_instance_custom_data(i, Color(tints[i], 0, 0, 0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.position = Vector3(center.x, 0.0, center.y)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = visibility_end
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)
