class_name FaceController
extends Node
## Painted-face expressions: swaps the face material's texture to blink at
## natural intervals, flap the mouth while speaking, and hold expressions
## requested by dialogue lines ("face": "happy" | "surprised" | ...).
## Textures: res://assets/models/characters/faces/<character>_<expression>.png

const EXPRESSIONS := ["neutral", "blink", "happy", "talk", "surprised"]

var _materials: Array[ShaderMaterial] = []
var _tex: Dictionary = {}
var _base := "neutral"
var _base_until := 0.0
var _talk_until := 0.0
var _mouth_open := false
var _next_flap := 0.0
var _next_blink := 0.0
var _blink_end := 0.0
var _shown := ""
## Bone mode: models with eyeball meshes rigged to eye.L / eye.R bones.
var _skel: Skeleton3D
var _eye_bones: Array[int] = []
const EYE_SCALE := {"neutral": 1.0, "talk": 1.0, "blink": 0.07, "happy": 0.28, "surprised": 1.16}


func setup(model: Node, character: String) -> bool:
	for e in EXPRESSIONS:
		var path := "res://assets/models/characters/faces/%s_%s.png" % [character, e]
		if ResourceLoader.exists(path):
			_tex[e] = load(path)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is ShaderMaterial and mat.resource_name.to_lower().contains("face"):
				_materials.append(mat)
	if _materials.is_empty() or not _tex.has("neutral"):
		_materials.clear()
		for sk in model.find_children("*", "Skeleton3D", true, false):
			for bn in ["eye.L", "eye.R"]:
				var i := (sk as Skeleton3D).find_bone(bn)
				if i >= 0:
					_skel = sk
					_eye_bones.append(i)
		for e in EYE_SCALE:
			_tex[e] = null
	_schedule_blink()
	return is_ready()


func is_ready() -> bool:
	return (not _materials.is_empty() and _tex.get("neutral") != null) or not _eye_bones.is_empty()


func set_expression(expr: String, hold := 0.0) -> void:
	if not _tex.has(expr) and not EYE_SCALE.has(expr):
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
	_next_blink = _now() + randf_range(2.2, 5.5)


func _process(_delta: float) -> void:
	if not is_ready():
		return
	var t := _now()
	if _base_until > 0.0 and t > _base_until:
		_base = "neutral"
		_base_until = 0.0
	var want := _base
	if t < _talk_until and _base != "happy":
		if t >= _next_flap:
			_mouth_open = not _mouth_open
			_next_flap = t + randf_range(0.07, 0.15)
		if _mouth_open:
			want = "talk" if _base == "neutral" else _base
	if t >= _next_blink and _base != "happy" and _base != "blink":
		_blink_end = t + 0.11
		_schedule_blink()
	if t < _blink_end:
		want = "blink"
	_show(want)


func _show(expr: String) -> void:
	if not _eye_bones.is_empty():
		var sc: float = EYE_SCALE.get(expr, 1.0)
		for i in _eye_bones:
			_skel.set_bone_pose_scale(i, Vector3(1.0, sc, 1.0))
		_shown = expr
		return
	if expr == _shown or not _tex.has(expr):
		return
	_shown = expr
	for m in _materials:
		m.set_shader_parameter("albedo_texture", _tex[expr])
