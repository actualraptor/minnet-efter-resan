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
	return ""


func _cast(spell: SpellDefinition) -> void:
	casting = true
	mana -= spell.mana_cost
	mana_changed.emit(mana, max_mana)
	_cooldowns[spell.id] = GameState.game_time() + spell.cooldown + spell.cast_time
	body.begin_cast(spell.cast_animation, spell.cast_time + spell.recovery_time)
	cast_started.emit(spell)
	Audio.sfx(spell.cast_sound, -4.0, 0.03)
	_set_gather(true, spell.gather_color)
	await get_tree().create_timer(spell.cast_time, false).timeout
	_set_gather(false, spell.gather_color)
	var ctx := SpellContext.new()
	ctx.spell = spell
	ctx.caster = body
	ctx.origin = body.global_position
	var fwd: Vector3 = body.facing_basis().z
	ctx.direction = fwd
	ctx.target = ctx.origin + fwd * (0.0 if spell.targeting == SpellDefinition.Targeting.SELF_AREA else spell.max_range)
	_cast_count += 1
	ctx.cast_seed = hash([spell.id, _cast_count, Time.get_ticks_usec()])
	if spell.effect_scene:
		var fx: Node = spell.effect_scene.instantiate()
		body.get_parent().add_child(fx)
		if fx is Node3D:
			(fx as Node3D).global_position = ctx.origin
		fx.call("start", ctx)
	Audio.sfx(spell.release_sound, -2.0, 0.02)
	cast_released.emit(spell, ctx)
	GameState.spell_cast.emit(String(spell.id), ctx.origin, ctx.target)
	await get_tree().create_timer(spell.recovery_time, false).timeout
	casting = false
	body.end_cast()


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
