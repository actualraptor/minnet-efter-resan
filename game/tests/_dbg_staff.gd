extends Node
## Dev: perform a staff spell and capture contact sheets + grip diagnostics.
## godot --path game -- --dbg --staff --out=<dir>
## env: DBG_ACT=zoltraak|flower|barrier  DBG_VIEW=<deg from behind>  DBG_ZOOM  DBG_PITCH
##      DBG_STEP=<seconds between frames>  DBG_HOVER=1  DBG_FRAMES=<n>
var _snap := {}
var _sk: Skeleton3D
var _rg: StaffRig


## Hand poses as the renderer sees them: read inside skeleton_updated, before the
## skeleton restores the unmodified pose.
func _on_skel_updated() -> void:
	if _sk == null or _rg == null or not _rg.is_active():
		return
	var sg := _sk.global_transform
	for side in ["Right", "Left"]:
		var hi := _sk.find_bone(side + "Hand")
		var mi := _sk.find_bone(side + "MiddleProximal")
		var ho := sg * _sk.get_bone_global_pose(hi).origin
		var mo := sg * _sk.get_bone_global_pose(mi).origin
		var d := _rg.shaft_up
		_snap[side] = {
			"dh": (ho - _rg.staff_global.origin).cross(d).length(),
			"dm": (mo - _rg.staff_global.origin).cross(d).length(),
			"basis": sg.basis * _sk.get_bone_global_pose(hi).basis,
		}


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await get_tree().create_timer(1.5).timeout
	var p: Player = main.player
	var act := OS.get_environment("DBG_ACT") if OS.get_environment("DBG_ACT") != "" else "zoltraak"
	var view := float(OS.get_environment("DBG_VIEW")) if OS.get_environment("DBG_VIEW") != "" else 150.0
	var step := float(OS.get_environment("DBG_STEP")) if OS.get_environment("DBG_STEP") != "" else 0.1
	var frames := int(OS.get_environment("DBG_FRAMES")) if OS.get_environment("DBG_FRAMES") != "" else 14
	var rig: CameraRig = p.camera_rig
	rig.zoom = float(OS.get_environment("DBG_ZOOM")) if OS.get_environment("DBG_ZOOM") != "" else 0.8
	rig.pitch = deg_to_rad(float(OS.get_environment("DBG_PITCH")) if OS.get_environment("DBG_PITCH") != "" else -6.0)
	p.caster.mana = p.caster.max_mana
	if OS.get_environment("DBG_HOVER") == "1":
		p.set_hover(true)
	# Summon the staff and let it settle.
	await p.staff.summon()
	await get_tree().create_timer(1.0).timeout
	var idx: int = {"flower": 0, "zoltraak": 1, "barrier": 2}[act]
	p.caster.equip(idx)
	# Aim straight down +Z (world) at a point slightly above the ground.
	p.aim_point_override = p.global_position + Vector3(0, 1.6, 14.0)
	p.model.rotation.y = 0.0
	rig.yaw = PI + deg_to_rad(view)
	await get_tree().create_timer(0.6).timeout
	var cols := int(OS.get_environment("DBG_COLS")) if OS.get_environment("DBG_COLS") != "" else 7
	var rows := int(ceil(float(frames) / cols))
	var cw := int(OS.get_environment("DBG_CW")) if OS.get_environment("DBG_CW") != "" else 260
	var ch := int(cw * 1.46)
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGB8)
	var hand_cam: Camera3D = null
	var hand_side := OS.get_environment("DBG_HAND")
	var hand_off := Vector3(0.5, 0.25, 0.6)
	if OS.get_environment("DBG_OFF") != "":
		var o := OS.get_environment("DBG_OFF").split(",")
		hand_off = Vector3(float(o[0]), float(o[1]), float(o[2]))
	if hand_side != "":
		hand_cam = Camera3D.new()
		hand_cam.fov = 38.0
		hand_cam.near = 0.05
		main.add_child(hand_cam)
		hand_cam.make_current()
	var sk: Skeleton3D = p.staff_grip.get_skeleton()
	_sk = sk
	_rg = p.staff_rig
	sk.skeleton_updated.connect(_on_skel_updated)
	for mod in sk.get_children():
		print("DBG modifier[%d] %s %s active=%s influence=%s" % [mod.get_index(), mod.name, mod.get_class(), str(mod.get("active")), str(mod.get("influence"))])
	print("DBG modifier_callback_mode=", sk.modifier_callback_mode_process)
	for side in ["Right", "Left"]:
		var h := sk.find_bone(side + "Hand")
		var mp := sk.find_bone(side + "MiddleProximal")
		var tp := sk.find_bone(side + "ThumbProximal")
		var ip := sk.find_bone(side + "IndexProximal")
		var lp := sk.find_bone(side + "LittleProximal")
		var gr := sk.get_bone_global_rest(h)
		var inv := gr.basis.inverse()
		print("DBG %s hand rest basis x=%s y=%s z=%s" % [side, gr.basis.x, gr.basis.y, gr.basis.z])
		print("DBG %s local dirs: middle=%s thumb=%s index=%s little=%s" % [side,
			inv * (sk.get_bone_global_rest(mp).origin - gr.origin), inv * (sk.get_bone_global_rest(tp).origin - gr.origin),
			inv * (sk.get_bone_global_rest(ip).origin - gr.origin), inv * (sk.get_bone_global_rest(lp).origin - gr.origin)])
	if act == "barrier":
		Input.action_press("cast")   # sustained spells hold while the button is down
	var reason := p.caster.try_cast()
	print("DBG cast reason='%s' act=%s" % [reason, act])
	var t := 0.0
	var next := float(OS.get_environment("DBG_SKIP")) if OS.get_environment("DBG_SKIP") != "" else 0.0
	var n := 0
	var hit_done := false
	while n < frames:
		var d := get_process_delta_time()
		t += d
		await get_tree().process_frame
		if hand_cam and p.staff_rig:
			var r0: StaffRig = p.staff_rig
			var tgt: Vector3 = r0.rear_fist if hand_side == "R" else (r0.front_fist if hand_side == "L" else p.global_position + Vector3(0, 1.25, 0))
			hand_cam.global_position = tgt + p.model.global_basis * hand_off
			hand_cam.look_at(tgt, Vector3.UP)
		if act == "barrier" and not hit_done and t > 1.6:
			hit_done = true
			Input.action_release("cast")
			p.caster.barrier_hit(p.global_position + Vector3(0.2, 1.2, 1.8))
		if act == "barrier" and t > 2.4 and t < 2.5:
			pass
		if t >= next:
			next += step
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var w := img.get_width()
			var h := img.get_height()
			img = img.get_region(Rect2i(int(w * 0.25), int(h * 0.02), int(w * 0.5), int(h * 0.96)))
			img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((n % cols) * cw, (n / cols) * ch))
			var g: StaffGrip = p.staff_grip
			var r: StaffRig = p.staff_rig
			var butt_local := Vector3.ZERO
			if r and r.is_active():
				var butt := r.staff_global * Vector3(0, -0.86, 0)
				butt_local = r.anchor.affine_inverse() * butt
			for side in _snap:
				var sn: Dictionary = _snap[side]
				var hb: Basis = sn.basis
				print("DBG   %s hand-to-shaft=%.3f midProx-to-shaft=%.3f hand x=%s y=%s z=%s shaft=%s" % [side, sn.dh, sn.dm, hb.x.snapped(Vector3.ONE * 0.01), hb.y.snapped(Vector3.ONE * 0.01), hb.z.snapped(Vector3.ONE * 0.01), r.shaft_up.snapped(Vector3.ONE * 0.01)])
			print("DBG t=%.2f w=%.2f reachR=%.3f reachL=%.3f butt=(%.2f %.2f %.2f) lift=%.2f yaw=%.0f" % [
				t, r.weight if r else -1.0, g.reach_error["R"] if g else -1.0, g.reach_error["L"] if g else -1.0,
				butt_local.x, butt_local.y, butt_local.z, p.hover_height(), rad_to_deg(p.model.rotation.y)])
			n += 1
	sheet.save_png(out.path_join("staff_%s_v%d.png" % [act, int(view)]))
	get_tree().quit()
