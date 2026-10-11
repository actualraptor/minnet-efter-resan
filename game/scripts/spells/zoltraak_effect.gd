extends Node3D
## Charged Zoltraak: a short, dense beam fired through a stack of seals. Width,
## brightness, seal count and impact all scale with the charge the caster built
## (cast_power 1..3 from the focus-aim charge, or the spell radius).


func start(ctx: SpellContext) -> void:
	var kind := ZoltraakVisuals.kind_of(ctx.spell)
	var power := maxf(ZoltraakShots.take_power(ctx.caster), ctx.spell.radius)
	var caster := ctx.caster
	var beam := ZoltraakBeam.new()
	beam.kind = kind
	beam.mode = ZoltraakBeam.Mode.PULSE
	beam.base_radius = 0.26 * power
	beam.power = power
	beam.hold = 0.18 + 0.1 * power
	beam.seals = 3 + int(round(power - 1.0))
	beam.seal_radius = 0.7 + 0.25 * power
	beam.reach = maxf(ctx.spell.max_range, 30.0)
	if caster is CollisionObject3D:
		beam.exclude.append((caster as CollisionObject3D).get_rid())
	beam.aim_fn = func() -> Array:
		return [ZoltraakShots.muzzle(caster), ZoltraakShots.aim(caster, ctx.aim)]
	get_parent().add_child(beam)
	beam.setup()
	beam.ended.connect(queue_free)
