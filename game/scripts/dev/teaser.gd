extends Node
## Scripted teaser, recorded with Godot's movie writer (fixed frame rate):
##   godot --path game --write-movie out.avi --fixed-fps 30 --resolution 1920x1080 -- --dbg --teaser
## TEASER_PORTRAIT=1 re-frames the same film for 9:16 (TikTok).
##
## Three acts on one timeline: a calm flower scene, a night battle (Solstråk and
## Mörkstråk, the barrier breaking, a dive from the sky), and a calm ending.
## Music is mixed in afterwards (tools/audio/compose_teaser.js).

const FPS := 30.0
const TOTAL := 41.0

var main: Node
var p: Player
var cam: Camera3D
var rig: CameraRig
var stage := Vector3.ZERO            # Freyja's position at the start (anchor for shots)
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
var _caption_sub: Label
var _mon := {}                       # name -> ZoltraakTurret
var _env: Environment
var _sun: DirectionalLight3D
var _fill: OmniLight3D
var _night := 0.0
var _slow_until := -1.0


# --- helpers ------------------------------------------------------------------------

func fwd() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Stage-relative point: x to her right, y up, z in front of her.
func rel(x: float, y: float, z: float) -> Vector3:
	var f := fwd()
	var right := Vector3(-f.z, 0.0, f.x) * -1.0
	return stage + right * x + Vector3.UP * y + f * z


func at(t: float, fn: Callable) -> void:
	_events.append([t, fn])


func shot(t0: float, t1: float, from0: Vector3, from1: Vector3, look0: Vector3, look1: Vector3, fov := 50.0, fov1 := -1.0, follow := false) -> void:
	var lift := Vector3(0.0, 0.9, 0.0)
	if from0.y - stage.y < 3.0:
		from0 += lift
	if from1.y - stage.y < 3.0:
		from1 += lift
	_shots.append({"t0": t0, "t1": t1, "f0": from0, "f1": from1, "l0": look0, "l1": look1, "fov": fov, "fov1": fov if fov1 < 0.0 else fov1, "follow": follow})


func caption(t0: float, t1: float, big: String, small := "") -> void:
	at(t0, func():
		_caption.text = big
		_caption_sub.text = small
		_fade_label(_caption, 1.0, 0.35)
		_fade_label(_caption_sub, 1.0, 0.5))
	at(t1, func():
		_fade_label(_caption, 0.0, 0.35)
		_fade_label(_caption_sub, 0.0, 0.35))


func _fade_label(l: Label, a: float, secs: float) -> void:
	create_tween().tween_property(l, "modulate:a", a, secs)


func _ground(x: float, z: float) -> float:
	return MeadowTerrain.instance.height_at(x, z)


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

	# Stage: the back meadow behind the cottage, Freyja facing deeper into it.
	var g := WorldLayout.GARDEN_MEADOW
	var sx := g.x + 1.5
	var sz := g.z + 8.0
	stage = Vector3(sx, _ground(sx, sz), sz)
	yaw = PI
	p.teleport(stage + Vector3(0, 0.1, 0), yaw)
	p.model.rotation.y = yaw
	p.caster.mana = p.caster.max_mana
	p.caster.max_mana = 400.0
	p.caster.mana = 400.0
	p.caster.mana_regen = 80.0
	p.stamina = 100.0
	_script()
	set_process(true)


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
	_sub = _label(layer, int(u * 2.6), 0.55)
	_caption = _label(layer, int(u * (5.2 if not portrait else 8.0)), 0.76 if not portrait else 0.72)
	_caption_sub = _label(layer, int(u * 2.4), 0.87 if not portrait else 0.8)
	for l in [_title, _sub, _caption, _caption_sub]:
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
	# ---- Act 1: flowers (calm) --------------------------------------------------------
	at(0.0, func(): _fade_to(0.0, 1.2))
	at(0.2, func(): p.staff.summon())
	shot(0.0, 3.9, rel(2.4, 0.6, 5.8), rel(1.3, 1.0, 3.7), rel(0, 1.25, 0), rel(0, 1.4, 0), 44.0)
	at(0.9, func():
		_title.text = "Minnet efter resan"
		_sub.text = "a cozy fantasy about remembering"
		_fade_label(_title, 1.0, 0.8)
		_fade_label(_sub, 1.0, 1.1))
	at(3.4, func():
		_fade_label(_title, 0.0, 0.6)
		_fade_label(_sub, 0.0, 0.5))
	at(3.9, func():
		p.caster.equip(0)
		p._cast_with_staff())
	shot(3.9, 8.6, rel(-3.4, 0.5, 3.6), rel(3.3, 1.3, 3.1), rel(0, 1.2, 0), rel(0, 1.9, 0), 42.0, 46.0)
	caption(5.4, 9.2, "Blommor.", "for emergencies")
	shot(8.6, 12.0, rel(0.0, 1.1, 5.0), rel(0.0, 7.5, 12.0), rel(0, 1.4, 1.5), rel(0, 0.2, 7.0), 48.0, 62.0)

	# ---- Night: fade through black ------------------------------------------------------
	at(11.3, func(): _fade_to(1.0, 0.9))
	at(12.35, func(): _night_scene())
	at(12.5, func(): _fade_to(0.0, 0.9))

	# ---- Act 2: Solstråk (action) ---------------------------------------------------------
	shot(12.4, 16.2, rel(1.5, 1.0, -2.2), rel(2.2, 0.7, -1.7), rel(0, 1.5, 9.0), rel(0, 1.6, 13.0), 50.0, 54.0)
	caption(13.2, 16.6, "Solstråk", "a sunbeam, politely")
	at(13.0, func():
		p.caster.equip(1)
		p.aim_point_override = _mon["Skeleton"].global_position + Vector3(0, 1.4, 0)
		p._begin_focus_aim())
	at(14.6, func(): p.aim_charge = 1.0)
	at(14.9, func(): p._fire_charged())
	at(15.9, func(): _mon["Skeleton"].ko())

	shot(16.2, 19.6, rel(-3.4, 0.8, 1.4), rel(3.4, 1.4, 1.0), rel(0, 1.5, 9.0), rel(0, 1.8, 9.5), 52.0, 56.0)
	caption(16.5, 19.8, "Mörkstråk", "the rude one")
	at(16.4, func():
		p.aim_point_override = _mon["Slime"].global_position + Vector3(0, 1.0, 0)
		p.lock_target = _mon["Slime"])
	at(16.8, func(): p._fire_variant("volley"))
	at(17.9, func():
		p.lock_target = _mon["Bat"]
		p.aim_point_override = _mon["Bat"].global_position + Vector3(0, 1.8, 0))
	at(18.1, func(): p._fire_variant("burst"))
	at(19.0, func(): _mon["Slime"].ko())
	at(19.3, func(): p._end_focus_aim(false))

	# Barrier: the remaining two open fire.
	shot(19.6, 23.4, rel(-2.8, 0.6, -2.8), rel(-1.6, 1.2, -2.0), rel(0.0, 1.3, 3.5), rel(0.0, 1.8, 7.0), 54.0)
	caption(20.0, 23.6, "Barriär", "temporary")
	at(19.5, func():
		_mon["Bat"].beam_power = 1.0
		_mon["Bat"].auto_target = p
		_mon["Bat"]._run_attack()
		_mon["Dragon"].beam_power = 1.0
		_mon["Dragon"].auto_target = p
		_mon["Dragon"]._run_attack())
	at(20.3, func():
		p.aim_point_override = _mon["Dragon"].global_position + Vector3(0, 2.0, 0)
		p.caster.equip(2)
		Input.action_press("cast")
		p.caster.try_cast())

	# The dragon commits: the barrier gives way.
	shot(23.4, 27.0, rel(3.4, 0.7, 4.6), rel(2.4, 1.1, 3.4), rel(0, 1.3, 1.8), rel(0, 1.3, 1.8), 52.0, 46.0)
	caption(24.6, 27.2, "…very temporary.", "")
	at(23.3, func():
		var d: ZoltraakTurret = _mon["Dragon"]
		d.beam_power = 12.0
		d.beam_seconds = 3.4
		d.auto_target = p
		d._run_attack())
	at(24.2, func(): shake = 0.35)

	# ---- Counter: up, and straight down on the dragon -------------------------------------
	shot(27.0, 29.6, rel(-3.0, 0.6, 2.8), rel(-3.0, 4.5, 3.4), rel(0, 1.2, 0), rel(0, 5.5, 3.0), 55.0, 60.0, true)
	at(26.6, func():
		Input.action_release("cast")
		for b in get_tree().get_nodes_in_group("magic_barrier"):
			(b as MagicBarrier3D).release()
		shake = 0.0)
	at(27.0, func():
		_mon["Dragon"].auto_target = null
		p.start_flight()
		Input.action_press("jump"))
	at(28.4, func():
		Input.action_release("jump")
		p.caster.equip(1)
		p.aim_point_override = _mon["Dragon"].global_position + Vector3(0, 1.5, 0)
		p._begin_focus_aim())
	shot(29.6, 31.6, rel(3.4, 7.2, -2.0), rel(1.6, 5.8, 6.0), rel(0, 3.5, 10.0), rel(0, 1.6, 22.0), 56.0, 60.0)
	at(29.7, func(): p.aim_charge = 1.0)
	at(30.0, func(): p._fire_charged())
	at(30.9, func():
		_mon["Dragon"].ko()
		_flash_white(0.9))

	# ---- Act 3: flowers again (calm) ----------------------------------------------------------
	at(31.1, func(): _fade_to(1.0, 0.7))
	at(31.9, func(): _calm_night())
	at(32.2, func(): _fade_to(0.0, 1.0))
	shot(31.9, 36.5, rel(-3.4, 1.0, 4.8), rel(3.6, 1.6, 4.4), rel(0, 1.3, 0), rel(0, 1.6, 0), 46.0, 44.0)
	at(33.0, func():
		p.caster.equip(0)
		p._cast_with_staff())
	shot(36.5, 41.0, rel(0.0, 1.4, 5.5), rel(0.0, 8.5, 13.0), rel(0, 1.4, 1.5), rel(0, 0.4, 8.0), 46.0, 62.0)
	at(37.4, func():
		_title.text = "Minnet efter resan"
		_sub.text = "a cozy fantasy about remembering"
		_fade_label(_title, 1.0, 1.0)
		_fade_label(_sub, 1.0, 1.4))
	at(40.0, func(): _fade_to(1.0, 0.9))


func _fade_to(a: float, secs: float) -> void:
	create_tween().tween_property(_fade, "color:a", a, secs)


func _flash_white(secs: float) -> void:
	_flash.color.a = 0.95
	create_tween().tween_property(_flash, "color:a", 0.0, secs)


func _night_scene() -> void:
	_night = 1.0
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
	# Land if she was still airborne from the flower cast; set the monsters out.
	p.set_levitation(0.0)
	_spawn_monsters()
	p.staff.touch()


func _calm_night() -> void:
	# A softer, warmer moonlit calm after the fight.
	_env.ambient_light_color = Color(0.3, 0.34, 0.55)
	_env.ambient_light_energy = 0.9
	_sun.light_color = Color(0.75, 0.82, 1.0)
	_sun.light_energy = 0.8
	_fill.light_energy = 1.4
	if p.flying:
		p.stop_flight()
	Input.action_release("jump")
	p._end_focus_aim(false)
	p.lock_target = null
	p.teleport(stage + Vector3(0, 0.1, 0), yaw)
	p.model.rotation.y = yaw
	_fill.global_position = stage + Vector3(0, 3.2, 0)
	p.staff.touch()
	for n in _mon:
		if is_instance_valid(_mon[n]):
			(_mon[n] as Node3D).queue_free()
	_mon.clear()
	for b in get_tree().get_nodes_in_group("magic_barrier"):
		(b as MagicBarrier3D).queue_free()


func _spawn_monsters() -> void:
	var spec := {
		"Slime": [Vector3(-5.5, 0.0, 10.0), ZoltraakVisuals.Kind.WHITE, false],
		"Skeleton": [Vector3(0.0, 0.0, 13.0), ZoltraakVisuals.Kind.BLACK, false],
		"Bat": [Vector3(5.5, 0.0, 9.5), ZoltraakVisuals.Kind.BLACK, true],
		"Dragon": [Vector3(1.5, 0.0, 22.0), ZoltraakVisuals.Kind.BLACK, false],
	}
	for n in spec:
		var t := ZoltraakTurret.new()
		t.kind = spec[n][1]
		t.monster = n
		t.volley = spec[n][2]
		t.telegraph = 1.0
		t.beam_seconds = 2.2
		main.add_child(t)
		var pos := rel(spec[n][0].x, 0.0, spec[n][0].z)
		pos.y = _ground(pos.x, pos.z)
		t.global_position = pos
		_mon[n] = t
		var scale_up: float = {"Dragon": 2.2, "Skeleton": 1.3, "Slime": 1.5, "Bat": 1.5}[n]
		t._model_scale *= scale_up
		var ml := OmniLight3D.new()
		ml.light_color = Color(1.0, 0.9, 0.6) if t.kind == ZoltraakVisuals.Kind.WHITE else Color(0.7, 0.5, 1.0)
		ml.light_energy = 2.4
		ml.omni_range = 7.0
		ml.shadow_enabled = false
		ml.position = Vector3(0, 2.6, -1.5)
		t.add_child(ml)
		# Hide the debug label.
		for l in t.find_children("*", "Label3D", true, false):
			l.visible = false


# --- per frame -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var t := float(_frame) / FPS
	# Events due this frame.
	for e in _events:
		if e[0] <= t and e[0] > t - 1.0 / FPS - 0.0001:
			(e[1] as Callable).call()
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
	# Slow motion around the barrier failure.
	_frame += 1
	if _frame >= int(TOTAL * FPS):
		get_tree().quit()
