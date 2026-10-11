extends Node3D
## Rapid burst: several smaller bolts in quick succession, each re-aimed from the
## staff head as she tracks, with a faint spread so they read as a stream.

const SHOTS := 5
const GAP := 0.075

var _ctx: SpellContext
var _rng := RandomNumberGenerator.new()


func start(ctx: SpellContext) -> void:
	_ctx = ctx
	_rng.seed = ctx.cast_seed
	_fire_series()


func _fire_series() -> void:
	for i in SHOTS:
		if not is_instance_valid(_ctx.caster):
			break
		var dir := ZoltraakShots.aim(_ctx.caster, _ctx.aim)
		var side := dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		var spread := deg_to_rad(2.4)
		dir = (dir + side * _rng.randfn(0.0, spread) + up * _rng.randfn(0.0, spread)).normalized()
		ZoltraakShots.spawn_bolt(get_parent(), _ctx.caster, ZoltraakShots.muzzle(_ctx.caster), dir, 70.0, 0.55, ZoltraakVisuals.kind_of(_ctx.spell))
		if _ctx.caster.has_method("recoil"):
			_ctx.caster.call("recoil", 0.35)
		await get_tree().create_timer(GAP).timeout
	queue_free()
