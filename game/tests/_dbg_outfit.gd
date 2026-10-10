extends Node
## Dev: dress the stand-in VRoid body in Freyja's outfit, move it (walk-like
## leg/arm swings, turns, a hop) and capture frames from four angles.
## godot --path game -- --dbg --outfit --out=<dir>
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
	var body: Node3D = (load("res://assets/dev/base_female.vrm") as PackedScene).instantiate()
	add_child(body)
	# Open meadow in full sun (no canopy shadows on the cloth).
	var t3: MeadowTerrain = main.terrain
	var spot := Vector3(6.0, 0.0, 14.0)
	spot.y = t3.height_at(spot.x, spot.z)
	body.global_position = spot
	var sim := Outfit.dress(body, load("res://assets/models/characters/freyja_outfit.glb"), load("res://assets/models/characters/freyja_outfit_bodymask.png"))
	if OS.get_environment("DBG_NOSHADOW") != "":
		for mi in Outfit.find_skeleton(body).find_children("*", "MeshInstance3D", false, false):
			if String(mi.name) in ["Skirt", "Petticoat"]:
				(mi as MeshInstance3D).visible = String(mi.name) != "Petticoat"
	if OS.get_environment("DBG_NOSUN") != "":
		main.world.sun.shadow_enabled = false
	if OS.get_environment("DBG_NOSSAO") != "":
		get_viewport().world_3d.environment.ssao_enabled = false
		get_viewport().world_3d.environment.sdfgi_enabled = false
	print("DBG dressed, springs: ", sim != null, " settings ", sim.setting_count if sim else 0)
	var skel := Outfit.find_skeleton(body)
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.current = true
	var sheet := Image.create(300 * 8, 450 * 4, false, Image.FORMAT_RGB8)
	var bones := {}
	for n in ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftUpperArm", "RightUpperArm", "Hips", "Spine"]:
		bones[n] = skel.find_bone(n)
	var rest := {}
	for n in bones:
		rest[n] = skel.get_bone_pose_rotation(bones[n])
	var t := 0.0
	var frame := 0
	for row in 4:
		var yaw: float = [0.0, 0.9, PI * 0.5, PI][row]
		for col in 8:
			for k in 5:
				var dt := get_process_delta_time()
				t += 0.016
				var s := sin(t * 7.0)
				# Walk-like swing + arms down from T-pose.
				skel.set_bone_pose_rotation(bones["LeftUpperLeg"], rest["LeftUpperLeg"] * Quaternion(Vector3.RIGHT, 0.55 * s))
				skel.set_bone_pose_rotation(bones["RightUpperLeg"], rest["RightUpperLeg"] * Quaternion(Vector3.RIGHT, -0.55 * s))
				skel.set_bone_pose_rotation(bones["LeftLowerLeg"], rest["LeftLowerLeg"] * Quaternion(Vector3.RIGHT, -0.6 * maxf(0.0, -s)))
				skel.set_bone_pose_rotation(bones["RightLowerLeg"], rest["RightLowerLeg"] * Quaternion(Vector3.RIGHT, -0.6 * maxf(0.0, s)))
				_rot_global(skel, bones["LeftUpperArm"], Quaternion(Vector3.FORWARD, 1.15) * Quaternion(Vector3.RIGHT, 0.3 * s))
				_rot_global(skel, bones["RightUpperArm"], Quaternion(Vector3.FORWARD, -1.15) * Quaternion(Vector3.RIGHT, -0.3 * s))
				body.rotation.y = yaw + 0.25 * sin(t * 1.3)
				await get_tree().process_frame
			var c := body.global_position + Vector3(0, 0.85, 0)
			cam.global_position = c + Vector3(0, 0.15, 3.2)
			cam.look_at(c, Vector3.UP)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			if col == 4:
				img.save_png(out.path_join("full_%d.png" % row))
			var w := img.get_width()
			var h := img.get_height()
			img = img.get_region(Rect2i(int(w * 0.3), 0, int(w * 0.4), h))
			img.resize(300, 450, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, 300, 450), Vector2i(col * 300, row * 450))
			frame += 1
	sheet.save_png(out.path_join("outfit_motion.png"))
	get_tree().quit()


## Rotate a bone by q in skeleton space, starting from its rest pose.
func _rot_global(skel: Skeleton3D, b: int, q: Quaternion) -> void:
	var parent := skel.get_bone_parent(b)
	var pg := skel.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var rg := skel.get_bone_global_rest(b).basis.get_rotation_quaternion()
	var pr := skel.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	# local = parent_pose^-1 * q * (parent_pose * parent_rest^-1 * rest)
	skel.set_bone_pose_rotation(b, pg.inverse() * q * (pg * pr.inverse() * rg))
