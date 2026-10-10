extends Node
## Dev audit: how high her ankles/toes are above the terrain (idle, walk, run).
func _ready() -> void:
	var main := get_parent()
	var p: Player = main.player
	var t: MeadowTerrain = main.terrain
	var skel: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var bones := {}
	for bn in ["foot.L", "foot.R", "toe.L", "toe.R"]:
		bones[bn] = skel.find_bone(bn)
	print("DBG bones ", bones, " grounder ", p.grounder != null)
	var start := Vector3(-14.0, 0, 6.0)
	start.y = t.height_at(start.x, start.z) + 0.1
	p.teleport(start, PI * 0.5)
	for phase in ["idle", "walk", "run"]:
		for a in ["move_right", "move_forward", "run"]:
			Input.action_release(a)
		if phase != "idle":
			Input.action_press("move_forward")
		if phase == "run":
			Input.action_press("run")
		await get_tree().create_timer(1.2).timeout
		var mins := {}
		var tt := 0.0
		while tt < 1.5:
			tt += get_process_delta_time()
			await skel.skeleton_updated
			for bn in bones:
				if bones[bn] < 0:
					continue
				var g: Vector3 = (skel.global_transform * skel.get_bone_global_pose(bones[bn])).origin
				var h := g.y - t.height_at(g.x, g.z)
				mins[bn] = minf(mins.get(bn, 99.0), h)
		var body_h := p.global_position.y - t.height_at(p.global_position.x, p.global_position.z)
		print("DBG %s min heights %s  body-over-ground %.3f  model.y %.3f  on_floor %s" % [phase, mins, body_h, p.model.position.y, p.is_on_floor()])
	get_tree().quit()
