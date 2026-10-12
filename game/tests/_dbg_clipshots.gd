extends Node
## Dev: close-up stills of the places hair and cloth clip: back, shoulders,
## sides and front, at rest and in motion.
##   godot --path game --screen 1 --audio-driver Dummy -- --dbg --clipshots --out=<dir>
var _out := ""
var _p: Player
var _rig: CameraRig


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(label + ".png"))
	print("SHOT ", label)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _angles(prefix: String, zoom: float, pitch_deg := -4.0) -> void:
	_rig.zoom = zoom
	_rig.pitch = deg_to_rad(pitch_deg)
	var base := _p.model.rotation.y
	for item in [["back", PI], ["left", PI * 0.5], ["right", -PI * 0.5], ["front34", 0.45]]:
		_rig.yaw = base + float(item[1])
		await _wait(0.35)
		await _snap("%s_%s" % [prefix, item[0]])


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	await _wait(1.5)
	_p = main.player
	_rig = _p.camera_rig
	await _p.staff.summon()
	# Rest.
	await _angles("idle", 0.42)
	# Walking away: hold forward, the camera keeps its set angle.
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_press("run")
	await _wait(1.6)
	await _angles("run", 0.5)
	Input.action_release("move_forward")
	Input.action_release("run")
	await _wait(0.4)
	await _angles("stopping", 0.5)
	_p.caster.equip(1)
	_p._cast_with_staff()
	await _wait(0.9)
	await _angles("cast", 0.55)
	get_tree().quit()
