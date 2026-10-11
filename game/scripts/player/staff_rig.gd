class_name StaffRig
extends Node
## Transform authority for the staff during staff spells.
##
## While a StaffPoseClip plays, this node owns the staff's pose: the rear fist and
## shaft direction are sampled from the clip (torso-anchored frame), the staff is
## derived from them, and StaffGrip solves both arms to its grip points. Outside
## a clip (weight 0) the staff is simply carried in the right hand
## (StaffSummon), exactly as before. The blend between the two is one weight:
## the staff, the hand IK and the torso posture all use the same value, so
## nothing snaps.

signal pose_event(event_name: String)
signal finished

var model: Node3D                       # yaw reference
var skeleton: Skeleton3D
var clip: StaffPoseClip
var cast_time := 1.0
var recovery_time := 0.5
var weight := 0.0
var sustained := false                  # holds at clip.sustain_t until release_hold()
var playing := false

## Where the staff would be if simply carried in the hand (set by StaffSummon).
var carry_global := Transform3D.IDENTITY
## Elevation (radians above horizontal) of the point being aimed at; set by the
## Player each frame while aiming.
var aim_elevation := 0.0
## How far (radians) the shaft may tilt off the clip's pitch to follow the aim:
## a little on foot, nearly straight up/down in flight.
var max_aim_delta := 0.31
## Driving value for param_driven clips (flight speed 0..1).
var param := 0.0

# Results of the last evaluate(); read by StaffGrip and StaffSummon.
var state: Dictionary = {}
var staff_global := Transform3D.IDENTITY
var rear_fist := Vector3.ZERO
var front_fist := Vector3.ZERO
var shaft_up := Vector3.UP
var anchor := Transform3D.IDENTITY
var grip_left := 0.0                    # effective left-hand grip weight
var free_left := 0.0                    # effective free-hand weight

var _t := 0.0
var _kick := Vector3.ZERO
var _kick_v := Vector3.ZERO
var _fired := {}
var _holding := false
var _ibone := -1


func setup(skel: Skeleton3D, model_node: Node3D) -> void:
	skeleton = skel
	model = model_node
	_ibone = RigNames.find(skel, "UpperChest")
	if _ibone < 0:
		_ibone = RigNames.find(skel, "chest")


func is_active() -> bool:
	return weight > 0.001


## Start a performance. cast_time = seconds to the release moment, recovery_time =
## seconds from there back to rest.
## Returns the seconds until the release moment: shorter than cast_t when the
## clip chains from a previous cast that is still in its recovery.
func play(c: StaffPoseClip, cast_t: float, recovery_t: float, hold_at_sustain := false) -> float:
	var chained := playing and clip == c and c.chain_t >= 0.0 and weight > 0.5
	clip = c
	cast_time = maxf(cast_t, 0.05)
	recovery_time = maxf(recovery_t, 0.05)
	sustained = hold_at_sustain and c.sustain_t >= 0.0
	_holding = sustained
	_t = 0.0
	var wind_up := cast_time
	if chained:
		var f := c.chain_t / maxf(c.release_t, 1e-3)
		_t = cast_time * f
		wind_up = cast_time * (1.0 - f)
	_fired.clear()
	playing = true
	return wind_up


## For sustained casts: let go and run the recovery.
## Hold a param_driven clip (flight carry) until stop_param().
func play_param(c: StaffPoseClip) -> void:
	clip = c
	cast_time = 1.0e6   # never reaches its end: sampling is by param
	recovery_time = 1.0e6
	_holding = false
	sustained = false
	_t = 0.0
	_fired.clear()
	playing = true


func stop_param() -> void:
	if clip and clip.param_driven:
		playing = false


func release_hold() -> void:
	_holding = false


func cancel() -> void:
	playing = false
	_holding = false


func _sustain_spell_time() -> float:
	return cast_time + recovery_time * (clip.sustain_t - clip.release_t) / maxf(1.0 - clip.release_t, 1e-3)


## A reactive shove on the staff hand (e.g. something hit the barrier), `v` in
## the torso frame, metres per second; a damped spring settles it.
func kick(v: Vector3) -> void:
	_kick_v += v


func _process(delta: float) -> void:
	_kick_v += (-_kick * 260.0 - _kick_v * 16.0) * delta
	_kick += _kick_v * delta
	var goal := 0.0
	if playing and clip:
		goal = 1.0
		var total := cast_time + recovery_time
		var nt := _t + delta
		if _holding and clip.sustain_t >= 0.0:
			nt = minf(nt, _sustain_spell_time())
		_t = minf(nt, total)
		var ct := clip.clip_time(_t, cast_time, recovery_time)
		for e in clip.events:
			if ct >= e.t and not _fired.has(e.name):
				_fired[e.name] = true
				pose_event.emit(e.name)
		if _t >= total:
			playing = false
			finished.emit()
	# Ease the authority in quickly, out a little slower.
	var rate := 7.0 if goal > weight else 4.5
	weight = move_toward(weight, goal, delta * rate)
	if not playing and weight <= 0.0:
		state = {}


## Pose sample for the current time (no skeleton access: safe to call first).
func sample() -> Dictionary:
	if clip == null:
		return {}
	if clip.param_driven:
		state = clip.sample(clampf(param, 0.0, 1.0))
	else:
		state = clip.sample(clip.clip_time(_t, cast_time, recovery_time))
	return state


func evaluate() -> void:
	if skeleton == null or model == null or clip == null or state.is_empty():
		return
	var w := smoothstep(0.0, 1.0, weight)
	var origin := skeleton.global_transform * skeleton.get_bone_global_pose(_ibone).origin
	anchor = Transform3D(model.global_basis.orthonormalized(), origin)
	var q: Quaternion = state.q
	if clip.level_to_world:
		q = Quaternion(Vector3.RIGHT, -model.rotation.x) * q
	if clip.aims:
		# Tilt the shaft toward the camera aim (elevation), within a safe range.
		var d := clampf(aim_elevation - deg_to_rad(clip.aim_elev_deg), -max_aim_delta, max_aim_delta)
		q = Quaternion(Vector3.RIGHT, -d * w) * q
	var u := q * Vector3.UP
	# While authority is blending in, the right hand keeps its carry grip and
	# slides to the rear grip as the staff comes up (a deliberate regrip).
	var ry := lerpf(0.0, float(state.ry), w)
	var fy := float(state.fy)
	var origin_local: Vector3 = (state.rear as Vector3) + _kick - u * ry
	var authored := anchor * Transform3D(Basis(q), origin_local)
	staff_global = carry_global.interpolate_with(authored, w)
	shaft_up = staff_global.basis * Vector3.UP
	rear_fist = staff_global * Vector3(0.0, ry, 0.0)
	front_fist = staff_global * Vector3(0.0, fy, 0.0)
	grip_left = w * float(state.gl)
	free_left = w * (1.0 - float(state.gl)) * float(state.fw)
