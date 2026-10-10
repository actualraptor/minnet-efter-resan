class_name MagicCircle
extends Node3D
## Procedural magic circle: thin glowing rings, ticks and a polygon sigil built as
## flat geometry in the local XY plane (normal = +Z), drawn additively. Parts spin
## at different rates. Used by the staff spells' charge visuals and the barrier.

enum Style { RUNE, PETAL }

var radius := 1.0
var color := Color(0.8, 0.9, 1.0)
var _mat: StandardMaterial3D
var _parts: Array[Node3D] = []
var _rates: Array[float] = []
var alpha := 1.0:
	set(v):
		alpha = v
		if _mat:
			_mat.albedo_color.a = v


func build(r: float, c: Color, style: Style = Style.RUNE) -> MagicCircle:
	radius = r
	color = c
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, alpha)
	_mat.disable_receive_shadows = true
	match style:
		Style.RUNE:
			_build_rune()
		Style.PETAL:
			_build_petal()
	return self


func _process(delta: float) -> void:
	for i in _parts.size():
		_parts[i].rotate_z(_rates[i] * delta)


func _add_part(g: Array, rate: float) -> void:
	var verts: PackedVector3Array = g[0]
	var idx: PackedInt32Array = g[1]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.append(mi)
	_rates.append(rate)


# --- geometry helpers: each returns [verts, indices] ----------------------------------

static func _new() -> Array:
	return [PackedVector3Array(), PackedInt32Array()]


## Arc band between radii r0..r1 over [a0, a1] radians.
static func _arc(g: Array, r0: float, r1: float, a0: float, a1: float, segs: int) -> void:
	var v: PackedVector3Array = g[0]
	var ix: PackedInt32Array = g[1]
	var base := v.size()
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / segs)
		var d := Vector3(cos(a), sin(a), 0.0)
		v.append(d * r0)
		v.append(d * r1)
	for i in segs:
		var k := base + i * 2
		ix.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])


## Straight line of width w.
static func _line(g: Array, p0: Vector3, p1: Vector3, w: float) -> void:
	var v: PackedVector3Array = g[0]
	var ix: PackedInt32Array = g[1]
	var d := (p1 - p0).normalized()
	var n := Vector3(-d.y, d.x, 0.0) * (w * 0.5)
	var k := v.size()
	v.append_array([p0 - n, p0 + n, p1 - n, p1 + n])
	ix.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])


## Closed regular polygon outline.
static func _poly(g: Array, r: float, n: int, rot: float, w: float) -> void:
	for i in n:
		var a0 := rot + TAU * i / n
		var a1 := rot + TAU * (i + 1) / n
		_line(g, Vector3(cos(a0), sin(a0), 0.0) * r, Vector3(cos(a1), sin(a1), 0.0) * r, w)


static func _dot(g: Array, c: Vector3, r: float) -> void:
	var v: PackedVector3Array = g[0]
	var ix: PackedInt32Array = g[1]
	var k := v.size()
	v.append(c)
	for i in 8:
		var a := TAU * i / 8.0
		v.append(c + Vector3(cos(a), sin(a), 0.0) * r)
	for i in 8:
		ix.append_array([k, k + 1 + i, k + 1 + (i + 1) % 8])


func _build_rune() -> void:
	var r := radius
	# Fixed outer rings.
	var outer := _new()
	_arc(outer, r * 0.965, r * 1.0, 0.0, TAU, 72)
	_arc(outer, r * 0.90, r * 0.91, 0.0, TAU, 72)
	_add_part(outer, 0.0)
	# Dashed band + ticks, turning one way.
	var dash := _new()
	for i in 24:
		var a := TAU * i / 24.0
		_arc(dash, r * 0.80, r * 0.86, a, a + TAU / 24.0 * 0.62, 5)
	for i in 48:
		var a := TAU * i / 48.0
		_line(dash, Vector3(cos(a), sin(a), 0.0) * r * 0.885, Vector3(cos(a), sin(a), 0.0) * r * 0.895, r * 0.012)
	_add_part(dash, 0.32)
	# Sigil (two triangles + inner ring), turning the other way.
	var sigil := _new()
	_poly(sigil, r * 0.76, 3, PI / 2.0, r * 0.014)
	_poly(sigil, r * 0.76, 3, -PI / 2.0, r * 0.014)
	_arc(sigil, r * 0.40, r * 0.415, 0.0, TAU, 48)
	_poly(sigil, r * 0.40, 6, 0.0, r * 0.01)
	for i in 6:
		var a := PI / 2.0 + TAU * i / 6.0
		_dot(sigil, Vector3(cos(a), sin(a), 0.0) * r * 0.76, r * 0.03)
	_add_part(sigil, -0.55)
	var core := _new()
	_dot(core, Vector3.ZERO, r * 0.06)
	_add_part(core, 0.0)


func _build_petal() -> void:
	var r := radius
	var outer := _new()
	_arc(outer, r * 0.97, r * 1.0, 0.0, TAU, 80)
	_arc(outer, r * 0.30, r * 0.315, 0.0, TAU, 48)
	_add_part(outer, 0.0)
	# Petals: lens outlines between the inner ring and the outer band.
	var petals := _new()
	var n := 8
	for i in n:
		var a := TAU * i / n
		var pts: Array[Vector3] = []
		for k in 13:
			var u := float(k) / 12.0
			var along := lerpf(0.32, 0.92, u)
			var half := sin(u * PI) * 0.17 * (1.0 - u * 0.25)
			pts.append(Vector3(along, half, 0.0))
		for side in [1.0, -1.0]:
			for k in 12:
				var p0: Vector3 = pts[k]
				var p1: Vector3 = pts[k + 1]
				p0.y *= side
				p1.y *= side
				_line(petals, p0.rotated(Vector3.BACK, a) * r, p1.rotated(Vector3.BACK, a) * r, r * 0.012)
	_add_part(petals, 0.28)
	var dots := _new()
	for i in 16:
		var a := TAU * i / 16.0 + TAU / 32.0
		_dot(dots, Vector3(cos(a), sin(a), 0.0) * r * 0.935, r * 0.022)
	_add_part(dots, -0.45)
