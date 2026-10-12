class_name TimeOfDay
extends Node
## Drives the sun, sky and fog from GameState's clock, so waiting and studying are
## visible. The 16:00 key is the golden hour the meadow was lit for; the rest of
## the day is interpolated from a handful of keys (dawn, morning, noon, sunset,
## dusk, a moonlit night).

const KEYS := [
	# h: hour, pitch/yaw: sun direction (deg), col/energy: sun, amb: ambient energy,
	# sky: zenith, mid, horizon, warm horizon, ground; cloud: light, sunlit, shade; fog
	{"h": 0.0, "pitch": -42.0, "yaw": 150.0, "col": Color(0.55, 0.65, 1.0), "energy": 0.55, "amb": 0.34,
		"sky": [Color(0.02, 0.04, 0.12), Color(0.05, 0.08, 0.2), Color(0.1, 0.13, 0.26), Color(0.12, 0.15, 0.3), Color(0.04, 0.06, 0.08)],
		"cloud": [Color(0.22, 0.26, 0.4), Color(0.28, 0.3, 0.46), Color(0.08, 0.1, 0.18)], "fog": Color(0.06, 0.09, 0.18), "vol": Color(0.5, 0.58, 0.85)},
	{"h": 5.0, "pitch": -42.0, "yaw": 150.0, "col": Color(0.55, 0.65, 1.0), "energy": 0.55, "amb": 0.34,
		"sky": [Color(0.02, 0.04, 0.12), Color(0.05, 0.08, 0.2), Color(0.1, 0.13, 0.26), Color(0.12, 0.15, 0.3), Color(0.04, 0.06, 0.08)],
		"cloud": [Color(0.22, 0.26, 0.4), Color(0.28, 0.3, 0.46), Color(0.08, 0.1, 0.18)], "fog": Color(0.06, 0.09, 0.18), "vol": Color(0.5, 0.58, 0.85)},
	{"h": 6.4, "pitch": -5.0, "yaw": 100.0, "col": Color(1.0, 0.62, 0.45), "energy": 1.5, "amb": 0.5,
		"sky": [Color(0.22, 0.3, 0.58), Color(0.6, 0.55, 0.7), Color(0.98, 0.72, 0.6), Color(1.0, 0.6, 0.4), Color(0.35, 0.36, 0.34)],
		"cloud": [Color(1.0, 0.85, 0.8), Color(1.0, 0.72, 0.55), Color(0.5, 0.5, 0.68)], "fog": Color(0.85, 0.7, 0.68), "vol": Color(1.0, 0.8, 0.7)},
	{"h": 9.0, "pitch": -35.0, "yaw": 70.0, "col": Color(1.0, 0.93, 0.8), "energy": 3.0, "amb": 0.62,
		"sky": [Color(0.15, 0.4, 0.86), Color(0.42, 0.66, 0.94), Color(0.82, 0.9, 0.94), Color(1.0, 0.92, 0.74), Color(0.5, 0.58, 0.46)],
		"cloud": [Color(1.0, 0.98, 0.94), Color(1.0, 0.94, 0.82), Color(0.64, 0.7, 0.84)], "fog": Color(0.74, 0.84, 0.96), "vol": Color(1.0, 0.95, 0.86)},
	{"h": 12.5, "pitch": -62.0, "yaw": 0.0, "col": Color(1.0, 0.97, 0.9), "energy": 3.2, "amb": 0.66,
		"sky": [Color(0.13, 0.38, 0.88), Color(0.4, 0.66, 0.96), Color(0.8, 0.9, 0.96), Color(0.95, 0.94, 0.84), Color(0.5, 0.58, 0.46)],
		"cloud": [Color(1.0, 1.0, 0.97), Color(1.0, 0.97, 0.9), Color(0.66, 0.72, 0.86)], "fog": Color(0.74, 0.85, 0.97), "vol": Color(1.0, 0.97, 0.9)},
	# The look the meadow was built for.
	{"h": 16.0, "pitch": -21.0, "yaw": -62.0, "col": Color(1.0, 0.82, 0.58), "energy": 2.9, "amb": 0.62,
		"sky": [Color(0.16, 0.42, 0.86), Color(0.42, 0.66, 0.93), Color(0.86, 0.9, 0.92), Color(1.0, 0.86, 0.62), Color(0.5, 0.58, 0.46)],
		"cloud": [Color(1.0, 0.97, 0.9), Color(1.0, 0.9, 0.7), Color(0.62, 0.68, 0.82)], "fog": Color(0.72, 0.82, 0.95), "vol": Color(1.0, 0.93, 0.82)},
	{"h": 18.8, "pitch": -8.0, "yaw": -88.0, "col": Color(1.0, 0.6, 0.36), "energy": 2.3, "amb": 0.52,
		"sky": [Color(0.2, 0.26, 0.58), Color(0.58, 0.46, 0.64), Color(0.98, 0.66, 0.44), Color(1.0, 0.5, 0.28), Color(0.32, 0.3, 0.32)],
		"cloud": [Color(1.0, 0.8, 0.7), Color(1.0, 0.62, 0.4), Color(0.48, 0.44, 0.62)], "fog": Color(0.92, 0.64, 0.5), "vol": Color(1.0, 0.72, 0.5)},
	{"h": 20.0, "pitch": -2.0, "yaw": -104.0, "col": Color(0.9, 0.42, 0.34), "energy": 0.8, "amb": 0.42,
		"sky": [Color(0.1, 0.12, 0.34), Color(0.3, 0.24, 0.46), Color(0.7, 0.4, 0.42), Color(0.9, 0.36, 0.3), Color(0.18, 0.17, 0.22)],
		"cloud": [Color(0.7, 0.5, 0.55), Color(0.9, 0.4, 0.34), Color(0.28, 0.26, 0.42)], "fog": Color(0.5, 0.36, 0.42), "vol": Color(0.8, 0.5, 0.5)},
	{"h": 21.5, "pitch": -42.0, "yaw": 150.0, "col": Color(0.55, 0.65, 1.0), "energy": 0.55, "amb": 0.34,
		"sky": [Color(0.02, 0.04, 0.12), Color(0.05, 0.08, 0.2), Color(0.1, 0.13, 0.26), Color(0.12, 0.15, 0.3), Color(0.04, 0.06, 0.08)],
		"cloud": [Color(0.22, 0.26, 0.4), Color(0.28, 0.3, 0.46), Color(0.08, 0.1, 0.18)], "fog": Color(0.06, 0.09, 0.18), "vol": Color(0.5, 0.58, 0.85)},
	{"h": 24.0, "pitch": -42.0, "yaw": 150.0, "col": Color(0.55, 0.65, 1.0), "energy": 0.55, "amb": 0.34,
		"sky": [Color(0.02, 0.04, 0.12), Color(0.05, 0.08, 0.2), Color(0.1, 0.13, 0.26), Color(0.12, 0.15, 0.3), Color(0.04, 0.06, 0.08)],
		"cloud": [Color(0.22, 0.26, 0.4), Color(0.28, 0.3, 0.46), Color(0.08, 0.1, 0.18)], "fog": Color(0.06, 0.09, 0.18), "vol": Color(0.5, 0.58, 0.85)},
]

const SKY_PARAMS := ["zenith", "mid_sky", "horizon", "warm_horizon", "ground"]
const CLOUD_PARAMS := ["cloud_light", "cloud_sunlit", "cloud_shade"]

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _clock := 0.0


func setup(sun: DirectionalLight3D, env: Environment) -> void:
	_sun = sun
	_env = env
	_sky = env.sky.sky_material as ShaderMaterial
	apply(float(GameState.world_date["hour"]))


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.25:
		return
	_clock = 0.0
	apply(float(GameState.world_date["hour"]))


## Light and sky for an hour of the day (0-24).
func apply(hour: float) -> void:
	hour = fposmod(hour, 24.0)
	var i := 0
	while i < KEYS.size() - 2 and hour >= float(KEYS[i + 1]["h"]):
		i += 1
	var a: Dictionary = KEYS[i]
	var b: Dictionary = KEYS[i + 1]
	var span := float(b["h"]) - float(a["h"])
	var t := smoothstep(0.0, 1.0, (hour - float(a["h"])) / maxf(span, 0.001))
	_sun.rotation = Vector3(deg_to_rad(lerpf(a["pitch"], b["pitch"], t)), lerp_angle(deg_to_rad(a["yaw"]), deg_to_rad(b["yaw"]), t), 0.0)
	_sun.light_color = (a["col"] as Color).lerp(b["col"], t)
	_sun.light_energy = lerpf(a["energy"], b["energy"], t)
	_env.ambient_light_energy = lerpf(a["amb"], b["amb"], t)
	_env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], t)
	_env.volumetric_fog_albedo = (a["vol"] as Color).lerp(b["vol"], t)
	if _sky:
		for n in SKY_PARAMS.size():
			_sky.set_shader_parameter(SKY_PARAMS[n], ((a["sky"] as Array)[n] as Color).lerp((b["sky"] as Array)[n], t))
		for n in CLOUD_PARAMS.size():
			_sky.set_shader_parameter(CLOUD_PARAMS[n], ((a["cloud"] as Array)[n] as Color).lerp((b["cloud"] as Array)[n], t))
