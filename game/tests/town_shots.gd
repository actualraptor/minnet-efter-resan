extends Node
## Dev: capture a handful of fixed viewpoints of the Linköping slice.
##   TOWN_SHOTS=<out dir> godot --path game res://scenes/linkoping.tscn
## Each shot: [name, camera position, look-at point, fov].
const SHOTS := [
	["approach", Vector3(14, 3.2, 122), Vector3(0, 12, 20), 62.0],
	["bridge", Vector3(-10, 4.0, 82), Vector3(0, 3, 50), 60.0],
	["street", Vector3(0, 2.2, 48), Vector3(0, 8, -20), 62.0],
	["square", Vector3(0, 3.5, 26), Vector3(0, 4, -10), 64.0],
	["fountain", Vector3(9, 3.0, 9), Vector3(0, 3.0, 0), 55.0],
	["cathedral", Vector3(30, 15.0, -2), Vector3(0, 14, -40), 60.0],
	["overview", Vector3(-70, 55, 150), Vector3(0, 6, 10), 55.0],
	["river", Vector3(60, 5.0, 40), Vector3(0, 0, 58), 58.0],
]


func _ready() -> void:
	var main := get_parent()
	var out := OS.get_environment("TOWN_SHOTS")
	main.get_node("UI").visible = false
	var rig := main.get_node("CameraRig") as Node3D
	rig.set_process(false)
	var cam := Camera3D.new()
	cam.far = 1200.0
	main.add_child(cam)
	cam.make_current()
	await get_tree().create_timer(2.0).timeout
	for s in SHOTS:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = s[3]
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("town_%s.png" % s[0]))
		print("TOWN shot ", s[0])
	print("TOWN houses=", main.get_node("World").house_count)
	get_tree().quit()
