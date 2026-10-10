extends Node3D
## Heavy Zoltraak: a short, dense, wide white-blue beam from the staff head along
## the aim, stopped by the first solid thing, with a big impact petal circle.
## The spell's `radius` scales the beam (1 = standard, ~3 = charged heavy shot).

const CORE := Color(1.0, 1.0, 1.0)
const GLOW := Color(0.5, 0.74, 1.0)
const GROW := 0.05
const HOLD := 0.16
const FADE := 0.38

var _t := 0.0
var _scale := 1.0
var _pivot: Node3D
var _light: OmniLight3D
var _circle: SixPetalCircle
var _hit := false


func start(ctx: SpellContext) -> void:
	_scale = maxf(ctx.spell.radius, 0.5)
	var from := ZoltraakShots.muzzle(ctx.caster)
	var dir := ZoltraakShots.aim(ctx.caster, ctx.aim)
	var reach := maxf(ctx.spell.max_range, 6.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | 4 | 16, [(ctx.caster as CollisionObject3D).get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var length := reach
	if not hit.is_empty():
		_hit = true
		length = from.distance_to(hit.position)
		var col = hit.get("collider")
		if col and col is Node and (col as Node).has_method("zoltraak_hit"):
			(col as Node).call("zoltraak_hit", 40.0 * _scale, dir)
		var fx := ZoltraakImpact.new()
		get_parent().add_child(fx)
		fx.global_position = hit.position + hit.normal * 0.05
		fx.play(hit.normal, _scale * 1.2)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-dir, up), from)
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.add_child(_beam(length, 0.06 * _scale, CORE, 1.0))
	_pivot.add_child(_beam(length, 0.17 * _scale, GLOW, 0.4))
	_circle = SixPetalCircle.new(0.7 + 0.3 * _scale)
	add_child(_circle)
	_circle.position = Vector3(0, 0, 0.5)
	_circle.set_charge(1.0)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 3.5 * _scale
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)
	_pivot.scale = Vector3(0.0, 0.0, 1.0)


func _beam(length: float, radius: float, color: Color, a: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 12
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * 1.9, color.g * 1.9, color.b * 1.9, a)
	cm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = Vector3(0, 0, length * 0.5)
	return mi


func _process(delta: float) -> void:
	_t += delta
	var w := 0.0
	if _t < GROW:
		w = _t / GROW
	elif _t < GROW + HOLD * _scale * 0.6:
		w = 1.0
	else:
		w = clampf(1.0 - (_t - GROW - HOLD * _scale * 0.6) / FADE, 0.0, 1.0)
		w = w * w
	_pivot.scale = Vector3(w, w, 1.0)
	_circle.set_alpha(w)
	_circle.scale = Vector3.ONE * (1.0 + (1.0 - w) * 0.35)
	_light.light_energy = 3.5 * _scale * w
	if _t > GROW + HOLD * _scale * 0.6 + FADE + 0.4:
		queue_free()
