extends Node
## Dev: full-res stills of the staff-out idle from several angles.
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var rig: CameraRig = p.camera_rig
	rig.zoom = 0.45
	rig.pitch = deg_to_rad(-4.0)
	await p.staff.summon("Summon")
	await get_tree().create_timer(1.5).timeout
	for ang in [0.0, 70.0, -70.0, 180.0]:
		rig.yaw = p.model.rotation.y + deg_to_rad(ang)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("staffidle_%d.png" % int(ang)))
	get_tree().quit()
