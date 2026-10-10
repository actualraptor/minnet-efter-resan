class_name ZoltraakImpact
extends Node3D
## The small petalled flash where a bolt lands: a six-petal circle pressed flat
## on the surface, a few sparks and a brief light.


func play(normal: Vector3, scale_factor := 1.0) -> void:
	var circle := SixPetalCircle.new(0.55 * scale_factor)
	add_child(circle)
	circle.set_charge(0.6)
	circle.face(normal)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.78, 1.0)
	light.light_energy = 2.4 * scale_factor
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.position = normal * 0.3
	add_child(light)
	var sparks := GPUParticles3D.new()
	sparks.amount = 22
	sparks.lifetime = 0.4
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 60.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0 * scale_factor
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.5
	pm.color = Color(0.85, 0.93, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	sparks.process_material = pm
	sparks.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	add_child(sparks)
	sparks.emitting = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(a: float): circle.set_alpha(a), 1.0, 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(circle, "scale", Vector3.ONE * 1.5, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.chain().tween_interval(0.2)
	tw.chain().tween_callback(queue_free)
