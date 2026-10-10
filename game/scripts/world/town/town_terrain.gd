class_name TownTerrain
extends MeadowTerrain
## Ground of the Linköping slice: a flat town centre with cobbled streets, a
## carved river, the cathedral's rise to the north and hills ringing it.

var _low := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _hills := FastNoiseLite.new()


func _enter_tree() -> void:
	half = TownLayout.HALF
	step = TownLayout.STEP
	super()


func _ready() -> void:
	if material == null:
		var m := WorldMaterials.terrain()
		m.set_shader_parameter("water_level", TownLayout.WATER_LEVEL)
		# Town grass leans a little warmer and drier than the meadow.
		m.set_shader_parameter("grass_light", Vector3(0.60, 0.74, 0.31))
		m.set_shader_parameter("grass_warm", Vector3(0.78, 0.74, 0.34))
		material = m
	super()


func _setup_noise() -> void:
	_low.seed = TownLayout.SEED
	_low.frequency = 0.014
	_low.fractal_octaves = 3
	_mid.seed = TownLayout.SEED + 5
	_mid.frequency = 0.07
	_mid.fractal_octaves = 2
	_hills.seed = TownLayout.SEED + 11
	_hills.frequency = 0.02
	_hills.fractal_octaves = 4


func _final_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var rolling := _low.get_noise_2d(x, z) * 1.9 + _mid.get_noise_2d(x, z) * 0.3
	# Flat around the town and along the river, gently rolling in the fields.
	var d_centre := p.distance_to(Vector2(0.0, -8.0))
	var town := 1.0 - smoothstep(62.0, 100.0, d_centre)
	var rd := TownLayout.river_distance(x, z)
	var corridor := 1.0 - smoothstep(14.0, 34.0, rd)
	var h := lerpf(rolling, rolling * 0.12, maxf(town, corridor))
	# Hills ring the valley, most of all to the north behind the cathedral.
	var r := p.length()
	var rim := smoothstep(98.0, 150.0, r)
	h += rim * rim * (16.0 + _hills.get_noise_2d(x, z) * 9.0)
	h += smoothstep(-60.0, -150.0, z) * 9.0
	h += TownLayout.precinct_rise(x, z)
	# The river bed.
	var bowl := 1.0 - smoothstep(3.0, 9.0, rd)
	h -= bowl * 2.5
	# Streets sit a hair lower than the verges.
	h -= TownLayout.cobble_amount(x, z) * 0.04 + TownLayout.lane_amount(x, z) * 0.06
	return h


func _vertex_color(x: float, z: float, vary: FastNoiseLite) -> Color:
	var r := Vector2(x, z).length()
	return Color(TownLayout.lane_amount(x, z), vary.get_noise_2d(x, z) * 0.5 + 0.5, smoothstep(70.0, 130.0, r), 1.0 - TownLayout.cobble_amount(x, z))
