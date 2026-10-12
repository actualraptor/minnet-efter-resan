class_name Settings
extends RefCounted
## Player options, kept in user://settings.cfg: four volumes (master, music,
## ambience, effects), mouse sensitivity and fullscreen. The sub-buses are created
## at runtime (the project's bus layout only has Master).

const PATH := "user://settings.cfg"
const BUSES := ["Music", "Ambience", "Effects"]

static var master := 1.0
static var music := 0.8
static var ambience := 1.0
static var effects := 1.0
## Multiplier on the camera's mouse look (1 = the designed feel).
static var mouse := 1.0
static var fullscreen := false


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master = clampf(float(cfg.get_value("audio", "master", master)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
	ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)
	effects = clampf(float(cfg.get_value("audio", "effects", effects)), 0.0, 1.0)
	mouse = clampf(float(cfg.get_value("input", "mouse", mouse)), 0.3, 2.5)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "ambience", ambience)
	cfg.set_value("audio", "effects", effects)
	cfg.set_value("input", "mouse", mouse)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


static func apply() -> void:
	ensure_buses()
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("Ambience", ambience)
	_set_bus("Effects", effects)
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


static func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)
