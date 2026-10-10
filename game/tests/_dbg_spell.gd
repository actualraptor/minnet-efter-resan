extends Node
## Dev audit: contact sheets of every staff-summon variant and the cast,
## from a front-quarter camera, for checking clipping and timing.
var main: Node
var out := ""
var _sheet: Image
var _n := 0
const COLS := 6
const CW := 320
const CH := 240

func _ready() -> void:
	main = get_parent()
	main.get_node("UI").visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var rig: CameraRig = p.camera_rig
	rig.zoom = 0.62
	rig.pitch = deg_to_rad(-6.0)
	for v in StaffSummon.VARIANTS.keys():
		for ang in [35.0, -60.0]:
			rig.yaw = p.model.rotation.y + deg_to_rad(ang)
			await get_tree().create_timer(0.8).timeout
			_begin()
			p.staff.summon(v)
			for i in 12:
				await get_tree().create_timer(0.1).timeout
				await _grab()
			_save("summon_%s_%d.png" % [v, int(ang)])
			await get_tree().create_timer(0.6).timeout
			p.staff.stow()
			await get_tree().create_timer(1.2).timeout
	for ang in [35.0, -60.0, 150.0]:
		rig.yaw = p.model.rotation.y + deg_to_rad(ang)
		await get_tree().create_timer(0.8).timeout
		_begin()
		p._cast_with_staff()
		for i in 18:
			await get_tree().create_timer(0.12 if i > 5 else 0.18).timeout
			await _grab()
		_save("cast_%d.png" % int(ang))
		await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _begin() -> void:
	_sheet = Image.create(CW * COLS, CH * 3, false, Image.FORMAT_RGB8)
	_n = 0

func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	# Crop the middle (she is centred) and shrink.
	var w := img.get_width()
	var h := img.get_height()
	img = img.get_region(Rect2i(int(w * 0.25), int(h * 0.1), int(w * 0.5), int(h * 0.85)))
	img.resize(CW, CH * 2 if false else CH, Image.INTERPOLATE_BILINEAR)
	if _n < COLS * 3:
		_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1

func _save(name: String) -> void:
	_sheet.save_png(out.path_join(name))
