class_name ZoltraakBolt
extends Node3D
## One Zoltraak bolt: a short white (or black) streak that travels in sub-frame
## raycasts so it never tunnels, optionally curves toward a target (a limited
## turn rate: a gentle curve, never an instant lock-on), is stopped by magic
## barriers of the other team (dispersing over the shield instead of exploding)
## and ends in a petalled impact on solid things.

var direction := Vector3.FORWARD
var speed := 70.0
var life := 1.4
var size := 1.0
var target: Node3D
var turn_rate := 0.0
## Missiles first sweep out along `direction` for this long without homing, then
## curve in on the target: the arc that gets around a barrier's front.
var arc_time := 0.0
var exclude: Array[RID] = []
var kind := ZoltraakVisuals.Kind.WHITE
var team := 0
var power := 1.0
var _light: OmniLight3D
var _trail: GPUParticles3D
var _done := false


func setup(from: Vector3, dir: Vector3, spd: float, scale_factor := 1.0, visual := ZoltraakVisuals.Kind.WHITE) -> void:
	add_to_group("zoltraak_missile")
	global_position = from
	direction = dir.normalized()
	speed = spd
	size = scale_factor
	kind = visual
	power = size
	_build()
	_orient()


func _build() -> void:
	var blen := 1.7 * size + 0.4
	var body := ZoltraakVisuals.make_beam(blen, 0.1 * size, kind)
	# The streak trails behind the head (local +Z is the direction of travel):
	# the body spans z in [-len, 0] and its start fade tapers the tail.
	add_child(body)
	body.position = Vector3(0, 0, -blen * 0.5)
	(body.material_override as ShaderMaterial).set_shader_parameter("start_fade", 1.0)
	(body.material_override as ShaderMaterial).set_shader_parameter("flow", 0.0)
	_light = OmniLight3D.new()
	_light.light_color = ZoltraakVisuals.accent(kind)
	_light.light_energy = 1.4 * size
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
	pm.color = Color(1, 1, 1) if kind == ZoltraakVisuals.Kind.WHITE else Color(0.45, 0.25, 0.9)
	_trail.process_material = pm
	_trail.draw_pass_1 = SpellCaster._mote_mesh(0.1 * size)
	add_child(_trail)


func _orient() -> void:
	var up := Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(direction, up)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if arc_time > 0.0:
		arc_time -= delta
	elif is_instance_valid(target) and turn_rate > 0.0:
		var want := (target.global_position + Vector3(0, 0.9, 0) - global_position).normalized()
		var axis := direction.cross(want)
		if axis.length() > 1e-4:
			var ang := minf(direction.angle_to(want), turn_rate * delta)
			direction = direction.rotated(axis.normalized(), ang).normalized()
			_orient()
	var step := speed * delta
	var tr := ZoltraakHit.trace(get_tree(), get_world_3d(), global_position, direction, step, exclude, team)
	if bool(tr.hit):
		_impact(tr)
		return
	global_position += direction * step
	life -= delta
	if life <= 0.0:
		_done = true
		queue_free()


func _impact(tr: Dictionary) -> void:
	_done = true
	global_position = tr.point
	var barrier := tr.barrier as MagicBarrier3D
	if barrier != null:
		# Absorbed: the energy disperses over the shield. No explosion.
		barrier.absorb(tr.point, power, false)
		queue_free()
		return
	var col = tr.collider
	if col != null and col is Node and (col as Node).has_method("zoltraak_hit"):
		(col as Node).call("zoltraak_hit", 10.0 * size, direction)
	var fx := ZoltraakImpact.new()
	get_parent().add_child(fx)
	fx.global_position = (tr.point as Vector3) + (tr.normal as Vector3) * 0.04
	fx.play(tr.normal, size, kind)
	queue_free()
