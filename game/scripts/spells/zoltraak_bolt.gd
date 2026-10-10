class_name ZoltraakBolt
extends Node3D
## One Zoltraak bolt: a fast white-blue streak with a soft glow and a short
## trail. It travels in sub-frame raycasts so it never tunnels, optionally curves
## toward a target (the tracking volley turns at a limited rate: a gentle curve,
## never an instant lock-on), and ends in a small petalled impact.

const CORE := Color(0.92, 0.97, 1.0)
const GLOW := Color(0.45, 0.7, 1.0)

var direction := Vector3.FORWARD
var speed := 70.0
var life := 1.4
var size := 1.0
var target: Node3D
var turn_rate := 0.0
var exclude: Array[RID] = []
var _light: OmniLight3D
var _trail: GPUParticles3D
var _done := false


func setup(from: Vector3, dir: Vector3, spd: float, scale_factor := 1.0) -> void:
	global_position = from
	direction = dir.normalized()
	speed = spd
	size = scale_factor
	_build()
	_orient()


func _build() -> void:
	var cm := CapsuleMesh.new()
	cm.radius = 0.055 * size
	cm.height = 1.0 * size + 0.25
	cm.radial_segments = 8
	cm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(CORE.r * 2.0, CORE.g * 2.0, CORE.b * 2.0, 1.0)
	cm.material = m
	var core := MeshInstance3D.new()
	core.mesh = cm
	core.rotation_degrees = Vector3(90, 0, 0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var gm := CapsuleMesh.new()
	gm.radius = 0.15 * size
	gm.height = 1.5 * size + 0.4
	gm.radial_segments = 8
	gm.rings = 3
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.albedo_color = Color(GLOW.r * 1.6, GLOW.g * 1.6, GLOW.b * 1.6, 0.35)
	gm.material = gmat
	var glow := MeshInstance3D.new()
	glow.mesh = gm
	glow.rotation_degrees = Vector3(90, 0, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 1.6 * size
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	add_child(_light)
	_trail = GPUParticles3D.new()
	_trail.amount = 28
	_trail.lifetime = 0.32
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.5
	pm.spread = 180.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	pm.color = Color(0.7, 0.88, 1.0)
	_trail.process_material = pm
	_trail.draw_pass_1 = SpellCaster._mote_mesh(0.1 * size)
	add_child(_trail)


func _orient() -> void:
	var up := Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(direction, up)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if is_instance_valid(target) and turn_rate > 0.0:
		var want := (target.global_position + Vector3(0, 0.9, 0) - global_position).normalized()
		var axis := direction.cross(want)
		if axis.length() > 1e-4:
			var ang := minf(direction.angle_to(want), turn_rate * delta)
			direction = direction.rotated(axis.normalized(), ang).normalized()
			_orient()
	var step := direction * speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1 | 4 | 16, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_impact(hit.position, hit.normal, hit.get("collider"))
		return
	global_position += step
	life -= delta
	if life <= 0.0:
		_done = true
		queue_free()


func _impact(point: Vector3, normal: Vector3, collider: Object) -> void:
	_done = true
	global_position = point
	if collider and collider is Node and (collider as Node).has_method("zoltraak_hit"):
		(collider as Node).call("zoltraak_hit", 10.0 * size, direction)
	var root := get_parent()
	var fx := ZoltraakImpact.new()
	root.add_child(fx)
	fx.global_position = point + normal * 0.04
	fx.play(normal, size)
	queue_free()
