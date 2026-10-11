class_name ZoltraakBeam
extends Node3D
## A Zoltraak beam: the luminous body, the seal formation it fires through, the
## contact point (sparks and a pressed petal circle, or a barrier's persistent
## shield contact) and per-frame collision. One class serves the quick pulse,
## the charged shot and the sustained channel, for the player and for hostile
## emitters (team), in both visual families.
##
## aim_fn: func() -> Array[Vector3] returning [origin, direction] each frame, so
## the beam follows the staff while the caster aims and moves.

signal ended

enum Mode { PULSE, SUSTAINED }

var kind := ZoltraakVisuals.Kind.WHITE
var mode := Mode.PULSE
var team := 0
var base_radius := 0.3            # beam body radius in metres
var power := 1.0                  # damage / barrier stress per second multiplier
var reach := 70.0
var hold := 0.2                   # pulse: seconds at full width
var seals := 3
var seal_radius := 0.8
var exclude: Array[RID] = []
var aim_fn: Callable
var last_trace: Dictionary = {}

var _t := 0.0
var _width := 0.0
var _released := false
var _fade := 1.0
var _body: MeshInstance3D
var _stack: SealStack
var _contact: GPUParticles3D
var _flat: SixPetalCircle
var _head: MeshInstance3D
var _light: OmniLight3D
var _tick := 0.0
var _length := 1.0
var _origin := Vector3.ZERO
var _dir := Vector3.FORWARD


func setup() -> void:
	_body = ZoltraakVisuals.make_beam(1.0, base_radius, kind)
	add_child(_body)
	if seals > 0:
		_stack = SealStack.new()
		add_child(_stack)
		_stack.build(seals, seal_radius * 0.5, 0.8 + seal_radius * 0.5, kind)
		_stack.assemble(0.05)
	_light = OmniLight3D.new()
	_light.light_color = ZoltraakVisuals.accent(kind)
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	add_child(_light)
	_contact = _make_sparks()
	add_child(_contact)
	_contact.top_level = true
	_flat = SixPetalCircle.new(0.5 + base_radius * 1.4, ZoltraakVisuals.seal_tint(kind))
	add_child(_flat)
	_flat.top_level = true
	_flat.set_charge(0.7)
	_flat.set_alpha(0.0)
	# A bright glow at the point of contact (billboard), so the line has a clear
	# end that reads from any camera angle, including looking straight down it.
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = MoteTexture.get_texture()
	hm.vertex_color_use_as_albedo = true
	hm.albedo_color = Color(1.4, 1.4, 1.6) if kind == ZoltraakVisuals.Kind.WHITE else Color(0.7, 0.35, 1.6)
	hm.no_depth_test = true
	q.material = hm
	_head = MeshInstance3D.new()
	_head.mesh = q
	_head.top_level = true
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_head)
	_update(0.0)


func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.45
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 70.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.color = Color(1, 1, 1) if kind == ZoltraakVisuals.Kind.WHITE else Color(0.5, 0.3, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	p.process_material = pm
	p.draw_pass_1 = SpellCaster._mote_mesh(0.08)
	return p


## Sustained beams run until released; pulses end on their own.
func release() -> void:
	_released = true


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


func _update(delta: float) -> void:
	# Envelope: opens in 50 ms; a pulse holds, then thins out over 0.35 s.
	var open := clampf(_t / 0.05, 0.0, 1.0)
	if mode == Mode.PULSE and _t > 0.05 + hold:
		_released = true
	if _released:
		_fade = maxf(_fade - delta / 0.35, 0.0)
		if _fade <= 0.0 and delta > 0.0:
			if _stack:
				_stack.retract()
			ended.emit()
			queue_free()
			return
	_width = open * (_fade * _fade)
	if aim_fn.is_valid():
		var r: Array = aim_fn.call()
		_origin = r[0]
		_dir = (r[1] as Vector3).normalized()
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-_dir, up), _origin)

	var live := _width > 0.15
	var tr := ZoltraakHit.trace(get_tree(), get_world_3d(), _origin, _dir, reach, exclude, team)
	last_trace = tr
	_length = float(tr.length)
	var rad := base_radius * lerpf(0.25, 1.0, _width) * (1.0 + 0.04 * sin(_t * 40.0))
	# Never thinner than a few pixels' worth: size the beam by its distance from
	# the camera so a small beam stays clearly readable at range.
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var mid := _origin + _dir * minf(_length * 0.5, 14.0)
		rad = maxf(rad, cam.global_position.distance_to(mid) * 0.014 * _width)
	ZoltraakVisuals.set_beam_length(_body, _length, rad)
	_body.visible = _width > 0.02

	var barrier := tr.barrier as MagicBarrier3D
	_tick -= delta
	if live and delta > 0.0:
		if barrier != null:
			barrier.absorb(tr.point, power * 2.0 * delta, true, get_instance_id())
		elif _tick <= 0.0:
			_tick = 0.1
			var col = tr.collider
			if col != null and col is Node and (col as Node).has_method("zoltraak_hit"):
				(col as Node).call("zoltraak_hit", 6.0 * power, _dir)
	if _stack:
		_stack.set_alpha_scale(_width)
		if _released and not _stack.is_gone():
			_stack.retract()
	# Contact point: sparks and a pressed circle on solid surfaces; barriers draw
	# their own persistent contact.
	var on_solid: bool = bool(tr.hit) and barrier == null
	_contact.emitting = live and bool(tr.hit)
	if tr.hit:
		_contact.global_position = tr.point + tr.normal * 0.05
		(_contact.process_material as ParticleProcessMaterial).direction = (tr.normal as Vector3) if barrier == null else -_dir.cross(Vector3.UP).normalized()
	if on_solid and live:
		_flat.global_position = tr.point + (tr.normal as Vector3) * 0.04
		_flat.face(tr.normal)
		_flat.set_alpha(_width * 0.9)
	else:
		_flat.set_alpha(0.0)
	_head.global_position = _origin + _dir * _length
	_head.scale = Vector3.ONE * (0.9 + base_radius * 5.0) * _width
	_head.visible = _width > 0.05
	_light.global_position = _origin + _dir * minf(_length, 3.0)
	_light.light_energy = 3.0 * _width * base_radius * 4.0
