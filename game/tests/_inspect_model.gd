extends SceneTree
## Dev: prints the node tree, skeleton names and materials of a model scene.
##   godot --headless --path game --script res://tests/_inspect_model.gd -- res://path/model.glb
func _init() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		path = a
	var ps := load(path) as PackedScene
	if ps == null:
		print("cannot load ", path)
		quit()
		return
	var root := ps.instantiate()
	_dump(root, 0)
	for s in root.find_children("*", "Skeleton3D", true, false):
		print("SKELETON ", s.name, " bones=", (s as Skeleton3D).get_bone_count())
		var names := PackedStringArray()
		for i in mini((s as Skeleton3D).get_bone_count(), 40):
			names.append((s as Skeleton3D).get_bone_name(i))
		print("  first bones: ", ", ".join(names))
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		print("ANIM ", ap.name, " ", (ap as AnimationPlayer).get_animation_list())
	root.free()
	quit()


func _dump(n: Node, depth: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mats := []
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			mats.append(m.resource_name if m else "<none>")
		extra = " mesh surfaces=%d mats=%s aabb=%s" % [mi.mesh.get_surface_count(), mats, mi.get_aabb().size]
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	if depth < 4:
		for c in n.get_children():
			_dump(c, depth + 1)
