class_name ZoltraakImpact
extends Node3D
## Where a bolt lands on something solid: a petalled circle pressed flat on the
## surface that blooms outward and fades, a burst of grains, a brief light and a
## few lingering motes. White for the modern spell, black-violet for the
## original.


func play(normal: Vector3, scale_factor := 1.0, kind := ZoltraakVisuals.Kind.WHITE) -> void:
	var white := kind == ZoltraakVisuals.Kind.WHITE
	var circle := SixPetalCircle.new(0.6 * scale_factor, ZoltraakVisuals.seal_tint(kind))
	add_child(circle)
	circle.set_charge(0.75)
	circle.set_energy(3.0 if white else 2.2)
	circle.face(normal)
	var light := OmniLight3D.new()
	light.light_color = ZoltraakVisuals.accent(kind)
	light.light_energy = 3.0 * scale_factor
	light.omni_range = 4.5
	light.shadow_enabled = false
	light.position = normal * 0.3
	add_child(light)
	var sparks := GPUParticles3D.new()
	sparks.amount = 30
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 62.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.5 * scale_factor
	pm.gravity = Vector3(0, -2.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.5
	pm.color = Color(1, 1, 1) if white else Color(0.5, 0.28, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	sparks.process_material = pm
	sparks.draw_pass_1 = SpellCaster._mote_mesh(0.08)
	add_child(sparks)
	sparks.emitting = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(a: float): circle.set_alpha(a), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(circle, "scale", Vector3.ONE * 1.6, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_interval(0.25)
	tw.chain().tween_callback(queue_free)
