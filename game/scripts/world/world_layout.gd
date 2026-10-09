class_name WorldLayout
extends RefCounted
## Hand-authored layout of the milestone-001 meadow. Every hand-placed landmark
## lives here so terrain shaping, grass, scattering and spells agree on it.

const SEED := 1031
## Half-size of the generated terrain (metres). Playable area is ~100 x 100 m.
const TERRAIN_HALF := 110.0
const TERRAIN_STEP := 1.25
## Player is softly kept within this radius of the origin.
const PLAY_RADIUS := 54.0

## Cottage: centre of footprint, yaw, and half-extents of the flattened pad.
const COTTAGE_POS := Vector3(0.0, 0.0, -6.0)
const COTTAGE_HALF := Vector2(5.6, 4.4)
const COTTAGE_FLOOR := 0.45

## Meadow where Edda's garden used to spread (behind the cottage).
const GARDEN_MEADOW := Vector3(-4.0, 0.0, -24.0)
const GARDEN_MEADOW_RADIUS := 13.0

## Bench overlooking the back meadow.
const BENCH_POS := Vector3(6.6, 0.0, -14.2)
const BENCH_YAW := deg_to_rad(200.0)

## Dirt path from the south road to the cottage door, plus a side path round the back.
const PATH_MAIN: Array[Vector2] = [
	Vector2(10.0, 92.0), Vector2(6.0, 64.0), Vector2(-2.0, 44.0), Vector2(-4.0, 30.0),
	Vector2(1.0, 18.0), Vector2(2.5, 9.0), Vector2(0.6, 2.6), Vector2(0.0, -1.2),
]
const PATH_SIDE: Array[Vector2] = [
	Vector2(2.0, 6.0), Vector2(7.0, 2.0), Vector2(9.0, -5.0), Vector2(8.0, -11.0),
	Vector2(6.6, -13.2),
]
const PATH_WIDTH := 1.25

const PLAYER_START := Vector3(-3.5, 0.0, 33.0)
const PLAYER_START_YAW := 0.0


static func cottage_rect_contains(p: Vector3, margin: float = 0.0) -> bool:
	var d := Vector2(p.x - COTTAGE_POS.x, p.z - COTTAGE_POS.z)
	return absf(d.x) < COTTAGE_HALF.x + margin and absf(d.y) < COTTAGE_HALF.y + margin


static func distance_to_polyline(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## 0 = grass, 1 = centre of a dirt path.
static func path_amount(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := minf(distance_to_polyline(p, PATH_MAIN), distance_to_polyline(p, PATH_SIDE) + 0.25)
	return 1.0 - smoothstep(PATH_WIDTH * 0.55, PATH_WIDTH * 1.25, d)
