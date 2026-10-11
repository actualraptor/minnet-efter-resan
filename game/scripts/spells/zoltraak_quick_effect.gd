extends Node3D
## Quick shot: one fast, precise bolt from the staff head along the aim, with a
## very brief two-seal formation so it still reads as Zoltraak.


func start(ctx: SpellContext) -> void:
	var kind := ZoltraakVisuals.kind_of(ctx.spell)
	var dir := ZoltraakShots.aim(ctx.caster, ctx.aim)
	var from := ZoltraakShots.muzzle(ctx.caster)
	ZoltraakShots.spawn_bolt(get_parent(), ctx.caster, from, dir, 90.0, 1.0, kind)
	ZoltraakShots.flash_seals(get_parent(), ctx.caster, kind, 2)
	get_tree().create_timer(0.1).timeout.connect(queue_free)
