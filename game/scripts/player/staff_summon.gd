class_name StaffSummon
extends Node
## Freyja's staff isn't carried: she pulls it out of thin air with a short
## gesture (it materialises outward from her hand in green-gold light) and it
## dissolves again after a while unused. Drives the locomotion "staff" blend.

signal summoned
signal stowed

const STOW_AFTER := 12.0
const GROW_TIME := 0.45
const STAFF_LENGTH := 1.9
## Ways Freyja draws her staff (clip -> seconds until it materialises in her hand).
const VARIANTS := {"Summon": 0.45, "SummonFlick": 0.31, "SummonReach": 0.42, "SummonTwirl": 0.3}
var _last_variant := ""

var player: Node3D
var loco: LocomotionAnimator
var out := false
var busy := false
var _mats: Array[ShaderMaterial] = []
var _skel: Skeleton3D
var _hand_bone := -1
var _last_used := 0.0
var _radius := 0.0
var _sparks: GPUParticles3D


func setup(p: Node3D, model: Node, locomotion: LocomotionAnimator) -> bool:
	player = p
	loco = locomotion
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).to_lower().begins_with("staff"):
			continue
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is ShaderMaterial:
				var own := (mat as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_surface_override_material(s, own)
				_mats.append(own)
	for sk in model.find_children("*", "Skeleton3D", true, false):
		_skel = sk
		_hand_bone = _skel.find_bone("hand.R")
		break
	_sparks = GPUParticles3D.new()
	_sparks.amount = 70
	_sparks.lifetime = 0.8
	_sparks.one_shot = true
	_sparks.explosiveness = 0.7
	_sparks.emitting = false
	_sparks.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.radial_accel_min = -4.0
	pm.radial_accel_max = -2.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.color = Color(0.85, 1.0, 0.6)
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_sparks.process_material = pm
	_sparks.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	add_child(_sparks)
	_set_radius(0.0)
	return not _mats.is_empty()


func _grip() -> Vector3:
	if _skel and _hand_bone >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(_hand_bone).origin
	return player.global_position + Vector3(0, 1.0, 0)


func _set_radius(r: float) -> void:
	_radius = r
	var o := _grip()
	for m in _mats:
		m.set_shader_parameter("dissolve_origin", o)
		m.set_shader_parameter("dissolve_radius", r if r < STAFF_LENGTH else 1000.0)


func _process(_delta: float) -> void:
	if _mats.is_empty():
		return
	if busy or (_radius > 0.0 and _radius < STAFF_LENGTH):
		_set_radius(_radius)  # keep the origin glued to the moving hand
	if out and not busy and Time.get_ticks_msec() / 1000.0 - _last_used > STOW_AFTER:
		stow()


func _hand(pose: String) -> void:
	var h = player.get("hands")
	if h:
		h.set_pose("R", pose)


func touch() -> void:
	_last_used = Time.get_ticks_msec() / 1000.0


## Plays the gesture and materialises the staff; awaitable.
func summon(variant := "") -> void:
	if out or busy:
		return
	busy = true
	touch()
	var options: Array = VARIANTS.keys().filter(func(k): return k != _last_variant)
	var clip: String = variant if VARIANTS.has(variant) else options.pick_random()
	_last_variant = clip
	if loco:
		loco.summon(clip)
	_hand("open")
	await get_tree().create_timer(VARIANTS[clip]).timeout
	_hand("grip")
	_sparks.global_position = _grip()
	_sparks.restart()
	Audio.sfx("spell_gather", -10.0, 0.05)
	var tw := create_tween()
	tw.tween_method(_set_radius, 0.0, STAFF_LENGTH + 0.1, GROW_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if loco:
		loco.set_staff(true)
	await tw.finished
	out = true
	busy = false
	summoned.emit()


func stow() -> void:
	if not out or busy:
		return
	busy = true
	_sparks.global_position = _grip()
	_sparks.restart()
	get_tree().create_timer(0.45).timeout.connect(_hand.bind("relaxed"))
	var tw := create_tween()
	tw.tween_method(_set_radius, STAFF_LENGTH + 0.1, 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	if loco:
		loco.set_staff(false)
	await tw.finished
	out = false
	busy = false
	stowed.emit()
