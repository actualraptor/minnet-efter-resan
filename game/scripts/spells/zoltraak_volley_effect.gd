extends Node3D
## Tracking volley: a handful of smaller bolts that leave in a loose fan and curve
## toward the nearest valid target in front of her (group "zoltraak_target").
## With no target they simply fan out and bend gently toward the aim point.

const COUNT := 6


func start(ctx: SpellContext) -> void:
	var kind := ZoltraakVisuals.kind_of(ctx.spell)
	var from := ZoltraakShots.muzzle(ctx.caster)
	var dir := ZoltraakShots.aim(ctx.caster, ctx.aim)
	var target: Node3D = null
	var locked = ctx.caster.get("lock_target")
	if locked != null and is_instance_valid(locked):
		target = locked
	else:
		target = ZoltraakShots.find_target(get_tree(), from, dir)
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var to_target := dir
	if target != null:
		to_target = (target.global_position + Vector3(0, 0.9, 0) - from).normalized()
	side = to_target.cross(Vector3.UP).normalized()
	up = side.cross(to_target).normalized()
	# Missiles leave in a ring around the line to the target and swing in from
	# the sides, above and below, so they arrive from outside a barrier's front.
	for i in COUNT:
		var a := TAU * float(i) / COUNT + 0.4
		var out := (side * cos(a) + up * sin(a))
		var d := (to_target * 0.45 + out * 0.9).normalized()
		var b := ZoltraakShots.spawn_bolt(get_parent(), ctx.caster, from, d, 30.0, 0.65, kind)
		b.life = 3.2
		b.target = target
		b.turn_rate = 4.2
		b.arc_time = 0.42 + 0.08 * (i % 3)
		if target == null:
			b.turn_rate = 0.0
		await get_tree().create_timer(0.05).timeout
	get_tree().create_timer(0.3).timeout.connect(queue_free)
