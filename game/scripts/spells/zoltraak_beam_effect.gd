extends Node3D
## Sustained Zoltraak: a continuous beam channelled while the cast button is
## held, with a large six-petal circle at the staff head. It follows the staff
## every frame, stops at the first solid thing and costs mana per second.
## Powerful but controlled: it ends when the button is released or mana is out.

const MAX_TIME := 4.0
const MANA_PER_SECOND := 24.0
const REACH := 70.0

var _caster: Node3D
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _circle: SixPetalCircle
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _t := 0.0
var _fade := 0.0
var _released := false
var _tick := 0.0


func start(ctx: SpellContext) -> void:
	_caster = ctx.caster
	_core = _cyl(0.05, Color(1.0, 1.0, 1.0), 1.0)
	_glow = _cyl(0.16, Color(0.5, 0.74, 1.0), 0.38)
	add_child(_core)
	add_child(_glow)
	_circle = SixPetalCircle.new(0.85)
	add_child(_circle)
	_circle.set_charge(1.0)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.8, 1.0)
	_light.light_energy = 2.4
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	add_child(_light)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.35
	_sparks.local_coords = false
	_sparks.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 55.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -2.5, 0)
	pm.color = Color(0.85, 0.93, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_sparks.process_material = pm
	_sparks.draw_pass_1 = SpellCaster._mote_mesh(0.08)
	_sparks.top_level = true
	add_child(_sparks)
	_process(0.0)


func _cyl(r: float, col: Color, a: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, a)
	cm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(90, 0, 0)
	return mi


func release() -> void:
	_released = true


func _process(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return
	_t += delta
	if _released or _t > MAX_TIME:
		_fade += delta * 7.0
		if _fade >= 1.0:
			queue_free()
			return
	else:
		var pl: SpellCaster = _caster.get("caster") as SpellCaster
		if pl:
			pl.mana = maxf(pl.mana - MANA_PER_SECOND * delta, 0.0)
			if pl.mana <= 0.5:
				_released = true
	var from := ZoltraakShots.muzzle(_caster)
	var dir := ZoltraakShots.aim(_caster, -global_basis.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, 1 | 4 | 16, [(_caster as CollisionObject3D).get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var length := REACH
	var end := from + dir * REACH
	if not hit.is_empty():
		end = hit.position
		length = from.distance_to(end)
		_sparks.global_position = end + hit.normal * 0.05
		_sparks.emitting = true
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.2
			var col = hit.get("collider")
			if col and col is Node and (col as Node).has_method("zoltraak_hit"):
				(col as Node).call("zoltraak_hit", 4.0, dir)
	else:
		_sparks.emitting = false
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-dir, up), from)
	var open := smoothstep(0.0, 0.12, _t) * (1.0 - _fade)
	var pulse := 1.0 + 0.1 * sin(_t * 46.0)
	for pair in [[_core, 1.0], [_glow, 1.0]]:
		var mi: MeshInstance3D = pair[0]
		(mi.mesh as CylinderMesh).height = length
		mi.position = Vector3(0, 0, length * 0.5)
		mi.scale = Vector3(open * pulse, 1.0, open * pulse)
	_circle.position = Vector3(0, 0, 0.5)
	_circle.set_alpha(open)
	_light.light_energy = 2.4 * open
	_light.global_position = from + dir * 1.0
