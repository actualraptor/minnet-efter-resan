extends Node
## Captures frame sequences of Linnaea moving, to judge locomotion and
## hair/cloth secondary motion:
##   godot --path game --screen 1 --audio-driver Dummy -- --motion --out=<dir>
## Sequence: idle -> walk -> run -> sudden stop -> turn; side-on camera.

var main: Node
var out_dir := "user://motion"


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main.get_node("UI").visible = false
	await get_tree().create_timer(2.0).timeout
	await _run()
	get_tree().quit()


func _frame(i: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("m_%03d.png" % i))


func _run() -> void:
	var p: Player = main.player
	var t: MeadowTerrain = main.terrain
	var start := Vector3(-14.0, 0, 6.0)
	start.y = t.height_at(start.x, start.z) + 0.1
	p.teleport(start, PI * 0.5)  # facing +X
	var rig: CameraRig = p.camera_rig
	rig.outdoor_length = 3.6
	rig.shoulder_offset = 0.0
	rig.yaw = 0.0        # camera looks along -Z: side view of movement along +X
	rig.pitch = deg_to_rad(-6.0)
	await get_tree().create_timer(1.0).timeout
	var i := 0
	# Movement is camera-relative: "move_right" walks along +X.
	var plan := [["", 0.6], ["walk", 1.8], ["run", 1.6], ["", 1.4], ["left", 1.0], ["", 0.8]]
	for step in plan:
		Input.action_release("move_right")
		Input.action_release("move_left")
		Input.action_release("run")
		match step[0]:
			"walk":
				Input.action_press("move_right")
			"run":
				Input.action_press("move_right")
				Input.action_press("run")
			"left":
				Input.action_press("move_left")
		var until: float = Time.get_ticks_msec() / 1000.0 + step[1]
		while Time.get_ticks_msec() / 1000.0 < until:
			await get_tree().create_timer(0.05).timeout
			await _frame(i)
			i += 1
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("run")
	print("MOTION frames: ", i)
