class_name FlightFx
extends Node3D
## Diegetic flight feedback, per the flight system concept sheet: a soft rune
## circle forms and ripples on the ground as she lifts off, a faint mana ring sits
## under her feet while she is aloft, a thin wake of light drifts behind her
## movement (denser when she boosts), and the ring softens away as she lands.
## No HUD elements.

const COLOR := Color(0.82, 1.0, 0.58)

var player: Player
var _ring: MagicCircle                # under her feet while flying
var _takeoff: MagicCircle             # on the ground at lift-off
var _wake: GPUParticles3D
var _exhaust: GPUParticles3D
var _burst: GPUParticles3D
var _ring_a := 0.0
var _takeoff_t := -1.0
var _land_t := -1.0
var _t := 0.0


func setup(p: Player) -> void:
	player = p
	top_level = true
	_ring = MagicCircle.new()
	add_child(_ring)
	_ring.build(0.55, COLOR, MagicCircle.Style.PETAL)
	_ring.alpha = 0.0
	_ring.rotation_degrees = Vector3(-90, 0, 0)
	_takeoff = MagicCircle.new()
	add_child(_takeoff)
	_takeoff.build(1.4, COLOR, MagicCircle.Style.PETAL)
	_takeoff.alpha = 0.0
	_takeoff.rotation_degrees = Vector3(-90, 0, 0)
	_wake = GPUParticles3D.new()
	_wake.amount = 70
	_wake.lifetime = 1.3
	_wake.local_coords = false
	_wake.emitting = false
	_wake.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.gravity = Vector3(0, 0.12, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.25
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.2))
	c.add_point(Vector2(0.25, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 1.0, 0.7))
	grad.set_color(1, Color(0.7, 1.0, 0.85))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	_wake.process_material = pm
	_wake.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	add_child(_wake)
	# Magic from the tail of the staff: a steady stream while she is driving
	# herself along, and a burst with every push-off stroke.
	_exhaust = _tail_particles(40, 0.6, false)
	add_child(_exhaust)
	_burst = _tail_particles(26, 0.45, true)
	add_child(_burst)
	p.flight_changed.connect(_on_flight_changed)
	p.thrust_pulse.connect(_on_thrust)


func _tail_particles(amount: int, life: float, one_shot: bool) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = amount
	g.lifetime = life
	g.one_shot = one_shot
	g.explosiveness = 0.9 if one_shot else 0.0
	g.local_coords = false
	g.emitting = false
	g.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 16.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 1.0
	pm.damping_max = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.2, 1.0))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.85))
	grad.set_color(1, Color(0.7, 1.0, 0.6))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	g.process_material = pm
	g.draw_pass_1 = SpellCaster._mote_mesh(0.09)
	return g


func _staff_tail() -> Array:
	var rig := player.staff_rig
	if rig == null:
		return [player.global_position + Vector3(0, 1.0, 0), Vector3.DOWN]
	var xf: Transform3D = rig.staff_global
	var up: Vector3 = xf.basis.y.normalized()
	return [xf.origin - up * 0.86, -up]


func _on_thrust(strength: float) -> void:
	var t := _staff_tail()
	_burst.global_position = t[0]
	(_burst.process_material as ParticleProcessMaterial).direction = t[1]
	(_burst.process_material as ParticleProcessMaterial).initial_velocity_max = 3.0 + 4.0 * strength
	_burst.restart()
	_burst.emitting = true


func _on_flight_changed(on: bool) -> void:
	if on:
		_takeoff_t = 0.0
		_land_t = -1.0
		_takeoff.global_position = player.ground_point() + Vector3(0, 0.06, 0)
	else:
		_land_t = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	# Ring under her feet.
	var want := 0.5 if player.flying else 0.0
	_ring_a = move_toward(_ring_a, want, delta * 1.2)
	_ring.alpha = _ring_a
	_ring.global_position = player.global_position + Vector3(0, 0.02, 0)
	_ring.scale = Vector3.ONE * (1.0 + 0.05 * sin(_t * 2.2))
	# Takeoff circle on the ground: forms, ripples outward, fades.
	if _takeoff_t >= 0.0:
		_takeoff_t += delta
		var k := _takeoff_t / 1.4
		if k >= 1.0:
			_takeoff_t = -1.0
			_takeoff.alpha = 0.0
		else:
			_takeoff.alpha = sin(k * PI) * 0.8
			_takeoff.scale = Vector3.ONE * lerpf(0.5, 1.5, 1.0 - pow(1.0 - k, 2.0))
			_takeoff.global_position.y = player.ground_point().y + 0.06
	# Wake: a faint drift of light behind her motion.
	_wake.emitting = player.flying and (speed > 1.2 or absf(player.velocity.y) > 1.0)
	# Staff-tail stream while pushing along under the flight clip.
	var driving := player.flying and speed > 1.5 and player.staff_rig != null and player.staff_rig.playing and player.staff_rig.clip != null and player.staff_rig.clip.param_driven
	_exhaust.emitting = driving
	if driving:
		var tt := _staff_tail()
		_exhaust.global_position = tt[0]
		(_exhaust.process_material as ParticleProcessMaterial).direction = tt[1]
	_wake.amount_ratio = clampf(0.25 + speed / 8.0, 0.25, 1.0)
	_wake.global_position = player.global_position + Vector3(0, 0.9, 0)
