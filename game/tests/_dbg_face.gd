extends Node
var main: Node
func _ready() -> void:
	main = get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var rig: CameraRig = p.camera_rig
	rig.zoom = 0.18
	rig.yaw = p.model.rotation.y   # camera in front, looking at her face
	rig.pitch = deg_to_rad(-2.0)
	p.face._next_blink = 1e9
	await get_tree().create_timer(1.5).timeout
	for e in ["neutral", "blink", "happy", "surprised", "talk"]:
		p.face.set_expression(e, 10.0)
		if e == "talk":
			p.face.talk(5.0)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("face_%s.png" % e))
	p.face.set_expression("neutral")
	rig.zoom = 0.4
	for side in [-1, 1, 0]:
		rig.yaw = p.model.rotation.y + side * deg_to_rad(55.0)
		await get_tree().create_timer(1.4).timeout
		await RenderingServer.frame_post_draw
		var arm: SpringArm3D = rig.get_node("Pitch/SpringArm3D")
		print("DBG side=%d hit=%.3f len=%.3f fade=%.3f" % [side, arm.get_hit_length(), arm.spring_length, p._fade])
		get_viewport().get_texture().get_image().save_png(out.path_join("look_%d.png" % side))
	rig.yaw = p.model.rotation.y + PI   # behind: should look ahead, not back
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("look_back.png"))
	get_tree().quit()
