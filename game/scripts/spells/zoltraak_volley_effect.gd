extends Node3D
## Tracking volley: a handful of smaller bolts that leave in a loose fan and curve
## toward the nearest valid target in front of her (group "zoltraak_target").
## With no target they simply fan out and bend gently toward the aim point.

const COUNT := 4


func start(ctx: SpellContext) -> void:
	var from := ZoltraakShots.muzzle(ctx.caster)
	var dir := ZoltraakShots.aim(ctx.caster, ctx.aim)
	var target := ZoltraakShots.find_target(get_tree(), from, dir)
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	for i in COUNT:
		var k := float(i) - (COUNT - 1) * 0.5
		var d := (dir + side * k * 0.2 + up * (0.12 if i % 2 == 0 else -0.04)).normalized()
		var b := ZoltraakShots.spawn_bolt(get_parent(), ctx.caster, from, d, 34.0, 0.6)
		b.life = 2.2
		b.turn_rate = 2.4
		b.target = target
		if target == null:
			# Curve back toward the point she was aiming at.
			b.turn_rate = 1.1
			var aim_point: Vector3 = ctx.target if ctx.target != Vector3.ZERO else from + dir * 25.0
			var marker := Node3D.new()
			get_parent().add_child(marker)
			marker.global_position = aim_point
			b.target = marker
			get_tree().create_timer(2.4).timeout.connect(marker.queue_free)
		await get_tree().create_timer(0.06).timeout
	get_tree().create_timer(0.3).timeout.connect(queue_free)
