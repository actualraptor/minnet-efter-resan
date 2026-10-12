extends Node
## Dev: sanity of the CPU skinning used by ClipAudit: mesh instance transforms,
## skin binding, and where each garment's skinned bounds sit against its aabb.
##   godot --headless --path game -- --dbg --clipcal
func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	await get_tree().create_timer(1.5).timeout
	var p: Player = main.player
	var sk: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var a := ClipAudit.new()
	a.skeleton = sk
	print("CAL skeleton xf origin=", sk.global_transform.origin, " scale=", sk.global_transform.basis.get_scale(), " model scale=", p.model.scale)
	for name in ["Body", "Face", "Hair", "Blouse", "Corset", "Tights", "Capelet", "CreamSkirtLining", "PlumPanel01", "LeftGatheredSleeve"]:
		var mi := sk.get_node_or_null(name) as MeshInstance3D
		if mi == null:
			continue
		var tris := a._skin_triangles(mi, [])
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for v in tris:
			lo = lo.min(v)
			hi = hi.max(v)
		var bb := mi.get_aabb()
		var bb_w := sk.global_transform * mi.transform * bb.get_center()
		print("CAL %-18s xf_identity=%s skin=%s binds=%d  skinned centre=%s size=%s | aabb centre=%s" % [
			name, mi.transform.is_equal_approx(Transform3D.IDENTITY), mi.skin != null,
			mi.skin.get_bind_count() if mi.skin else 0, str((lo + hi) * 0.5), str(hi - lo), str(bb_w)])
	get_tree().quit()
