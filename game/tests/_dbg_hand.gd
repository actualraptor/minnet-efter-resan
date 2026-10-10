extends Node
## Dev: close-up camera on Freyja's right hand: relaxed, then gripping the staff.
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var skel: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var hb := RigNames.find(skel, "hand.R")
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.current = true
	print("DBG hand poser ", p.hands != null)
	for stage in ["relaxed", "grip"]:
		if stage == "grip":
			await p.staff.summon("Summon")
			await get_tree().create_timer(1.2).timeout
			await skel.skeleton_updated
			var tip: Node3D = p.model.find_child("StaffTip", true, false)
			var hxf := skel.global_transform * skel.get_bone_global_pose(hb)
			# The staff is rigid in hand.R and vertical when the hand is in its grip
			# orientation; its axis passes through the tip, along the hand's grip axis.
			var top := tip.global_position
			var axis := Vector3.UP
			for nm in ["f_middle_1.R", "f_middle_3.R", "f_index_3.R", "thumb_1.R", "thumb_3.R"]:
				var b := skel.find_bone(nm)
				var g := skel.global_transform * skel.get_bone_global_pose(b)
				var tail := g.origin + g.basis.y.normalized() * 0.022
				var v := tail - top
				var d := (v - axis * v.dot(axis)).length()
				print("DBG grip %s tail-dist-to-staff-axis %.3f  height %.3f" % [nm, d, (tail - hxf.origin).y])
			var pv := hxf.origin - top
			print("DBG grip wrist dist %.3f" % (pv - axis * pv.dot(axis)).length())
		else:
			await get_tree().create_timer(0.8).timeout
		for k in 3:
			var ang: float = [0.0, 1.2, -1.0][k]
			var h := (skel.global_transform * skel.get_bone_global_pose(hb)).origin
			var fwd := p.model.global_basis.z
			var right := p.model.global_basis.x
			var dir := (fwd * cos(ang) + right * -sin(ang)).normalized()
			cam.global_position = h + dir * 0.45 + Vector3.UP * 0.08
			cam.look_at(h, Vector3.UP)
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("hand_%s_%d.png" % [stage, k]))
	get_tree().quit()
