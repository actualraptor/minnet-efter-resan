extends Node
## Dev audit: side view of a running jump and landing (contact sheet + land check).
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var p: Player = main.player
	var t: MeadowTerrain = main.terrain
	var rig: CameraRig = p.camera_rig
	rig.shoulder_offset = 0.0
	rig.outdoor_length = 3.2
	rig.pitch = deg_to_rad(-4.0)
	var start := Vector3(-14.0, 0, 6.0)
	start.y = t.height_at(start.x, start.z) + 0.1
	p.teleport(start, PI * 0.5)
	rig.yaw = 0.0
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_right")
	await get_tree().create_timer(1.0).timeout
	var sheet := Image.create(300 * 6, 400 * 3, false, Image.FORMAT_RGB8)
	Input.action_press("jump")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("jump")
	var landed := false
	for i in 18:
		await get_tree().create_timer(0.06).timeout
		await RenderingServer.frame_post_draw
		if p.loco.tree.get("parameters/land/active"):
			landed = true
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var w := img.get_width()
		var h := img.get_height()
		img = img.get_region(Rect2i(int(w * 0.3), int(h * 0.1), int(w * 0.4), int(h * 0.85)))
		img.resize(300, 400, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, 300, 400), Vector2i((i % 6) * 300, (i / 6) * 400))
	Input.action_release("move_right")
	print("DBG land one-shot fired: ", landed)
	sheet.save_png(out.path_join("jump_sheet.png"))
	get_tree().quit()
