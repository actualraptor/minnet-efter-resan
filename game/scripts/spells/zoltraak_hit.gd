class_name ZoltraakHit
extends RefCounted
## One query for everything a Zoltraak attack can run into: the world (physics
## layers 1|4|16) and any MagicBarrier3D of another team, whose coverage is the
## same analytic dome that is drawn, so visual and collision always agree.

const WORLD_MASK := 1 | 4 | 16


## Result: {length, point, normal, collider, barrier (MagicBarrier3D or null),
## hit (bool)}.
static func trace(tree: SceneTree, world: World3D, from: Vector3, dir: Vector3, reach: float, exclude: Array[RID], team := 0) -> Dictionary:
	var out := {"length": reach, "point": from + dir * reach, "normal": -dir, "collider": null, "barrier": null, "hit": false}
	# Hostile attacks also strike the player's body (physics layer 2).
	var mask := WORLD_MASK | (2 if team != 0 else 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, mask, exclude)
	var hit := world.direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		out.length = from.distance_to(hit.position)
		out.point = hit.position
		out.normal = hit.normal
		out.collider = hit.get("collider")
		out.hit = true
	for n in tree.get_nodes_in_group("magic_barrier"):
		var b := n as MagicBarrier3D
		if b == null or b.team == team or not b.active:
			continue
		var t := b.intersect(from, dir, float(out.length))
		if t >= 0.0 and t < float(out.length):
			out.length = t
			out.point = from + dir * t
			out.normal = b.surface_normal(out.point)
			out.collider = null
			out.barrier = b
			out.hit = true
	return out
