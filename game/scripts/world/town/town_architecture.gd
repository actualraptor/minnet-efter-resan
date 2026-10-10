class_name TownArchitecture
extends RefCounted
## Procedural medieval-fantasy architecture for the Linköping slice. All pieces
## are drawn into a TownMesh in a local frame (origin on the ground, +Z the
## front). Palettes follow the concept art: cream, rose and ochre plaster,
## timber, red tile and slate, with a pale stone cathedral.

const PLASTER: Array[Color] = [
	Color("#eadcc0"), Color("#e6c9b4"), Color("#e9c98b"), Color("#cfd8d2"),
	Color("#d6cdb0"), Color("#e3b9a2"), Color("#f0e6d2"), Color("#c9d3b4"),
]
const ROOFS: Array[Color] = [
	Color("#9c4a36"), Color("#a65a3a"), Color("#7f3d33"), Color("#4d5160"), Color("#6a5b4a"), Color("#8e4f3a"),
]
const SHUTTER: Array[Color] = [Color("#5a7a58"), Color("#4f6b8a"), Color("#8a4a3c"), Color("#6b5037"), Color("#7a5a8a")]
const TIMBER := Color("#4a3426")
const STONE := Color("#a89a86")
const STONE_DARK := Color("#7d725f")
const STONE_LIGHT := Color("#c9bda6")
const GLASS := Color("#2c3d54")
const DOOR := Color("#5b3a24")
const SLATE := Color("#394155")
const SLATE_LIGHT := Color("#4d566b")


# --- houses -------------------------------------------------------------------------------

## A townhouse, `w` wide (X) by `d` deep (Z), front at +Z. Returns the roof ridge
## height so callers can place smoke/etc.
static func house(m: TownMesh, w: float, d: float, floors: int, rng: RandomNumberGenerator, gable_front := false) -> float:
	var plaster: Color = PLASTER[rng.randi() % PLASTER.size()]
	var roof: Color = ROOFS[rng.randi() % ROOFS.size()]
	var shutter: Color = SHUTTER[rng.randi() % SHUTTER.size()]
	var floor_h := 2.85
	var wall_h := 3.3 + float(floors - 1) * floor_h
	var plinth := 0.55
	# Body.
	m.box(0, 0, 0, w + 0.14, plinth, d + 0.14, STONE.darkened(rng.randf() * 0.1), false, 0.2)
	m.box(0, plinth, 0, w, wall_h - plinth, d, plaster, false, 0.16)
	for f in range(1, floors):
		var y := plinth + 2.75 + (f - 1) * floor_h
		m.box(0, y, 0, w + 0.1, 0.16, d + 0.1, plaster.lightened(0.15))
	# Roof: ridge along the street unless the gable faces it.
	var span := w if gable_front else d
	var rise := span * 0.5 * 0.92
	m.gable(0, wall_h, 0, w, d, rise, roof, plaster, not gable_front)
	# Ridge cap.
	if gable_front:
		m.box(0, wall_h + rise - 0.05, 0, 0.22, 0.2, d + 0.7, roof.darkened(0.25))
	else:
		m.box(0, wall_h + rise - 0.05, 0, w + 0.7, 0.2, 0.22, roof.darkened(0.25))
	# Chimney.
	var cx := w * (0.5 - 0.18) * (1.0 if rng.randf() < 0.5 else -1.0)
	if gable_front:
		m.box(w * 0.18, wall_h + rise * 0.3, -d * 0.2, 0.85, rise * 0.75 + 0.6, 0.85, STONE_DARK)
		m.box(w * 0.18, wall_h + rise * 1.05 + 0.5, -d * 0.2, 1.05, 0.22, 1.05, STONE)
	else:
		m.box(cx, wall_h + rise * 0.35, 0.0, 0.85, rise * 0.7 + 0.6, 0.85, STONE_DARK)
		m.box(cx, wall_h + rise * 1.05 + 0.4, 0.0, 1.05, 0.22, 1.05, STONE)
	# Facades.
	var half_timber := rng.randf() < 0.35 and floors >= 2
	_facade_z(m, w, wall_h, d * 0.5, 1.0, floors, rng, shutter, plaster, true, half_timber)
	_facade_z(m, w, wall_h, -d * 0.5, -1.0, floors, rng, shutter, plaster, false, false)
	_facade_x(m, d, wall_h, w * 0.5, 1.0, floors, rng, plaster)
	_facade_x(m, d, wall_h, -w * 0.5, -1.0, floors, rng, plaster)
	# Dormer on tall houses with a long roof.
	if not gable_front and floors >= 2 and w > 8.0 and rng.randf() < 0.55:
		var dx := (rng.randf() - 0.5) * (w - 6.0)
		var z0 := d * 0.5 - 1.5
		var y0 := wall_h + rise * (1.5 / (d * 0.5)) - 0.3
		m.box(dx, y0, z0, 1.7, 1.7, 1.3, plaster)
		m.gable(dx, y0 + 1.7, z0, 1.7, 1.3, 0.8, roof.darkened(0.08), plaster, false, 0.3, 0.25)
		m.decal_z(dx, y0 + 0.3, z0 + 0.66, 0.8, 1.1, GLASS, 1.0)
	return wall_h + rise


static func _facade_z(m: TownMesh, w: float, wall_h: float, zc: float, sign: float, floors: int, rng: RandomNumberGenerator, shutter: Color, plaster: Color, front: bool, half_timber: bool) -> void:
	var n := maxi(1, roundi(w / 2.7))
	var door_i := n / 2
	for i in n:
		var x := -w * 0.5 + (i + 0.5) * w / n
		for f in floors:
			var y := 0.55 + 0.95 + f * 2.85
			if f == 0 and front and i == door_i:
				_door(m, x, zc, sign, rng)
				continue
			_window(m, x, y, zc, sign, true, shutter, plaster, rng.randf() < 0.5, rng.randf() < 0.25 and f == 0)
	if half_timber:
		# Timber frame over the upper storeys.
		var y0 := 0.55 + 2.75
		var y1 := wall_h
		for i in n + 1:
			var x := -w * 0.5 + i * w / n
			m.box(clampf(x, -w * 0.5 + 0.1, w * 0.5 - 0.1), y0, zc + 0.04 * sign, 0.16, y1 - y0, 0.07, TIMBER)
		m.box(0, y0 - 0.05, zc + 0.04 * sign, w, 0.16, 0.08, TIMBER)
		for f in range(1, floors):
			m.box(0, y0 + f * 2.85 - 0.08, zc + 0.04 * sign, w, 0.14, 0.08, TIMBER)


static func _facade_x(m: TownMesh, d: float, wall_h: float, xc: float, sign: float, floors: int, rng: RandomNumberGenerator, plaster: Color) -> void:
	var n := maxi(0, roundi(d / 4.2))
	for i in n:
		var z := -d * 0.5 + (i + 0.5) * d / n
		for f in floors:
			if rng.randf() < 0.75:
				_window(m, z, 0.55 + 0.95 + f * 2.85, xc, sign, false, STONE, plaster, false, false)


static func _window(m: TownMesh, pos: float, y: float, plane: float, sign: float, axis_z: bool, shutter: Color, plaster: Color, shutters: bool, flowers: bool) -> void:
	var off := 0.03 * sign
	var casing := plaster.lightened(0.28)
	if axis_z:
		m.decal_z(pos, y - 0.1, plane + off, 1.15, 1.62, casing, sign)
		m.decal_z(pos, y, plane + off * 2.0, 0.84, 1.26, GLASS, sign)
		m.decal_z(pos, y + 0.58, plane + off * 3.0, 0.84, 0.07, casing, sign)
		m.decal_z(pos, y, plane + off * 3.0, 0.07, 1.26, casing, sign)
		m.box(pos, y - 0.2, plane + 0.1 * sign, 1.3, 0.1, 0.24, STONE_LIGHT)
		if shutters:
			for s in [-1.0, 1.0]:
				m.box(pos + s * 0.72, y - 0.05, plane + 0.05 * sign, 0.42, 1.4, 0.07, shutter)
		if flowers:
			m.box(pos, y - 0.42, plane + 0.18 * sign, 1.0, 0.22, 0.26, Color("#5d4630"))
			for k in 4:
				var c: Color = [Color("#d8567a"), Color("#f2ecd8"), Color("#a56fd0"), Color("#f2c24a")][k]
				m.box(pos - 0.38 + k * 0.25, y - 0.2, plane + 0.18 * sign, 0.15, 0.18, 0.15, c)
	else:
		m.decal_x(plane + off, y - 0.1, pos, 1.15, 1.62, casing, sign)
		m.decal_x(plane + off * 2.0, y, pos, 0.84, 1.26, GLASS, sign)
		m.box(plane + 0.1 * sign, y - 0.2, pos, 0.24, 0.1, 1.3, STONE_LIGHT)


static func _door(m: TownMesh, x: float, zc: float, sign: float, rng: RandomNumberGenerator) -> void:
	var col := DOOR.lightened(rng.randf() * 0.15)
	m.box(x, 0.0, zc + 0.12 * sign, 1.9, 0.22, 0.9, STONE)           # step
	m.decal_z(x, 0.5, zc + 0.03 * sign, 1.55, 2.35, STONE_LIGHT, sign)  # surround
	m.decal_z(x, 0.55, zc + 0.06 * sign, 1.15, 2.1, col, sign)
	m.box(x, 2.62, zc + 0.12 * sign, 1.75, 0.22, 0.34, STONE_LIGHT)    # lintel
	m.decal_z(x + 0.3, 1.4, zc + 0.08 * sign, 0.1, 0.1, Color("#c7a45a"), sign)   # handle


# --- cathedral ----------------------------------------------------------------------------

## Linköping cathedral as the map paints it: a long slate-roofed nave with
## aisles, a tall central tower and two smaller flanking towers on the south
## front, all with steep spires. Local frame: front facade at z = 0 facing +Z,
## the nave running north into -Z. Returns collision boxes as
## [{pos: Vector3, size: Vector3}] (centre, size).
static func cathedral(m: TownMesh, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var wall := Color("#b59a7c")
	var wall_hi := Color("#c4aa8a")
	var roof := SLATE
	var trim := STONE_LIGHT
	var boxes: Array[Dictionary] = []
	var nave_h := 15.0
	var aisle_h := 8.6
	var nave_w := 15.0
	var aisle_w := 4.6
	var z_front := -8.0          # tower block depth
	var z_rear := -41.0

	# Plinth under everything.
	m.box(0, -1.2, (z_front + z_rear) * 0.5 - 1.0, nave_w + 2.0 * aisle_w + 1.0, 1.5, (z_front - z_rear) + 4.0, STONE_DARK)

	# Nave + aisles.
	m.box(0, 0, (z_front + z_rear) * 0.5, nave_w, nave_h, z_front - z_rear, wall, false, 0.14)
	for s in [-1.0, 1.0]:
		var ax: float = s * (nave_w * 0.5 + aisle_w * 0.5)
		m.box(ax, 0, (z_front + z_rear + 3.0) * 0.5, aisle_w, aisle_h, z_front - z_rear - 3.0, wall, false, 0.14)
	boxes.append({"pos": Vector3(0, nave_h * 0.5, (z_front + z_rear) * 0.5), "size": Vector3(nave_w + 2.0 * aisle_w, nave_h, z_front - z_rear)})
	# Nave roof (steep slate) with a ridge cresting.
	m.gable(0, nave_h, (z_front + z_rear) * 0.5, nave_w, z_front - z_rear, 7.6, roof, wall, false, 0.7, 0.2)
	# Aisle lean-to roofs.
	for s in [-1.0, 1.0]:
		var x0: float = s * (nave_w * 0.5)
		var x1: float = s * (nave_w * 0.5 + aisle_w + 0.5)
		var zf := z_front
		var zr := z_front + (z_rear - z_front) + 3.0
		var hi := aisle_h + 2.6
		var lo := aisle_h - 0.1
		m.quad(Vector3(x0, hi, zf), Vector3(x1, lo, zf), Vector3(x1, lo, zr), Vector3(x0, hi, zr), roof.lightened(0.05), Vector3(s * 0.6, 0.8, 0))
	# Apse: a half-octagon of stone closing the north end, with its own cone roof.
	m.drum(0, 0, z_rear, nave_w * 0.5, nave_h - 2.0, wall, 8, 0.0, false)
	m.spire(0, nave_h - 2.0, z_rear, nave_w * 0.5 + 0.5, 7.0, roof, 8)

	# Bays: buttresses, aisle windows and clerestory windows.
	var bay := 4.4
	var z := z_front - 3.0
	while z > z_rear + 2.0:
		for s in [-1.0, 1.0]:
			var bx: float = s * (nave_w * 0.5 + aisle_w + 0.15)
			m.box(bx, 0, z, 0.9, aisle_h + 0.9, 1.0, wall_hi, false, 0.1)
			m.spire(bx, aisle_h + 0.9, z, 0.7, 2.2, roof, 4, 0.0, PI * 0.25)
			# Aisle window between buttresses (facade normal ±X).
			var wz := z - bay * 0.5
			var plane: float = s * (nave_w * 0.5 + aisle_w + 0.02)
			m.pointed_window(wz, 2.4, plane, 1.2, 4.6, GLASS, false, s)
			# Clerestory windows above the aisle roof.
			var cplane: float = s * (nave_w * 0.5 + 0.02)
			m.pointed_window(wz, 11.8, cplane, 1.3, 3.0, GLASS, false, s)
		z -= bay
	# String courses along the nave.
	m.box(0, aisle_h + 2.7, (z_front + z_rear) * 0.5, nave_w + 0.2, 0.25, z_front - z_rear + 0.2, trim)

	# --- West (here: south) front: three towers.
	# Central tower: square to the belfry, an octagonal lantern, the tall spire.
	var ct_w := 10.4
	var ct_h := 30.0
	m.box(0, 0, -4.5, ct_w, ct_h, 9.0, wall, false, 0.12)
	boxes.append({"pos": Vector3(0, ct_h * 0.5, -4.5), "size": Vector3(ct_w, ct_h, 9.0)})
	for y in [8.0, 16.0, 24.0]:
		m.box(0, y, -4.5, ct_w + 0.3, 0.3, 9.3, trim)
	# Portal, rose window, clock.
	m.decal_z(0, 0.0, 0.03, 3.8, 6.4, STONE_LIGHT, 1.0)
	m.pointed_window(0, 0.0, 0.07, 2.9, 5.8, DOOR, true, 1.0)
	m.pointed_window(0, 7.0, 0.05, 1.8, 6.0, GLASS, true, 1.0)
	_disc(m, Vector3(0, 15.5, 0.05), 1.7, Color("#3a4a78"), Color("#e0cf9c"))
	_disc(m, Vector3(0, 21.5, 0.05), 1.3, Color("#efe4c0"), Color("#5b4a2a"))
	# Belfry louvres on all four faces.
	for y in [26.0]:
		m.pointed_window(-2.0, y, 0.05, 1.1, 3.4, GLASS, true, 1.0)
		m.pointed_window(2.0, y, 0.05, 1.1, 3.4, GLASS, true, 1.0)
		for s in [-1.0, 1.0]:
			m.pointed_window(-4.5 + 1.5, y, s * (ct_w * 0.5 + 0.02), 1.1, 3.4, GLASS, false, s)
			m.pointed_window(-4.5 - 1.5, y, s * (ct_w * 0.5 + 0.02), 1.1, 3.4, GLASS, false, s)
	# Lantern and spire.
	m.drum(0, ct_h, -4.5, 4.2, 5.0, wall_hi, 8, PI / 8.0)
	m.spire(0, ct_h + 5.0, -4.5, 4.5, 27.0, roof, 8, 0.0, PI / 8.0)
	# Corner pinnacles on the tower top.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(sx * 4.6, ct_h, -4.5 + sz * 4.0, 1.1, 2.2, 1.1, wall_hi)
			m.spire(sx * 4.6, ct_h + 2.2, -4.5 + sz * 4.0, 0.9, 4.2, roof, 4, 0.0, PI * 0.25)
	# Flanking towers.
	for s in [-1.0, 1.0]:
		var fx: float = s * 9.0
		m.box(fx, 0, -4.2, 6.6, 22.0, 8.4, wall, false, 0.12)
		boxes.append({"pos": Vector3(fx, 11.0, -4.2), "size": Vector3(6.6, 22.0, 8.4)})
		for y in [7.5, 15.0]:
			m.box(fx, y, -4.2, 6.9, 0.28, 8.7, trim)
		m.pointed_window(fx, 3.0, 0.05, 1.2, 4.2, GLASS, true, 1.0)
		m.pointed_window(fx, 10.0, 0.05, 1.2, 4.4, GLASS, true, 1.0)
		m.pointed_window(fx, 17.0, 0.05, 1.2, 3.8, GLASS, true, 1.0)
		m.pointed_window(-4.2, 3.0, fx + s * 3.32, 1.2, 4.2, GLASS, false, s)
		m.pointed_window(-4.2, 12.5, fx + s * 3.32, 1.2, 4.2, GLASS, false, s)
		m.spire(fx, 22.0, -4.2, 3.9, 14.5, roof, 8, 0.0, PI / 8.0)
		for sx in [-1.0, 1.0]:
			m.box(fx + sx * 3.0, 22.0, -4.2 - 3.6, 0.8, 1.6, 0.8, wall_hi)
			m.box(fx + sx * 3.0, 22.0, -4.2 + 3.6, 0.8, 1.6, 0.8, wall_hi)
	# Facade gable linking the towers over the nave.
	m.box(0, 0, -6.0, 15.0, 17.0, 3.0, wall, false, 0.12)
	return boxes


static func _disc(m: TownMesh, c: Vector3, r: float, col: Color, ring: Color) -> void:
	var sides := 16
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := c + Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := c + Vector3(cos(a1) * r, sin(a1) * r, 0)
		m.tri(c + Vector3(0, 0, 0.02), p0 + Vector3(0, 0, 0.02), p1 + Vector3(0, 0, 0.02), col, Vector3(0, 0, 1))
		var q0 := c + Vector3(cos(a0) * (r + 0.22), sin(a0) * (r + 0.22), 0)
		var q1 := c + Vector3(cos(a1) * (r + 0.22), sin(a1) * (r + 0.22), 0)
		m.quad(p0 + Vector3(0, 0, 0.02), q0 + Vector3(0, 0, 0.02), q1 + Vector3(0, 0, 0.02), p1 + Vector3(0, 0, 0.02), ring, Vector3(0, 0, 1))


# --- bridge -------------------------------------------------------------------------------

## The stone arch bridge, in world coordinates (it is placed at the origin).
## Returns collision boxes as [{pos, size, rot_x}] (centre, size, pitch radians).
static func bridge(m: TownMesh, ground_y := 0.0) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var x := TownLayout.BRIDGE_X
	var w := TownLayout.BRIDGE_WIDTH
	var deck := TownLayout.BRIDGE_DECK_Y
	var z0 := TownLayout.BRIDGE_Z0 + 5.5      # abutment ends (ramps lie beyond)
	var z1 := TownLayout.BRIDGE_Z1 - 5.5
	var stone := Color("#a79880")
	var cobble := Color("#9a9184")
	var bed := -3.0
	var spring_y := -1.0
	var arches := 3
	var pier := 1.5
	var span := ((z1 - z0) - pier * (arches + 1)) / arches
	var r := span * 0.5
	# Solid core between and under arches, built from thin columns so the arch
	# openings are cut out of it.
	var step := 0.3
	var zc := z0
	while zc < z1:
		var zm := zc + step * 0.5
		var top := deck - 0.35
		var under := bed
		var rel := zm - z0 - pier
		var k := floori(rel / (span + pier))
		if rel >= 0.0 and k >= 0 and k < arches:
			var local := rel - k * (span + pier)
			if local < span:
				var dz := local - r
				under = spring_y + sqrt(maxf(r * r - dz * dz, 0.0))
		if under < top:
			m.box(x, under, zm, w, top - under, step + 0.01, stone, true, 0.12)
		zc += step
	# Deck, parapets and caps.
	m.box(x, deck - 0.35, (z0 + z1) * 0.5, w, 0.35, z1 - z0, cobble)
	for s in [-1.0, 1.0]:
		m.box(x + s * (w * 0.5 - 0.3), deck, (z0 + z1) * 0.5, 0.6, 0.95, z1 - z0, stone)
		m.box(x + s * (w * 0.5 - 0.3), deck + 0.95, (z0 + z1) * 0.5, 0.8, 0.18, z1 - z0 + 0.2, STONE_LIGHT)
	boxes.append({"pos": Vector3(x, deck - 0.3, (z0 + z1) * 0.5), "size": Vector3(w, 0.6, z1 - z0), "rot_x": 0.0})
	for s in [-1.0, 1.0]:
		boxes.append({"pos": Vector3(x + s * (w * 0.5 - 0.3), deck + 0.5, (z0 + z1) * 0.5), "size": Vector3(0.7, 1.2, z1 - z0), "rot_x": 0.0})
	# Approach ramps: sloped wedges climbing from the street to the deck.
	for end in [-1.0, 1.0]:
		var za: float = z0 if end < 0.0 else z1
		var zb: float = za + end * 5.5
		var y_hi := deck
		# Buried a little so the ramp meets the street in a crease, not a lip.
		var y_lo := ground_y - 0.35
		var l := Vector3(x - w * 0.5, y_hi, za)
		var rgt := Vector3(x + w * 0.5, y_hi, za)
		var lo_l := Vector3(x - w * 0.5, y_lo, zb)
		var lo_r := Vector3(x + w * 0.5, y_lo, zb)
		m.quad(l, rgt, lo_r, lo_l, cobble, Vector3(0, 1, end * 0.3))
		# Side walls of the ramp (triangles) and parapets that follow the slope.
		for s in [-1.0, 1.0]:
			var xs: float = x + s * w * 0.5
			var xin: float = x + s * (w * 0.5 - 0.6)
			m.tri(Vector3(xs, y_hi, za), Vector3(xs, y_lo, zb), Vector3(xs, y_lo, za), stone, Vector3(s, 0, 0))
			var p0 := Vector3(xin, y_hi + 0.95, za)
			var p1 := Vector3(xin, y_lo + 0.95, zb)
			m.quad(p0, p1, p1 + Vector3(s * 0.6, 0, 0), p0 + Vector3(s * 0.6, 0, 0), STONE_LIGHT, Vector3.UP)
			m.quad(Vector3(xs, y_hi + 0.95, za), Vector3(xs, y_lo + 0.95, zb), Vector3(xs, y_lo, zb), Vector3(xs, y_hi, za), stone, Vector3(s, 0, 0))
			m.quad(Vector3(xin, y_hi + 0.95, za), Vector3(xin, y_lo + 0.95, zb), Vector3(xin, y_lo, zb), Vector3(xin, y_hi, za), stone, Vector3(-s, 0, 0))
		var ang := atan2(y_hi - y_lo, 5.5)
		boxes.append({"pos": Vector3(x, (y_hi + y_lo) * 0.5 - 0.3 * cos(ang), (za + zb) * 0.5), "size": Vector3(w, 0.6, 5.5 / cos(ang)), "rot_x": ang * end})
	return boxes


# --- square furniture ---------------------------------------------------------------------

## Octagonal fountain with a column and a winged figure holding a ring up, after
## the statue in the village concept art. Origin at the centre on the ground.
static func fountain(m: TownMesh) -> void:
	var stone := Color("#b9ad98")
	m.drum(0, 0, 0, 3.6, 0.8, stone, 8, PI / 8.0, false)
	m.drum(0, 0.8, 0, 3.4, 0.14, STONE_LIGHT, 8, PI / 8.0)       # rim cap (water sits below)
	m.drum(0, 0, 0, 1.1, 2.4, stone, 8, PI / 8.0)
	m.drum(0, 2.4, 0, 1.9, 0.35, STONE_LIGHT, 8, PI / 8.0)
	m.drum(0, 2.75, 0, 1.0, 1.1, stone, 8, PI / 8.0)
	# Figure: robe, torso, head, hair, raised arms with a ring, wings.
	var y := 3.85
	m.spire(0, y, 0, 0.62, 1.7, Color("#d9d2c0"), 8, 0.22)
	m.drum(0, y + 1.7, 0, 0.22, 0.45, Color("#d9d2c0"), 8)
	m.drum(0, y + 2.15, 0, 0.16, 0.28, Color("#e6d3bd"), 8)
	m.spire(0, y + 2.43, 0, 0.2, 0.22, Color("#cfc7b4"), 6)
	for s in [-1.0, 1.0]:
		# Wings: a swept pair of feather panels behind the shoulders.
		var wr := Vector3(s * 0.2, y + 1.8, -0.15)
		m.quad(wr, wr + Vector3(s * 1.7, 0.9, -0.4), wr + Vector3(s * 1.5, 2.0, -0.35), wr + Vector3(s * 0.15, 1.2, -0.05), Color("#ece6d6"), Vector3(0, 0, 1))
		m.quad(wr, wr + Vector3(s * 1.5, 0.3, -0.35), wr + Vector3(s * 1.7, 0.9, -0.4), wr + Vector3(s * 0.2, 0.5, -0.05), Color("#e1dac8"), Vector3(0, 0, 1))
		m.box(s * 0.28, y + 2.0, 0.0, 0.1, 0.8, 0.1, Color("#d9d2c0"))     # arm
	# Ring (a circle of small blocks) held overhead.
	for i in 12:
		var a := TAU * i / 12.0
		m.box(cos(a) * 0.42, y + 3.1 + sin(a) * 0.42, 0, 0.14, 0.14, 0.14, Color("#d8b25a"))


## A market stall with a striped awning.
static func stall(m: TownMesh, rng: RandomNumberGenerator) -> void:
	var wood := Color("#7a5a3c")
	var cloth_a: Color = [Color("#b8453a"), Color("#3f6fa3"), Color("#4f8a58"), Color("#c9993a")][rng.randi() % 4]
	var cloth_b := Color("#efe7d2")
	for sx in [-1.0, 1.0]:
		m.box(sx * 1.45, 0, -0.9, 0.14, 2.6, 0.14, wood)
		m.box(sx * 1.45, 0, 0.9, 0.14, 2.3, 0.14, wood)
	m.box(0, 0.0, 0.35, 3.0, 0.95, 0.9, wood.lightened(0.08), false, 0.1)
	# Awning: sloped strips from the back (higher) to the front.
	var n := 8
	for i in n:
		var x0 := -1.7 + 3.4 * i / n
		var x1 := -1.7 + 3.4 * (i + 1) / n
		var col := cloth_a if i % 2 == 0 else cloth_b
		var a := Vector3(x0, 2.7, -1.0)
		var b := Vector3(x1, 2.7, -1.0)
		var c := Vector3(x1, 2.35, 1.3)
		var d := Vector3(x0, 2.35, 1.3)
		m.quad(a, b, c, d, col, Vector3(0, 1, 0.3))
		m.quad(d, c, c + Vector3(0, -0.18, 0.05), d + Vector3(0, -0.18, 0.05), col.darkened(0.1), Vector3(0, 0, 1))
	# Goods on the counter.
	var goods: Array[Color] = [Color("#d8573a"), Color("#e8c14a"), Color("#6fa04a"), Color("#8c5a9a"), Color("#e8d4a8")]
	for i in 7:
		m.box(-1.2 + i * 0.4, 0.95, 0.35, 0.26, 0.2 + rng.randf() * 0.1, 0.26, goods[rng.randi() % goods.size()])
	# Crates at the side.
	m.box(1.9, 0, 0.4, 0.7, 0.55, 0.7, wood.darkened(0.1))
	m.box(1.9, 0.55, 0.4, 0.6, 0.45, 0.6, wood)


## A banner pole as in the village art: a tall pole with a hanging green banner.
static func banner(m: TownMesh, height := 5.2) -> void:
	m.box(0, 0, 0, 0.14, height, 0.14, Color("#4a3426"))
	m.box(0, height - 0.25, 0, 1.0, 0.1, 0.1, Color("#4a3426"))
	var g := Color("#3f6a4a")
	m.quad(Vector3(-0.42, height - 0.3, 0.03), Vector3(0.42, height - 0.3, 0.03), Vector3(0.42, height - 2.6, 0.03), Vector3(-0.42, height - 2.6, 0.03), g, Vector3(0, 0, 1))
	m.quad(Vector3(0.42, height - 0.3, -0.03), Vector3(-0.42, height - 0.3, -0.03), Vector3(-0.42, height - 2.6, -0.03), Vector3(0.42, height - 2.6, -0.03), g, Vector3(0, 0, -1))
	# Cream emblem: a diamond with a small leaf.
	for sg in [1.0, -1.0]:
		var zz: float = 0.04 * sg
		m.tri(Vector3(0, height - 0.75, zz), Vector3(-0.22, height - 1.25, zz), Vector3(0.22, height - 1.25, zz), Color("#efe4c0"), Vector3(0, 0, sg))
		m.tri(Vector3(0, height - 1.75, zz), Vector3(0.22, height - 1.25, zz), Vector3(-0.22, height - 1.25, zz), Color("#efe4c0"), Vector3(0, 0, sg))
	m.tri(Vector3(-0.42, height - 2.6, 0.03), Vector3(0.42, height - 2.6, 0.03), Vector3(0, height - 3.0, 0.03), g, Vector3(0, 0, 1))
	m.tri(Vector3(0.42, height - 2.6, -0.03), Vector3(-0.42, height - 2.6, -0.03), Vector3(0, height - 3.0, -0.03), g, Vector3(0, 0, -1))


## A round stone tower with a crenellated crown (the map's tower by the river).
static func round_tower(m: TownMesh) -> void:
	var stone := Color("#9b8f7c")
	m.drum(0, -0.8, 0, 3.8, 1.0, STONE_DARK, 12)
	m.drum(0, 0, 0, 3.4, 11.0, stone, 12)
	for y in [3.5, 7.0]:
		m.drum(0, y, 0, 3.5, 0.22, STONE_LIGHT, 12, 0.0, false)
	m.drum(0, 11.0, 0, 3.9, 0.9, stone.lightened(0.05), 12)          # corbelled crown
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		m.box(cos(a) * 3.7, 11.9, sin(a) * 3.7, 0.9, 0.9, 0.9, stone.lightened(0.08))
	m.spire(0, 11.9, 0, 2.8, 3.2, Color("#8a4a3c"), 12)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		# arrow slits
		m.decal_z(sin(a) * 3.38, 5.0 + i * 1.6, cos(a) * 3.38, 0.18, 0.9, Color("#1f232c"), 1.0 if cos(a) > 0 else -1.0)


## A low garden wall / fence run for yards, as one box.
static func wall_run(m: TownMesh, length: float, col := Color("#a89a86")) -> void:
	m.box(0, 0, 0, length, 0.9, 0.35, col, false, 0.15)
	m.box(0, 0.9, 0, length + 0.1, 0.12, 0.45, STONE_LIGHT)
