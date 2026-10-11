extends MagicBarrier3D
## The player's defensive barrier spell: a MagicBarrier3D held in front of the
## caster, turned toward her guard direction (where the staff points) and kept
## centred on her while it is held. Mana is billed per absorbed power and when
## the shield is overwhelmed it fails locally, then recovers.

var _caster: Node3D
var _guard := Vector3.FORWARD
var _sc: SpellCaster


func start(ctx: SpellContext) -> void:
	_caster = ctx.caster
	team = 0
	build(1.85, 150.0)
	_sc = _caster.get("caster") as SpellCaster
	pay = func(mana: float) -> bool:
		if _sc == null:
			return true
		_sc.mana = maxf(_sc.mana - mana, 0.0)
		return _sc.mana > 0.0
	_guard = Vector3(ctx.direction.x, 0.0, ctx.direction.z).normalized()
	_place(0.0)


func _place(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		return
	var want := _guard
	if _caster.has_method("guard_direction"):
		want = _caster.call("guard_direction")
	want.y = clampf(want.y, -0.2, 0.45)
	want = want.normalized()
	_guard = _guard.slerp(want, 1.0 - exp(-8.0 * delta)) if delta > 0.0 else want
	var lift := 0.0
	if _caster.has_method("hover_height"):
		lift = _caster.call("hover_height")
	var base := _caster.global_position + Vector3(0, 1.15 + lift, 0) + _guard * 0.15
	var up := Vector3.UP if absf(_guard.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-_guard, up), base)


func _process(delta: float) -> void:
	_place(delta)
	super(delta)


## Dev/test: something struck the barrier at world `point`.
func hit(point: Vector3) -> void:
	absorb(point, 1.0, false)
