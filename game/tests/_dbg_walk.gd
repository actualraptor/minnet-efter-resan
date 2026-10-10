extends Node
## Dev audit: contact sheets of walk / run / stop (rows) from side and back,
## for checking skirt + hair springs and clipping in motion.
var main: Node
var out := ""
var _sheet: Image
var _n := 0
const COLS := 8
const CW := 240
const CH := 300

func _ready() -> void:
	main = get_parent()
	main.get_node("UI").visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var p: Player = main.player
	var t: MeadowTerrain = main.terrain
	var rig: CameraRig = p.camera_rig
	rig.shoulder_offset = 0.0
	rig.outdoor_length = 3.0
	rig.pitch = deg_to_rad(-4.0)
	for view in ["side", "back", "front"]:
		var start := Vector3(-14.0, 0, 6.0)
		start.y = t.height_at(start.x, start.z) + 0.1
		p.teleport(start, PI * 0.5)
		rig.yaw = {"side": 0.0, "back": PI * 0.5, "front": -PI * 0.5}[view]
		var fwd: String = {"side": "move_right", "back": "move_forward", "front": "move_back"}[view]
		await get_tree().create_timer(1.2).timeout
		_sheet = Image.create(CW * COLS, CH * 3, false, Image.FORMAT_RGB8)
		_n = 0
		_press([fwd])
		await get_tree().create_timer(1.2).timeout
		for i in COLS:
			await get_tree().create_timer(0.07).timeout
			await _grab()
		_press([fwd, "run"])
		await get_tree().create_timer(1.3).timeout
		for i in COLS:
			await get_tree().create_timer(0.05).timeout
			await _grab()
		_press([])
		for i in COLS:
			await get_tree().create_timer(0.1).timeout
			await _grab()
		_sheet.save_png(out.path_join("walk_%s.png" % view))
	get_tree().quit()

func _press(actions: Array) -> void:
	for a in ["move_right", "move_left", "move_forward", "move_back", "run"]:
		Input.action_release(a)
	for a in actions:
		Input.action_press(a)

func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	img = img.get_region(Rect2i(int(w * 0.34), int(h * 0.12), int(w * 0.32), int(h * 0.8)))
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1
