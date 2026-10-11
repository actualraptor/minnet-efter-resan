extends Node
## Dev: the practice range as it appears in the real game: dummies, the Mörkstråk
## and Solstråk shooters hunting her, then a barrier up against the black beam.
##   godot --path game -- --dbg --range --out=<dir>
var _p: Player
var _sheet: Image
var _n := 0
const COLS := 2
var CW := int(OS.get_environment("DBG_CW")) if OS.get_environment("DBG_CW") != "" else 960
var CH := CW * 9 / 16


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1
	print("RANGE snap %s" % label)


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_sheet = Image.create(CW * COLS, CH * 3, false, Image.FORMAT_RGB8)
	main.call("_build_practice_range")
	await _wait(1.5)
	_p = main.player
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 1.3
	rig.pitch = deg_to_rad(-6.0)
	# Wide establishing view from behind-left.
	rig.yaw = _p.model.rotation.y + PI * 0.92
	var turrets := get_tree().get_nodes_in_group("zoltraak_target").filter(func(n): return n is ZoltraakTurret)
	print("RANGE turrets=%d dummies=%d" % [turrets.size(), get_tree().get_nodes_in_group("zoltraak_target").size() - turrets.size()])
	for t in turrets:
		t._clock = t.interval - 0.2     # fire soon
	await _wait(1.2)
	await _snap("telegraph")
	await _wait(1.3)
	await _snap("shooters firing at her (no barrier)")
	await _wait(3.0)
	# Barrier up, then wait for the next black beam to land on it.
	_p.caster.equip(2)
	Input.action_press("cast")
	_p.caster.try_cast()
	await _wait(0.8)
	for t in turrets:
		t._clock = t.interval - 0.2
	await _wait(2.4)
	await _snap("barrier against the beams")
	await _wait(1.2)
	await _snap("barrier holding")
	Input.action_release("cast")
	var struck := 0
	for b in get_tree().get_nodes_in_group("magic_barrier"):
		struck += (b as MagicBarrier3D).slot_info().size()
	print("RANGE barrier slots lit=%d" % struck)
	_sheet.save_png(out.path_join("range.png"))
	get_tree().quit()
