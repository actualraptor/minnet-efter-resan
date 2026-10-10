extends Node
## Dev audit: full-res close frames of the waist/skirt mid-stride from several angles.
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
	var start := Vector3(-14.0, 0, 6.0)
	start.y = t.height_at(start.x, start.z) + 0.1
	p.teleport(start, PI * 0.5)
	await get_tree().create_timer(1.0).timeout
	rig.outdoor_length = 1.6
	rig.pitch = deg_to_rad(-8.0)
	var k := 0
	for ang in [90.0, 135.0, 180.0, 225.0, 270.0, 0.0]:
		var start2 := Vector3(-14.0, 0, 6.0)
		start2.y = t.height_at(start2.x, start2.z) + 0.1
		p.teleport(start2, PI * 0.5)
		rig.yaw = p.model.rotation.y + deg_to_rad(ang)
		# Move in model-forward direction regardless of camera.
		await get_tree().create_timer(0.5).timeout
		for run in [false, true]:
			Input.action_press("move_forward") if false else null
			p.set_meta("dbg_dir", Vector3(1, 0, 0))
			var dur := 1.2
			var tt := 0.0
			while tt < dur:
				var d := get_process_delta_time()
				tt += d
				_drive(p, rig, run)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("waist_%03d_%s.png" % [int(ang), "run" if run else "walk"]))
			k += 1
		_release()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("waist_%03d_stop.png" % int(ang)))
	get_tree().quit()

func _release() -> void:
	for a in ["move_right", "move_left", "move_forward", "move_back", "run"]:
		Input.action_release(a)

func _drive(p: Player, rig: CameraRig, run: bool) -> void:
	# Pick the input whose camera-relative direction is closest to world +X.
	_release()
	var best := ""
	var bd := -2.0
	var basis := Basis(Vector3.UP, rig.yaw)
	var dirs := {"move_forward": -basis.z, "move_back": basis.z, "move_left": -basis.x, "move_right": basis.x}
	for a in dirs:
		var dd: float = (dirs[a] as Vector3).dot(Vector3(1, 0, 0))
		if dd > bd:
			bd = dd
			best = a
	Input.action_press(best)
	if run:
		Input.action_press("run")
	# keep the camera angle relative to her heading
