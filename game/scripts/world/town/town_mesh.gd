class_name TownMesh
extends RefCounted
## Tiny flat-shaded mesh builder for the town's architecture: boxes, gabled
## roofs, spires, pointed windows. Everything is vertex-coloured and ends up in
## one ArrayMesh (one draw call per material). A transform stack places pieces
## in a building's local frame. Winding is resolved from an outward "hint"
## normal, so callers never think about triangle order.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _stack: Array[Transform3D] = []
var xf := Transform3D.IDENTITY


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


func triangle_count() -> int:
	return _v.size() / 3


# --- primitives -------------------------------------------------------------------------

func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var h := xf.basis * hint
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(h) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var nn := -n.normalized()
	_v.append_array([a, b, c])
	_n.append_array([nn, nn, nn])
	_c.append_array([col, col, col])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint: Vector3, col_top: Color = Color(0, 0, 0, -1)) -> void:
	# col_top (optional) darkens/lightens the far edge for a baked gradient.
	tri(a, b, c, col, hint)
	tri(a, c, d, col, hint)


## Axis-aligned box (in the current frame) from its bottom-centre.
func box(cx: float, y0: float, cz: float, sx: float, sy: float, sz: float, col: Color, bottom := false, grime := 0.0) -> void:
	var x0 := cx - sx * 0.5
	var x1 := cx + sx * 0.5
	var z0 := cz - sz * 0.5
	var z1 := cz + sz * 0.5
	var y1 := y0 + sy
	var low := col.darkened(grime)
	_face(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), low, col, Vector3(0, 0, 1))
	_face(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), low, col, Vector3(0, 0, -1))
	_face(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), low, col, Vector3(1, 0, 0))
	_face(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), low, col, Vector3(-1, 0, 0))
	quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), col.lightened(0.04), Vector3.UP)
	if bottom:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), low, Vector3.DOWN)


## A wall face whose bottom edge is `low` and top edge is `high` coloured.
func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color, hint: Vector3) -> void:
	if low == high:
		quad(a, b, c, d, high, hint)
		return
	# Split so the colour fades up the face (a,b bottom; c,d top).
	var h := xf.basis * hint
	_tri_col(a, b, c, low, low, high, hint, h)
	_tri_col(a, c, d, low, high, high, hint, h)


func _tri_col(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, hint: Vector3, _h: Vector3) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var h := xf.basis * hint
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(h) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	var nn := -n.normalized()
	_v.append_array([a, b, c])
	_n.append_array([nn, nn, nn])
	_c.append_array([ca, cb, cc])


## Gabled roof over a rectangle centred at (cx, cz) with eave height y0. The
## ridge runs along X when along_x, else along Z. Includes the end gables
## (wall-coloured) and a slight overhang.
func gable(cx: float, y0: float, cz: float, sx: float, sz: float, rise: float, col: Color, gable_col: Color, along_x := true, over_eave := 0.55, over_end := 0.35) -> void:
	var hx := sx * 0.5 + (over_end if along_x else over_eave)
	var hz := sz * 0.5 + (over_eave if along_x else over_end)
	var yb := y0 - 0.1
	var lo := col.darkened(0.12)
	if along_x:
		var r0 := Vector3(cx - hx, y0 + rise, cz)
		var r1 := Vector3(cx + hx, y0 + rise, cz)
		var f0 := Vector3(cx - hx, yb, cz + hz)
		var f1 := Vector3(cx + hx, yb, cz + hz)
		var b0 := Vector3(cx - hx, yb, cz - hz)
		var b1 := Vector3(cx + hx, yb, cz - hz)
		var nf := Vector3(0, hz, rise).normalized()
		var nb := Vector3(0, hz, -rise).normalized()
		_face(f0, f1, r1, r0, lo, col, nf)
		_face(b1, b0, r0, r1, lo, col, nb)
		# Underside so the overhang isn't hollow.
		quad(f0, f1, b1, b0, lo.darkened(0.25), Vector3.DOWN)
		# Gable triangles (in the wall plane, slightly inside the overhang).
		var gx0 := cx - sx * 0.5
		var gx1 := cx + sx * 0.5
		tri(Vector3(gx0, y0, cz + sz * 0.5), Vector3(gx0, y0, cz - sz * 0.5), Vector3(gx0, y0 + rise * (sz * 0.5) / hz, cz), gable_col, Vector3(-1, 0, 0))
		tri(Vector3(gx1, y0, cz - sz * 0.5), Vector3(gx1, y0, cz + sz * 0.5), Vector3(gx1, y0 + rise * (sz * 0.5) / hz, cz), gable_col, Vector3(1, 0, 0))
	else:
		var r0 := Vector3(cx, y0 + rise, cz - hz)
		var r1 := Vector3(cx, y0 + rise, cz + hz)
		var l0 := Vector3(cx - hx, yb, cz - hz)
		var l1 := Vector3(cx - hx, yb, cz + hz)
		var m0 := Vector3(cx + hx, yb, cz - hz)
		var m1 := Vector3(cx + hx, yb, cz + hz)
		var nl := Vector3(-rise, hx, 0).normalized()
		var nr := Vector3(rise, hx, 0).normalized()
		_face(l0, l1, r1, r0, lo, col, nl)
		_face(m1, m0, r0, r1, lo, col, nr)
		quad(l0, l1, m1, m0, lo.darkened(0.25), Vector3.DOWN)
		var gz0 := cz - sz * 0.5
		var gz1 := cz + sz * 0.5
		tri(Vector3(cx + sx * 0.5, y0, gz1), Vector3(cx - sx * 0.5, y0, gz1), Vector3(cx, y0 + rise * (sx * 0.5) / hx, gz1), gable_col, Vector3(0, 0, 1))
		tri(Vector3(cx - sx * 0.5, y0, gz0), Vector3(cx + sx * 0.5, y0, gz0), Vector3(cx, y0 + rise * (sx * 0.5) / hx, gz0), gable_col, Vector3(0, 0, -1))


## Pyramid / spire on a regular polygon of `sides`, base circumradius r at y0,
## apex at y0 + h. Optional `top_r` truncates it.
func spire(cx: float, y0: float, cz: float, r: float, h: float, col: Color, sides := 8, top_r := 0.0, rot := 0.0) -> void:
	var apex := Vector3(cx, y0 + h, cz)
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var p0 := Vector3(cx + cos(a0) * r, y0, cz + sin(a0) * r)
		var p1 := Vector3(cx + cos(a1) * r, y0, cz + sin(a1) * r)
		var mid := (a0 + a1) * 0.5
		var hint := Vector3(cos(mid) * h, r, sin(mid) * h).normalized()
		var shade := col.lightened(0.08) if (i % 2 == 0) else col.darkened(0.06)
		if top_r <= 0.001:
			tri(p0, p1, apex, shade, hint)
		else:
			var q0 := Vector3(cx + cos(a0) * top_r, y0 + h, cz + sin(a0) * top_r)
			var q1 := Vector3(cx + cos(a1) * top_r, y0 + h, cz + sin(a1) * top_r)
			quad(p0, p1, q1, q0, shade, hint)


## Straight prism on a regular polygon (towers, columns, drums).
func drum(cx: float, y0: float, cz: float, r: float, h: float, col: Color, sides := 8, rot := 0.0, cap := true) -> void:
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var p0 := Vector3(cx + cos(a0) * r, y0, cz + sin(a0) * r)
		var p1 := Vector3(cx + cos(a1) * r, y0, cz + sin(a1) * r)
		var mid := (a0 + a1) * 0.5
		var hint := Vector3(cos(mid), 0, sin(mid))
		var q0 := p0 + Vector3(0, h, 0)
		var q1 := p1 + Vector3(0, h, 0)
		_face(p0, p1, q1, q0, col.darkened(0.08), col, hint)
		if cap:
			tri(Vector3(cx, y0 + h, cz), q0, q1, col.lightened(0.05), Vector3.UP)


## Thin vertical facade decal in the plane z = zc (front +Z or back -Z by sign),
## centred at x, from y to y + h. Used for windows, doors and banners.
func decal_z(x: float, y: float, zc: float, w: float, h: float, col: Color, sign := 1.0) -> void:
	var hz := Vector3(0, 0, sign)
	quad(Vector3(x - w * 0.5, y, zc), Vector3(x + w * 0.5, y, zc), Vector3(x + w * 0.5, y + h, zc), Vector3(x - w * 0.5, y + h, zc), col, hz)


func decal_x(xc: float, y: float, z: float, w: float, h: float, col: Color, sign := 1.0) -> void:
	var hx := Vector3(sign, 0, 0)
	quad(Vector3(xc, y, z - w * 0.5), Vector3(xc, y, z + w * 0.5), Vector3(xc, y + h, z + w * 0.5), Vector3(xc, y + h, z - w * 0.5), col, hx)


## Pointed (lancet) window on a facade. axis_z: facade normal is ±Z (else ±X).
func pointed_window(x: float, y: float, plane: float, w: float, h: float, col: Color, axis_z := true, sign := 1.0) -> void:
	var body := h * 0.72
	var tip := h
	if axis_z:
		decal_z(x, y, plane, w, body, col, sign)
		tri(Vector3(x - w * 0.5, y + body, plane), Vector3(x + w * 0.5, y + body, plane), Vector3(x, y + tip, plane), col, Vector3(0, 0, sign))
	else:
		decal_x(plane, y, x, w, body, col, sign)
		tri(Vector3(plane, y + body, x - w * 0.5), Vector3(plane, y + body, x + w * 0.5), Vector3(plane, y + tip, x), col, Vector3(sign, 0, 0))


# --- output -------------------------------------------------------------------------------

func commit(material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


static func material(rough := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = 0.25
	return m
