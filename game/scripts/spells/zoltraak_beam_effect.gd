extends Node3D
## Sustained Zoltraak: a coherent continuous beam while the cast button is held,
## fired through a maintained formation. It follows the staff every frame, stops
## at the first solid thing or barrier (holding a persistent contact there),
## costs mana per second and ends on release or when mana runs out.

const MAX_TIME := 6.0
const MANA_PER_SECOND := 22.0

var _caster: Node3D
var _beam: ZoltraakBeam
var _t := 0.0


func start(ctx: SpellContext) -> void:
	_caster = ctx.caster
	var kind := ZoltraakVisuals.kind_of(ctx.spell)
	_beam = ZoltraakBeam.new()
	_beam.kind = kind
	_beam.mode = ZoltraakBeam.Mode.SUSTAINED
	# A charged cast (cast_power 1..3 from the focus charge) is wider, brighter
	# and fires through more seals.
	var power := ZoltraakShots.take_power(ctx.caster)
	# Uncharged: a clear 0.3 m shaft; fully charged (power 3): a WIDE 1.0 m beam.
	_beam.base_radius = 0.3 + 0.35 * (power - 1.0)
	_beam.power = power
	_beam.seals = 3
	_beam.seal_radius = 0.9 + 0.5 * (power - 1.0)
	_beam.reach = maxf(ctx.spell.max_range, 40.0)
	if _caster is CollisionObject3D:
		_beam.exclude.append((_caster as CollisionObject3D).get_rid())
	var caster := _caster
	_beam.aim_fn = func() -> Array:
		return [ZoltraakShots.muzzle(caster), ZoltraakShots.aim(caster, Vector3.FORWARD)]
	get_parent().add_child(_beam)
	_beam.setup()
	_beam.ended.connect(queue_free)


func release() -> void:
	if is_instance_valid(_beam):
		_beam.release()


func _process(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		release()
		return
	_t += delta
	var sc = _caster.get("caster")
	if sc != null and is_instance_valid(_beam):
		sc.mana = maxf(sc.mana - MANA_PER_SECOND * delta, 0.0)
		if sc.mana <= 0.5 or _t > MAX_TIME:
			release()
