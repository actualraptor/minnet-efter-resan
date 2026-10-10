class_name TownLayout
extends RefCounted
## Hand-authored plan of Linköping, "the city of churches", after the
## illustrated map (World/Östergötland.png): a three-towered cathedral on a
## gentle rise, a market square with a fountain, a stone-arched bridge over the
## river and lanes out into the fields. Metres; +X east, +Z south (the player
## arrives from the south), the cathedral stands to the north.
##
## Everything that has a place on the map lives here so the terrain, streets,
## buildings and props all agree.

const SEED := 1032
const HALF := 150.0
const STEP := 1.25
## Player is softly kept within this radius of the origin.
const PLAY_RADIUS := 132.0
const PLAYER_START := Vector3(7.0, 0.0, 132.0)

## Stora torget (the market square).
const PLAZA_HALF := Vector2(17.0, 13.0)
## Cathedral: south facade (with the towers) at CATHEDRAL_FRONT_Z, apse at REAR_Z.
const CATHEDRAL_FRONT_Z := -31.0
const CATHEDRAL_REAR_Z := -80.0
const PRECINCT_RISE := 3.2
const PRECINCT_HALF_X := 27.0

## The river (Stångån) enters from the west and leaves to the east, passing
## south of the town. The surface sits below the banks.
const RIVER: Array[Vector2] = [
	Vector2(-160.0, 76.0), Vector2(-122.0, 72.0), Vector2(-86.0, 63.0), Vector2(-52.0, 57.0),
	Vector2(-20.0, 55.0), Vector2(10.0, 56.0), Vector2(42.0, 55.0), Vector2(74.0, 60.0),
	Vector2(106.0, 70.0), Vector2(160.0, 76.0),
]
const RIVER_HALF_WIDTH := 7.0
const WATER_LEVEL := -0.95

## The stone bridge: along Z at BRIDGE_X, from BRIDGE_Z0 (north) to BRIDGE_Z1.
const BRIDGE_X := 0.0
const BRIDGE_Z0 := 41.0
const BRIDGE_Z1 := 71.0
const BRIDGE_WIDTH := 7.0
const BRIDGE_DECK_Y := 1.7

## Cobbled streets (centre lines and widths).
const STORGATAN: Array[Vector2] = [Vector2(0.0, 72.0), Vector2(0.0, 40.0), Vector2(0.0, 12.0)]
const STORGATAN_WIDTH := 8.0
const AGATAN: Array[Vector2] = [Vector2(-74.0, 1.0), Vector2(-20.0, 0.0), Vector2(20.0, 0.0), Vector2(74.0, 1.0)]
const AGATAN_WIDTH := 6.0
const DOMKYRKOGATAN: Array[Vector2] = [Vector2(0.0, -12.0), Vector2(0.0, -32.0)]
const DOMKYRKOGATAN_WIDTH := 10.0
## Country lanes (dirt): from the bridge to the player start, and out of town.
const LANE_SOUTH: Array[Vector2] = [
	Vector2(0.0, 71.0), Vector2(-1.5, 84.0), Vector2(2.0, 98.0), Vector2(8.0, 112.0), Vector2(7.0, 126.0), Vector2(10.0, 150.0),
]
const LANE_WEST: Array[Vector2] = [Vector2(-74.0, 1.0), Vector2(-96.0, 6.0), Vector2(-122.0, 16.0), Vector2(-160.0, 30.0)]
const LANE_EAST: Array[Vector2] = [Vector2(74.0, 1.0), Vector2(100.0, -2.0), Vector2(128.0, -14.0), Vector2(160.0, -24.0)]
const LANE_WIDTH := 3.2

## The round stone tower on the south bank (it stands by the river on the map).
const ROUND_TOWER_POS := Vector2(50.0, 80.0)


static func distance_to_polyline(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func river_distance(x: float, z: float) -> float:
	return distance_to_polyline(Vector2(x, z), RIVER)


static func _rect_dist(p: Vector2, centre: Vector2, half: Vector2) -> float:
	var d := Vector2(absf(p.x - centre.x) - half.x, absf(p.y - centre.y) - half.y)
	return maxf(d.x, d.y) if d.x < 0.0 and d.y < 0.0 else Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


## 0..1: how cobbled the ground is at (x, z).
static func cobble_amount(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := minf(_rect_dist(p, Vector2.ZERO, PLAZA_HALF), _rect_dist(p, Vector2(0.0, -28.0), Vector2(18.0, 3.2)))
	d = minf(d, distance_to_polyline(p, STORGATAN) - STORGATAN_WIDTH * 0.5)
	d = minf(d, distance_to_polyline(p, AGATAN) - AGATAN_WIDTH * 0.5)
	d = minf(d, distance_to_polyline(p, DOMKYRKOGATAN) - DOMKYRKOGATAN_WIDTH * 0.5)
	# The bridge is paved, but not the lane south of it.
	if z > BRIDGE_Z1:
		d = maxf(d, 1.5)
	return 1.0 - smoothstep(-0.6, 0.8, d)


## 0..1: dirt lane amount (kept clear of cobbles).
static func lane_amount(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := minf(distance_to_polyline(p, LANE_SOUTH), minf(distance_to_polyline(p, LANE_WEST), distance_to_polyline(p, LANE_EAST)))
	return (1.0 - smoothstep(LANE_WIDTH * 0.5, LANE_WIDTH * 0.5 + 1.0, d)) * (1.0 - cobble_amount(x, z))


## Raised ground under the cathedral and its forecourt.
static func precinct_rise(x: float, z: float) -> float:
	var wx := 1.0 - smoothstep(PRECINCT_HALF_X, PRECINCT_HALF_X + 18.0, absf(x))
	return PRECINCT_RISE * wx * smoothstep(-13.0, -34.0, z)


static func in_water_corridor(x: float, z: float, margin := 0.0) -> bool:
	return river_distance(x, z) < RIVER_HALF_WIDTH + margin


## True when something placed at (x, z) would stand in a street, the square, the
## river or the cathedral's footprint (with `margin`).
static func blocked(x: float, z: float, margin := 0.0) -> bool:
	var p := Vector2(x, z)
	if _rect_dist(p, Vector2.ZERO, PLAZA_HALF) < margin:
		return true
	if distance_to_polyline(p, STORGATAN) < STORGATAN_WIDTH * 0.5 + margin:
		return true
	if distance_to_polyline(p, AGATAN) < AGATAN_WIDTH * 0.5 + margin:
		return true
	if distance_to_polyline(p, DOMKYRKOGATAN) < DOMKYRKOGATAN_WIDTH * 0.5 + margin:
		return true
	if distance_to_polyline(p, LANE_SOUTH) < LANE_WIDTH * 0.5 + margin:
		return true
	if river_distance(x, z) < RIVER_HALF_WIDTH + 2.0 + margin:
		return true
	# Cathedral footprint (nave, aisles and towers) and its forecourt.
	if absf(x) < 17.0 + margin and z < CATHEDRAL_FRONT_Z + 2.0 + margin and z > CATHEDRAL_REAR_Z - 6.0 - margin:
		return true
	if _rect_dist(p, ROUND_TOWER_POS, Vector2(4.0, 4.0)) < margin:
		return true
	return false
