extends Node
## Dev: cast the Field of Flowers and capture the levitation from the side/front.
## godot --path game -- --dbg --float --out=<dir>
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.5).timeout
	var p: Player = main.player
	var rig: CameraRig = p.camera_rig
	rig.zoom = float(OS.get_environment("DBG_ZOOM")) if OS.get_environment("DBG_ZOOM") != "" else 0.9
	rig.pitch = deg_to_rad(-4.0)
	rig.yaw = p.model.rotation.y + deg_to_rad(float(OS.get_environment("DBG_YAW")) if OS.get_environment("DBG_YAW") != "" else 40.0)
	p.caster.mana = p.caster.max_mana
	p._cast_with_staff()
	var sheet := Image.create(300 * 6, 400 * 2, false, Image.FORMAT_RGB8)
	var n := 0
	var t := 0.0
	var next := 0.0
	while n < 12:
		var d := get_process_delta_time()
		t += d
		await get_tree().process_frame
		if t >= next:
			next += 0.32
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var w := img.get_width()
			var h := img.get_height()
			img = img.get_region(Rect2i(int(w * 0.28), int(h * 0.04), int(w * 0.44), int(h * 0.92)))
			img.resize(300, 400, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, 300, 400), Vector2i((n % 6) * 300, (n / 6) * 400))
			print("DBG t=%.2f hover=%.2f model.y=%.2f body.y=%.2f" % [t, p.hover_height(), p.model.position.y, p.global_position.y])
			n += 1
	sheet.save_png(out.path_join("float_sheet.png"))
	get_tree().quit()
