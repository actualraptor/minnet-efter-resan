class_name ZoltraakShots
extends RefCounted
## Shared helpers for the Zoltraak firing modes: where the muzzle and aim are
## right now, and spawning bolts into the world.


static func muzzle(caster: Node) -> Vector3:
	return caster.call("staff_tip") if caster.has_method("staff_tip") else (caster as Node3D).global_position + Vector3(0, 1.4, 0)


static func aim(caster: Node, fallback: Vector3) -> Vector3:
	if caster.has_method("staff_direction"):
		var d: Vector3 = caster.call("staff_direction")
		if d.length() > 0.1:
			return d.normalized()
	return fallback


static func spawn_bolt(world_parent: Node, caster: Node, from: Vector3, dir: Vector3, speed: float, size := 1.0) -> ZoltraakBolt:
	var b := ZoltraakBolt.new()
	world_parent.add_child(b)
	if caster is CollisionObject3D:
		b.exclude.append((caster as CollisionObject3D).get_rid())
	b.setup(from, dir, speed, size)
	return b


## Nearest registered target in front of `dir`, within range and `max_angle`.
static func find_target(tree: SceneTree, from: Vector3, dir: Vector3, max_range := 45.0, max_angle := deg_to_rad(42.0)) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for n in tree.get_nodes_in_group("zoltraak_target"):
		var t := n as Node3D
		if t == null:
			continue
		var to := t.global_position + Vector3(0, 0.9, 0) - from
		var d := to.length()
		if d > max_range or d < 1.0:
			continue
		var ang := dir.angle_to(to)
		if ang > max_angle:
			continue
		var score := ang * 8.0 + d * 0.05
		if score < best_score:
			best_score = score
			best = t
	return best
