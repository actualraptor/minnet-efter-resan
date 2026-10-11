class_name ZoltraakTurret
extends StaticBody3D
## A hostile Zoltraak emitter (team 1): the practice range's "shooter". It fires
## the same bolts and beams as the player, in either visual family; barriers of
## team 0 stop them and solid things take the hit. With `auto_target` set it
## runs a loop: a seal forms facing the target (the telegraph), then a straight
## beam or a volley is loosed along the line that was locked when the telegraph
## ended, so you can step behind a barrier and watch it hold.

var kind := ZoltraakVisuals.Kind.WHITE
var team := 1
## Node the turret hunts (usually the player); null = manual only.
var auto_target: Node3D
var interval := 8.0
var telegraph := 1.3
var beam_seconds := 2.4
var volley := false
var max_range := 55.0
var _beams: Array[ZoltraakBeam] = []
var _clock := 0.0
var _busy := false
var _eye: MeshInstance3D
var _monster: Node3D
var _anim: AnimationPlayer
var _model_scale := 1.0
## Which monster wears this turret: "Slime" (sun-yellow, Solstråk), "Skeleton"
## (Mörkstråk), "Bat" (volleys), "Dragon" (the big one).
var monster := ""
var _pulse := 0.0


func _ready() -> void:
	add_to_group("zoltraak_target")
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.4
	cs.shape = shape
	cs.position = Vector3(0, 1.2, 0)
	add_child(cs)
	var white := kind == ZoltraakVisuals.Kind.WHITE
	_build_monster(white)
	var lbl := Label3D.new()
	lbl.text = ("Mörkstråk" if not white else "Solstråk") + " " + (monster if monster != "" else ("Slime" if white else "Skeleton")).to_lower()
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.85, 0.8, 1.0) if not white else Color(0.9, 0.95, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 3.4, 0)
	lbl.no_depth_test = true
	add_child(lbl)


func _build_monster(white: bool) -> void:
	var name := monster if monster != "" else ("Slime" if white else "Skeleton")
	var path := "res://assets/models/monsters/%s.glb" % name
	if not ResourceLoader.exists(path):
		return
	_monster = (load(path) as PackedScene).instantiate()
	add_child(_monster)
	_model_scale = {"Slime": 1.1, "Skeleton": 0.85, "Bat": 1.2, "Dragon": 1.0}.get(name, 1.4)
	_monster.scale = Vector3.ONE * _model_scale
	if name == "Bat" or name == "Dragon":
		_monster.position = Vector3(0, 1.6, 0)
	# Tint so the two families read apart: warm sun-yellow vs. dusk violet.
	var tint := Color(1.15, 1.0, 0.55) if white else Color(0.62, 0.5, 0.95)
	for mi in _monster.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			if src is BaseMaterial3D:
				var dup := src.duplicate() as BaseMaterial3D
				if name == "Slime":
					dup.albedo_color = Color(1.0, 0.82, 0.3) if white else Color(0.45, 0.3, 0.9)   # sun-gold (or dusk) jelly
				else:
					dup.albedo_color = (dup.albedo_color * tint).clamp(Color(0, 0, 0), Color(2, 2, 2))
				dup.roughness = 0.8
				m.set_surface_override_material(s, dup)
	_anim = _monster.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle")


func _play(base: String) -> void:
	if _anim == null:
		return
	for n in _anim.get_animation_list():
		var low := String(n).to_lower()
		if low.ends_with(base.to_lower()) or low.contains("_" + base.to_lower()):
			if _anim.current_animation != n:
				_anim.play(n, 0.15)
				var anim := _anim.get_animation(n)
				if anim and base == "Idle":
					anim.loop_mode = Animation.LOOP_LINEAR
			return
	# Fall back to anything that moves (the bat and dragon only have "Flying").
	if base == "Idle":
		for n in _anim.get_animation_list():
			if String(n).to_lower().contains("fly") or String(n).to_lower().contains("walk"):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
				if _anim.current_animation != n:
					_anim.play(n, 0.15)
				return


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.8 * _model_scale + 0.3, 0) if _monster else global_position + Vector3(0, 2.45, 0)


func _process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	if _monster != null:
		_monster.scale = Vector3.ONE * _model_scale * (1.0 + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * 2.0) + _pulse * 0.12)
		# Always turn to face what it is hunting.
		if auto_target != null and is_instance_valid(auto_target):
			var to := auto_target.global_position - global_position
			_monster.rotation.y = lerp_angle(_monster.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	elif _eye != null:
		_eye.scale = Vector3.ONE * (1.0 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 2.0) + _pulse * 0.6)
	if auto_target == null or not is_instance_valid(auto_target) or _busy:
		return
	_clock += delta
	if _clock < interval:
		return
	if global_position.distance_to(auto_target.global_position) > max_range:
		_clock = interval - 1.0
		return
	_clock = 0.0
	_run_attack()


func _run_attack() -> void:
	_busy = true
	var aim_at := auto_target.global_position + Vector3(0, 1.1, 0)
	# Telegraph: a seal swells at the muzzle facing the target.
	var st := SealStack.new()
	add_child(st)
	st.top_level = true
	st.build(2, 0.45, 0.6, kind)
	var dir := (aim_at - muzzle()).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	st.global_transform = Transform3D(Basis.looking_at(-dir, up), muzzle())
	st.set_charge(0.9)
	st.assemble(0.05)
	var elapsed := 0.0
	while elapsed < telegraph:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		_pulse = 0.5 + elapsed / telegraph
		_play("Attack")
	# The line is fixed now: she can step out of it or put a barrier in it.
	aim_at = auto_target.global_position + Vector3(0, 1.1, 0)
	if volley:
		await fire_volley(aim_at, 5)
	else:
		fire_beam(aim_at, beam_seconds, 0.2)
		await get_tree().create_timer(beam_seconds + 0.2).timeout
	st.retract()
	get_tree().create_timer(0.6).timeout.connect(st.queue_free)
	_play("Idle")
	_busy = false


func fire_bolt(at: Vector3, speed := 45.0, size := 1.0) -> ZoltraakBolt:
	var dir := (at - muzzle()).normalized()
	return ZoltraakShots.spawn_bolt(get_parent(), self, muzzle(), dir, speed, size, kind, team)


func fire_volley(at: Vector3, count := 4) -> void:
	for i in count:
		var spread := Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))
		var dir := (at + spread - muzzle()).normalized()
		ZoltraakShots.spawn_bolt(get_parent(), self, muzzle(), dir, 40.0, 0.9, kind, team)
		await get_tree().create_timer(0.12).timeout


## A beam toward a fixed world point for `seconds`.
func fire_beam(at: Vector3, seconds := 2.0, radius := 0.22) -> ZoltraakBeam:
	var b := ZoltraakBeam.new()
	b.kind = kind
	b.team = team
	b.mode = ZoltraakBeam.Mode.SUSTAINED
	b.base_radius = radius
	b.seals = 2
	b.seal_radius = 0.7
	b.power = 1.0
	b.reach = 70.0
	b.exclude.append(get_rid())
	var src := self
	var dir := (at - muzzle()).normalized()
	b.aim_fn = func() -> Array:
		return [src.muzzle(), dir]
	get_parent().add_child(b)
	b.setup()
	_beams.append(b)
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(b):
			b.release())
	return b


func zoltraak_hit(_damage: float, _dir: Vector3) -> void:
	_pulse = 1.0
