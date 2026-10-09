class_name FlowerMeshBuilder
extends RefCounted
## Builds the original low-poly flower variants used by the Field of Flowers.
## Vertex COLOR.rgb = base colour, COLOR.a = part (0 stem/leaf, 0.5 centre, 1 petal).
## Every variant's head pivot is at (0, head_height, 0) so the shader can bloom it.

const STEM := Color(0.30, 0.55, 0.22, 0.0)
const LEAF := Color(0.36, 0.62, 0.25, 0.0)

## id -> {head_height, petal_a, petal_b, glow}
const VARIANTS := {
	"meadow_daisy": {"head": 0.30, "a": Color(1.0, 0.98, 0.93), "b": Color(1.0, 0.92, 0.95), "weight": 1.2},
	"sky_bell": {"head": 0.34, "a": Color(0.45, 0.55, 0.95), "b": Color(0.62, 0.48, 0.92), "weight": 0.9},
	"rose_cosmos": {"head": 0.42, "a": Color(0.98, 0.56, 0.72), "b": Color(0.95, 0.72, 0.86), "weight": 1.0},
	"sun_buttercup": {"head": 0.22, "a": Color(1.0, 0.84, 0.25), "b": Color(1.0, 0.70, 0.22), "weight": 1.0},
	"plum_tulip": {"head": 0.38, "a": Color(0.62, 0.30, 0.62), "b": Color(0.95, 0.45, 0.42), "weight": 0.7},
	"lupin_spire": {"head": 0.46, "a": Color(0.56, 0.42, 0.9), "b": Color(0.78, 0.55, 0.95), "weight": 0.6},
}


static func build(id: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = VARIANTS[id]["head"]
	match id:
		"meadow_daisy":
			_stem(st, h, 0.012, 0.03)
			_leaf(st, Vector3(0, 0.04, 0), 0.0, 0.11)
			_leaf(st, Vector3(0, 0.07, 0), PI * 0.9, 0.09)
			_petal_ring(st, Vector3(0, h, 0), 13, 0.075, 0.018, 0.15, 0.0)
			_dome(st, Vector3(0, h, 0), 0.028, 0.018, Color(1.0, 0.78, 0.18, 0.5))
		"sky_bell":
			_stem(st, h, 0.01, 0.06)
			_leaf(st, Vector3(0, 0.03, 0), 0.5, 0.14)
			_leaf(st, Vector3(0, 0.03, 0), 3.6, 0.12)
			for i in 3:
				var a := float(i) * 2.1
				var p := Vector3(cos(a) * 0.035, h - i * 0.05, sin(a) * 0.035)
				_bell(st, p, 0.032, 0.05)
		"rose_cosmos":
			_stem(st, h, 0.012, 0.04)
			_leaf(st, Vector3(0, 0.1, 0), 1.0, 0.1)
			_leaf(st, Vector3(0, 0.18, 0), 4.0, 0.08)
			_petal_ring(st, Vector3(0, h, 0), 8, 0.085, 0.04, 0.25, 0.0)
			_dome(st, Vector3(0, h, 0), 0.024, 0.016, Color(0.98, 0.72, 0.25, 0.5))
		"sun_buttercup":
			_stem(st, h, 0.01, 0.02)
			_leaf(st, Vector3(0, 0.02, 0), 2.0, 0.08)
			_petal_ring(st, Vector3(0, h, 0), 5, 0.05, 0.035, 0.75, 0.0)
			_dome(st, Vector3(0, h + 0.004, 0), 0.016, 0.012, Color(0.9, 0.62, 0.1, 0.5))
		"plum_tulip":
			_stem(st, h, 0.014, 0.015)
			_leaf(st, Vector3(0, 0.02, 0), 0.3, 0.2)
			_leaf(st, Vector3(0, 0.02, 0), 3.5, 0.18)
			_petal_ring(st, Vector3(0, h - 0.02, 0), 6, 0.075, 0.045, 1.25, 0.6)
		"lupin_spire":
			_stem(st, h + 0.16, 0.012, 0.01)
			for k in 5:
				_leaf(st, Vector3(0, 0.03, 0), k * 1.26, 0.11)
			for i in 9:
				var y := h - 0.14 + i * 0.035
				_petal_ring(st, Vector3(0, y, 0), 5, 0.04 * (1.0 - i * 0.075), 0.022, -0.2, 0.4)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, c: Color, a: Vector3, b: Vector3, d: Vector3) -> void:
	st.set_color(c)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(d)


static func _stem(st: SurfaceTool, height: float, r: float, bend: float) -> void:
	var segs := 4
	var sides := 4
	for s in segs:
		var t0 := float(s) / segs
		var t1 := float(s + 1) / segs
		var c0 := Vector3(sin(t0 * PI) * bend, height * t0, 0)
		var c1 := Vector3(sin(t1 * PI) * bend, height * t1, 0)
		var r0 := r * (1.0 - t0 * 0.35)
		var r1 := r * (1.0 - t1 * 0.35)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00 := c0 + Vector3(cos(a0), 0, sin(a0)) * r0
			var p01 := c0 + Vector3(cos(a1), 0, sin(a1)) * r0
			var p10 := c1 + Vector3(cos(a0), 0, sin(a0)) * r1
			var p11 := c1 + Vector3(cos(a1), 0, sin(a1)) * r1
			_tri(st, STEM, p00, p10, p11)
			_tri(st, STEM, p00, p11, p01)


static func _leaf(st: SurfaceTool, base: Vector3, yaw: float, length: float) -> void:
	var dir := Vector3(cos(yaw), 0, sin(yaw))
	var side := Vector3(-dir.z, 0, dir.x)
	var mid := base + dir * length * 0.5 + Vector3(0, length * 0.35, 0)
	var tip := base + dir * length + Vector3(0, length * 0.2, 0)
	var w := length * 0.22
	_tri(st, LEAF, base, mid + side * w, mid)
	_tri(st, LEAF, base, mid, mid - side * w)
	_tri(st, LEAF, mid, mid + side * w, tip)
	_tri(st, LEAF, mid, tip, mid - side * w)


## tilt: radians the petals lift from horizontal. cup > 0 curls tips inward.
static func _petal_ring(st: SurfaceTool, center: Vector3, count: int, length: float, width: float, tilt: float, cup: float) -> void:
	for i in count:
		var a := TAU * i / count + (0.15 if i % 2 else 0.0)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var up := Vector3.UP
		var out1 := (dir * cos(tilt) + up * sin(tilt)).normalized()
		var tilt2 := tilt + cup
		var out2 := (dir * cos(tilt2) + up * sin(tilt2)).normalized()
		var base := center + dir * 0.008
		var mid := base + out1 * length * 0.5
		var tip := mid + out2 * length * 0.5
		var pc := Color(1, 1, 1, 1.0)
		var root_c := Color(0.93, 0.93, 0.93, 1.0)
		st.set_color(root_c)
		st.add_vertex(base)
		st.set_color(pc)
		st.add_vertex(mid + side * width)
		st.add_vertex(mid)
		st.set_color(root_c)
		st.add_vertex(base)
		st.set_color(pc)
		st.add_vertex(mid)
		st.add_vertex(mid - side * width)
		_tri(st, pc, mid, mid + side * width, tip)
		_tri(st, pc, mid, tip, mid - side * width)


static func _dome(st: SurfaceTool, center: Vector3, r: float, h: float, c: Color) -> void:
	var sides := 8
	var top := center + Vector3(0, h, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := center + Vector3(cos(a0) * r, h * 0.2, sin(a0) * r)
		var p1 := center + Vector3(cos(a1) * r, h * 0.2, sin(a1) * r)
		_tri(st, c, p0, top, p1)


## A drooping bell: open end faces down.
static func _bell(st: SurfaceTool, top: Vector3, r: float, depth: float) -> void:
	var sides := 6
	var pc := Color(1, 1, 1, 1.0)
	var bottom := top - Vector3(0, depth, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var m0 := top + Vector3(cos(a0) * r * 0.75, -depth * 0.45, sin(a0) * r * 0.75)
		var m1 := top + Vector3(cos(a1) * r * 0.75, -depth * 0.45, sin(a1) * r * 0.75)
		var b0 := bottom + Vector3(cos(a0) * r * 1.15, 0, sin(a0) * r * 1.15)
		var b1 := bottom + Vector3(cos(a1) * r * 1.15, 0, sin(a1) * r * 1.15)
		_tri(st, pc, top, m1, m0)
		_tri(st, pc, m0, m1, b1)
		_tri(st, pc, m0, b1, b0)
