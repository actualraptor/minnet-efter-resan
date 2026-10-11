extends Node
## Scripted teaser, recorded with Godot's movie writer (fixed frame rate):
##   godot --path game --write-movie out.avi --fixed-fps 30 -- --dbg --teaser
## TEASER_PORTRAIT=1 re-frames the same film for 9:16 (TikTok); the resolution
## comes from the window size (see build/teaser/render.sh).
##
## One timeline: a calm flower scene, a night showing each ability in turn on
## straw dummies (Solstråk quick / charged / sustained / burst / arcing missiles,
## Mörkstråk, the barrier holding and breaking, a dive from the sky), then a
## second, larger bloom. Music is mixed in afterwards (tools/audio/compose_teaser.js).

const FPS := 30.0
const TOTAL := 58.0
const FLOWER_RADIUS := 26.0

var main: Node
var p: Player
var cam: Camera3D
var rig: CameraRig
var stage := Vector3.ZERO            # Freyja's position for the night scene
var stage1 := Vector3.ZERO           # the garden (first bloom)
var stage3 := Vector3.ZERO           # the path (second bloom)
var yaw := PI
var portrait := false
var shake := 0.0

var _frame := 0
var _events: Array = []              # [time, Callable]
var _shots: Array = []               # dictionaries, see shot()
var _fade: ColorRect
var _flash: ColorRect
var _title: Label
var _sub: Label
var _caption: Label
var _dummies := {}                   # name -> PracticeDummy
var _shooter: ZoltraakTurret
var _env: Environment
var _sun: DirectionalLight3D
var _fill: OmniLight3D
var _sweep := {}


# --- helpers ------------------------------------------------------------------------

func fwd() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Point relative to a stage: x to her LEFT (positive), y up, z in front of her.
func relf(base: Vector3, x: float, y: float, z: float) -> Vector3:
	var f := fwd()
	var left := Vector3(-f.z, 0.0, f.x) * -1.0
	return base + left * x + Vector3.UP * y + f * z


func rel(x: float, y: float, z: float) -> Vector3:
	return relf(stage, x, y, z)


func at(t: float, fn: Callable) -> void:
	_events.append([t, fn])


func shot(t0: float, t1: float, from0: Vector3, from1: Vector3, look0: Vector3, look1: Vector3, fov := 50.0, fov1 := -1.0, follow := false, base := Vector3(INF, 0, 0)) -> void:
	# Low cameras are lifted clear of the grass.
	var floor_y := (stage.y if not base.is_finite() else base.y)
	var lift := Vector3(0.0, 0.9, 0.0)
	if from0.y - floor_y < 3.0:
		from0 += lift
	if from1.y - floor_y < 3.0:
		from1 += lift
	_shots.append({"t0": t0, "t1": t1, "f0": from0, "f1": from1, "l0": look0, "l1": look1, "fov": fov, "fov1": fov if fov1 < 0.0 else fov1, "follow": follow})


## Ability name, lower third. Appears and fades; nothing else on screen.
func name_card(t0: float, t1: float, text: String) -> void:
	at(t0, func():
		_caption.text = text
		_fade_label(_caption, 1.0, 0.25))
	at(t1, func(): _fade_label(_caption, 0.0, 0.3))


func _fade_label(l: Label, a: float, secs: float) -> void:
	create_tween().tween_property(l, "modulate:a", a, secs)


func _ground(x: float, z: float) -> float:
	return MeadowTerrain.instance.height_at(x, z)


func _stand(x: float, z: float) -> Vector3:
	return Vector3(x, _ground(x, z), z)


# --- setup --------------------------------------------------------------------------

func _ready() -> void:
	main = get_parent()
	main.get_node("UI").visible = false
	portrait = OS.get_environment("TEASER_PORTRAIT") == "1"
	p = main.player
	rig = p.camera_rig
	rig.set_process(false)
	AudioServer.set_bus_mute(0, true)        # music is mixed in afterwards
	_build_overlay()
	cam = Camera3D.new()
	cam.far = 900.0
	cam.near = 0.05
	if portrait:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
	main.add_child(cam)
	cam.make_current()
	var we := main.world.get_node("WorldEnvironment") as WorldEnvironment
	_env = we.environment
	_sun = main.world.sun
	_fill = OmniLight3D.new()
	_fill.light_color = Color(0.7, 0.8, 1.0)
	_fill.light_energy = 0.0
	_fill.omni_range = 9.0
	_fill.shadow_enabled = false
	main.add_child(_fill)

	var g := WorldLayout.GARDEN_MEADOW
	stage1 = _stand(g.x + 1.5, g.z + 8.0)
	stage = stage1
	# The night is played on the path in front of the cottage: open ground.
	stage3 = _stand(-3.5, 33.0)
	yaw = PI
	p.teleport(stage1 + Vector3(0, 0.1, 0), yaw)
	p.model.rotation.y = yaw
	p.caster.max_mana = 600.0
	p.caster.mana = 600.0
	p.caster.mana_regen = 120.0
	p.stamina = 100.0
	# A much bigger Field of Flowers for the film.
	p.caster.spells[0].radius = FLOWER_RADIUS
	_script()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var vp := get_viewport().get_visible_rect().size
	var u := minf(vp.x, vp.y * 1.2) / 100.0          # 1% of the usable width
	_title = _label(layer, int(u * (8.0 if not portrait else 9.0)), 0.42)
	_sub = _label(layer, int(u * 3.0), 0.55)
	_caption = _label(layer, int(u * (4.4 if not portrait else 7.0)), 0.88 if not portrait else 0.84)
	for l in [_title, _sub, _caption]:
		l.modulate.a = 0.0


func _label(layer: CanvasLayer, size: int, y_frac: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiStyle.title_font(700))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.1, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = y_frac
	l.anchor_bottom = y_frac
	l.offset_top = -size
	l.offset_bottom = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l


# --- the film -------------------------------------------------------------------------

func _script() -> void:
	var s1 := stage1
	var s3 := stage3

	# ---- Act 1: the first bloom (calm) -------------------------------------------------
	at(0.0, func(): _fade_to(0.0, 1.2))
	at(0.2, func(): p.staff.summon())
	shot(0.0, 3.4, relf(s1, 2.4, 0.6, 5.8), relf(s1, 1.3, 1.0, 3.7), relf(s1, 0, 1.25, 0), relf(s1, 0, 1.4, 0), 44.0, -1.0, false, s1)
	at(0.9, func():
		_title.text = "Minnet efter resan*"
		_sub.text = "A cozy adventure."
		_fade_label(_title, 1.0, 0.8)
		_fade_label(_sub, 1.0, 1.1))
	at(3.0, func():
		_fade_label(_title, 0.0, 0.6)
		_fade_label(_sub, 0.0, 0.5))
	at(3.2, func():
		p.caster.equip(0)
		p._cast_with_staff())
	name_card(3.6, 6.6, "Field of Flowers")
	# Close and circling while she gathers (release is at about 5.0 s)...
	shot(3.2, 5.1, relf(s1, -3.0, 0.5, 3.8), relf(s1, 3.0, 1.2, 3.4), relf(s1, 0, 1.2, 0), relf(s1, 0, 1.8, 0), 42.0, 46.0, false, s1)
	# ...then up and away as the wave of flowers spreads.
	shot(5.1, 11.8, relf(s1, 3.0, 1.3, 3.4), relf(s1, 0.0, 30.0, 17.0), relf(s1, 0, 1.8, 0), relf(s1, 0, 0.0, 2.0), 46.0, 66.0, false, s1)
	at(11.2, func(): _fade_to(1.0, 1.0))

	# ---- Night: the range -----------------------------------------------------------------
	stage = stage3          # the night (and the last bloom) are on the path
	at(12.3, func(): _night_scene())
	at(12.5, func(): _fade_to(0.0, 0.9))

	# Solstråk: quick shots (three taps)
	shot(12.4, 16.0, rel(-1.6, 0.9, -2.4), rel(-2.4, 0.7, -1.6), rel(0.0, 1.3, 6.5), rel(0.0, 1.3, 8.0), 50.0, 54.0)
	name_card(13.0, 16.0, "Solstråk")
	at(13.0, func():
		p.caster.equip(1)
		p.aim_point_override = _dummies["B"].global_position + Vector3(0, 1.1, 0)
		p._begin_focus_aim())
	for tt in [14.0, 14.5, 15.0]:
		at(tt, func(): p._fire_variant("quick"))

	# Charged shot: the seals build, a fat beam
	shot(16.0, 19.6, rel(6.2, 1.3, 0.0), rel(5.4, 1.9, 2.6), rel(0.0, 1.3, 5.0), rel(0.0, 1.3, 6.0), 56.0, 52.0)
	name_card(16.2, 19.4, "Solstråk: Charged")
	at(16.1, func():
		p.aim_charge = 0.0
		p.aim_point_override = _dummies["B"].global_position + Vector3(0, 1.1, 0))
	at(17.7, func():
		p.aim_charge = 1.0
		Input.action_press("cast")
		p._fire_charged())
	at(18.9, func(): Input.action_release("cast"))

	# Sustained beam sweeping across all three
	shot(19.6, 23.6, rel(-3.0, 1.0, -2.2), rel(2.0, 1.4, -2.4), rel(0.0, 1.3, 6.5), rel(0.0, 1.3, 8.0), 56.0, 58.0)
	name_card(19.8, 23.4, "Solstråk: Sustained Beam")
	at(19.8, func():
		p.aim_charge = 0.0
		var a: Vector3 = _dummies["A"].global_position + Vector3(0, 1.1, 0)
		p.aim_point_override = a
		Input.action_press("cast")
		p._fire_variant("beam")
		_sweep = {"t0": 20.3, "t1": 22.9, "a": a, "b": _dummies["C"].global_position + Vector3(0, 1.1, 0)})
	at(23.2, func():
		Input.action_release("cast")
		_sweep = {})

	# Rapid burst
	shot(23.6, 26.6, rel(2.2, 0.8, -1.8), rel(1.0, 1.2, -2.2), rel(0.0, 1.3, 6.5), rel(0.0, 1.3, 8.0), 50.0, 52.0)
	name_card(23.8, 26.4, "Rapid Burst")
	at(23.8, func(): p.aim_point_override = _dummies["C"].global_position + Vector3(0, 1.1, 0))
	at(24.4, func(): p._fire_variant("burst"))
	at(25.5, func():
		p.aim_point_override = _dummies["A"].global_position + Vector3(0, 1.1, 0)
		p._fire_variant("burst"))

	# Lock-on: arcing missiles
	shot(26.6, 30.2, rel(-4.0, 0.9, 1.0), rel(3.8, 1.5, 0.6), rel(0.0, 1.3, 6.5), rel(0.0, 1.4, 8.0), 54.0, 58.0)
	name_card(26.8, 30.0, "Solstråk: Arcing Missiles")
	at(26.8, func():
		p.lock_target = _dummies["B"]
		p.aim_point_override = _dummies["B"].global_position + Vector3(0, 1.1, 0))
	at(27.6, func(): p._fire_variant("volley"))
	at(28.9, func(): p._fire_variant("volley"))

	# Mörkstråk: the original, charged
	shot(30.2, 34.0, rel(-6.4, 1.4, -0.4), rel(-5.6, 2.0, 2.4), rel(0.0, 1.3, 5.0), rel(0.0, 1.3, 6.0), 58.0, 54.0)
	name_card(30.4, 33.8, "Mörkstråk")
	at(30.3, func():
		p.lock_target = null
		p.caster.equip(3)
		p.caster.mana = 600.0
		p.aim_charge = 0.0
		p.aim_point_override = _dummies["B"].global_position + Vector3(0, 1.1, 0))
	at(31.9, func():
		p.aim_charge = 1.0
		Input.action_press("cast")
		p._fire_charged())
	at(33.2, func(): Input.action_release("cast"))

	# Barrier: holds the shooter's black beam, then gives way
	shot(34.0, 38.0, rel(-3.0, 0.7, -3.2), rel(-1.7, 1.3, -2.4), rel(0.0, 1.3, 4.0), rel(0.0, 1.8, 8.0), 54.0)
	name_card(34.3, 37.8, "Defensive Barrier")
	at(33.8, func():
		p._end_focus_aim(false)
		p.aim_point_override = _shooter.global_position + Vector3(0, 2.0, 0)
		p.caster.equip(2)
		Input.action_press("cast")
		p.caster.try_cast())
	at(34.4, func():
		_shooter.beam_power = 1.0
		_shooter.beam_seconds = 2.4
		_shooter.auto_target = p
		_shooter._run_attack())
	shot(38.0, 41.4, rel(3.4, 0.7, 4.6), rel(2.4, 1.1, 3.4), rel(0, 1.3, 1.8), rel(0, 1.3, 1.8), 52.0, 46.0)
	at(37.7, func():
		_shooter.beam_power = 14.0
		_shooter.beam_seconds = 3.4
		_shooter.auto_target = p
		_shooter._run_attack())
	at(38.6, func(): shake = 0.35)

	# Up and a dive from the sky
	shot(41.4, 44.0, rel(-3.0, 0.6, 2.8), rel(-3.0, 4.5, 3.4), rel(0, 1.2, 0), rel(0, 5.5, 3.0), 55.0, 60.0, true)
	at(41.0, func():
		Input.action_release("cast")
		shake = 0.0
		for b in get_tree().get_nodes_in_group("magic_barrier"):
			(b as MagicBarrier3D).release())
	at(41.4, func():
		_shooter.auto_target = null
		p.start_flight()
		Input.action_press("jump"))
	at(42.8, func():
		Input.action_release("jump")
		p.caster.equip(1)
		p.aim_point_override = _shooter.global_position + Vector3(0, 1.8, 0)
		p._begin_focus_aim())
	name_card(41.6, 44.6, "Flight")
	shot(44.0, 46.2, rel(3.4, 7.2, -2.0), rel(1.6, 5.8, 6.0), rel(0, 3.5, 8.0), rel(0, 1.8, 16.0), 56.0, 60.0)
	at(44.1, func(): p.aim_charge = 1.0)
	at(44.4, func():
		Input.action_press("cast")
		p._fire_charged())
	at(45.4, func():
		Input.action_release("cast")
		_flash_white(0.9))

	# ---- Act 3: a second, larger bloom on the path -------------------------------------------
	at(45.6, func(): _fade_to(1.0, 0.7))
	at(46.4, func(): _calm_night())
	at(46.7, func(): _fade_to(0.0, 1.0))
	shot(46.4, 48.4, relf(s3, -3.2, 0.5, 3.8), relf(s3, 3.0, 1.2, 3.4), relf(s3, 0, 1.2, 0), relf(s3, 0, 1.8, 0), 42.0, 46.0, false, s3)
	at(47.2, func():
		p.caster.equip(0)
		p._cast_with_staff())
	name_card(47.6, 50.6, "Field of Flowers")
	shot(48.4, 56.0, relf(s3, 3.0, 1.3, 3.4), relf(s3, 0.0, 32.0, 18.0), relf(s3, 0, 1.8, 0), relf(s3, 0, 0.0, 2.0), 46.0, 66.0, false, s3)
	at(52.5, func():
		_title.text = "Minnet efter resan*"
		_sub.text = "A cozy adventure."
		_fade_label(_title, 1.0, 1.0)
		_fade_label(_sub, 1.0, 1.4))
	at(56.9, func(): _fade_to(1.0, 0.9))


func _fade_to(a: float, secs: float) -> void:
	create_tween().tween_property(_fade, "color:a", a, secs)


func _flash_white(secs: float) -> void:
	_flash.color.a = 0.95
	create_tween().tween_property(_flash, "color:a", 0.0, secs)


func _night_scene() -> void:
	p.teleport(stage + Vector3(0, 0.1, 0), yaw)
	p.model.rotation.y = yaw
	p.set_levitation(0.0)
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.015, 0.025, 0.07)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.3, 0.36, 0.62)
	_env.ambient_light_energy = 1.25
	_env.fog_enabled = false
	_env.volumetric_fog_enabled = false
	_env.tonemap_exposure = 1.05
	_sun.light_color = Color(0.6, 0.7, 1.0)
	_sun.light_energy = 1.1
	_sun.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(150.0), 0.0)
	_fill.light_energy = 2.2
	_fill.omni_range = 16.0
	_fill.global_position = stage + Vector3(0, 3.2, 0)
	_spawn_dummies()
	p.staff.touch()


func _calm_night() -> void:
	# A softer moonlit calm after the fight; the second bloom lands on untouched
	# ground of the same path.
	_env.ambient_light_color = Color(0.32, 0.36, 0.58)
	_env.ambient_light_energy = 1.0
	_sun.light_color = Color(0.78, 0.84, 1.0)
	_sun.light_energy = 0.9
	_fill.light_energy = 1.4
	if p.flying:
		p.stop_flight()
	Input.action_release("jump")
	Input.action_release("cast")
	p._end_focus_aim(false)
	p.lock_target = null
	p.aim_point_override = Vector3.INF
	for d in _dummies.values():
		if is_instance_valid(d):
			(d as Node3D).queue_free()
	_dummies.clear()
	if is_instance_valid(_shooter):
		_shooter.queue_free()
	for b in get_tree().get_nodes_in_group("magic_barrier"):
		(b as MagicBarrier3D).queue_free()
	p.teleport(stage + Vector3(0, 0.1, 0), yaw)
	p.model.rotation.y = yaw
	_fill.global_position = stage + Vector3(0, 3.2, 0)
	p.staff.touch()


func _spawn_dummies() -> void:
	var spec := {"A": Vector2(4.4, 7.4), "B": Vector2(0.0, 8.6), "C": Vector2(-4.4, 7.4)}
	for n in spec:
		var d := PracticeDummy.new()
		d.show_count = false
		main.add_child(d)
		var pos := rel(spec[n].x, 0.0, spec[n].y)
		pos.y = _ground(pos.x, pos.z)
		d.global_position = pos
		d.rotation.y = yaw + PI
		d.scale = Vector3.ONE * 1.35
		_dummies[n] = d
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.7)
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.shadow_enabled = false
		light.position = Vector3(0, 2.6, -1.0)
		d.add_child(light)
	# The shooter: a larger dummy with a black sigil, far back.
	_shooter = ZoltraakTurret.new()
	_shooter.kind = ZoltraakVisuals.Kind.BLACK
	_shooter.monster = "dummy"
	_shooter.telegraph = 1.0
	_shooter.beam_seconds = 2.4
	main.add_child(_shooter)
	var sp := rel(0.0, 0.0, 17.0)
	sp.y = _ground(sp.x, sp.z)
	_shooter.global_position = sp
	_shooter._model_scale = 1.9
	for l in _shooter.find_children("*", "Label3D", true, false):
		l.visible = false


# --- per frame -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var t := float(_frame) / FPS
	# Events due this frame.
	for e in _events:
		if e[0] <= t and e[0] > t - 1.0 / FPS - 0.0001:
			(e[1] as Callable).call()
	# Sweeping aim for the sustained beam.
	if not _sweep.is_empty() and t >= _sweep.t0:
		var u := clampf((t - _sweep.t0) / (_sweep.t1 - _sweep.t0), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		p.aim_point_override = (_sweep.a as Vector3).lerp(_sweep.b, u)
	# Active shot.
	for s in _shots:
		if t >= s.t0 and t <= s.t1:
			var u := clampf((t - s.t0) / maxf(s.t1 - s.t0, 0.001), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			var from_p: Vector3 = (s.f0 as Vector3).lerp(s.f1, u)
			var look_p: Vector3 = (s.l0 as Vector3).lerp(s.l1, u)
			if s.follow:
				var off := p.global_position - stage
				from_p += off
				look_p += off
			if shake > 0.0:
				from_p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.18
			cam.global_position = from_p
			cam.look_at(look_p, Vector3.UP)
			var fov := lerpf(s.fov, s.fov1, u)
			cam.fov = fov * (1.12 if portrait else 1.0)
	_frame += 1
	if _frame >= int(TOTAL * FPS):
		get_tree().quit()
