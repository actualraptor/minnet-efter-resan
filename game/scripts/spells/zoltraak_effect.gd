extends Node3D
## Zoltraak release: a narrow piercing beam from the staff head along the shaft,
## stopped by the first solid thing it meets, with a tight impact burst. Quick and
## clean: it opens in ~40 ms, holds a beat, then thins out.

const CORE := Color(1.0, 0.96, 1.0)
const GLOW := Color(0.72, 0.5, 1.0)
const GROW := 0.04
const HOLD := 0.07
const FADE := 0.26

var _t := 0.0
var _pivot: Node3D
var _light: OmniLight3D
var _impact: GPUParticles3D
var _hit := false
var _hit_pos := Vector3.ZERO


func start(ctx: SpellContext) -> void:
	var from := ctx.muzzle
	var dir := ctx.aim.normalized()
	var reach := maxf(ctx.spell.max_range, 6.0)
	var to := from + dir * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [(ctx.caster as CollisionObject3D).get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var length := reach
	if not hit.is_empty():
		_hit = true
		_hit_pos = hit.position
		length = from.distance_to(_hit_pos)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-dir, up), from)   # local +Z along the beam
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.add_child(_beam(length, 0.05, CORE, 1.0))
	_pivot.add_child(_beam(length, 0.13, GLOW, 0.4))
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 3.5
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)
	if _hit:
		_build_impact(hit.normal)
	_pivot.scale = Vector3(0.0, 0.0, 1.0)


func _beam(length: float, radius: float, color: Color, alpha: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, alpha)
	cm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder runs along Y; lay it along the beam's +Z with its start at the muzzle.
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = Vector3(0, 0, length * 0.5)
	return mi


func _build_impact(normal: Vector3) -> void:
	_impact = GPUParticles3D.new()
	_impact.amount = 36
	_impact.lifetime = 0.45
	_impact.one_shot = true
	_impact.explosiveness = 1.0
	_impact.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -4.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color = Color(1.0, 0.85, 1.0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	_impact.process_material = pm
	_impact.draw_pass_1 = SpellCaster._mote_mesh(0.09)
	_impact.top_level = true
	add_child(_impact)
	_impact.global_position = _hit_pos + normal * 0.05
	_impact.emitting = true
	var flash := OmniLight3D.new()
	flash.top_level = true
	flash.light_color = GLOW
	flash.light_energy = 4.0
	flash.omni_range = 3.5
	flash.shadow_enabled = false
	add_child(flash)
	flash.global_position = _hit_pos + normal * 0.3
	create_tween().tween_property(flash, "light_energy", 0.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	var w := 0.0
	if _t < GROW:
		w = _t / GROW
	elif _t < GROW + HOLD:
		w = 1.0
	else:
		w = clampf(1.0 - (_t - GROW - HOLD) / FADE, 0.0, 1.0)
		w = w * w
	_pivot.scale = Vector3(w, w, 1.0)
	_light.light_energy = 3.5 * w
	if _t > GROW + HOLD + FADE + (0.5 if _hit else 0.0):
		queue_free()
