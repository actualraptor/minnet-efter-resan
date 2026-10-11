extends Node
## Dev: drive the real input events (RMB hold to charge, LMB hold to fire) and
## report what actually happens frame by frame, from the real gameplay camera.
##   godot --path game -- --dbg --input --out=<dir>
var _p: Player
var _sheet: Image
var _n := 0
const COLS := 2
var CW := int(OS.get_environment("DBG_CW")) if OS.get_environment("DBG_CW") != "" else 480
var CH := CW * 9 / 16


func _mouse(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(e)


func _beams() -> Array:
	var out := []
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is ZoltraakBeam:
			out.append(n)
	return out


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1
	var bs := _beams()
	var info := ""
	for b in bs:
		var zb: ZoltraakBeam = b
		info += " beam(width=%.2f len=%.1f body_vis=%s released=%s hit=%s at %s aim=%s muzzle=%s)" % [zb._width, zb._length, zb._body.visible, zb._released, zb.last_trace.get("collider"), zb.last_trace.get("point"), _p.aim_point(), ZoltraakShots.muzzle(_p)]
	print("IN t=%.2f %-26s focus=%s charge=%.2f casting=%s mana=%.0f beams=%d%s" % [Time.get_ticks_msec() / 1000.0, label, _p.focus_aim, _p.aim_charge, _p.caster.casting, _p.caster.mana, bs.size(), info])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_sheet = Image.create(CW * COLS, CH * 4, false, Image.FORMAT_RGB8)
	await _wait(1.5)
	_p = main.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()
	_p.caster.equip(1)
	_p.caster.cast_started.connect(func(sp): print("IN   cast_started %s at %.2f" % [sp.id, Time.get_ticks_msec() / 1000.0]))
	await _wait(0.6)
	_p.camera_rig.pitch = deg_to_rad(-10.0)

	_p._begin_focus_aim()
	await _wait(0.4)
	await _snap("RMB down 0.4s")
	await _wait(1.3)
	await _snap("RMB held 1.7s (charged)")
	Input.action_press("cast")
	_p._fire_charged()
	await _wait(0.15)
	await _snap("LMB down +0.15s")
	await _wait(0.5)
	await _snap("LMB held +0.65s")
	await _wait(0.8)
	await _snap("LMB held +1.45s")
	Input.action_release("cast")
	await _wait(0.15)
	await _snap("LMB released +0.15s")
	await _wait(0.6)
	await _snap("LMB released +0.75s")
	_p._end_focus_aim(false)
	await _wait(0.6)
	await _snap("RMB released")
	_sheet.save_png(out.path_join("input.png"))
	get_tree().quit()
