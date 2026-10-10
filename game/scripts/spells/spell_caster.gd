class_name SpellCaster
extends Node
## Spell activation for any caster: equipped spells, mana, cooldowns, the shared
## gathering visual and handing off to the spell's effect scene. The owning body
## implements the small "caster interface":
##   can_start_cast() -> bool, is_indoors() -> bool, staff_tip() -> Vector3,
##   begin_cast(anim: StringName, duration: float), end_cast()

signal cast_started(spell: SpellDefinition)
signal cast_released(spell: SpellDefinition, ctx: SpellContext)
signal cast_failed(spell: SpellDefinition, reason: String)
signal mana_changed(mana: float, max_mana: float)
signal equipped_changed(spell: SpellDefinition)

@export var spells: Array[SpellDefinition] = []
@export var max_mana := 100.0
@export var mana_regen := 9.0

var mana := 100.0
## The casting body; defaults to the parent node.
var body  # duck-typed caster interface (see header)
var equipped := 0
var casting := false
var _cooldowns: Dictionary = {}
var _cast_count := 0
var _cast_id := 0
var _charge_fx: Node3D
var _sustain_fx: Node
var _gather: GPUParticles3D
var _gather_light: OmniLight3D


func _ready() -> void:
	if body == null:
		body = get_parent()
	mana = max_mana
	_build_gather_vfx()


func current_spell() -> SpellDefinition:
	return spells[equipped] if equipped < spells.size() else null


func equip(index: int) -> void:
	if index >= 0 and index < spells.size():
		equipped = index
		equipped_changed.emit(current_spell())


func cooldown_left(spell: SpellDefinition) -> float:
	return maxf(0.0, float(_cooldowns.get(spell.id, 0.0)) - GameState.game_time())


func _process(delta: float) -> void:
	if mana < max_mana:
		mana = minf(max_mana, mana + mana_regen * delta)
		mana_changed.emit(mana, max_mana)
	if _gather and _gather.emitting:
		_gather.global_position = body.staff_tip()
		_gather_light.global_position = _gather.global_position


## Returns "" on success or a short, in-character reason.
func try_cast(spell: SpellDefinition = null) -> String:
	spell = spell if spell else current_spell()
	var reason := _validate(spell)
	if reason != "":
		cast_failed.emit(spell, reason)
		return reason
	_cast(spell)
	return ""


func _validate(spell: SpellDefinition) -> String:
	if spell == null:
		return "No spell prepared."
	if casting:
		return "busy"
	if not body.can_start_cast():
		return "busy"
	if body.is_indoors() and not spell.allowed_indoors:
		return "Not indoors. Someone would have to sweep up after."
	if cooldown_left(spell) > 0.0:
		return "The mana hasn't settled yet."
	if mana < spell.mana_cost:
		return "Not enough mana. Patience."
	if body.has_method("can_afford_cast") and not body.can_afford_cast(spell):
		return "Too winded to cast up here."
	return ""


func _cast(spell: SpellDefinition) -> void:
	casting = true
	_cast_id += 1
	var my_id := _cast_id
	mana -= spell.mana_cost
	mana_changed.emit(mana, max_mana)
	if body.has_method("pay_cast_cost"):
		body.pay_cast_cost(spell)   # extra stamina when casting from the air
	_cooldowns[spell.id] = GameState.game_time() + spell.cooldown + spell.cast_time
	var staff_cast: bool = spell.staff_pose != &"" and body.has_method("begin_staff_cast")
	var cast_time := spell.cast_time
	if staff_cast:
		# A chained cast starts partway into the pose, so its wind-up is shorter.
		cast_time = body.begin_staff_cast(spell)
	else:
		body.begin_cast(spell.cast_animation, spell.cast_time + spell.recovery_time)
		if spell.levitate_height > 0.0 and body.has_method("set_levitation"):
			body.set_levitation(spell.levitate_height)
	if spell.expression != &"" and body.get("face") != null:
		body.face.set_expression(String(spell.expression), spell.cast_time + spell.recovery_time + 0.4)
	cast_started.emit(spell)
	Audio.sfx(spell.cast_sound, -4.0, 0.03)
	_set_gather(spell.gather_particles, spell.gather_color)
	if spell.charge_script != "":
		_charge_fx = _make_fx(spell.charge_script)
		if _charge_fx:
			body.get_parent().add_child(_charge_fx)
			_charge_fx.call("begin", body, spell, cast_time)
	await get_tree().create_timer(cast_time, false).timeout
	if my_id != _cast_id:
		return
	_set_gather(false, spell.gather_color)
	var ctx := SpellContext.new()
	ctx.spell = spell
	ctx.caster = body
	# Effects start on the ground beneath the caster, even when she is airborne.
	ctx.origin = body.ground_point() if body.has_method("ground_point") else body.global_position
	var fwd: Vector3 = body.facing_basis().z
	ctx.direction = fwd
	ctx.muzzle = body.staff_tip()
	ctx.aim = body.staff_direction() if body.has_method("staff_direction") else fwd
	ctx.target = ctx.origin + fwd * (0.0 if spell.targeting == SpellDefinition.Targeting.SELF_AREA else spell.max_range)
	_cast_count += 1
	ctx.cast_seed = hash([spell.id, _cast_count, Time.get_ticks_usec()])
	if _charge_fx and is_instance_valid(_charge_fx):
		_charge_fx.call("finish")
		_charge_fx = null
	var fx: Node = null
	if spell.effect_script != "":
		fx = _make_fx(spell.effect_script)
		if fx:
			body.get_parent().add_child(fx)
	elif spell.effect_scene:
		fx = spell.effect_scene.instantiate()
		body.get_parent().add_child(fx)
	if fx:
		if fx is Node3D:
			(fx as Node3D).global_position = ctx.origin
		fx.call("start", ctx)
	Audio.sfx(spell.release_sound, -2.0, 0.02)
	cast_released.emit(spell, ctx)
	GameState.spell_cast.emit(String(spell.id), ctx.origin, ctx.target)
	# Sustained spells (barriers) hold until the cast button is let go.
	if spell.sustained:
		_sustain_fx = fx
		var held := 0.0
		while my_id == _cast_id and held < 60.0 and (Input.is_action_pressed("cast") or Input.is_action_pressed("cast_alt")):
			await get_tree().process_frame
			held += get_process_delta_time()
		if _sustain_fx and is_instance_valid(_sustain_fx) and _sustain_fx.has_method("release"):
			_sustain_fx.call("release")
		_sustain_fx = null
		if staff_cast and body.has_method("end_staff_hold"):
			body.end_staff_hold()
	if my_id != _cast_id:
		return
	# Chaining: the caster may start the next cast before the recovery tail ends.
	var rec := spell.recovery_time
	if spell.chain_after >= 0.0 and not spell.sustained:
		await get_tree().create_timer(minf(spell.chain_after, rec), false).timeout
		if my_id != _cast_id:
			return
		casting = false
		await get_tree().create_timer(maxf(rec - spell.chain_after, 0.0), false).timeout
		if my_id != _cast_id:
			return
	else:
		await get_tree().create_timer(rec, false).timeout
		if my_id != _cast_id:
			return
		casting = false
	body.end_cast()
	if body.has_method("set_levitation") and spell.levitate_height > 0.0:
		# Hang in the air a beat after the flowers have bloomed, then settle.
		await get_tree().create_timer(0.6, false).timeout
		body.set_levitation(0.0)


## An incoming hit on a held barrier (world point of impact).
func barrier_hit(point: Vector3) -> void:
	if _sustain_fx and is_instance_valid(_sustain_fx) and _sustain_fx.has_method("hit"):
		_sustain_fx.call("hit", point)


## Cancels the current cast: visuals stop, the caster is free again.
func interrupt() -> void:
	_cast_id += 1
	casting = false
	_set_gather(false, Color.WHITE)
	if _charge_fx and is_instance_valid(_charge_fx):
		_charge_fx.call("finish")
	_charge_fx = null
	if _sustain_fx and is_instance_valid(_sustain_fx) and _sustain_fx.has_method("release"):
		_sustain_fx.call("release")
	_sustain_fx = null


func _make_fx(path: String) -> Node3D:
	var scr := load(path) as GDScript
	return scr.new() as Node3D if scr else null


func _build_gather_vfx() -> void:
	_gather = GPUParticles3D.new()
	_gather.name = "GatherParticles"
	_gather.amount = 160
	_gather.lifetime = 0.9
	_gather.emitting = false
	_gather.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 1.1
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.radial_accel_min = -3.5
	pm.radial_accel_max = -2.5
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	_gather.process_material = pm
	_gather.draw_pass_1 = _mote_mesh(0.11)
	_gather_light = OmniLight3D.new()
	_gather_light.light_energy = 0.0
	_gather_light.omni_range = 4.0
	_gather_light.shadow_enabled = false
	add_child(_gather)
	add_child(_gather_light)


func _set_gather(on: bool, color: Color) -> void:
	_gather.global_position = body.staff_tip()
	_gather_light.global_position = _gather.global_position
	var mat: StandardMaterial3D = _gather.draw_pass_1.surface_get_material(0)
	mat.albedo_color = color
	mat.emission = color
	_gather_light.light_color = color
	_gather.emitting = on
	var tw := create_tween()
	tw.tween_property(_gather_light, "light_energy", 3.5 if on else 0.0, 0.5 if on else 0.8)


static func _mote_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = MoteTexture.get_texture()
	m.emission_enabled = true
	m.emission_energy_multiplier = 2.0
	m.vertex_color_use_as_albedo = true
	q.material = m
	return q
