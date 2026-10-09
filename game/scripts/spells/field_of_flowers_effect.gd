extends Node3D
## Field of Flowers world effect. Sequence after the caster's gather phase:
## flash at the feet -> luminous wave travels outward over the terrain (drawn
## by the terrain/grass shaders via global uniforms, so it hugs the ground) ->
## flowers sprout as the wave passes and bloom progressively -> motes drift up
## and fade -> real flowers remain in the FlowerField.

@export var wave_speed := 4.8
@export var color := Color(0.82, 1.0, 0.5)

var _ctx: SpellContext
var _radius := 10.0
var _wave_r := 0.0
var _strength := 0.0
var _plan: Array[Dictionary] = []
var _next_flower := 0
var _planned := false
var _finished := false
var _ring: GPUParticles3D
var _field_motes: GPUParticles3D
var _flash: OmniLight3D


func start(ctx: SpellContext) -> void:
	_ctx = ctx
	_radius = ctx.spell.radius
	global_position = ctx.origin
	_build_vfx()
	var tw := create_tween()
	tw.tween_property(self, "_strength", 1.0, 0.35)
	_flash.light_energy = 6.0
	create_tween().tween_property(_flash, "light_energy", 0.0, 1.6).set_ease(Tween.EASE_OUT)
	Audio.sfx("spell_wave", -3.0, 0.0, ctx.origin)


func _physics_process(_delta: float) -> void:
	if _ctx == null or _planned:
		return
	_planned = true
	var field := FlowerField.instance
	if field == null:
		return
	_plan = FlowerField.plan_patch(get_world_3d().direct_space_state, _ctx.origin, _radius, _ctx.cast_seed, field.variant_count())


func _process(delta: float) -> void:
	if _ctx == null:
		return
	if _wave_r < _radius + 1.5:
		_wave_r += wave_speed * delta * lerpf(1.3, 0.75, _wave_r / _radius)
	elif not _finished:
		_finish()
	_reveal_flowers()
	RenderingServer.global_shader_parameter_set("spell_wave", Vector4(_ctx.origin.x, _ctx.origin.y, _ctx.origin.z, _wave_r))
	RenderingServer.global_shader_parameter_set("spell_wave_strength", _strength)
	var pm := _ring.process_material as ParticleProcessMaterial
	pm.emission_ring_radius = maxf(_wave_r, 0.3)
	pm.emission_ring_inner_radius = maxf(_wave_r - 0.7, 0.0)
	var fm := _field_motes.process_material as ParticleProcessMaterial
	fm.emission_ring_radius = maxf(_wave_r, 0.5)


func _reveal_flowers() -> void:
	var field := FlowerField.instance
	if field == null:
		return
	var now := GameState.game_time()
	while _next_flower < _plan.size() and float(_plan[_next_flower]["dist"]) <= _wave_r - 0.3:
		var f := _plan[_next_flower]
		field.add_flower(f, now + randf() * 0.25)
		_next_flower += 1


func _finish() -> void:
	_finished = true
	# Make sure every planned flower exists even on a hitching frame.
	_wave_r = _radius + 2.0
	_reveal_flowers()
	if FlowerField.instance:
		FlowerField.instance.record_patch(_ctx.origin, _radius, _ctx.cast_seed)
	_ring.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "_strength", 0.0, 1.4)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): _field_motes.emitting = false)
	tw.tween_interval(3.0)
	tw.tween_callback(_cleanup)


func _cleanup() -> void:
	RenderingServer.global_shader_parameter_set("spell_wave_strength", 0.0)
	queue_free()


func _build_vfx() -> void:
	_flash = OmniLight3D.new()
	_flash.light_color = color
	_flash.omni_range = 7.0
	_flash.position = Vector3(0, 0.6, 0)
	add_child(_flash)

	_ring = _make_particles(260, 1.6, 0.06)
	var pm := _ring.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.05
	pm.emission_ring_radius = 0.3
	pm.emission_ring_inner_radius = 0.0
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.25, 0)
	_ring.position = Vector3(0, 0.15, 0)
	_ring.emitting = true

	_field_motes = _make_particles(120, 3.0, 0.045)
	var fm := _field_motes.process_material as ParticleProcessMaterial
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fm.emission_ring_axis = Vector3.UP
	fm.emission_ring_height = 0.3
	fm.emission_ring_radius = 0.5
	fm.emission_ring_inner_radius = 0.0
	fm.direction = Vector3.UP
	fm.spread = 40.0
	fm.initial_velocity_min = 0.1
	fm.initial_velocity_max = 0.5
	fm.gravity = Vector3(0, 0.12, 0)
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 0.6
	fm.turbulence_noise_scale = 3.0
	_field_motes.position = Vector3(0, 0.3, 0)
	_field_motes.emitting = true


func _make_particles(amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 10, 32))
	var pm := ParticleProcessMaterial.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.15, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6))
	grad.set_color(1, Color(0.7, 1.0, 0.55))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = SpellCaster._mote_mesh(size)
	add_child(p)
	return p
