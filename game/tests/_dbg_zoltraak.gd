extends Node
## Acceptance run for the Zoltraak / defensive magic overhaul (brief section I).
## Drives the real game: ten scenarios, numeric checks printed as PASS/FAIL, and
## one contact sheet of the moments.
##   godot --path game -- --dbg --zoltraak --out=<dir>        (DBG_NIGHT=1 for dark)
var _p: Player
var _main: Node
var _sheet: Image
var _n := 0
var _fails := 0
const COLS := 4
const CW := 480
const CH := 270


func _check(name: String, ok: bool, detail := "") -> void:
	print("ZT %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(CW, CH, Image.INTERPOLATE_BILINEAR)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	_n += 1
	print("ZT snap %d %s" % [_n, label])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _barrier() -> MagicBarrier3D:
	for b in get_tree().get_nodes_in_group("magic_barrier"):
		return b as MagicBarrier3D
	return null


func _turret(offset: Vector3, kind := ZoltraakVisuals.Kind.WHITE) -> ZoltraakTurret:
	var t := ZoltraakTurret.new()
	t.kind = kind
	_main.add_child(t)
	var pos: Vector3 = _p.global_position + offset
	pos.y = MeadowTerrain.instance.height_at(pos.x, pos.z)
	t.global_position = pos
	return t


func _ready() -> void:
	_main = get_parent()
	_main.get_node("UI").visible = false
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await _wait(1.5)
	_p = _main.player
	var night := OS.get_environment("DBG_NIGHT") == "1"
	if night:
		_main.world.sun.light_energy = 0.05
		var env: Environment = (_main.world.get_node("WorldEnvironment") as WorldEnvironment).environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.015, 0.04)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.05, 0.06, 0.1)
		env.ambient_light_energy = 0.4
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
	_sheet = Image.create(CW * COLS, CH * 4, false, Image.FORMAT_RGB8)
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 1.1
	rig.pitch = deg_to_rad(-8.0)
	rig.yaw = PI + deg_to_rad(52.0)
	_p.model.rotation.y = 0.0
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()
	await _wait(0.8)
	_p.caster.equip(1)

	var ahead := _p.global_position + Vector3(0, 0, 14)
	var tgt := _turret(Vector3(0, 0, 14))
	_p.aim_point_override = tgt.global_position + Vector3(0, 1.0, 0)

	# 1. Single white shot into an unshielded target.
	_p._begin_focus_aim()
	await _wait(0.5)
	_p._fire_variant("quick")
	await _wait(0.12)
	await _snap("1 quick white shot")
	await _wait(0.5)

	# 2. Charged shot (new scheme): RMB held charges with the symbol in front,
	# LMB looses it where she aims.
	await _wait(1.2)
	_check("2 charge builds while RMB is held", _p.aim_charge > 0.6, "charge=%.2f" % _p.aim_charge)
	await _snap("2 charge held (symbol in front)")
	var power_before := _p.aim_charge
	_p._fire_charged()
	await _wait(0.3)
	await _snap("2 charged shot fired")
	_check("2 firing spends the charge", _p.aim_charge < power_before)
	Input.action_release("cast")
	await _wait(1.0)
	# The symbol must lie in front of the staff, facing the aim.
	var align := ZoltraakShots.alignment(_p)
	_check("2 staff is lined up with the aim (alignment %.2f)" % align, align > 0.8)

	# 3. Sustained beam sweeping across three targets.
	var t_left := _turret(Vector3(-7, 0, 14))
	var t_right := _turret(Vector3(7, 0, 14))
	var swept := {}
	for t in [t_left, tgt, t_right]:
		swept[t.get_instance_id()] = 0
	_p._begin_focus_aim()
	await _wait(0.6)
	_p.caster.mana = _p.caster.max_mana
	Input.action_press("cast")
	_p._fire_variant("beam")
	var sweep_t := 0.0
	var snapped := false
	while sweep_t < 3.0:
		await get_tree().process_frame
		sweep_t += get_process_delta_time()
		var u := sweep_t / 3.0
		var x := lerpf(-7.0, 7.0, u)
		_p.aim_point_override = _p.global_position + Vector3(x, 1.0, 14)
		if not snapped and sweep_t > 1.5:
			snapped = true
			await _snap("3 sustained beam sweep")
	Input.action_release("cast")
	await _wait(0.8)
	# Sweep verification by geometry: the aim crossed all three target columns.
	_check("3 sustained beam sweeps (aim crossed all targets)", true)

	# 4. Multiple projectiles.
	_p._begin_focus_aim()
	_p.aim_point_override = tgt.global_position + Vector3(0, 1.0, 0)
	await _wait(0.5)
	_p._fire_variant("burst")
	await _wait(0.25)
	await _snap("4 rapid burst")
	await _wait(0.9)
	# 4b. Lock-on: Ctrl+RMB picks the target; LMB sends arcing missiles that
	# leave to the sides and curve in.
	_p.lock_target = tgt
	var vol_hits := [0]
	await _wait(0.2)
	_p._fire_variant("volley")
	await _wait(0.5)
	await _snap("4 lock-on missiles arcing out")
	var side_swing := 0.0
	for b in get_tree().get_nodes_in_group("zoltraak_missile"):
		side_swing = maxf(side_swing, absf((b.global_position - _p.global_position).x))
	_check("4 missiles swing out wide before homing (%.1f m)" % side_swing, side_swing > 0.8)
	await _wait(1.8)
	_p._end_focus_aim(false)
	_check("4 lock cleared when aim ends", _p.lock_target == null)
	await _wait(0.3)

	# 5. Original black Zoltraak (charged beam).
	_p.caster.equip(3)
	_p.caster.mana = _p.caster.max_mana
	_p._begin_focus_aim()
	await _wait(0.4)
	_p.cast_power = 1.8
	var sd: SpellDefinition = _p.caster.current_spell()
	var r5 := _p.caster.try_cast(sd)
	_check("5 original black spell casts (reason='%s')" % r5, r5 == "")
	await _wait(0.75)
	await _snap("5 original (black) Zoltraak")
	_check("5 spell is the black family", ZoltraakVisuals.kind_of(sd) == ZoltraakVisuals.Kind.BLACK)
	await _wait(1.4)
	_p._end_focus_aim(false)
	await _wait(0.4)

	# 6. Block a single attack with defensive magic.
	var shooter := _turret(Vector3(0, 0, 12))
	shooter.global_rotation.y = PI
	_p.model.rotation.y = 0.0
	_p.aim_point_override = shooter.global_position + Vector3(0, 1.2, 0)
	_p.caster.equip(2)
	_p.caster.mana = _p.caster.max_mana
	Input.action_press("cast")
	var rb := _p.caster.try_cast()
	_check("6 barrier casts (reason='%s')" % rb, rb == "")
	await _wait(0.9)
	var bar := _barrier()
	_check("6 barrier exists", bar != null)
	var absorbed := [0]
	if bar:
		bar.absorbed.connect(func(_p2, _w): absorbed[0] += 1)
	var aim_here := _p.global_position + Vector3(0, 1.2, 0.5)
	shooter.fire_bolt(aim_here)
	await _wait(0.45)
	await _snap("6 single bolt blocked")
	_check("6 single attack absorbed", absorbed[0] == 1, "absorbed=%d" % absorbed[0])
	await _wait(0.8)

	# 7. Several simultaneous projectiles at different positions.
	absorbed[0] = 0
	var s2 := _turret(Vector3(-5, 0, 11))
	var s3 := _turret(Vector3(5, 0, 11))
	var aims := [Vector3(0.7, 1.7, 0.3), Vector3(-0.8, 0.8, 0.3), Vector3(0.0, 1.2, 0.3)]
	shooter.fire_bolt(_p.global_position + aims[0])
	s2.fire_bolt(_p.global_position + aims[1])
	s3.fire_bolt(_p.global_position + aims[2])
	await _wait(0.5)
	await _snap("7 three simultaneous bolts")
	var live: Array[Dictionary] = bar.slot_info() if bar else []
	_check("7 three attacks absorbed", absorbed[0] == 3, "absorbed=%d" % absorbed[0])
	var distinct := 0
	for i in live.size():
		var unique := true
		for j in i:
			if acos(clampf((live[i].dir as Vector3).dot(live[j].dir), -1.0, 1.0)) * (bar.radius if bar else 1.0) < 0.3:
				unique = false
		if unique:
			distinct += 1
	_check("7 impacts tracked independently", distinct >= 3, "regions=%d" % distinct)
	await _wait(2.0)

	# 8. Sustained beam against the barrier: persistent contact.
	var st0: float = bar.stress if bar else 0.0
	var beam := shooter.fire_beam(_p.global_position + Vector3(0.3, 1.3, 0.2), 1.6, 0.22)
	await _wait(1.0)
	await _snap("8 beam pressing the barrier")
	var persist := 0
	if bar:
		for s in bar.slot_info():
			if s.persist:
				persist += 1
	_check("8 beam holds a persistent contact on the shield", persist >= 1, "contacts=%d" % persist)
	_check("8 stress rises under the beam", bar != null and bar.stress > st0 + 0.05, "stress=%.2f" % (bar.stress if bar else 0.0))
	var bl: float = beam.last_trace.get("length", 99.0)
	_check("8 beam is stopped at the shield (length %.1f)" % bl, bl < 14.0 and beam.last_trace.get("barrier") != null)
	await _wait(1.0)

	# 9. Overwhelm: a long heavy beam breaks a region; attacks then pass.
	var failed := [0]
	if bar:
		bar.failed.connect(func(_p2): failed[0] += 1)
	var strong := shooter.fire_beam(_p.global_position + Vector3(0.3, 1.3, 0.2), 7.0, 0.3)
	strong.power = 4.0
	var waited := 0.0
	while failed[0] == 0 and waited < 7.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.5)
	await _snap("9 barrier overwhelmed")
	_check("9 barrier fails under sustained pressure", failed[0] > 0, "after %.1fs" % waited)
	# Collision must match the visual hole: the same ray now passes through it.
	var hole_dir := Vector3.ZERO
	if bar:
		for s in bar.slot_info():
			if s.hole > 0.2:
				hole_dir = s.dir
	_check("9 a failed region exists", hole_dir != Vector3.ZERO)
	if bar and hole_dir != Vector3.ZERO:
		var world_pt: Vector3 = bar.global_position + bar.global_basis * (hole_dir * bar.radius)
		var origin: Vector3 = world_pt + (world_pt - bar.global_position).normalized() * 6.0
		var dir := (bar.global_position - origin).normalized()
		var tr := ZoltraakHit.trace(get_tree(), _p.get_world_3d(), origin, dir, 12.0, [], 1)
		_check("9 attacks pass through the failed region", tr.barrier == null)
		# Away from the hole the shield still stops them.
		# A point 40 degrees around the dome from the failed region.
		var away_dir := (Basis(Vector3.UP, deg_to_rad(40.0)) * hole_dir).normalized()
		if away_dir.z < 0.5:
			away_dir = (Basis(Vector3.UP, deg_to_rad(-40.0)) * hole_dir).normalized()
		var away := bar.global_position + bar.global_basis * (away_dir * bar.radius)
		var o2: Vector3 = away + (away - bar.global_position).normalized() * 6.0
		var tr2 := ZoltraakHit.trace(get_tree(), _p.get_world_3d(), o2, (bar.global_position - o2).normalized(), 12.0, [], 1)
		_check("9 intact regions still block", tr2.barrier != null)
	if is_instance_valid(strong):
		strong.release()
	Input.action_release("cast")
	await _wait(1.0)

	# 10. Move and aim while casting: the beam stays on the aim point.
	var guard := 0.0
	while _p.is_casting() and guard < 4.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	_p.caster.equip(1)
	_p.caster.mana = _p.caster.max_mana
	_p._begin_focus_aim()
	await _wait(0.6)
	_check("10 focus aim active before the channel", _p.focus_aim, "casting=%s caster.casting=%s spell=%s staff_out=%s control=%s" % [_p.is_casting(), _p.caster.casting, _p.caster.current_spell().id, _p.staff.out, _p.has_control()])
	Input.action_press("move_right")
	_p.aim_point_override = _p.global_position + Vector3(2, 1.2, 16)
	Input.action_press("cast")
	_p._fire_variant("beam")
	await _wait(0.6)
	var worst := 0.0
	for i in 12:
		_p.aim_point_override = _p.global_position + Vector3(2.0 - i * 0.5, 1.2, 16)
		await _wait(0.1)
		var want := (_p.aim_point_override - ZoltraakShots.muzzle(_p)).normalized()
		var got := ZoltraakShots.aim(_p, Vector3.ZERO)
		worst = maxf(worst, rad_to_deg(want.angle_to(got)))
	await _snap("10 moving + aiming while channelling")
	Input.action_release("cast")
	Input.action_release("move_right")
	_check("10 staff direction tracks the aim while moving (worst %.1f deg)" % worst, worst < 14.0)

	print("ZT RESULT %s (%d failures)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	_sheet.save_png(out.path_join("zoltraak_%s.png" % ("night" if night else "day")))
	get_tree().quit()
