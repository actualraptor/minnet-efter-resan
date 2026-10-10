extends Node
## Dev: full-res single frames mid-walk and mid-run from the side and three-quarter back.
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
	rig.outdoor_length = 2.4
	rig.pitch = deg_to_rad(-6.0)
	for view in [["side", 0.0, "move_right"], ["backq", 0.9, "move_forward"]]:
		var start := Vector3(-14.0, 0, 6.0)
		start.y = t.height_at(start.x, start.z) + 0.1
		p.teleport(start, PI * 0.5)
		rig.yaw = view[1]
		await get_tree().create_timer(1.0).timeout
		for run in [false, true]:
			for a in ["move_right", "move_forward", "run"]:
				Input.action_release(a)
			Input.action_press(view[2])
			if run:
				Input.action_press("run")
			await get_tree().create_timer(1.4).timeout
			for i in 3:
				await get_tree().create_timer(0.13).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s_%d.png" % [view[0], "run" if run else "walk", i]))
		for a in ["move_right", "move_forward", "run"]:
			Input.action_release(a)
	get_tree().quit()
