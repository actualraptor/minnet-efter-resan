class_name TownBuilder
extends WorldBuilder
## Dresses the Linköping slice: environment, river, cobbled square with its
## fountain and stalls, rows of townhouses along the streets, the three-towered
## cathedral, the stone bridge, farmsteads and fields south of the river, and
## the tree ring. Placement is authored in TownLayout; randomness is seeded.

const WATER_SHADER := preload("res://shaders/river_water.gdshader")

var _rng := RandomNumberGenerator.new()
var _chunks: Dictionary = {}                 # Vector2i -> TownMesh
var _colliders: StaticBody3D
var _footprints: Array[Rect2] = []           # world XZ rects houses occupy (with margin)
var _material: StandardMaterial3D
var _water_material: ShaderMaterial
var house_count := 0


func build(t: MeadowTerrain) -> void:
	terrain = t
	_rng.seed = TownLayout.SEED
	_material = TownMesh.material()
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter("ripples", WorldMaterials.detail_noise())
	_colliders = StaticBody3D.new()
	_colliders.name = "TownColliders"
	_colliders.collision_layer = 1 | 32
	_colliders.collision_mask = 0
	_colliders.add_to_group("building")
	add_child(_colliders)
	_environment()
	_town_light()
	_mountains()
	_river()
	_cathedral()
	_bridge()
	_square()
	_houses()
	_farms_and_fields()
	_lamps_and_banners()
	_tree_ring_town()
	_pollen_motes()
	_commit_chunks()


# --- helpers ---------------------------------------------------------------------------

## Town grading: a bit less sun and haze than the meadow, and a far depth-of-field
## that keeps the whole town sharp (the meadow blurs beyond 70 m).
func _town_light() -> void:
	sun.light_energy = 2.5
	var we := get_node("WorldEnvironment") as WorldEnvironment
	var env := we.environment
	env.tonemap_exposure = 0.92
	env.volumetric_fog_density = 0.0028
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 520.0
	env.adjustment_saturation = 1.12
	var ca := we.camera_attributes as CameraAttributesPractical
	if ca:
		ca.dof_blur_far_distance = 220.0
		ca.dof_blur_far_transition = 160.0
		ca.dof_blur_amount = 0.03


func _mesh_at(p: Vector2) -> TownMesh:
	var key := Vector2i(floori(p.x / 60.0), floori(p.y / 60.0))
	if not _chunks.has(key):
		_chunks[key] = TownMesh.new()
	return _chunks[key]


func _commit_chunks() -> void:
	for key in _chunks:
		var tm: TownMesh = _chunks[key]
		var mi := tm.commit(_material)
		mi.name = "Town_%d_%d" % [key.x, key.y]
		mi.visibility_range_end = 260.0
		mi.visibility_range_end_margin = 20.0
		add_child(mi)
	_chunks.clear()


func _box_collider(centre: Vector3, size: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), centre)
	_colliders.add_child(cs)


## Run `fn(mesh)` with the chunk mesh positioned at world (pos, yaw).
func _with_mesh(pos: Vector3, yaw: float, fn: Callable) -> void:
	var tm := _mesh_at(Vector2(pos.x, pos.z))
	tm.push(Transform3D(Basis(Vector3.UP, yaw), pos))
	fn.call(tm)
	tm.pop()


func _free_of_footprints(r: Rect2) -> bool:
	for f in _footprints:
		if f.intersects(r):
			return false
	return true


# --- river -----------------------------------------------------------------------------

func _river() -> void:
	var pts: Array[Vector2] = TownLayout.RIVER
	# Resample along the polyline with a Catmull-Rom feel via simple subdivision.
	var samples: Array[Vector2] = []
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in 8:
			var t := float(k) / 8.0
			samples.append(Vector2(
				_catmull(p0.x, p1.x, p2.x, p3.x, t), _catmull(p0.y, p1.y, p2.y, p3.y, t)))
	samples.append(pts[pts.size() - 1])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var along := 0.0
	var hw := TownLayout.RIVER_HALF_WIDTH + 1.3        # reaches under the banks
	for i in samples.size():
		var dir := samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]
		dir = dir.normalized()
		var n := Vector2(-dir.y, dir.x)
		if i > 0:
			along += samples[i].distance_to(samples[i - 1])
		var a := samples[i] + n * hw
		var b := samples[i] - n * hw
		verts.append(Vector3(a.x, TownLayout.WATER_LEVEL, a.y))
		verts.append(Vector3(b.x, TownLayout.WATER_LEVEL, b.y))
		norms.append_array([Vector3.UP, Vector3.UP])
		uvs.append(Vector2(0.0, along / 9.0))
		uvs.append(Vector2(1.0, along / 9.0))
	for i in samples.size() - 1:
		var k := i * 2
		# Wound so the surface faces up (clockwise from above in Godot).
		idx.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _water_material)
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _catmull(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


# --- cathedral & bridge -------------------------------------------------------------------

func _cathedral() -> void:
	var gy := terrain.height_at(0.0, TownLayout.CATHEDRAL_FRONT_Z)
	var origin := Vector3(0.0, gy, TownLayout.CATHEDRAL_FRONT_Z)
	var tm := _mesh_at(Vector2(0.0, TownLayout.CATHEDRAL_FRONT_Z))
	tm.push(Transform3D(Basis.IDENTITY, origin))
	var boxes := TownArchitecture.cathedral(tm, _rng)
	tm.pop()
	for b in boxes:
		_box_collider(origin + (b.pos as Vector3), b.size as Vector3)
	_footprints.append(Rect2(-18.0, TownLayout.CATHEDRAL_REAR_Z - 8.0, 36.0, 62.0))


func _bridge() -> void:
	var tm := _mesh_at(Vector2(0.0, 55.0))
	var boxes := TownArchitecture.bridge(tm, 0.0)
	for b in boxes:
		_box_collider(b.pos as Vector3, b.size as Vector3, 0.0, float(b.get("rot_x", 0.0)))
	_footprints.append(Rect2(-8.0, TownLayout.BRIDGE_Z0 - 8.0, 16.0, TownLayout.BRIDGE_Z1 - TownLayout.BRIDGE_Z0 + 16.0))


# --- the square ----------------------------------------------------------------------------

func _square() -> void:
	var y := terrain.height_at(0.0, 0.0)
	_with_mesh(Vector3(0, y, 0), 0.0, func(m: TownMesh): TownArchitecture.fountain(m))
	_box_collider(Vector3(0, y + 0.45, 0), Vector3(7.2, 0.9, 7.2))
	_box_collider(Vector3(0, y + 2.5, 0), Vector3(2.2, 5.0, 2.2))
	# Basin water.
	var disc := CylinderMesh.new()
	disc.top_radius = 3.25
	disc.bottom_radius = 3.25
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	disc.material = _water_material
	var wi := MeshInstance3D.new()
	wi.mesh = disc
	wi.position = Vector3(0, y + 0.66, 0)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)
	# Stalls: along the square's east and west sides and by the cathedral road.
	var stalls := [
		[-12.8, 6.0, 90.0], [-12.8, -3.5, 90.0], [12.8, 6.0, -90.0], [12.8, -3.5, -90.0],
		[-9.5, -9.0, 8.0], [9.5, -9.0, -8.0],
	]
	for s in stalls:
		var sy := terrain.height_at(s[0], s[1])
		_with_mesh(Vector3(s[0], sy, s[1]), deg_to_rad(s[2]), func(m: TownMesh): TownArchitecture.stall(m, _rng))
		_box_collider(Vector3(s[0], sy + 0.5, s[1]), Vector3(3.2, 1.0, 1.4), deg_to_rad(s[2]))
	# Benches round the fountain.
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		place("bench", cos(a) * 5.6, sin(a) * 5.6, rad_to_deg(-a) + 90.0 + 180.0, 1.0, 0.02)


# --- houses --------------------------------------------------------------------------------

func _houses() -> void:
	# Storgatan, both sides, from the square down to the river promenade.
	_row(Vector2(-5.4, 15.0), Vector2(0, 1), Vector2(1, 0), 25.0, 3)
	_row(Vector2(5.4, 15.0), Vector2(0, 1), Vector2(-1, 0), 25.0, 3)
	# Ågatan, east and west, north and south sides.
	for sx in [-1.0, 1.0]:
		_row(Vector2(sx * 19.0, -4.5), Vector2(sx, 0), Vector2(0, 1), 55.0, 3)
		_row(Vector2(sx * 19.0, 4.5), Vector2(sx, 0), Vector2(0, -1), 55.0, 3)
	# Second rows behind them, quieter and lower.
	for sx in [-1.0, 1.0]:
		_row(Vector2(sx * 21.0, -17.0), Vector2(sx, 0), Vector2(0, 1), 50.0, 2)
		_row(Vector2(sx * 21.0, 18.0), Vector2(sx, 0), Vector2(0, -1), 48.0, 2)
		# Riverfront row, fronts to the water.
		_row(Vector2(sx * 17.0, 38.5), Vector2(sx, 0), Vector2(0, 1), 60.0, 2)
	# The two tall halls that flank the cathedral road on the square's north side.
	for sx in [-1.0, 1.0]:
		_house_at(Vector3(sx * 11.8, 0.0, -19.6), 0.0, 10.6, 10.0, 3, false)


func _row(start: Vector2, dir: Vector2, face: Vector2, length: float, floors_hint: int) -> void:
	var t := 0.0
	while t < length - 7.0:
		var w := _rng.randf_range(7.4, 10.4)
		if t + w > length:
			break
		var d := _rng.randf_range(7.5, 9.5)
		var centre := start + dir * (t + w * 0.5) - face * (d * 0.5)
		var yaw := atan2(face.x, face.y)
		var floors := floors_hint
		var roll := _rng.randf()
		if floors_hint >= 3:
			floors = 3 if roll < 0.4 else 2
		else:
			floors = 2 if roll < 0.55 else 1
		var gable := _rng.randf() < 0.22
		if _house_at(Vector3(centre.x, 0.0, centre.y), yaw, w, d, floors, gable):
			t += w + _rng.randf_range(0.3, 1.2)
		else:
			t += 3.0


func _house_at(p: Vector3, yaw: float, w: float, d: float, floors: int, gable: bool) -> bool:
	# Footprint (axis-aligned bound of the rotated rectangle) must be clear.
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	var hx := (w * c + d * s) * 0.5 + 0.5
	var hz := (w * s + d * c) * 0.5 + 0.5
	var r := Rect2(p.x - hx, p.z - hz, hx * 2.0, hz * 2.0)
	if not _free_of_footprints(r):
		return false
	for corner in [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), r.get_center()]:
		if TownLayout.blocked(corner.x, corner.y, 0.4):
			return false
		if absf(corner.x) > 118.0 or absf(corner.y) > 118.0:
			return false
	var y := terrain.height_at(p.x, p.z)
	var hh := 0.0
	var tm := _mesh_at(Vector2(p.x, p.z))
	tm.push(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.z)))
	hh = TownArchitecture.house(tm, w, d, floors, _rng, gable)
	tm.pop()
	var wall := 3.3 + (floors - 1) * 2.85
	_box_collider(Vector3(p.x, y + wall * 0.5, p.z), Vector3(w, wall, d), yaw)
	_footprints.append(r)
	house_count += 1
	return true


# --- countryside --------------------------------------------------------------------------

func _farms_and_fields() -> void:
	# The round tower by the river.
	var tp := TownLayout.ROUND_TOWER_POS
	var ty := terrain.height_at(tp.x, tp.y)
	_with_mesh(Vector3(tp.x, ty, tp.y), 0.0, func(m: TownMesh): TownArchitecture.round_tower(m))
	_box_collider(Vector3(tp.x, ty + 6.0, tp.y), Vector3(6.4, 12.0, 6.4))
	_footprints.append(Rect2(tp.x - 6.0, tp.y - 6.0, 12.0, 12.0))
	# Farmsteads on the south bank.
	for f in [[-34.0, 94.0, 0.4, 11.0, 7.5], [-24.0, 104.0, -0.8, 14.0, 9.0], [42.0, 110.0, -0.5, 10.0, 7.5], [64.0, 92.0, 2.6, 9.0, 7.0]]:
		_house_at(Vector3(f[0], 0.0, f[1]), f[2], f[3], f[4], 1, false)
	# Crop fields: ridged strips in two golds, dark green between.
	var fields := [
		[Rect2(-80.0, 82.0, 38.0, 26.0), 0.1], [Rect2(-84.0, 112.0, 46.0, 30.0), -0.05],
		[Rect2(20.0, 118.0, 40.0, 26.0), 0.0], [Rect2(60.0, 100.0, 34.0, 26.0), 0.2],
		[Rect2(-30.0, 120.0, 30.0, 24.0), 0.0],
	]
	for fd in fields:
		_field(fd[0], fd[1])
	# Meadow side of the town north of Ågatan: a hay field and pasture trees come
	# from the tree ring; nothing else is needed.


func _field(rect: Rect2, angle: float) -> void:
	var centre := rect.get_center()
	var tm := _mesh_at(centre)
	var base := Color("#d2a94a")
	var alt := Color("#b8903a")
	var green := Color("#7f9a43")
	var row := 1.1
	var n := int(rect.size.x / row)
	var rot := Basis(Vector3.UP, angle)
	var wheat := _rng.randf() < 0.6
	for i in n:
		var lx := -rect.size.x * 0.5 + (i + 0.5) * row
		for seg in 3:
			var lz := -rect.size.y * 0.5 + (seg + 0.5) * rect.size.y / 3.0
			var wp := Vector3(centre.x, 0.0, centre.y) + rot * Vector3(lx, 0.0, lz)
			# Skip rows that run into streets, water or the cathedral.
			if TownLayout.blocked(wp.x, wp.z, 2.0) or wp.z < 66.0 or not _free_of_footprints(Rect2(wp.x - 1.0, wp.z - 1.0, 2.0, 2.0)):
				continue
			var gy := terrain.height_at(wp.x, wp.z)
			var col := (base if (i % 2 == 0) else alt) if wheat else green.lerp(Color("#5e8a3a"), float(i % 3) / 3.0)
			col = col.lightened(_rng.randf() * 0.06)
			tm.push(Transform3D(rot, Vector3(centre.x, 0, centre.y)))
			tm.box(lx, gy - 0.1, lz, row * 0.62, 0.55 if wheat else 0.3, rect.size.y / 3.0 - 0.15, col)
			tm.pop()


# --- lamps, banners, trees ---------------------------------------------------------------

func _lamps_and_banners() -> void:
	# Lamp posts along the main streets.
	for z in [18.0, 32.0, -18.0]:
		for sx in [-1.0, 1.0]:
			place("lamp_post", sx * 4.4, z, 0.0, 1.0, 0.0)
	for x in [-26.0, -42.0, -58.0, 26.0, 42.0, 58.0]:
		place("lamp_post", x, 3.4, 0.0, 1.0, 0.0)
	# Banners at the square's corners and along the cathedral road.
	var spots := [
		Vector3(-15.5, 0, -11.5), Vector3(15.5, 0, -11.5), Vector3(-15.5, 0, 11.5), Vector3(15.5, 0, 11.5),
		Vector3(-6.5, 0, -22.0), Vector3(6.5, 0, -22.0), Vector3(-6.0, 0, -29.0), Vector3(6.0, 0, -29.0),
	]
	for sp in spots:
		var y := terrain.height_at(sp.x, sp.z)
		_with_mesh(Vector3(sp.x, y, sp.z), _rng.randf_range(-0.2, 0.2), func(m: TownMesh): TownArchitecture.banner(m))
		_box_collider(Vector3(sp.x, y + 1.0, sp.z), Vector3(0.3, 2.0, 0.3))


func _tree_ring_town() -> void:
	var near := ["tree_oak_a", "tree_oak_b", "tree_oak_c", "tree_birch_a", "tree_birch_b"]
	var far := ["tree_pine_a", "tree_pine_b", "tree_pine_a", "tree_oak_c"]
	var count := 0
	var tries := 0
	while count < 170 and tries < 6000:
		tries += 1
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 148.0
		var p := Vector2(cos(a), sin(a)) * r
		# Keep the town itself, the fields and the river clear; trees gather on the
		# edges, along the river banks, and thicken into forest to the north.
		var d_town := p.distance_to(Vector2(0.0, -8.0))
		var near_bank := absf(TownLayout.river_distance(p.x, p.y) - 11.0) < 5.0
		var forest := p.y < -70.0 or r > 112.0
		if not (forest or near_bank or (d_town > 78.0 and _rng.randf() < 0.3)):
			continue
		if TownLayout.blocked(p.x, p.y, 4.0) or TownLayout.in_water_corridor(p.x, p.y, 3.0):
			continue
		if not _free_of_footprints(Rect2(p.x - 4.0, p.y - 4.0, 8.0, 8.0)):
			continue
		var crowded := false
		for q in _placed:
			if q.distance_to(p) < 6.0:
				crowded = true
				break
		if crowded:
			continue
		var list: Array = far if (r > 100.0 or p.y < -60.0) else near
		var model: String = list[_rng.randi() % list.size()]
		place(model, p.x, p.y, _rng.randf() * 360.0, _rng.randf_range(0.9, 1.45))
		count += 1


func _ambient_life() -> void:
	_pollen_motes()
