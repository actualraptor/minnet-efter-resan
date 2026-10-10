extends Node
## Dev: VRoid Freyja + reference outfit with spring physics on, walking, running
## and stopping in the meadow. Contact sheets from side, back and front.
## godot --path game -- --dbg --vroid --out=<dir>
const COLS := 6
const CW := 320
const CH := 440
var out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var main := get_parent()
	main.get_node("UI").visible = false
	var p: Player = main.player
	p.visible = false
	p.set_physics_process(false)
	var t: MeadowTerrain = main.terrain
	var root := Node3D.new()
	add_child(root)
	var model: Node3D = (load("res://assets/models/characters/freyja_vroid_game.glb") as PackedScene).instantiate()
	root.add_child(model)
	CharacterVisual.prepare(model)
	var sim := CharacterPhysics.setup(model)
	print("DBG springs ", sim.setting_count if sim else 0)
	var sg := OS.get_environment("DBG_SKIRT")    # e.g. "grav=0" or "stiff=8"
	if sg != "" and sim:
		for i in sim.setting_count:
			if String(sim.get_root_bone_name(i)).begins_with("skirt_"):
				var kv := sg.split("=")
				if kv[0] == "grav":
					sim.set_gravity(i, float(kv[1]))
				elif kv[0] == "stiff":
					sim.set_stiffness(i, float(kv[1]))
		print("DBG skirt override ", sg)
	var phys := OS.get_environment("DBG_PHYS")
	if phys != "":
		for m in model.find_children("*", "SkeletonModifier3D", true, false):
			if (phys == "off") or (phys == "nofollow" and m is SkirtLegFollow):
				(m as SkeletonModifier3D).active = false
		print("DBG phys mode ", phys)
	var anim := CharacterVisual.find_animation_player(model)
	print("DBG clips ", anim.get_animation_list())
	var mode := OS.get_environment("DBG_SHADOWMODE")
	if mode != "":
		var body_names := ["Body", "Face", "Hair"]
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var is_body := String(mi.name) in body_names
			if (mode == "outfit_off" and not is_body) or (mode == "body_off" and is_body):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		print("DBG meshes ", model.find_children("*", "MeshInstance3D", true, false).map(func(m): return m.name).slice(0, 8))
	if OS.get_environment("DBG_NOSUN") != "":
		main.world.sun.shadow_enabled = false
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.current = true
	for view in [["side", Vector3(0, 0, 3.6)], ["back", Vector3(-3.6, 0, 0)], ["front", Vector3(3.6, 0, 0)]]:
		var gm := WorldLayout.GARDEN_MEADOW
		var pos := Vector3(gm.x - 6.0, 0.0, gm.z)   # open meadow behind the cottage
		root.global_position = Vector3(pos.x, t.height_at(pos.x, pos.z), pos.z)
		root.rotation.y = PI * 0.5      # model forward (+Z) -> world +X
		anim.play("Idle")
		if sim:
			sim.reset()
		await get_tree().create_timer(0.8).timeout
		var sheet := Image.create(CW * COLS, CH * 3, false, Image.FORMAT_RGB8)
		var n := 0
		for phase in [["Walk", 1.296, 1.2, 0.07], ["Run", 3.147, 1.0, 0.05], ["Idle", 0.0, 0.0, 0.1]]:
			anim.play(phase[0], 0.25)
			var speed: float = phase[1]
			var tt := 0.0
			var shots := 0
			var next_shot: float = phase[2]
			while shots < COLS:
				var dt := get_process_delta_time()
				tt += dt
				var x := root.global_position.x + speed * dt
				root.global_position = Vector3(x, t.height_at(x, pos.z), pos.z)
				var c := root.global_position + Vector3(0, 0.8, 0)
				cam.global_position = c + view[1] + Vector3(0, 0.12, 0)
				cam.look_at(c, Vector3.UP)
				await get_tree().process_frame
				if tt >= next_shot:
					next_shot = tt + phase[3]
					await RenderingServer.frame_post_draw
					var img := get_viewport().get_texture().get_image()
					img.convert(Image.FORMAT_RGB8)
					var w := img.get_width()
					var h := img.get_height()
					img = img.get_region(Rect2i(int(w * 0.33), int(h * 0.04), int(w * 0.34), int(h * 0.92)))
					img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
					sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((n % COLS) * CW, (n / COLS) * CH))
					n += 1
					shots += 1
		sheet.save_png(out.path_join("vroid_%s.png" % view[0]))
	# Close-ups: skirt from the side while running (knee vs. skirt), then the hand.
	var gm2 := WorldLayout.GARDEN_MEADOW
	root.global_position = Vector3(gm2.x - 6.0, t.height_at(gm2.x - 6.0, gm2.z), gm2.z)
	anim.play("Run")
	for k in 6:
		var dt := 0.0
		var steps := 0
		while steps < 7:
			var d := get_process_delta_time()
			var x := root.global_position.x + 3.147 * d
			root.global_position = Vector3(x, t.height_at(x, gm2.z), gm2.z)
			var c := root.global_position + Vector3(0, 0.62, 0)
			cam.global_position = c + Vector3(0.25, 0.05, 1.5)
			cam.look_at(c, Vector3.UP)
			await get_tree().process_frame
			steps += 1
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("runskirt_%d.png" % k))
	anim.play("Walk")
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hand := skel.find_bone("RightHand")
	for k in 3:
		await get_tree().create_timer(0.23).timeout
		var hp := (skel.global_transform * skel.get_bone_global_pose(hand)).origin
		cam.global_position = hp + Vector3(0.05, 0.05, -0.55)
		cam.look_at(hp, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("hand_%d.png" % k))
	get_tree().quit()
