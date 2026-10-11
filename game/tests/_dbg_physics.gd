extends Node
## Dev: long scripted motion (walk, run, turns, jump, flight, casts) while every
## hair / skirt / cape spring bone is sampled each frame. Reports instability:
## NaNs, speed or acceleration spikes, and bones that stray far from their rest
## position relative to the hips. Objective evidence for "stable physics".
##   godot --path game -- --dbg --physics
var _p: Player
var _sk: Skeleton3D
var _bones: Array[int] = []
var _names: Array[String] = []
var _prev: Array[Vector3] = []
var _prev_v: Array[Vector3] = []
var _rest: Array[Vector3] = []
var _max_speed := {}
var _max_acc := {}
var _max_off := {}
var _nan := 0
var _frames := 0
var _phase := "idle"
var _phase_stats := {}


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	await get_tree().create_timer(1.2).timeout
	_p = main.player
	_sk = _p.model.find_children("*", "Skeleton3D", true, false)[0]
	for i in _sk.get_bone_count():
		var n := _sk.get_bone_name(i)
		if n.begins_with("hairB_") or n.begins_with("skirt_") or n.begins_with("cape_"):
			_bones.append(i)
			_names.append(n)
	print("PHYS tracking %d spring bones" % _bones.size())
	var hips := _sk.find_bone("Hips")
	for i in _bones:
		_prev.append(Vector3.ZERO)
		_prev_v.append(Vector3.ZERO)
		_rest.append(_rel(i, hips, true))
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 1.0
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()

	# Scripted sequence.
	await _run_phase("walk", ["move_forward"], 3.0, rig, 0.0)
	await _run_phase("run", ["move_forward", "run"], 3.0, rig, 0.0)
	await _run_phase("run+turn", ["move_forward", "run"], 5.0, rig, 1.2)
	await _run_phase("stop", [], 1.5, rig, 0.0)
	_p.caster.equip(1)
	_p._cast_with_staff()
	await _run_phase("zoltraak", [], 1.8, rig, 0.0)
	await _run_phase("jump", ["move_forward", "jump"], 1.0, rig, 0.0)
	await _run_phase("land", [], 1.2, rig, 0.0)
	_p.start_flight()
	await _run_phase("fly climb", ["jump"], 1.5, rig, 0.0)
	await _run_phase("fly boost+turn", ["move_forward", "run"], 4.0, rig, 1.0)
	await _run_phase("fly hover", [], 1.5, rig, 0.0)
	_p.caster.equip(0)
	_p.caster.try_cast()
	await _run_phase("flower aloft", [], 3.5, rig, 0.0)
	_p.stop_flight()
	await _run_phase("descend", ["descend"], 3.0, rig, 0.0)

	print("PHYS frames=%d nan=%d" % [_frames, _nan])
	var worst_speed := 0.0
	var worst_acc := 0.0
	var worst_off := 0.0
	for ph in _phase_stats:
		var s: Dictionary = _phase_stats[ph]
		print("PHYS phase %-15s max speed %5.1f m/s  max acc %6.0f m/s2  max offset %.2f m" % [ph, s.speed, s.acc, s.off])
		worst_speed = maxf(worst_speed, s.speed)
		worst_acc = maxf(worst_acc, s.acc)
		worst_off = maxf(worst_off, s.off)
	print("PHYS worst speed=%.1f acc=%.0f offset=%.2f" % [worst_speed, worst_acc, worst_off])
	var bad := _nan > 0 or worst_speed > 40.0 or worst_off > 1.6
	print("PHYS %s" % ("FAIL" if bad else "PASS"))
	get_tree().quit()


## Bone position in the model's frame (yaw only), relative to the hips.
func _rel(bone: int, hips: int, _rest_pose: bool) -> Vector3:
	var gp := _sk.global_transform * _sk.get_bone_global_pose(bone).origin
	var hp := _sk.global_transform * _sk.get_bone_global_pose(hips).origin
	var yaw := Basis(Vector3.UP, _p.model.global_rotation.y)
	return yaw.inverse() * (gp - hp)


func _run_phase(label: String, actions: Array, seconds: float, rig: CameraRig, turn_rate: float) -> void:
	_phase = label
	if not _phase_stats.has(label):
		_phase_stats[label] = {"speed": 0.0, "acc": 0.0, "off": 0.0}
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "jump", "descend"]:
		Input.action_release(a)
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	var hips := _sk.find_bone("Hips")
	while t < seconds:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if turn_rate != 0.0:
			rig.yaw += turn_rate * dt * (1.0 if int(t * 0.5) % 2 == 0 else -1.0)
		_frames += 1
		var st: Dictionary = _phase_stats[label]
		for k in _bones.size():
			var pos := _rel(_bones[k], hips, false)
			if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
				_nan += 1
				continue
			var v := (pos - _prev[k]) / maxf(dt, 1e-4)
			var acc := (v - _prev_v[k]).length() / maxf(dt, 1e-4)
			if _frames > 4:
				st.speed = maxf(st.speed, v.length())
				st.acc = maxf(st.acc, acc)
				st.off = maxf(st.off, pos.distance_to(_rest[k]))
			_prev[k] = pos
			_prev_v[k] = v
	for a in actions:
		Input.action_release(a)
