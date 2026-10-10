extends Node
## Dev: every animation clip on the player model, front view, 3 moments each.
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var p: Player = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var tree: AnimationTree = p.loco.tree if p.loco else null
	if tree:
		tree.active = false
	var ap: AnimationPlayer = CharacterVisual.find_animation_player(p.model)
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.current = true
	var c := p.global_position + Vector3(0, 0.95, 0)
	cam.global_position = c + p.model.global_basis.z * 3.2 + Vector3(0, 0.1, 0)
	cam.look_at(c, Vector3.UP)
	var clips := ["Idle", "Talk", "IdleStaff", "Summon", "SummonReach", "Cast"]
	if OS.get_environment("DBG_CLIPS") != "":
		clips = Array(OS.get_environment("DBG_CLIPS").split(","))
		var src: Node = (load("res://assets/animations/ual/ual1.glb") as PackedScene).instantiate()
		var lib := (src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation_library("")
		ap.add_animation_library("ual", lib)
		clips = clips.map(func(c): return "ual/" + c)
	var sheet := Image.create(300 * 3, 400 * clips.size(), false, Image.FORMAT_RGB8)
	for r in clips.size():
		var a := ap.get_animation(clips[r])
		print("CLIP ", clips[r], " len ", a.length if a else -1.0, " tracks ", a.get_track_count() if a else 0)
		ap.play(clips[r])
		for k in 3:
			ap.seek(a.length * (0.15 + 0.35 * k), true)
			await get_tree().create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var w := img.get_width()
			var h := img.get_height()
			img = img.get_region(Rect2i(int(w * 0.3), 0, int(w * 0.4), h))
			img.resize(300, 400, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, 300, 400), Vector2i(k * 300, r * 400))
	sheet.save_png(out.path_join("clips.png"))
	get_tree().quit()
