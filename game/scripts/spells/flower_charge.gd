extends Node3D
## Field of Flowers circle: a petal circle blooms on the ground under her while
## she gathers, turning slowly; at the release it opens outward and dissolves,
## handing over to the wave of flowers.

const COLOR := Color(0.85, 1.0, 0.55)
const BASE_RADIUS := 1.15

var _body: Node3D
var _circle: MagicCircle
var _t := 0.0
var _dur := 1.0
var _done := false


func begin(body: Node3D, _spell: SpellDefinition, cast_time: float) -> void:
	_body = body
	_dur = maxf(cast_time, 0.05)
	_circle = MagicCircle.new()
	add_child(_circle)
	_circle.build(BASE_RADIUS, COLOR, MagicCircle.Style.PETAL)
	_circle.alpha = 0.0
	# Lie flat: the circle's normal (+Z) points up.
	_circle.rotation_degrees = Vector3(-90, 0, 0)
	_follow()


func _follow() -> void:
	if _body and is_instance_valid(_body):
		var ground: Vector3 = _body.call("ground_point") if _body.has_method("ground_point") else _body.global_position
		global_position = ground + Vector3(0, 0.07, 0)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_follow()
	var p := clampf(_t / _dur, 0.0, 1.0)
	_circle.scale = Vector3.ONE * lerpf(0.2, 1.0, smoothstep(0.0, 0.8, p))
	_circle.alpha = smoothstep(0.0, 0.4, p) * 0.9


func finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_circle, "scale", Vector3.ONE * 5.5, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_circle, "alpha", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
