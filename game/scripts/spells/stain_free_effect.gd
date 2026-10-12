extends Node3D
## Fläckfri: lifts the moss/stain off the nearest dirty cleanable in front of her.
## A household spell: no staff. A pale band wipes across the surface twice, soap
## bubbles lift and pop, small glints settle, and a ting. Without a target it only
## says so.

const REACH := 6.0


func start(ctx: SpellContext) -> void:
	var best: Inspectable = null
	var best_d := REACH
	for n in get_tree().get_nodes_in_group("cleanable"):
		var c := n as Inspectable
		if c == null or not c.is_dirty():
			continue
		var d := c.global_position.distance_to(ctx.origin)
		# Prefer what she faces: a thing behind her counts as farther away.
		var to := (c.global_position - ctx.origin).normalized()
		d *= 1.0 + 0.6 * (1.0 - clampf(to.dot(ctx.direction), -1.0, 1.0)) * 0.5
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		GameState.toast.emit("Nothing here needs it. Mostly.")
		get_tree().create_timer(0.1).timeout.connect(queue_free)
		return
	if best.clean():
		_play(best, ctx.origin)
	get_tree().create_timer(best.clean_time + 2.6).timeout.connect(queue_free)


func _play(target: Inspectable, from: Vector3) -> void:
	var centre := target.global_position + Vector3(0, target.extent.y * 0.5, 0)
	var dur := target.clean_time
	# The wipe band hangs in front of the surface, facing her.
	var face := Vector3(from.x - centre.x, 0.0, from.z - centre.z)
	if face.length() < 0.1:
		face = Vector3(0, 0, 1)
	var band := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(maxf(target.extent.x, target.extent.z) * 1.15, target.extent.y * 1.1)
	band.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/wipe_band.gdshader")
	band.material_override = mat
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	band.global_position = centre + face.normalized() * (maxf(target.extent.x, target.extent.z) * 0.5 + 0.05)
	band.look_at(centre, Vector3.UP)
	band.rotate_object_local(Vector3.UP, PI)   # a quad faces +Z; look_at points -Z at the target
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("t", v), 0.0, 1.0, dur)
	tw.tween_callback(band.queue_free)
	_bubbles(target, centre, dur)
	_glints(target, centre, dur)
	Audio.sfx("memory_chime", -9.0, 0.0, centre)
	get_tree().create_timer(dur * 0.55).timeout.connect(func(): Audio.sfx("memory_chime", -15.0, 0.12, centre))


func _bubbles(target: Inspectable, centre: Vector3, dur: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 34
	p.lifetime = 2.4
	p.emitting = true
	p.one_shot = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = target.extent * 0.5
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.12, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 2.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.2))
	c.add_point(Vector2(0.12, 1))
	c.add_point(Vector2(0.85, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	p.process_material = pm
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 14
	sphere.rings = 8
	var bm := StandardMaterial3D.new()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.85, 0.96, 1.0, 0.22)
	bm.roughness = 0.05
	bm.metallic_specular = 1.0
	bm.rim_enabled = true
	bm.rim = 1.0
	bm.rim_tint = 0.2
	bm.emission_enabled = true
	bm.emission = Color(0.55, 0.8, 1.0)
	bm.emission_energy_multiplier = 0.35
	sphere.material = bm
	p.draw_pass_1 = sphere
	add_child(p)
	p.global_position = centre
	get_tree().create_timer(dur * 0.9).timeout.connect(func(): p.emitting = false)


func _glints(target: Inspectable, centre: Vector3, dur: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.1
	p.emitting = true
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = target.extent * 0.5
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3.ZERO
	pm.color = Color(0.9, 0.98, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	p.process_material = pm
	p.draw_pass_1 = SpellCaster._mote_mesh(0.09)
	add_child(p)
	p.global_position = centre
	get_tree().create_timer(dur).timeout.connect(func(): p.emitting = false)
