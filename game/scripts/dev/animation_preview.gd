extends Node3D
## Development animation preview: Freyja on an empty stage with an orbit camera
## and a panel to trigger every staff/spell performance, pause, slow down and
## read the grip diagnostics. Not part of the game build flow.
##   godot --path game res://scenes/animation_preview.tscn
## Mouse: right-drag orbits, wheel zooms, middle-drag pans height. Arrows orbit.

const PLAYER_SCENE := "res://scenes/player.tscn"

var player: Player
var world: Node3D
var cam: Camera3D
var target_pillar: MeshInstance3D
var _yaw := PI + 0.5
var _pitch := -0.12
var _dist := 3.6
var _height := 1.15
var _panel: PanelContainer
var _readout: Label
var _hold_cast := false
var _aim_target := true
var _speed_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()
	_build_ui()
	if OS.get_environment("PREVIEW_AUTO") != "":
		_auto(OS.get_environment("PREVIEW_AUTO"))


# --- stage ----------------------------------------------------------------------------

func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	ground.add_child(cs)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.46, 0.56, 0.42)
	pm.material = gm
	plane.mesh = pm
	ground.add_child(plane)
	world.add_child(ground)
	# One-metre grid lines so reach and distances can be judged by eye.
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10, 11):
		im.surface_add_vertex(Vector3(i, 0.01, -10))
		im.surface_add_vertex(Vector3(i, 0.01, 10))
		im.surface_add_vertex(Vector3(-10, 0.01, i))
		im.surface_add_vertex(Vector3(10, 0.01, i))
	im.surface_end()
	grid.mesh = im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.18)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = lm
	world.add_child(grid)

	# A target pillar for beams to hit, 12 m ahead of her (+Z).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var bcs := CollisionShape3D.new()
	var bshape := CylinderShape3D.new()
	bshape.radius = 0.6
	bshape.height = 4.0
	bcs.shape = bshape
	body.add_child(bcs)
	target_pillar = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 4.0
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.75, 0.55, 0.45)
	cm.material = tm
	target_pillar.mesh = cm
	body.add_child(target_pillar)
	body.position = Vector3(0, 2.0, 12)
	world.add_child(body)

	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	player.model.rotation.y = 0.0

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()


# --- ui -------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_panel.add_child(v)
	_header(v, "Freyja animation preview")

	_header(v, "Staff")
	_row(v, [["Summon", _summon], ["Stow", func(): if player.staff: player.staff.stow()]])
	_header(v, "Spells (need the staff out)")
	_row(v, [["Zoltraak", func(): _cast(1)], ["x3 chain", _chain], ["Flowers", func(): _cast(0)]])
	_row(v, [["Barrier", _barrier], ["Hit", _barrier_hit], ["Release", _release], ["Interrupt", func(): player.interrupt_cast()]])
	var aim := CheckBox.new()
	aim.text = "Aim at target pillar"
	aim.button_pressed = true
	aim.toggled.connect(func(on): _aim_target = on)
	v.add_child(aim)

	_header(v, "Movement")
	_row(v, [["Fly", func(): player.toggle_flight()], ["Hover idle", func(): player.set_hover(not player.hover_idle)]])
	_row(v, [["Refill stamina", func(): player.stamina = player.max_stamina], ["Face front", func(): player.model.rotation.y = 0.0]])
	var hint := Label.new()
	hint.text = "WASD move, Shift fast, Space up, Ctrl down"
	hint.add_theme_font_size_override("font_size", 11)
	v.add_child(hint)

	_header(v, "Face")
	_row(v, [["neutral", func(): _face("neutral")], ["focused", func(): _face("focused")], ["serene", func(): _face("serene")], ["alert", func(): _face("alert")], ["happy", func(): _face("happy")]])

	_header(v, "Playback")
	var pause := CheckBox.new()
	pause.text = "Pause"
	pause.toggled.connect(func(on): get_tree().paused = on)
	v.add_child(pause)
	_speed_label = Label.new()
	_speed_label.text = "Speed 1.00x"
	v.add_child(_speed_label)
	var sl := HSlider.new()
	sl.min_value = 0.05
	sl.max_value = 2.0
	sl.step = 0.05
	sl.value = 1.0
	sl.custom_minimum_size = Vector2(240, 18)
	sl.value_changed.connect(func(val):
		Engine.time_scale = val
		_speed_label.text = "Speed %.2fx" % val)
	v.add_child(sl)
	_row(v, [["Front", func(): _yaw = PI], ["Side", func(): _yaw = PI * 0.5], ["Back", func(): _yaw = 0.0], ["3/4", func(): _yaw = PI + 0.7]])

	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 12)
	v.add_child(_readout)


func _header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	parent.add_child(l)


func _row(parent: Control, items: Array) -> void:
	var h := HBoxContainer.new()
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(it[1])
		h.add_child(b)
	parent.add_child(h)


# --- actions --------------------------------------------------------------------------

func _summon() -> void:
	if player.staff and not player.staff.out and not player.staff.busy:
		player.staff.summon()


func _cast(index: int) -> void:
	player.caster.mana = player.caster.max_mana
	player.caster.equip(index)
	await player._cast_with_staff()


func _chain() -> void:
	for i in 3:
		player.caster.mana = player.caster.max_mana
		player.caster.equip(1)
		var r := player.caster.try_cast()
		var guard := 0.0
		while r != "" and guard < 3.0:
			await get_tree().create_timer(0.05).timeout
			guard += 0.05
			r = player.caster.try_cast()
		await get_tree().create_timer(0.35).timeout


func _barrier() -> void:
	player.caster.mana = player.caster.max_mana
	player.caster.equip(2)
	_hold_cast = true
	Input.action_press("cast")
	await player._cast_with_staff()


func _release() -> void:
	_hold_cast = false
	Input.action_release("cast")


func _barrier_hit() -> void:
	player.caster.barrier_hit(player.global_position + player.model.global_basis * Vector3(0.3, 1.2, 1.8))


func _face(expr: String) -> void:
	if player.face:
		player.face.set_expression(expr, 4.0)


# --- per frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _aim_target and is_instance_valid(player):
		player.aim_point_override = target_pillar.global_position + Vector3(0, 0.0, 0)
	else:
		player.aim_point_override = Vector3.INF
	var pivot := player.global_position + Vector3(0, _height + player.hover_height(), 0)
	var rot := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	cam.global_position = pivot + rot * Vector3(0, 0, _dist)
	cam.look_at(pivot, Vector3.UP)
	var look := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_yaw -= look.x * delta * 1.6
	_pitch = clampf(_pitch - look.y * delta, -1.2, 0.8)
	var r := player.staff_rig
	var g := player.staff_grip
	var t := "fps %d  stamina %.0f  %s\n" % [Engine.get_frames_per_second(), player.stamina, "flying" if player.flying else "grounded"]
	if r:
		t += "rig weight %.2f  clip %s  reach R %.3f L %.3f" % [r.weight, r.clip.name if r.clip else "-", g.reach_error["R"] if g else 0.0, g.reach_error["L"] if g else 0.0]
	_readout.text = t


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw -= mm.relative.x * 0.006
			_pitch = clampf(_pitch - mm.relative.y * 0.006, -1.2, 0.8)
		elif mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_height = clampf(_height + mm.relative.y * 0.004, 0.2, 2.2)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.7)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist / 0.9, 12.0)


## Unattended smoke run (PREVIEW_AUTO=<png path>): summon, Zoltraak, screenshot, quit.
func _auto(out_path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	await player.staff.summon()
	await get_tree().create_timer(0.8).timeout
	_yaw = PI + 0.9
	_dist = 2.8
	player.caster.mana = player.caster.max_mana
	player.caster.equip(1)
	player.caster.try_cast()
	await get_tree().create_timer(0.62).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("PREVIEW ok rig_weight=%.2f" % player.staff_rig.weight)
	get_tree().quit()
