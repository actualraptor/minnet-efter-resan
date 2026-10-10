extends Node3D
## Zoltraak charge: a small circle forms just in front of the staff head, facing
## where it points, and tightens to full brightness at the release moment. It
## follows the staff every frame, so it stays welded to the head while the pose
## settles into the aim.

const COLOR := Color(0.85, 0.7, 1.0)

var _body: Node3D
var _circle: MagicCircle
var _light: OmniLight3D
var _t := 0.0
var _dur := 0.5
var _done := false


func begin(body: Node3D, _spell: SpellDefinition, cast_time: float) -> void:
	_body = body
	_dur = maxf(cast_time, 0.05)
	_circle = MagicCircle.new()
	add_child(_circle)
	_circle.build(0.2, COLOR, MagicCircle.Style.RUNE)
	_circle.alpha = 0.0
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_follow()


func _follow() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var dir: Vector3 = _body.call("staff_direction")
	dir = dir.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-dir, up), _body.call("staff_tip") + dir * 0.2)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var p := clampf(_t / _dur, 0.0, 1.0)
	_follow()
	var form := smoothstep(0.0, 0.75, p)
	_circle.scale = Vector3.ONE * lerpf(0.25, 1.0, form)
	_circle.alpha = smoothstep(0.0, 0.35, p)
	_light.light_energy = 0.4 + 2.6 * p * p


## Release: one bright pulse, then gone.
func finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_circle, "scale", Vector3.ONE * 1.5, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_circle, "alpha", 0.0, 0.16)
	tw.tween_property(_light, "light_energy", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
