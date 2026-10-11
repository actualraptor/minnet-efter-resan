extends Node3D
## Zoltraak's casting formation (no focus-aim): a stack of seals emerges along
## the firing axis in front of the staff head, aligns, and builds brightness and
## detail over the cast time. It follows the staff every frame. finish() fires
## the release flash and folds the formation away.

var _body: Node3D
var _stack: SealStack
var _light: OmniLight3D
var _t := 0.0
var _dur := 0.5
var _done := false
var _kind := ZoltraakVisuals.Kind.WHITE


func begin(body: Node3D, spell: SpellDefinition, cast_time: float) -> void:
	_body = body
	_dur = maxf(cast_time, 0.05)
	_kind = ZoltraakVisuals.kind_of(spell)
	_stack = SealStack.new()
	add_child(_stack)
	_stack.build(3, 0.55, 0.85, _kind)
	_stack.assemble(0.06)
	_light = OmniLight3D.new()
	_light.light_color = ZoltraakVisuals.accent(_kind)
	_light.omni_range = 3.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_follow()


func _follow() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var dir := ZoltraakShots.aim(_body, Vector3.FORWARD)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-dir, up), ZoltraakShots.muzzle(_body))
	_light.global_position = global_position + dir * 0.8


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var p := clampf(_t / _dur, 0.0, 1.0)
	_follow()
	_stack.set_charge(p)
	_light.light_energy = 0.4 + 2.4 * p * p


func finish() -> void:
	if _done:
		return
	_done = true
	_stack.set_charge(1.0)
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 5.0, 0.04)
	tw.tween_callback(_stack.retract)
	tw.tween_property(_light, "light_energy", 0.0, 0.3)
	tw.tween_interval(0.35)
	tw.tween_callback(queue_free)
