class_name ClipAudit
extends RefCounted
## Objective clipping measurement for skinned characters, at runtime.
##
## Every vertex of the "subject" meshes (hair, and the garments that are driven
## by spring bones) is skinned on the CPU to its current world position and
## tested against each "occluder" mesh (the body and the garments that stay put):
## the occluder's triangles are rasterised into a 1.2 cm voxel grid and a vertex
## counts as inside it when at least 4 of the 6 axis rays from it cross the
## surface an odd number of times (this survives open tubes, which have no
## interior in the strict sense: sleeves, tights, a blouse, a skirt).
##
## measure() returns, per subject mesh name: the number of tested vertices
## inside an occluder, the deepest (cm) and the occluder that holds them.

const CELL := 0.012
const MARGIN := 0.06
const MAX_RAY := 70       # cells

var skeleton: Skeleton3D
var _cache: Dictionary = {}   # mesh surface -> arrays


## `subjects` and `occluders`: Array of {mi: MeshInstance3D, surfaces: Array[int] (empty = all)}.
func measure(subjects: Array, occluders: Array, stride := 5) -> Dictionary:
	var out := {}
	var occ_world: Array = []
	for o in occluders:
		var tris := _skin_triangles(o["mi"], o.get("surfaces", []))
		if tris.size() >= 9:
			occ_world.append({"name": (o["mi"] as MeshInstance3D).name, "tris": tris})
	var grids: Array = []
	for o in occ_world:
		grids.append(_voxelize(o["tris"], o["name"]))
	for s in subjects:
		var mi: MeshInstance3D = s["mi"]
		var verts := _skin_vertices(mi, s.get("surfaces", []), stride)
		var res := {"tested": verts.size(), "inside": 0, "depth_cm": 0.0, "by": {}, "worst": Vector3.ZERO}
		for v in verts:
			for g in grids:
				var d := _inside_depth(g, v)
				if d >= 0.0:
					res["inside"] += 1
					res["by"][g["name"]] = int(res["by"].get(g["name"], 0)) + 1
					if d * 100.0 > float(res["depth_cm"]):
						res["depth_cm"] = d * 100.0
						res["worst"] = v
					break
		out[mi.name] = res
	return out


# --- skinning ------------------------------------------------------------------------

func _surface_arrays(mi: MeshInstance3D, surface: int) -> Dictionary:
	var key := "%d_%d" % [mi.mesh.get_instance_id(), surface]
	if not _cache.has(key):
		var a := mi.mesh.surface_get_arrays(surface)
		_cache[key] = {
			"v": a[Mesh.ARRAY_VERTEX] as PackedVector3Array,
			"b": a[Mesh.ARRAY_BONES] as PackedInt32Array if a[Mesh.ARRAY_BONES] != null else PackedInt32Array(),
			"w": a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array if a[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array(),
			"i": a[Mesh.ARRAY_INDEX] as PackedInt32Array if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(),
		}
	return _cache[key]


func _bind_transforms(mi: MeshInstance3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var skin := mi.skin
	if skin == null:
		return out
	for i in skin.get_bind_count():
		var bone := skeleton.find_bone(skin.get_bind_name(i))
		if bone < 0:
			bone = skin.get_bind_bone(i)
		var pose := skeleton.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
		out.append(pose * skin.get_bind_pose(i))
	return out


func _pos(a: Dictionary, k: int, binds: Array[Transform3D], skel_xf: Transform3D) -> Vector3:
	var v: Vector3 = a["v"][k]
	var bones: PackedInt32Array = a["b"]
	if bones.is_empty() or binds.is_empty():
		return skel_xf * v
	var per := bones.size() / (a["v"] as PackedVector3Array).size()
	var w: PackedFloat32Array = a["w"]
	var acc := Vector3.ZERO
	var tot := 0.0
	for j in per:
		var wt := w[k * per + j]
		if wt <= 0.0:
			continue
		var bi := bones[k * per + j]
		if bi < binds.size():
			acc += (binds[bi] * v) * wt
			tot += wt
	return skel_xf * (acc / tot if tot > 0.0 else v)


func _surfaces(mi: MeshInstance3D, only: Array) -> Array:
	var out := []
	for i in mi.mesh.get_surface_count():
		if only.is_empty() or i in only:
			out.append(i)
	return out


func _skin_vertices(mi: MeshInstance3D, only: Array, stride: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var binds := _bind_transforms(mi)
	var xf := skeleton.global_transform
	for s in _surfaces(mi, only):
		var a := _surface_arrays(mi, s)
		var n := (a["v"] as PackedVector3Array).size()
		var k := 0
		while k < n:
			out.append(_pos(a, k, binds, xf))
			k += stride
	return out


func _skin_triangles(mi: MeshInstance3D, only: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var binds := _bind_transforms(mi)
	var xf := skeleton.global_transform
	for s in _surfaces(mi, only):
		var a := _surface_arrays(mi, s)
		var n := (a["v"] as PackedVector3Array).size()
		var world := PackedVector3Array()
		world.resize(n)
		for k in n:
			world[k] = _pos(a, k, binds, xf)
		var idx: PackedInt32Array = a["i"]
		if idx.is_empty():
			for k in range(0, n - 2, 3):
				out.append(world[k])
				out.append(world[k + 1])
				out.append(world[k + 2])
		else:
			for k in range(0, idx.size() - 2, 3):
				out.append(world[idx[k]])
				out.append(world[idx[k + 1]])
				out.append(world[idx[k + 2]])
	return out


# --- voxels --------------------------------------------------------------------------

func _voxelize(tris: PackedVector3Array, label: String) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in tris:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector3.ONE * MARGIN
	hi += Vector3.ONE * MARGIN
	var dims := Vector3i(ceili((hi.x - lo.x) / CELL), ceili((hi.y - lo.y) / CELL), ceili((hi.z - lo.z) / CELL))
	var grid := PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	var step := CELL * 0.6
	for t in range(0, tris.size() - 2, 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var n := maxi(1, ceili(longest / step))
		for i in n + 1:
			var u := float(i) / n
			for j in n + 1 - i:
				var v := float(j) / n
				var p := a + (b - a) * u + (c - a) * v
				var ix := int((p.x - lo.x) / CELL)
				var iy := int((p.y - lo.y) / CELL)
				var iz := int((p.z - lo.z) / CELL)
				if ix >= 0 and iy >= 0 and iz >= 0 and ix < dims.x and iy < dims.y and iz < dims.z:
					grid[(iz * dims.y + iy) * dims.x + ix] = 1
	return {"name": label, "grid": grid, "lo": lo, "dims": dims}


## Depth (m) of `p` inside the occluder, or -1 when it is outside.
func _inside_depth(g: Dictionary, p: Vector3) -> float:
	var lo: Vector3 = g["lo"]
	var dims: Vector3i = g["dims"]
	var ix := int((p.x - lo.x) / CELL)
	var iy := int((p.y - lo.y) / CELL)
	var iz := int((p.z - lo.z) / CELL)
	if ix < 0 or iy < 0 or iz < 0 or ix >= dims.x or iy >= dims.y or iz >= dims.z:
		return -1.0
	var grid: PackedByteArray = g["grid"]
	var odd := 0
	var nearest := 999
	for d in 6:
		var dx := 0
		var dy := 0
		var dz := 0
		match d:
			0: dx = 1
			1: dx = -1
			2: dy = 1
			3: dy = -1
			4: dz = 1
			_: dz = -1
		var x := ix
		var y := iy
		var z := iz
		var crossings := 0
		var first := -1
		var in_surf := grid[(z * dims.y + y) * dims.x + x] != 0
		for s in range(1, MAX_RAY + 1):
			x += dx
			y += dy
			z += dz
			if x < 0 or y < 0 or z < 0 or x >= dims.x or y >= dims.y or z >= dims.z:
				break
			var on := grid[(z * dims.y + y) * dims.x + x] != 0
			if on and not in_surf:
				crossings += 1
				if first < 0:
					first = s
			in_surf = on
		if crossings % 2 == 1:
			odd += 1
			nearest = mini(nearest, first)
	if odd >= 4:
		return nearest * CELL
	return -1.0
