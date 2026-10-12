extends Node
## Dev: line up NPC candidates (VRM files) in the meadow light and screenshot them.
##   godot --path game -- --dbg --npc --out=<dir>
## Env NPC_FILES = comma separated res:// paths (default: the candidate set).
var _out := ""


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var files := ["base_female", "sample_d", "sample_e", "sample_f", "sample_g", "shino"]
	var paths := []
	var env := OS.get_environment("NPC_FILES")
	if env != "":
		paths = env.split(",")
	else:
		for f in files:
			paths.append("res://assets/dev/npc/%s.vrm" % f)
	var terrain: MeadowTerrain = main.terrain
	main.player.visible = false
	var z := 20.0
	var spacing := 1.25
	var x0 := -spacing * (paths.size() - 1) * 0.5
	for i in paths.size():
		var ps := load(paths[i]) as PackedScene
		if ps == null:
			print("NPC cannot load ", paths[i])
			continue
		var m := ps.instantiate() as Node3D
		main.add_child(m)
		var x := x0 + i * spacing
		m.global_position = Vector3(x, terrain.height_at(x, z), z)
		var ok := CharacterVisual.use_humanoid_library(m)
		var anim := CharacterVisual.find_animation_player(m)
		print("NPC ", paths[i], " library=", ok, " idle=", anim != null and anim.has_animation(&"Idle"))
		if anim and anim.has_animation(&"Idle"):
			anim.play(&"Idle")
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 38.0
	cam.make_current()
	cam.global_position = Vector3(0, terrain.height_at(0, z) + 1.25, z + 5.6)
	cam.look_at(Vector3(0, terrain.height_at(0, z) + 0.95, z), Vector3.UP)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("npc_candidates.png"))
	# Close-ups of each head.
	for i in paths.size():
		var x := x0 + i * spacing
		cam.global_position = Vector3(x, terrain.height_at(x, z) + 1.4, z + 1.5)
		cam.look_at(Vector3(x, terrain.height_at(x, z) + 1.38, z), Vector3.UP)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("npc_face_%d.png" % i))
	get_tree().quit()
