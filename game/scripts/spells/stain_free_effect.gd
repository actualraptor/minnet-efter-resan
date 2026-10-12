extends Node3D
## Fläckfri: lifts the moss/stain off the nearest dirty cleanable in front of her.
## A household spell: no staff, no flourish, one "ting".

const REACH := 6.0


func start(ctx: SpellContext) -> void:
	var best: Inspectable = null
	var best_d := REACH
	for n in get_tree().get_nodes_in_group("cleanable"):
		var c := n as Inspectable
		if c == null or not c.is_dirty():
			continue
		var d := c.global_position.distance_to(ctx.origin)
		# Prefer what she faces: a thing behind her counts as farther away.
		var to := (c.global_position - ctx.origin).normalized()
		d *= 1.0 + 0.6 * (1.0 - clampf(to.dot(ctx.direction), -1.0, 1.0)) * 0.5
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		GameState.toast.emit("Nothing here needs it. Mostly.")
	elif best.clean():
		Audio.sfx("memory_chime", -10.0, 0.0, best.global_position)
	get_tree().create_timer(0.1).timeout.connect(queue_free)
