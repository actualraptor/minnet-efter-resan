extends Node
## Dev: frame-time measurement in the real scene at fixed viewpoints (vsync off).
##   godot --path game --resolution 1920x1080 -- --dbg --perf
var _main: Node
var _p: Player
var _terrain: MeadowTerrain
var _samples: Array[float] = []
var _recording := false


func _process(delta: float) -> void:
	if _recording:
		_samples.append(delta)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain.height_at(x, z), z)


func _view(pos: Vector3, yaw: float, zoom := 1.2, pitch_deg := -8.0, side := 0.0) -> void:
	_p.teleport(pos, yaw)
	var rig: CameraRig = _p.camera_rig
	rig.zoom = zoom
	rig.pitch = deg_to_rad(pitch_deg)
	rig.yaw = yaw + PI + side


func _measure(label: String, seconds := 6.0) -> void:
	await _wait(1.5)
	_samples.clear()
	_recording = true
	await _wait(seconds)
	_recording = false
	var s := _samples.duplicate()
	s.sort()
	var n := s.size()
	var sum := 0.0
	for x in s:
		sum += x
	var avg := sum / maxf(n, 1)
	var p99: float = s[mini(n - 1, int(n * 0.99))]
	var worst: float = s[n - 1]
	print("PERF %-34s frames=%4d  avg=%5.1f fps (%.1f ms)  1%%low=%5.1f fps  worst=%.1f ms" % [label, n, 1.0 / avg, avg * 1000.0, 1.0 / p99, worst * 1000.0])


func _ready() -> void:
	_main = get_parent()
	_main.get_node("UI").visible = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_p = _main.player
	_terrain = _main.terrain
	print("PERF gpu=%s  viewport=%s" % [RenderingServer.get_video_adapter_name(), get_viewport().get_visible_rect().size])
	GameState.set_quest("garden_of_jonas", "complete")
	GameState.set_quest("jonas_stone", "complete")
	GameState.set_quest("statue_by_the_road", "active")
	_main.call("_build_range_yard")
	await _wait(2.0)

	_view(_ground(-3.5, 33.0) + Vector3(0, 0.2, 0), PI)
	await _measure("meadow at the start (golden hour)")
	var st := StoneQuests.STATUE_POS
	_view(_ground(st.x + 5.0, st.y + 1.0) + Vector3(0, 0.2, 0), -PI / 2.0 - 0.15, 1.0, -6.0, 0.7)
	await _measure("beside the statue")
	var r := _main.get_node("PracticeRange") as PracticeRange
	r.set_active(true)
	var o := PracticeRange.ORIGIN
	_view(_ground(o.x - 8.0, o.y + 3.5) + Vector3(0, 0.2, 0), PI / 2.0, 1.6, -12.0, 0.0)
	await _measure("range, both lanes firing")
	_p.caster.equip(_p.caster.spells.find(SpellLibrary.get_def("spell_barrier")))
	_p.caster.mana = _p.caster.max_mana
	_view(_ground(o.x + 8.0, o.y) + Vector3(0, 0.2, 0), PI / 2.0, 1.2, -8.0, -0.9)
	Input.action_press("cast")
	_p.caster.try_cast()
	await _measure("in a lane, barrier up against a beam")
	Input.action_release("cast")
	r.set_active(false)
	GameState.world_date["hour"] = 21.5
	_view(_ground(-3.5, 33.0) + Vector3(0, 0.2, 0), PI)
	await _measure("meadow at night")
	GameState.world_date["hour"] = 16.0
	var m := WorldLayout.GARDEN_MEADOW
	_view(_ground(m.x, m.z) + Vector3(0, 0.2, 0), 0.0, 1.4, -10.0)
	_p.caster.equip(0)
	_p.caster.mana = _p.caster.max_mana
	_p.caster._cooldowns.clear()
	_p.caster.try_cast()
	await _wait(5.0)
	await _measure("meadow after Field of Flowers")
	get_tree().quit()
