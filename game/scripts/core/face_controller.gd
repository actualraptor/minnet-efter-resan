class_name FaceController
extends Node
## Living face. Drives blend shapes (glTF morph targets) and eye/iris bones:
##  * blinks on a natural rhythm (eased close/open, occasional double blink)
##  * small eye saccades, optional gaze target (camera, speaker)
##  * speech: mouth opens/closes in syllable-like bursts while talking
##  * expressions ("neutral", "happy", "surprised", "thoughtful", "sad")
##    cross-fade smoothly instead of snapping.
## Blend shapes used: blink, squint, mouth_open, mouth_smile, mouth_o, brow_up.

const EXPRESSIONS := {
	"neutral": {},
	"happy": {"squint": 0.85, "mouth_smile": 1.0, "brow_up": 0.25},
	"surprised": {"brow_up": 1.0, "mouth_o": 0.7, "wide": 1.0},
	"thoughtful": {"squint": 0.25, "brow_up": -0.0},
	"sad": {"squint": 0.35, "mouth_smile": -0.0, "brow_up": 0.15},
	# Casting faces (VRoid shapes, kept subtle: she is calm, not theatrical).
	"focused": {"Fcl_BRW_Angry": 0.32, "Fcl_EYE_Angry": 0.14, "squint": 0.05},
	"serene": {"squint": 0.4, "Fcl_BRW_Fun": 0.45, "mouth_smile": 0.35},
	"alert": {"Fcl_BRW_Angry": 0.22, "Fcl_EYE_Surprised": 0.22, "brow_up": 0.1},
	# Legacy names used by older data.
	"blink": {"blink": 1.0},
	"talk": {},
}

var _shapes: Dictionary = {}          # name -> Array of [MeshInstance3D, index]
var _weights: Dictionary = {}         # name -> current value
var _skel: Skeleton3D
var _eye_bones: Array[int] = []
var _iris_bones: Array[int] = []
var _iris_rest: Array[Vector3] = []
var _materials: Array = []            # kept for API compatibility (painted-face mode removed)

var _base := "neutral"
var _base_until := 0.0
var _talk_until := 0.0
var _next_blink := 0.0
var _blink_t := -1.0
var _double := false
var _syllable_target := 0.0
var _next_syllable := 0.0
var _gaze := Vector2.ZERO
var _gaze_target := Vector2.ZERO
var _next_saccade := 0.0
var look_at_node: Node3D = null


func setup(model: Node, _character: String) -> bool:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_blend_shape_count():
			var n := String(m.mesh.get_blend_shape_name(i))
			if not _shapes.has(n):
				_shapes[n] = []
				_weights[n] = 0.0
			_shapes[n].append([m, i])
	for sk in model.find_children("*", "Skeleton3D", true, false):
		_skel = sk
		for bn in ["eye.L", "eye.R"]:
			var i := _skel.find_bone(bn)
			if i >= 0:
				_eye_bones.append(i)
		for bn in ["iris.L", "iris.R"]:
			var i := _skel.find_bone(bn)
			if i >= 0:
				_iris_bones.append(i)
				_iris_rest.append(_skel.get_bone_rest(i).origin)
		break
	_schedule_blink()
	return is_ready()


func is_ready() -> bool:
	return not _shapes.is_empty() or not _eye_bones.is_empty()


func blend_shape_count() -> int:
	return _shapes.size()


func set_expression(expr: String, hold := 0.0) -> void:
	if not EXPRESSIONS.has(expr):
		return
	_base = expr
	_base_until = _now() + hold if hold > 0.0 else 0.0


func talk(seconds: float) -> void:
	_talk_until = _now() + seconds


func stop_talking() -> void:
	_talk_until = 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _schedule_blink() -> void:
	_next_blink = _now() + randf_range(2.0, 5.5)


func _blink_curve(t: float) -> float:
	# 0 -> 1 in 70 ms (fast close), hold 30 ms, back to 0 over 140 ms (slower open).
	if t < 0.07:
		return ease(t / 0.07, 0.6)
	if t < 0.10:
		return 1.0
	if t < 0.24:
		return 1.0 - ease((t - 0.10) / 0.14, 1.8)
	return -1.0


func _process(delta: float) -> void:
	if not is_ready():
		return
	var t := _now()
	if _base_until > 0.0 and t > _base_until:
		_base = "neutral"
		_base_until = 0.0
	var target: Dictionary = (EXPRESSIONS[_base] as Dictionary).duplicate()
	# --- blinking ---------------------------------------------------------------
	var blink := 0.0
	if _blink_t < 0.0 and t >= _next_blink and _base != "happy":
		_blink_t = 0.0
		_double = randf() < 0.15
	if _blink_t >= 0.0:
		_blink_t += delta
		var b := _blink_curve(_blink_t)
		if b < 0.0:
			if _double:
				_double = false
				_blink_t = 0.0
			else:
				_blink_t = -1.0
				_schedule_blink()
			b = 0.0
		blink = b
	target["blink"] = maxf(float(target.get("blink", 0.0)), blink)
	# --- speech --------------------------------------------------------------------
	if t < _talk_until:
		if t >= _next_syllable:
			var gap := randf() < 0.18
			_syllable_target = 0.05 if gap else randf_range(0.35, 1.0)
			_next_syllable = t + (randf_range(0.1, 0.2) if gap else randf_range(0.07, 0.15))
		target["mouth_open"] = maxf(float(target.get("mouth_open", 0.0)), _syllable_target * (0.6 if _base == "happy" else 1.0))
	# --- apply with smoothing (fast for blink/mouth, slower for expressions) --------
	for n in _shapes:
		var want := float(target.get(n, 0.0))
		var rate := 60.0 if n == "blink" else (22.0 if n.begins_with("mouth_open") else 7.0)
		var v: float = _weights[n]
		v = want if n == "blink" else lerpf(v, want, 1.0 - exp(-rate * delta))
		_weights[n] = v
		for pair in _shapes[n]:
			(pair[0] as MeshInstance3D).set_blend_shape_value(pair[1], v)
	# --- eyes: widen and gaze --------------------------------------------------------
	if _skel:
		var wide := 1.0 + 0.07 * float(target.get("wide", 0.0))
		for i in _eye_bones:
			var cur := _skel.get_bone_pose_scale(i)
			_skel.set_bone_pose_scale(i, cur.lerp(Vector3(wide, wide, wide), 1.0 - exp(-8.0 * delta)))
		_update_gaze(t, delta)


func _update_gaze(t: float, delta: float) -> void:
	if _iris_bones.is_empty():
		return
	if t >= _next_saccade:
		_next_saccade = t + randf_range(0.6, 2.8)
		var base := Vector2.ZERO
		if is_instance_valid(look_at_node):
			var head_i := RigNames.find(_skel, "head")
			var head_xf := _skel.global_transform * _skel.get_bone_global_pose(head_i)
			var local := head_xf.affine_inverse() * look_at_node.global_position
			base = Vector2(clampf(local.x * 0.6, -1.0, 1.0), clampf(local.y * 0.6 - 0.1, -1.0, 1.0))
		_gaze_target = base + Vector2(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25))
	# Saccades are quick but not instant.
	_gaze = _gaze.lerp(_gaze_target, 1.0 - exp(-28.0 * delta))
	var off := Vector3(_gaze.x * 0.0028, _gaze.y * 0.0016, 0.0)
	for k in _iris_bones.size():
		_skel.set_bone_pose_position(_iris_bones[k], _iris_rest[k] + off)
