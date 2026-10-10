extends Node
## Dev: Zoltraak focus aim and firing modes, captured from behind her.
## godot --path game -- --dbg --aim --out=<dir>
## env: DBG_VIEW = degrees off straight-behind (default 18)
var _p: Player
var _sheet: Image
var _n := 0
var CW := int(OS.get_environment("DBG_CW")) if OS.get_environment("DBG_CW") != "" else 400
var CH := CW * 9 / 16
const COLS := 3


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1
	print("DBG snap %s charge=%.2f blend=%.2f focus=%s mana=%.0f" % [label, _p.aim_charge, _p.aim_blend, _p.focus_aim, _p.caster.mana])


func _check(name: String, ok: bool) -> void:
	print("DBG %s %s" % ["PASS" if ok else "FAIL", name])


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_sheet = Image.create(CW * COLS, CH * 4, false, Image.FORMAT_RGB8)
	await get_tree().create_timer(1.5).timeout
	_p = main.player
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 1.0
	rig.pitch = deg_to_rad(-9.0)
	var view := float(OS.get_environment("DBG_VIEW")) if OS.get_environment("DBG_VIEW") != "" else 18.0
	_p.caster.mana = _p.caster.max_mana
	_p.model.rotation.y = 0.0
	rig.yaw = PI + deg_to_rad(view)
	# Two practice targets ahead in the meadow.
	var fwd := Vector3(0, 0, -1)
	for off in [Vector3(-3.0, 0, -15.0), Vector3(4.0, 0, -19.0)]:
		var m := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.5
		cm.height = 1.9
		m.mesh = cm
		m.add_to_group("zoltraak_target")
		main.add_child(m)
		var pos: Vector3 = _p.global_position + off
		pos.y = MeadowTerrain.instance.height_at(pos.x, pos.z) + 0.95
		m.global_position = pos
	await _p.staff.summon()
	_p.caster.equip(1)
	await get_tree().create_timer(1.0).timeout
	await _snap("neutral ready")
	_check("zoltraak equipped counts as combat-ready", _p.caster.current_spell().aim)

	# Hold RMB: focus aim.
	_p._begin_focus_aim()
	await get_tree().create_timer(0.5).timeout
	await _snap("focus aim stage 1")
	_check("focus aim active", _p.focus_aim)
	await get_tree().create_timer(0.7).timeout
	await _snap("focus aim stage 2")
	await get_tree().create_timer(0.9).timeout
	await _snap("full charge")
	_check("charge reaches 1.0 by 1.5 s", _p.aim_charge >= 0.99)

	# Quick shot, burst, volley, sustained beam while still aiming.
	_p.caster.mana = 50.0
	var mana0 := _p.caster.mana
	_p._fire_variant("quick")
	_check("quick shot costs mana", _p.caster.mana < mana0)
	await get_tree().create_timer(0.1).timeout
	await _snap("quick shot")
	await get_tree().create_timer(0.5).timeout
	_p._fire_variant("burst")
	await get_tree().create_timer(0.22).timeout
	await _snap("rapid burst")
	await get_tree().create_timer(0.9).timeout
	_p._fire_variant("volley")
	await get_tree().create_timer(0.35).timeout
	await _snap("tracking volley")
	await get_tree().create_timer(1.3).timeout
	_p.caster.mana = 60.0
	Input.action_press("cast")
	_p._fire_variant("beam")
	await get_tree().create_timer(0.8).timeout
	await _snap("sustained beam")
	var m_beam := _p.caster.mana
	await get_tree().create_timer(0.5).timeout
	_check("beam drains mana while held", _p.caster.mana < m_beam)
	Input.action_release("cast")
	await get_tree().create_timer(0.9).timeout

	# Release RMB at full charge: the heavy shot.
	_p.aim_charge = 1.0
	_p._end_focus_aim(true)
	await get_tree().create_timer(0.2).timeout
	await _snap("heavy shot")
	await get_tree().create_timer(1.2).timeout
	await _snap("after")
	_check("focus ended", not _p.focus_aim)
	_sheet.save_png(out.path_join("aim_sheet.png"))
	get_tree().quit()
