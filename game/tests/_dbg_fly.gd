extends Node
## Dev: exercise flight + stamina + casting from the air, capture a contact sheet.
## godot --path game -- --dbg --fly --out=<dir>
var _p: Player
var _sheet: Image
var _n := 0
const CW := 300
const CH := 440


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	img = img.get_region(Rect2i(int(w * 0.2), int(h * 0.0), int(w * 0.6), int(h * 1.0)))
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % 4) * CW, (_n / 4) * CH))
	_n += 1
	print("DBG snap %s  y=%.2f stamina=%.1f flying=%s vy=%.2f model.y=%.2f" % [label, _p.global_position.y, _p.stamina, _p.flying, _p.velocity.y, _p.model.position.y])


func _check(name: String, ok: bool) -> void:
	print("DBG %s %s" % ["PASS" if ok else "FAIL", name])


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_sheet = Image.create(CW * 4, CH * 2, false, Image.FORMAT_RGB8)
	await get_tree().create_timer(1.5).timeout
	_p = main.player
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 0.55
	rig.pitch = deg_to_rad(-8.0)
	rig.yaw = _p.model.rotation.y + deg_to_rad(65.0)
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()
	await get_tree().create_timer(0.8).timeout

	var y0 := _p.global_position.y
	_check("start: grounded, full stamina", _p.is_on_floor() and _p.stamina >= 99.0 and not _p.flying)
	_check("takeoff succeeds", _p.start_flight())
	await _hold("jump", 1.6)
	await _snap("climbed")
	_check("climbed above ground", _p.global_position.y > y0 + 2.0)
	_check("still flying", _p.flying)
	_check("stamina drains", _p.stamina < 99.0)
	await get_tree().create_timer(0.8).timeout
	var y_hover := _p.global_position.y
	await get_tree().create_timer(1.0).timeout
	_check("holds altitude with no input", absf(_p.global_position.y - y_hover) < 0.3)
	await _snap("hovering")

	# Cast Zoltraak from the air; stamina drops by more than the hover alone.
	_p.caster.equip(1)
	_p.aim_point_override = _p.global_position + Vector3(0, -2.0, 14.0)
	var s_before := _p.stamina
	var reason := _p.caster.try_cast()
	_check("can cast zoltraak while flying (reason='%s')" % reason, reason == "")
	await get_tree().create_timer(0.55).timeout
	await _snap("zoltraak aloft")
	await get_tree().create_timer(1.2).timeout
	_check("cast cost stamina (>= 4.5 + drain)", s_before - _p.stamina > 4.5)
	_p.aim_point_override = Vector3.INF

	# Fly forward fast.
	Input.action_press("move_forward")
	await get_tree().create_timer(1.2).timeout
	await _hold("run", 1.0)
	await _snap("boosting")
	Input.action_release("move_forward")
	await get_tree().create_timer(1.0).timeout

	# Cast the flower spell from the air: effect must originate on the ground.
	_p.caster.equip(0)
	var fr := _p.caster.try_cast()
	_check("flower spell from the air (reason='%s')" % fr, fr == "")
	await get_tree().create_timer(2.0).timeout
	await _snap("flowers aloft")
	await get_tree().create_timer(2.6).timeout

	# Descend and land.
	var guard := 0.0
	Input.action_press("descend")
	while _p.flying and guard < 12.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	Input.action_release("descend")
	await get_tree().create_timer(0.4).timeout
	await _snap("landed")
	_check("landed by descending", not _p.flying and _p.is_on_floor())

	# Exhaustion: low stamina forces a gentle fall.
	await get_tree().create_timer(0.8).timeout
	_p.stamina = 20.0
	_p._exhausted = false
	_check("takeoff with 20 stamina", _p.start_flight())
	await _hold("jump", 1.0)
	_p.stamina = 1.0
	await get_tree().create_timer(1.0).timeout
	_check("exhaustion ends flight", not _p.flying)
	await _snap("exhausted")
	var vmin := 0.0
	var guard2 := 0.0
	while not _p.is_on_floor() and guard2 < 10.0:
		await get_tree().process_frame
		vmin = minf(vmin, _p.velocity.y)
		guard2 += get_process_delta_time()
	_check("exhausted fall is gentle (vmin=%.2f)" % vmin, vmin > -3.5)
	_check("cannot retake off while exhausted", not _p.start_flight())
	await _snap("end")
	_sheet.save_png(out.path_join("fly_sheet.png"))
	get_tree().quit()
