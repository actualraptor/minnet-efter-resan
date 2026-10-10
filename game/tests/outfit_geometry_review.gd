extends Node3D
## Milestone 1: static material/fit review. No SpringBoneSimulator3D.
## godot --path game res://tests/outfit_geometry_review.tscn -- --out=<absolute folder>

const ASSET := "res://assets/models/characters/freyja_reference_outfit/"
var avatar: Node3D
var camera: Camera3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("34363b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6c4dc")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 0.8
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color("cad7f0")
	fill.light_energy = 0.35
	add_child(fill)
	var body_scene := load("res://assets/models/characters/freyja_vroid.vrm") as PackedScene
	if body_scene == null:
		push_error("Geometry review requires the owner-provided Freyja VRM.")
		get_tree().quit(1)
		return
	avatar = body_scene.instantiate()
	add_child(avatar)
	var original_meshes := avatar.find_children("*", "MeshInstance3D", true, false)
	# Disable imported VRM hair springs too: this is a static geometry gate.
	for modifier in avatar.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	Outfit.dress(avatar, load(ASSET + "outfit.glb"), load(ASSET + "bodymask.png"), true, false, false)
	var skel := Outfit.find_skeleton(avatar)
	if skel == null:
		get_tree().quit(1)
		return
	# Static A-pose for garment silhouette, no animation or physics.
	for side in ["Left", "Right"]:
		var bone := skel.find_bone(side + "UpperArm")
		if bone >= 0:
			var parent := skel.get_bone_parent(bone)
			var pg := skel.get_bone_global_pose(parent).basis.get_rotation_quaternion()
			var rest := skel.get_bone_global_rest(bone).basis.get_rotation_quaternion()
			var pr := skel.get_bone_global_rest(parent).basis.get_rotation_quaternion()
			var q := Quaternion(Vector3.FORWARD, 1.2 if side == "Left" else -1.2)
			skel.set_bone_pose_rotation(bone, pg.inverse() * q * (pg * pr.inverse() * rest))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	add_child(camera)
	camera.current = true
	var out := ""
	var show_avatar := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		if arg == "--garments-only":
			show_avatar = false
	if not show_avatar:
		for part in original_meshes:
			(part as MeshInstance3D).visible = false
	if out.is_empty():
		_set_view(0.0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var angles := {"front": 0.0, "side": PI / 2.0, "back": PI, "three_quarter": 0.6}
	for label in angles:
		_set_view(angles[label])
		for frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		capture.save_png(out.path_join("geometry_%s.png" % label))
	print("GEOMETRY_REVIEW_CAPTURED: four views, outfit simulation disabled")
	# Closer garment crops expose fit and hardware that a full-body view can hide.
	for angle in [0.0, PI]:
		var target := Vector3(0, 1.05, 0)
		camera.size = 1.0
		camera.position = target + Vector3(sin(angle) * 4, 0.04, cos(angle) * 4)
		camera.look_at(target)
		for frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("detail_%s.png" % ("front" if angle == 0.0 else "back")))
	# Skirt, hem and ruffles close-up (front three-quarter) and the sleeve cuff.
	for shot in [["skirt", Vector3(0, 0.62, 0), 0.5, 0.95], ["cuff", Vector3(0.36, 1.0, 0), 0.25, 0.45]]:
		var target: Vector3 = shot[1]
		camera.size = shot[3]
		camera.position = target + Vector3(sin(shot[2]) * 4, 0.04, cos(shot[2]) * 4)
		camera.look_at(target)
		for frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("detail_%s.png" % shot[0]))
	get_tree().quit()

func _set_view(angle: float) -> void:
	var target := Vector3(0, 0.85, 0)
	camera.position = target + Vector3(sin(angle) * 4, 0.12, cos(angle) * 4)
	camera.look_at(target)
