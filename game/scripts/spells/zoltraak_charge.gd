extends Node3D
## Zoltraak charge visual for the full cast (no focus-aim): the six-petal circle
## forms just in front of the staff head, facing where it points, and builds to
## full brightness by the release moment. It follows the staff every frame.

var _body: Node3D
var _circle: SixPetalCircle
var _light: OmniLight3D
var _t := 0.0
var _dur := 0.5
var _done := false


func begin(body: Node3D, _spell: SpellDefinition, cast_time: float) -> void:
	_body = body
	_dur = maxf(cast_time, 0.05)
	_circle = SixPetalCircle.new(0.62)
	add_child(_circle)
	_circle.set_alpha(0.0)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.8, 1.0)
	_light.omni_range = 3.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_follow()


func _follow() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var dir: Vector3 = ZoltraakShots.aim(_body, Vector3.FORWARD)
	global_position = ZoltraakShots.muzzle(_body) + dir * 0.45
	_circle.face(dir)
	_light.global_position = global_position


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var p := clampf(_t / _dur, 0.0, 1.0)
	_follow()
	_circle.set_charge(p)
	_circle.set_alpha(smoothstep(0.0, 0.3, p))
	_circle.scale = Vector3.ONE * lerpf(0.5, 1.0, smoothstep(0.0, 0.8, p))
	_light.light_energy = 0.4 + 2.6 * p * p


## Release: one bright pulse, then gone.
func finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_circle, "scale", Vector3.ONE * 1.5, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float): _circle.set_alpha(a), 1.0, 0.0, 0.16)
	tw.tween_property(_light, "light_energy", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
