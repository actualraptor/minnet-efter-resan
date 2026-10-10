extends Node3D
## Quick shot: one fast, precise bolt from the staff head along the aim.


func start(ctx: SpellContext) -> void:
	var dir := ZoltraakShots.aim(ctx.caster, ctx.aim)
	ZoltraakShots.spawn_bolt(get_parent(), ctx.caster, ZoltraakShots.muzzle(ctx.caster), dir, 85.0, 1.0)
	_flash(ZoltraakShots.muzzle(ctx.caster))
	get_tree().create_timer(0.1).timeout.connect(queue_free)


func _flash(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.85, 1.0)
	l.light_energy = 3.0
	l.omni_range = 4.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = at
	create_tween().tween_property(l, "light_energy", 0.0, 0.1)
