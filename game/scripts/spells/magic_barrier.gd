class_name MagicBarrier3D
extends Node3D
## Defensive hexagonal barrier: a spherical cap (the "dome") of `radius` metres
## centred on this node, opening toward local +Z over `coverage_deg`. The cap
## is both what is drawn and what stops attacks: intersect() is an analytic
## ray/sphere test plus a hole list, so visuals and collision cannot disagree.
##
## Attacks call absorb(point, power, persistent, key). One-shot hits light the
## cells and ripple outward; a beam passes persistent=true with a stable key and
## keeps its contact cells lit while particles stream along the surface.
## Stress accumulates with absorbed power; past 1.0 the struck region fails
## (a ragged hole that attacks pass through) and heals once stress recedes.

signal absorbed(point: Vector3, power: float)
signal failed(point: Vector3)
signal collapsed

const SHADER := preload("res://shaders/magic_barrier.gdshader")
const SLOTS := 8

var team := 0
var active := true
var radius := 1.8
var coverage_deg := 150.0
var stress := 0.0
## Stress gained per unit of attack power, and recovery per second when quiet.
var stress_per_power := 0.06
var stress_recovery := 0.3
## Mana per unit power; the owner's SpellCaster is billed via `pay`.
var mana_per_power := 3.0
var pay: Callable                  # func(mana: float) -> bool (false = out of mana)
var appear := 0.0

var _mat: ShaderMaterial
var _mi: MeshInstance3D
var _slots: Array[Dictionary] = []
var _quiet := 0.0
var _closing := false
var _streams := {}                 # key -> GPUParticles3D for persistent contacts
var _light: OmniLight3D


func build(r: float, coverage: float, tint := Color(0.45, 0.82, 1.0)) -> void:
	radius = r
	coverage_deg = coverage
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("radius", r)
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_mi = MeshInstance3D.new()
	_mi.mesh = _cap_mesh(r, coverage)
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 4.0
	add_child(_mi)
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.omni_range = r * 2.6
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0, r * 0.8)
	add_child(_light)
	for i in SLOTS:
		_slots.append({"dir": Vector3.FORWARD, "age": -1.0, "str": 0.0, "persist": false, "key": 0, "seen": 0.0, "hole": 0.0, "hole_goal": 0.0})
	add_to_group("magic_barrier")
	_push()


static func _cap_mesh(r: float, coverage: float) -> ArrayMesh:
	var theta_max := deg_to_rad(clampf(coverage * 0.5, 20.0, 88.0))
	var rings := 20
	var segs := 72
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in rings + 1:
		var th := theta_max * float(i) / rings
		for j in segs:
			var ph := TAU * float(j) / segs
			var n := Vector3(sin(th) * cos(ph), sin(th) * sin(ph), cos(th))
			verts.append(n * r)
			norms.append(n)
	for i in rings:
		for j in segs:
			var a := i * segs + j
			var b := i * segs + (j + 1) % segs
			idx.append_array([a, b, a + segs, b, b + segs, a + segs])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- queries ---------------------------------------------------------------------------

func forward() -> Vector3:
	return global_basis.z


func surface_normal(p: Vector3) -> Vector3:
	return (p - global_position).normalized()


func _local_dir(p: Vector3) -> Vector3:
	return (global_basis.orthonormalized().inverse() * (p - global_position)).normalized()


func is_open_at(p: Vector3) -> bool:
	var d := _local_dir(p)
	for s in _slots:
		if s.hole > 0.06 and s.age >= 0.0:
			if acos(clampf(d.dot(s.dir), -1.0, 1.0)) * radius < s.hole:
				return true
	return false


## Distance along the ray at which it enters the covered dome, or -1. Rays that
## start inside the dome (the caster's own side) are never stopped.
func intersect(from: Vector3, dir: Vector3, max_t: float) -> float:
	if not active or appear < 0.5:
		return -1.0
	var c := global_position
	var oc := from - c
	if oc.length_squared() < radius * radius:
		return -1.0
	var b := oc.dot(dir)
	var cc := oc.length_squared() - radius * radius
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	if t < 0.0 or t > max_t:
		return -1.0
	var p := from + dir * t
	var d := _local_dir(p)
	if d.z < cos(deg_to_rad(coverage_deg * 0.5)):
		return -1.0
	if is_open_at(p):
		return -1.0
	return t


# --- absorbing -------------------------------------------------------------------------

## Take an attack at world `point`. Returns true when it was stopped (false if
## the point is inside a failed region or the barrier is down).
func absorb(point: Vector3, power: float, persistent := false, key := 0) -> bool:
	if not active or appear < 0.5 or is_open_at(point):
		return false
	var d := _local_dir(point)
	var slot := _find_slot(d, persistent, key)
	slot.dir = d
	slot.str = clampf(0.55 + power * 0.5, 0.4, 2.0)
	if persistent:
		slot.persist = true
		slot.key = key
		slot.seen = 0.0
		if slot.age < 0.0:
			slot.age = 0.0
	else:
		slot.persist = false
		slot.age = 0.0
	stress = minf(stress + power * stress_per_power, 1.6)
	_quiet = 0.0
	if pay.is_valid():
		if not pay.call(power * mana_per_power):
			collapse()
	absorbed.emit(point, power)
	if not persistent:
		_burst(point, power)
	if stress >= 1.0 and slot.hole_goal < 0.05:
		slot.hole_goal = 0.85 + 0.4 * (stress - 1.0)
		failed.emit(point)
	return true


func _find_slot(d: Vector3, persistent: bool, key: int) -> Dictionary:
	for s in _slots:
		if persistent and s.persist and s.key == key and s.age >= 0.0:
			return s
	# Merge a fresh hit into a nearby live one so a stream of bolts on the same
	# spot keeps one steadily lit region instead of eating every slot.
	for s in _slots:
		if s.age >= 0.0 and not s.persist and s.hole_goal < 0.05 and acos(clampf(d.dot(s.dir), -1.0, 1.0)) * radius < 0.25 and s.age < 0.5:
			return s
	var oldest: Dictionary = _slots[0]
	for s in _slots:
		if s.age < 0.0:
			return s
		if s.hole_goal < 0.05 and (oldest.hole_goal >= 0.05 or s.age > oldest.age):
			oldest = s
	return oldest


func release() -> void:
	_closing = true


func collapse() -> void:
	_closing = true
	collapsed.emit()


func _process(delta: float) -> void:
	if _closing:
		appear = move_toward(appear, 0.0, delta * 3.0)
		if appear <= 0.0:
			queue_free()
			return
	else:
		appear = move_toward(appear, 1.0, delta * 2.6)
	_quiet += delta
	if _quiet > 0.4:
		stress = maxf(stress - stress_recovery * delta, 0.0)
	var live := 0
	for s in _slots:
		if s.age < 0.0:
			continue
		s.age += delta
		if s.persist:
			s.seen += delta
			if s.seen > 0.12:
				s.persist = false
				s.age = 0.35
		# Failed regions heal as stress recedes.
		if s.hole_goal > 0.05 and stress < 0.45:
			s.hole_goal = 0.0
		s.hole = move_toward(s.hole, s.hole_goal, delta * (2.5 if s.hole_goal > s.hole else 0.9))
		if s.age > 3.0 and not s.persist and s.hole < 0.01:
			s.age = -1.0
		else:
			live += 1
	_update_streams(delta)
	_light.light_energy = appear * (0.5 + 1.6 * minf(stress, 1.0)) + minf(live, 4) * 0.35
	_push()


func _push() -> void:
	var dirs := PackedVector4Array()
	var data := PackedVector4Array()
	for s in _slots:
		var dv: Vector3 = s.dir
		dirs.append(Vector4(dv.x, dv.y, dv.z, s.age))
		data.append(Vector4(s.str, 1.0 if s.persist else 0.0, s.hole, 0.0))
	_mat.set_shader_parameter("imp_dir", dirs)
	_mat.set_shader_parameter("imp_data", data)
	_mat.set_shader_parameter("appear", appear)
	_mat.set_shader_parameter("stress", clampf(stress, 0.0, 1.0))


# --- effects ------------------------------------------------------------------------------

func _make_sparks(count: int, life: float, speed: float, spread: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3.ZERO
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.color = Color(0.8, 0.95, 1.0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	p.process_material = pm
	p.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	return p


## The attack's energy dispersing over the shield: sparks skate along the
## surface in all directions, no flash of an explosion.
func _burst(point: Vector3, power: float) -> void:
	var p := _make_sparks(18, 0.5, 3.0 + power, 180.0)
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = surface_normal(point)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	add_child(p)
	p.top_level = true
	p.global_position = point
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func _update_streams(_delta: float) -> void:
	var seen := {}
	for s in _slots:
		if s.age >= 0.0 and s.persist:
			seen[s.key] = s
	for key in seen:
		var s: Dictionary = seen[key]
		var world_p: Vector3 = global_position + global_basis * (s.dir * radius)
		if not _streams.has(key):
			var p := _make_sparks(40, 0.55, 3.5, 90.0)
			add_child(p)
			p.top_level = true
			_streams[key] = p
		var st: GPUParticles3D = _streams[key]
		st.global_position = world_p
		(st.process_material as ParticleProcessMaterial).direction = (global_basis * s.dir).cross(Vector3.UP).normalized()
		st.emitting = true
	for key in _streams.keys():
		if not seen.has(key):
			var st: GPUParticles3D = _streams[key]
			st.emitting = false
			get_tree().create_timer(0.7).timeout.connect(st.queue_free)
			_streams.erase(key)


func slot_info() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in _slots:
		if s.age >= 0.0:
			out.append(s.duplicate())
	return out
