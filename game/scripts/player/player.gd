class_name Player
extends CharacterBody3D
## Third-person mage controller: camera-relative movement, walk/run/jump,
## interaction focus, and the caster interface used by SpellCaster.

signal focus_changed(target: Node)
signal stamina_changed(stamina: float, max_stamina: float)
signal flight_changed(flying: bool)
signal aim_changed(on: bool)

const MIN_TAKEOFF_STAMINA := 12.0
const EXHAUSTED_RECOVER := 35.0
const EXHAUSTED_FALL_SPEED := 3.0
const FLY_CEILING := 60.0

@export var walk_speed := 1.45
@export var run_speed := 4.3
## Human-like ground acceleration / braking (m/s^2).
@export var acceleration := 7.5
@export var deceleration := 10.0
@export var air_acceleration := 3.5
@export var jump_velocity := 4.9
@export var gravity := 15.0
@export var turn_speed := 11.0
@export var interact_range := 2.6
@export_group("Flight")
@export var fly_speed := 4.2
@export var fly_boost_speed := 8.0
@export var fly_climb_speed := 3.4
@export var fly_acceleration := 4.5
@export var fly_deceleration := 3.5
@export var max_stamina := 100.0
@export var stamina_regen := 20.0

@onready var model: Node3D = $Model
@onready var caster: SpellCaster = $SpellCaster
var camera_rig: CameraRig

var input_locks := 0
var focus: Node = null
var _anim: AnimationPlayer
var _current_anim := ""
var _casting := false
var _cast_anim: StringName = &"Cast"
var _indoors := 0
var _coyote := 0.0
var _jump_buffer := 0.0
var _step_accum := 0.0
var _staff_tip: Node3D
var _was_on_floor := true
var _meshes: Array[GeometryInstance3D] = []
var face: FaceController
var secondary: SpringBoneSimulator3D
var _fade := 0.0
var loco: LocomotionAnimator
var staff: StaffSummon
var _look_mod: LookAtModifier3D
var _neck_mod: LookAtModifier3D
var _fly_clip_on := false
var _prop_t := 0.0
signal thrust_pulse(strength: float)
var gait_polish: GaitPolish
var grounder: FootGrounder
var hands: HandPoser
var staff_rig: StaffRig
var staff_grip: StaffGrip
var hover_pose: HoverPose
var hover_idle := false               # dev: visual-only hover (gameplay stays grounded)
var flying := false
var stamina := 100.0
var _exhausted := false
var _exhausted_fall := false
var _fly_t := 0.0
var _fly_blend := 0.0
var _stamina_rest := 0.0
var _stamina_emit := 0.0
var _last_jump_press := -10.0
var _flight_hint_shown := false
var _flight_pitch := 0.0
## Strength of the airflow on hair/cloth springs while flying (dev: 0 = off).
var airflow_scale := 1.0
var _lift_spell := 0.0
var _lift_idle_goal := 0.0
var _aim_active := false
var _aim_yaw := 0.0
var _aim_offset := 0.0
var _aim_marker: Node3D
## Dev/preview: aim here instead of at the camera crosshair (Vector3.INF = off).
var aim_point_override := Vector3.INF
var _cast_move := 0.0
## Soft world boundary (metres from the origin); scenes set their own.
var play_radius := WorldLayout.PLAY_RADIUS
var _cast_gen := 0
## Zoltraak focus aim (hold RMB): staff raised, circle held, shots fire over it.
var focus_aim := false
var aim_charge := 0.0              # 0..1 over AIM_CHARGE_TIME while RMB is held
var aim_blend := 0.0               # smoothed 0..1, drives camera, circle and reticle
var _aim_fx: AimFx
var _cast_hold := 0.0
## Charge multiplier for the next charged Zoltraak (1 = uncharged); read and
## reset by the effect.
var cast_power := 1.0
var _heavy_ready_sfx := false
var _combat_goal := 0.0
var _variants := {}
const AIM_CHARGE_TIME := 1.5
const AIM_MOVE_SCALE := 0.4
var _lift := 0.0               # current levitation height (m)
var _lift_goal := 0.0
var _lift_t := 0.0
var _lift_motes: GPUParticles3D
var _look_point: Node3D
var _look_node: Node3D = null
var _look_offset := Vector3.ZERO
var _talking := false
var _lean := 0.0
var _prev_yaw := 0.0
var _prev_speed := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	_anim = CharacterVisual.find_animation_player(model)
	_staff_tip = model.find_child("StaffTip", true, false) as Node3D
	var humanoid := CharacterVisual.use_humanoid_library(model)
	CharacterVisual.prepare(model)
	for n in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(n)
	face = FaceController.new()
	face.name = "Face"
	add_child(face)
	face.setup(model, "freyja")
	_build_lift_motes()
	secondary = CharacterPhysics.setup(model)
	_setup_look_at()
	_setup_grounding()
	_setup_staff_rig()
	_setup_gait_polish()
	_aim_fx = AimFx.new()
	_aim_fx.name = "AimFx"
	add_child(_aim_fx)
	_aim_fx.setup(self)
	var flight_fx := FlightFx.new()
	flight_fx.name = "FlightFx"
	add_child(flight_fx)
	flight_fx.setup(self)
	if _anim and _anim.has_animation(&"Walk") and _anim.has_animation(&"Run"):
		loco = LocomotionAnimator.new()
		loco.setup(_anim, "freyja_ual" if humanoid else "freyja")
		if humanoid:
			run_speed = 3.4   # the library's jog; a calm mage doesn't sprint
		staff = StaffSummon.new()
		staff.name = "Staff"
		add_child(staff)
		if not staff.setup(self, model, loco):
			staff.queue_free()
			staff = null
	if caster.spells.is_empty():
		for sp in ["field_of_flowers", "zoltraak", "barrier", "zoltraak_original"]:
			var path := "res://data/spells/%s.tres" % sp
			if ResourceLoader.exists(path):
				caster.spells.append(load(path) as SpellDefinition)
		caster.equip(0)


## Staff performance rig (humanoid skeletons only): authored staff transform,
## two-handed IK and hover legs. Modifier order: grounder, hands, grip/hover,
## then look-at, so the torso posture is in place before the head turns.
func _setup_staff_rig() -> void:
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	if skel.find_bone("RightUpperArm") < 0 or skel.find_bone("LeftUpperLeg") < 0:
		return
	var rig := StaffRig.new()
	rig.name = "StaffRig"
	add_child(rig)
	rig.setup(skel, model)
	var grip := StaffGrip.new()
	grip.name = "StaffGrip"
	skel.add_child(grip)
	if not grip.setup(rig):
		grip.queue_free()
		rig.queue_free()
		return
	var hv := HoverPose.new()
	hv.name = "HoverPose"
	skel.add_child(hv)
	if not hv.setup():
		hv.queue_free()
		hv = null
	# Hover legs sit after the foot grounder/hand poser, the arm solver after both.
	if hv:
		skel.move_child(hv, 2)
	skel.move_child(grip, 3 if hv else 2)
	staff_rig = rig
	staff_grip = grip
	hover_pose = hv
	_aim_marker = Node3D.new()
	_aim_marker.name = "AimPoint"
	_aim_marker.top_level = true
	add_child(_aim_marker)


## Begin a staff spell: the rig takes over the staff and both arms for the
## duration. Falls back to the library gesture when there is no rig or clip.
## Returns the seconds until the release moment.
func begin_staff_cast(spell: SpellDefinition) -> float:
	var clip := StaffPoses.get_clip(spell.staff_pose)
	if staff_rig == null or clip == null:
		begin_cast(spell.cast_animation, spell.cast_time + spell.recovery_time)
		if spell.levitate_height > 0.0:
			set_levitation(spell.levitate_height)
		return spell.cast_time
	_casting = true
	_cast_gen += 1
	_cast_move = spell.move_scale
	var wind_up := staff_rig.play(clip, spell.cast_time, spell.recovery_time, spell.sustained)
	if spell.levitate_height > 0.0:
		set_levitation(spell.levitate_height)
	_aim_active = spell.aim or clip.aims
	_aim_offset = deg_to_rad(clip.aim_yaw_deg)
	if _aim_active:
		_update_aim()
		set_look_target(_aim_marker)
	if staff:
		staff.touch()
	return wind_up


## Sustained spells (barrier): let go and play the recovery.
func end_staff_hold() -> void:
	if staff_rig:
		staff_rig.release_hold()


## Cancels whatever is being cast; the rig eases out and control returns.
func interrupt_cast() -> void:
	if focus_aim:
		_end_focus_aim(false)
	if not _casting:
		return
	if staff_rig:
		staff_rig.cancel()
	_aim_active = false
	_casting = false
	_cast_gen += 1
	set_look_target(null)
	set_levitation(0.0)
	caster.interrupt()


## The barrier took a hit coming from `from_dir` (world, pointing at her): the
## staff hand is shoved back a little and the shoulders rock.
func barrier_impact(from_dir: Vector3) -> void:
	if staff_rig == null:
		return
	var local := model.global_basis.inverse() * (-from_dir)
	staff_rig.kick(Vector3(local.x, 0.0, local.z).normalized() * 0.5)


## World direction the staff head points (the spell's aim).
func staff_direction() -> Vector3:
	if staff_rig and staff_rig.is_active():
		return staff_rig.shaft_up
	return model.global_basis.z


## The point under the camera crosshair (ray up to 40 m) and the yaw toward it.
func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _aim_marker == null:
		return
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3 = hit.position if not hit.is_empty() else from + dir * 40.0
	if aim_point_override.is_finite():
		p = aim_point_override
	# Measure from the staff head so the beam, not her chest, hits the point.
	var from_pt := staff_tip() if staff_rig and staff_rig.is_active() else global_position + Vector3(0.0, 1.3, 0.0)
	var flat := Vector3(p.x - from_pt.x, 0.0, p.z - from_pt.z)
	if flat.length() < 1.5:
		# Too close to read as a direction: aim where the camera faces.
		var f := Vector3(dir.x, 0.0, dir.z).normalized()
		p = from_pt + f * 6.0 + Vector3(0.0, dir.y * 6.0, 0.0)
		flat = f * 6.0
	_aim_marker.global_position = p
	_aim_yaw = atan2(flat.x, flat.z)
	if staff_rig:
		staff_rig.aim_elevation = atan2(p.y - from_pt.y, flat.length())


## Procedural finishing layer for the walk/run (pelvic tilt, torso carry, level
## head, breath). First in the modifier stack, so the foot grounder runs after it.
func _setup_gait_polish() -> void:
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	if skel.find_bone("Hips") < 0 or skel.find_bone("LeftFoot") < 0:
		return
	var gp := GaitPolish.new()
	gp.name = "GaitPolish"
	skel.add_child(gp)
	if not gp.setup():
		gp.queue_free()
		return
	skel.move_child(gp, 0)
	gait_polish = gp


func _setup_look_at() -> void:
	var skel: Skeleton3D = null
	for sk in model.find_children("*", "Skeleton3D", true, false):
		skel = sk
		break
	if skel == null or RigNames.find(skel, "head") < 0:
		return
	_look_point = Node3D.new()
	_look_point.name = "LookPoint"
	_look_point.top_level = true
	add_child(_look_point)
	# The turn is shared by neck and head (a head-only twist folds the jaw into
	# the collar). Limit angles are full ranges: neck +-22 deg, head +-32 deg.
	var neck_mod := _make_look_mod(skel, RigNames.resolve(skel, "neck"), 44.0, 30.0, 0.6) if RigNames.find(skel, "neck") >= 0 else null
	_look_mod = _make_look_mod(skel, RigNames.resolve(skel, "head"), 64.0, 36.0, 0.75)
	_neck_mod = neck_mod
	if neck_mod:
		skel.move_child(neck_mod, 0)
		skel.move_child(_look_mod, 1)
	else:
		skel.move_child(_look_mod, 0)  # before secondary motion
	if face:
		face.look_at_node = _look_point


func _setup_grounding() -> void:
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	grounder = FootGrounder.new()
	grounder.name = "FootGrounder"
	skel.add_child(grounder)
	skel.move_child(grounder, 0)  # feet first, then look-at, then spring bones
	if not grounder.setup(self):
		grounder.queue_free()
		grounder = null
	hands = HandPoser.new()
	hands.name = "HandPoser"
	skel.add_child(hands)
	skel.move_child(hands, 1)
	if not hands.setup():
		hands.queue_free()
		hands = null


func _make_look_mod(skel: Skeleton3D, bone: String, yaw_range: float, pitch_range: float, weight: float) -> LookAtModifier3D:
	var m := LookAtModifier3D.new()
	m.name = "Look_" + bone
	skel.add_child(m)
	m.bone_name = bone
	m.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	m.primary_rotation_axis = Vector3.AXIS_Y
	m.use_secondary_rotation = true
	m.target_node = m.get_path_to(_look_point)
	m.duration = 0.55
	m.transition_type = Tween.TRANS_SINE
	m.ease_type = Tween.EASE_IN_OUT
	m.use_angle_limitation = true
	m.symmetry_limitation = true
	m.primary_limit_angle = deg_to_rad(yaw_range)
	m.primary_damp_threshold = 0.5
	m.secondary_limit_angle = deg_to_rad(pitch_range)
	m.secondary_damp_threshold = 0.5
	m.influence = weight
	return m


## Look at a node (e.g. a speaker) with an offset; null returns to automatic.
func set_look_target(node: Node3D, offset := Vector3.ZERO) -> void:
	_look_node = node
	_look_offset = offset


func _update_look(delta: float) -> void:
	if _look_point == null:
		return
	var eye := global_position + Vector3(0, 1.52, 0)
	var yaw_f := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var fwd := yaw_f
	var want := eye + fwd * 4.0
	if flying and Vector2(velocity.x, velocity.z).length() > 1.0:
		var vd := Vector3(velocity.x, velocity.y * 0.6, velocity.z).normalized()
		want = eye + vd * 8.0
	if is_instance_valid(_look_node):
		want = _look_node.global_position + _look_offset
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var to := cam.global_position - eye
			var flat := Vector3(to.x, 0, to.z).normalized()
			if flat.dot(fwd) > 0.55 and to.length() < 9.0 and velocity.length() < 3.0:
				want = cam.global_position
	# Ease the target itself too, so glances are smooth rather than snapping.
	_look_point.global_position = _look_point.global_position.lerp(want, 1.0 - exp(-6.0 * delta))


## 0 = fully visible, 1 = invisible. Used by the camera in tight interiors.
func set_model_fade(amount: float) -> void:
	if amount == _fade:
		return
	# Snap the last bit: any transparency > 0 moves her into the alpha pass, where
	# eyes and layered clothing sort incorrectly, so "visible" must be exactly 0.
	_fade = amount if absf(amount - _fade) < 0.02 else lerpf(_fade, amount, 0.25)
	for m in _meshes:
		m.transparency = _fade


func lock_input() -> void:
	input_locks += 1


func unlock_input() -> void:
	input_locks = maxi(0, input_locks - 1)


func has_control() -> bool:
	return input_locks == 0 and not get_tree().paused


# --- Caster interface -----------------------------------------------------------

func can_start_cast() -> bool:
	return has_control() and (is_on_floor() or flying) and not _casting


func is_indoors() -> bool:
	return _indoors > 0


func set_indoors(entered: bool) -> void:
	_indoors += 1 if entered else -1
	_indoors = maxi(_indoors, 0)


func staff_tip() -> Vector3:
	if _staff_tip:
		return _staff_tip.global_position
	return global_position + Vector3(0, 1.9, 0) + model.global_basis.z * 0.3


func facing_basis() -> Basis:
	return model.global_basis


func begin_cast(anim: StringName, _duration: float) -> void:
	_casting = true
	_cast_anim = anim
	if loco:
		loco.cast()
	else:
		_play(anim, 0.15)


func end_cast() -> void:
	_casting = false
	if _aim_active and not focus_aim:
		_aim_active = false
		set_look_target(null)


## Float `height` metres above the ground (0 = settle back down). The body keeps
## its ground position (spell effects, collision); only the visual model rises.
func set_levitation(height: float) -> void:
	_lift_spell = height
	_refresh_lift_goal()


## Toggle the idle hover (visual only: collision and movement stay grounded).
func set_hover(on: bool) -> void:
	hover_idle = on
	_lift_idle_goal = 0.38 if on else 0.0
	_refresh_lift_goal()


func _refresh_lift_goal() -> void:
	_lift_goal = maxf(0.0 if flying else _lift_spell, _lift_idle_goal)
	if grounder:
		grounder.suspended = flying or _lift_goal > 0.0 or _lift > 0.02
	if _lift_motes:
		_lift_motes.emitting = flying or _lift_spell > 0.0


func is_casting() -> bool:
	return _casting


func hover_height() -> float:
	return _lift


## Hover legs follow how far she has risen; the leg trail follows her velocity
## in the model's frame.
## While flying with her staff out the staff is held in the flight pose: upright
## at her side while she hovers, both hands forward like a lance as she speeds up.
func _update_flight_hold() -> void:
	if staff_rig == null:
		return
	var clip := StaffPoses.get_clip(&"fly")
	var spd := Vector2(velocity.x, velocity.z).length()
	var want := flying and staff != null and staff.out and not _casting and not focus_aim
	if want:
		if not (staff_rig.playing and staff_rig.clip == clip):
			staff_rig.play_param(clip)
		staff_rig.param = clampf(spd / fly_boost_speed, 0.0, 1.0)
		_fly_clip_on = true
		# Push-off strokes: every so often she drives the staff forward and the
		# magic bursts from its tail. Quicker the faster she goes; the first
		# stroke comes as she sets off.
		_prop_t -= get_physics_process_delta_time()
		if spd > 0.9 and _prop_t <= 0.0:
			_prop_t = lerpf(1.35, 0.7, clampf(spd / fly_boost_speed, 0.0, 1.0))
			staff_rig.kick(Vector3(0.0, -0.1, 1.9))
			thrust_pulse.emit(clampf(0.5 + spd / fly_boost_speed, 0.5, 1.5))
		elif spd <= 0.9:
			_prop_t = minf(_prop_t, 0.15)
	elif _fly_clip_on:
		_fly_clip_on = false
		if staff_rig.clip == clip:
			staff_rig.stop_param()


func _update_hover_pose() -> void:
	if gait_polish:
		var grounded := is_on_floor() and not flying and _lift < 0.05
		gait_polish.amount = move_toward(gait_polish.amount, 1.0 if grounded else 0.0, get_physics_process_delta_time() * 4.0)
		gait_polish.speed01 = Vector2(velocity.x, velocity.z).length() / maxf(walk_speed, 0.1)
	if hover_pose == null:
		return
	hover_pose.amount = maxf(smoothstep(0.0, 1.0, clampf(_lift / 0.25, 0.0, 1.0)), smoothstep(0.0, 1.0, _fly_blend))
	hover_pose.body_pitch = model.rotation.x if flying else 0.0
	hover_pose.speed01 = clampf(Vector2(velocity.x, velocity.z).length() / fly_boost_speed, 0.0, 1.0) if flying else 0.0
	hover_pose.climb = velocity.y if flying else 0.0
	# A body lying forward needs much more neck and head range to keep looking ahead.
	if _look_mod:
		_look_mod.secondary_limit_angle = deg_to_rad(lerpf(36.0, 120.0, _fly_blend))
	if _neck_mod:
		_neck_mod.secondary_limit_angle = deg_to_rad(lerpf(30.0, 100.0, _fly_blend))
	hover_pose.velocity = model.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)


func _update_levitation(delta: float) -> void:
	if _lift <= 0.001 and _lift_goal <= 0.0:
		if grounder and grounder.suspended and not flying:
			grounder.suspended = false
		return
	_lift_t += delta
	# Critically-damped rise (slow start, soft stop) and a slightly slower fall.
	var rate := 3.4 if _lift_goal > _lift else 2.6
	_lift = lerpf(_lift, _lift_goal, 1.0 - exp(-rate * delta))
	var fade := clampf(_lift / maxf(_lift_goal, 0.001), 0.0, 1.0) if _lift_goal > 0.0 else clampf(_lift / 0.75, 0.0, 1.0)
	var bob := sin(_lift_t * 2.3) * 0.035 * fade
	model.position.y = _lift + bob
	if _lift_motes:
		_lift_motes.global_position = global_position + Vector3(0, 0.05, 0)
	# A slow lean as if drifting, strongest at the top.
	model.rotation.x = deg_to_rad(-5.0) * fade * sin(_lift_t * 1.1 + 1.0) * 0.6
	if _lift <= 0.002 and _lift_goal <= 0.0:
		_lift = 0.0
		model.position.y = 0.0
		model.rotation.x = 0.0


func _build_lift_motes() -> void:
	_lift_motes = GPUParticles3D.new()
	_lift_motes.name = "LiftMotes"
	_lift_motes.amount = 48
	_lift_motes.lifetime = 1.4
	_lift_motes.emitting = false
	_lift_motes.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.85, 1.0, 0.6)
	_lift_motes.process_material = pm
	_lift_motes.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	add_child(_lift_motes)


# --- Movement -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if flying:
		pass   # no gravity while flying
	elif not on_floor:
		velocity.y -= gravity * delta
		if _exhausted_fall:
			velocity.y = maxf(velocity.y, -EXHAUSTED_FALL_SPEED)   # drifts down, doesn't plummet
		_coyote -= delta
	else:
		_coyote = 0.12
		_exhausted_fall = false
	_jump_buffer -= delta

	var input := Vector2.ZERO
	var running := false
	var climb := 0.0
	if has_control() and (not _casting or _cast_move > 0.0):
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		running = Input.is_action_pressed("run") and not _casting and not focus_aim
		if _casting:
			input *= _cast_move
		elif focus_aim:
			input *= AIM_MOVE_SCALE
		if Input.is_action_just_pressed("jump") and not _casting and not flying:
			_jump_buffer = 0.13
	if has_control() and flying and not (_casting and _cast_move <= 0.0):
		climb = Input.get_action_strength("jump") - Input.get_action_strength("descend")
	# Double-tap jump in the air: take off.
	if has_control() and not flying and not on_floor and Input.is_action_just_pressed("jump"):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_jump_press < 0.3:
			start_flight()
		_last_jump_press = now
	elif has_control() and Input.is_action_just_pressed("jump"):
		_last_jump_press = Time.get_ticks_msec() / 1000.0

	var yaw := camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var move_speed := run_speed if running else walk_speed
	var accel_up := acceleration
	var accel_down := deceleration
	if flying:
		move_speed = fly_boost_speed if running else fly_speed
		accel_up = fly_acceleration
		accel_down = fly_deceleration
	var target_speed := move_speed * minf(input.length(), 1.0)
	var target := dir.normalized() * target_speed if dir.length() > 0.01 else Vector3.ZERO
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	var accel := (accel_up if target.length() >= cur.length() else accel_down) if (on_floor or flying) else air_acceleration
	var hv := cur.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if flying:
		_fly_step(delta, on_floor, climb, hv.length(), running)

	if _jump_buffer > 0.0 and _coyote > 0.0 and not flying:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		Audio.sfx("jump", -10.0)

	_apply_soft_boundary()
	move_and_slide()

	if _aim_active:
		# Aiming: the body turns so the staff (offset by the pose's shaft yaw)
		# points at the crosshair, whatever direction she is drifting.
		_update_aim()
		model.rotation.y = lerp_angle(model.rotation.y, _aim_yaw - _aim_offset, 1.0 - exp(-13.0 * delta))
	elif dir.length() > 0.05:
		var want := atan2(dir.x, dir.z)
		# Turn slower at speed, like a person carrying momentum.
		var ts := turn_speed * lerpf(1.0, 0.55, clampf(hv.length() / run_speed, 0.0, 1.0))
		model.rotation.y = lerp_angle(model.rotation.y, want, 1.0 - exp(-ts * delta))
	# Lean into turns (bank) and slightly forward when speeding up.
	var yaw_rate := wrapf(model.rotation.y - _prev_yaw, -PI, PI) / maxf(delta, 1e-4)
	_prev_yaw = model.rotation.y
	var accel_fwd := (hv.length() - _prev_speed) / maxf(delta, 1e-4)
	_prev_speed = hv.length()
	var bank := clampf(-yaw_rate * hv.length() * 0.035, -0.18, 0.18) if on_floor else 0.0
	if flying:
		bank = clampf(-yaw_rate * (0.5 + hv.length()) * 0.07, -0.55, 0.55)
	_lean = lerpf(_lean, bank, 1.0 - exp(-6.0 * delta))
	var pitch := clampf(accel_fwd * 0.012, -0.06, 0.08) if on_floor else 0.0
	if flying:
		# Levitation, not jet propulsion: upright when hovering, a small forward lean
		# as she glides. She straightens up to cast or aim.
		var sp := clampf(hv.length() / fly_boost_speed, 0.0, 1.0)
		var lean := lerpf(0.0, deg_to_rad(24.0), smoothstep(0.0, 1.0, sp))
		if _casting or _aim_active or focus_aim:
			lean = minf(lean, deg_to_rad(8.0))
		pitch = lean + clampf(accel_fwd * 0.02, -0.14, 0.05)   # brakes tip her back a touch
		_flight_pitch = lerpf(_flight_pitch, pitch, 1.0 - exp(-4.0 * delta))
		pitch = _flight_pitch
	else:
		_flight_pitch = lerpf(_flight_pitch, 0.0, 1.0 - exp(-6.0 * delta))
	model.rotation.z = _lean
	model.rotation.x = lerpf(model.rotation.x, pitch, 1.0 - exp(-5.0 * delta))

	if on_floor and not _was_on_floor and velocity.y <= 0.0 and not flying:
		_footstep(-6.0)
	_was_on_floor = on_floor
	_update_footsteps(delta, hv.length())
	_update_animation(hv.length())
	_update_focus()
	_update_look(delta)
	_update_flight_visual(delta)
	_update_levitation(delta)
	_update_hover_pose()
	_update_stamina(delta, on_floor)
	_update_focus_aim(delta)
	_update_flight_hold()
	RenderingServer.global_shader_parameter_set("player_position", global_position)


func _apply_soft_boundary() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var over := flat.length() - play_radius
	if over > 0.0:
		var push := -flat.normalized() * over * 6.0
		velocity.x += push.x
		velocity.z += push.y


# --- Flight ---------------------------------------------------------------------
# Free flight costs stamina: a little to hover, more to move, climb or boost, and
# casting from the air costs extra on top. Stamina refills on the ground.

func start_flight() -> bool:
	if flying or not has_control():
		return false
	if is_indoors():
		GameState.toast.emit("Not indoors. The ceiling has opinions.")
		return false
	if _exhausted and stamina < EXHAUSTED_RECOVER:
		GameState.toast.emit("Out of breath. Give it a moment.")
		return false
	if stamina < MIN_TAKEOFF_STAMINA:
		GameState.toast.emit("Too tired to fly.")
		return false
	flying = true
	# Flight is a new, difficult art in this world: she always takes it with her
	# staff, summoning it if it is not already in her hand.
	if staff and not staff.out and not staff.busy:
		staff.summon()
	_exhausted = false
	_exhausted_fall = false
	_fly_t = 0.0
	velocity.y = maxf(velocity.y, 2.4)
	_refresh_lift_goal()
	flight_changed.emit(true)
	if not _flight_hint_shown:
		_flight_hint_shown = true
		GameState.toast.emit("Space climbs, Ctrl descends, Shift is faster. H lands.")
	return true


func stop_flight(exhausted := false) -> void:
	if not flying:
		return
	flying = false
	if exhausted:
		_exhausted = true
		_exhausted_fall = true
		GameState.toast.emit("Out of breath. She drifts down.")
	_stamina_rest = 0.6
	_refresh_lift_goal()
	flight_changed.emit(false)


func toggle_flight() -> void:
	if flying:
		stop_flight()
	else:
		start_flight()


## Stamina a spell costs to cast while airborne (0 on the ground).
func cast_stamina_cost(spell: SpellDefinition) -> float:
	if not flying:
		return 0.0
	return spell.flight_stamina_cost if spell.flight_stamina_cost >= 0.0 else spell.mana_cost * 0.6


func can_afford_cast(spell: SpellDefinition) -> bool:
	return not flying or stamina >= cast_stamina_cost(spell)


func pay_cast_cost(spell: SpellDefinition) -> void:
	var c := cast_stamina_cost(spell)
	if c > 0.0:
		stamina = maxf(stamina - c, 0.0)
		stamina_changed.emit(stamina, max_stamina)


## The ground beneath her (spell effects originate there, even from the air).
func ground_point() -> Vector3:
	if not flying and is_on_floor():
		return global_position
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -300, 0), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else global_position


func _fly_step(delta: float, on_floor: bool, climb: float, speed: float, boosting: bool) -> void:
	_fly_t += delta
	var vy_goal := climb * fly_climb_speed
	# Touch down gently: the last couple of metres slow the descent.
	if climb <= 0.0 and velocity.y < -0.4:
		var h := global_position.y - ground_point().y
		if h < 3.0:
			velocity.y = maxf(velocity.y, -(0.7 + h * 0.9))
	if global_position.y > FLY_CEILING and vy_goal > 0.0:
		vy_goal = 0.0
	velocity.y = move_toward(velocity.y, vy_goal, 10.0 * delta)
	# Land by flying down into the ground (or tapping descend on it).
	if on_floor and climb <= 0.0 and _fly_t > 0.5 and velocity.y <= 0.01:
		stop_flight()
		return
	# Stamina: hovering is cheap, moving, climbing and boosting cost more, and
	# everything doubles while she is casting.
	var rate := 2.5 + 3.5 * clampf(speed / fly_speed, 0.0, 2.0)
	if climb > 0.0:
		rate += 5.0 * climb
	if boosting and speed > 0.5:
		rate += 5.0
	if _casting:
		rate *= 2.0
	stamina = maxf(stamina - rate * delta, 0.0)
	if stamina <= 0.0:
		stop_flight(true)


func _update_stamina(delta: float, on_floor: bool) -> void:
	if not flying and on_floor and stamina < max_stamina:
		_stamina_rest = maxf(_stamina_rest - delta, 0.0)
		if _stamina_rest <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
			if _exhausted and stamina >= EXHAUSTED_RECOVER:
				_exhausted = false
	_stamina_emit -= delta
	if _stamina_emit <= 0.0:
		_stamina_emit = 0.1
		stamina_changed.emit(stamina, max_stamina)


## Feet off the ground, relaxed legs, a slow bob and a drift in the model's tilt.
func _update_flight_visual(delta: float) -> void:
	_fly_blend = move_toward(_fly_blend, 1.0 if flying else 0.0, delta * 4.0)
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 1.9) * 0.04 * _fly_blend
	# Pitch about her centre of mass (hips), not her feet, so leaning in at speed
	# swings the legs back instead of throwing the head forward.
	var th := model.rotation.x
	var pivot := 0.95
	var shift := Basis(Vector3.UP, model.rotation.y) * Vector3(0.0, pivot * (1.0 - cos(th)), -pivot * sin(th))
	model.position = Vector3(0.0, _lift + bob, 0.0) + shift * _fly_blend
	# Airflow: hair, cape and skirt stream back against her motion while flying.
	if secondary:
		var wind := -velocity * 0.7 * _fly_blend * airflow_scale
		wind.y *= 0.5
		secondary.external_force = secondary.external_force.lerp(wind.limit_length(7.0), 1.0 - exp(-5.0 * delta))


func _update_footsteps(delta: float, speed: float) -> void:
	if flying or not is_on_floor() or speed < 0.4:
		_step_accum = 0.0
		return
	_step_accum += speed * delta
	var stride := 1.35 if speed > walk_speed + 0.8 else 0.7
	if _step_accum >= stride:
		_step_accum -= stride
		_footstep(-9.0 if speed > walk_speed + 0.5 else -13.0)


func _footstep(volume: float) -> void:
	Audio.sfx("step_wood_*" if is_indoors() else "step_grass_*", volume, 0.08)


func _update_animation(speed: float) -> void:
	if _anim == null:
		return
	if loco:
		if flying:
			# Airborne but not "falling": the idle pose, with the hover legs on top.
			loco.update(get_physics_process_delta_time(), 0.0, walk_speed, run_speed, true, 0.0, _talking)
		else:
			loco.update(get_physics_process_delta_time(), speed, walk_speed, run_speed, is_on_floor(), velocity.y, _talking)
		return
	if _casting:
		return
	if not is_on_floor():
		_play(&"Jump" if velocity.y > 0.5 else &"Fall", 0.2)
	elif speed > walk_speed + 0.6:
		_play(&"Run", 0.25, speed / run_speed)
	elif speed > 0.25:
		_play(&"Walk", 0.25, clampf(speed / walk_speed, 0.6, 1.4))
	elif input_locks > 0 and _anim.has_animation(&"Talk") and _current_anim == "Talk":
		pass
	else:
		_play(&"Idle", 0.35)


func _play(anim_name: StringName, blend: float, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _current_anim != anim_name:
		_anim.play(anim_name, blend)
		_current_anim = anim_name
	_anim.speed_scale = speed


## Dialogue gestures. Falls back to Idle when an animation is missing.
func emote(anim_name: String) -> void:
	if loco:
		_talking = anim_name == "Talk"
		return
	if _anim and _anim.has_animation(anim_name):
		_play(StringName(anim_name), 0.3)


# --- Zoltraak focus aim -----------------------------------------------------------

func _zoltraak_equipped() -> bool:
	var s := caster.current_spell()
	return s != null and s.aim


## Hold RMB: raise the staff and aim. Summons the staff first if it is away.
func _begin_focus_aim() -> void:
	if focus_aim or _casting or not has_control() or not _zoltraak_equipped():
		return
	if staff and not staff.out:
		if staff.busy or is_indoors():
			return
		await staff.summon()
		if not Input.is_action_pressed("aim") or _casting:
			return
	focus_aim = true
	aim_charge = 0.0
	_heavy_ready_sfx = false
	_cast_hold = 0.0
	_aim_active = true
	_aim_offset = deg_to_rad(22.0)
	set_look_target(_aim_marker)
	if staff_rig:
		staff_rig.play(StaffPoses.get_clip(&"zoltraak_aim"), 0.3, 0.5, true)
	if staff:
		staff.touch()
	if face:
		face.set_expression("focused", 0.0)
	aim_changed.emit(true)


## Release RMB. At full charge the circle is loosed as a heavy shot.
func _end_focus_aim(allow_fire: bool) -> void:
	if not focus_aim:
		return
	# Any meaningful charge fires; width and brightness scale with it (1..3).
	var heavy := allow_fire and aim_charge >= 0.4
	cast_power = lerpf(1.0, 3.0, clampf((aim_charge - 0.4) / 0.6, 0.0, 1.0))
	focus_aim = false
	aim_changed.emit(false)
	if heavy:
		_fire_variant("heavy", true)
		get_tree().create_timer(0.55, false).timeout.connect(_release_aim_pose.bind(_cast_gen))
	else:
		_release_aim_pose(_cast_gen)


func _release_aim_pose(gen: int) -> void:
	if focus_aim or gen != _cast_gen:
		return
	if staff_rig and not _casting:
		staff_rig.release_hold()
	if not _casting:
		_aim_active = false
		set_look_target(null)
	if face:
		face.set_expression("neutral", 0.0)


func _fire_variant(variant: String, force := false) -> void:
	if not _variants.has(variant):
		_variants[variant] = load("res://data/spells/zoltraak_%s.tres" % variant) as SpellDefinition
	var sd: SpellDefinition = _variants[variant]
	if sd == null:
		return
	if not force and not (focus_aim and can_start_cast()):
		return
	var reason := caster.try_cast(sd)
	if reason != "" and reason != "busy":
		GameState.toast.emit(reason)


## Called by overlay spells: the staff kicks back a touch; returns the cast time.
func begin_overlay_cast(spell: SpellDefinition) -> float:
	recoil(1.0)
	if staff:
		staff.touch()
	return spell.cast_time


func recoil(amount: float) -> void:
	if staff_rig:
		staff_rig.kick(Vector3(0.0, 0.12, -0.85) * amount)


## Where the barrier faces: toward the dev aim point if set, otherwise where the
## camera looks (flattened, with a little of its pitch so high attacks are covered).
func guard_direction() -> Vector3:
	if aim_point_override.is_finite():
		var to := aim_point_override - (global_position + Vector3(0, 1.2, 0))
		if to.length() > 0.5:
			return to.normalized()
	var cam := get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_basis.z
		return Vector3(f.x, clampf(f.y, -0.2, 0.35), f.z).normalized()
	return model.global_basis.z


func aim_point() -> Vector3:
	return _aim_marker.global_position if _aim_marker else global_position + model.global_basis.z * 10.0


func _update_focus_aim(delta: float) -> void:
	aim_blend = move_toward(aim_blend, 1.0 if focus_aim else 0.0, delta * 5.0)
	if focus_aim:
		aim_charge = minf(aim_charge + delta / AIM_CHARGE_TIME, 1.0)
		if aim_charge >= 0.99 and not _heavy_ready_sfx:
			_heavy_ready_sfx = true
			Audio.sfx("spell_gather", -14.0, 0.0)
		# Holding the cast button past a tap channels the sustained beam.
		if Input.is_action_pressed("cast") or Input.is_action_pressed("cast_alt"):
			_cast_hold += delta
			if _cast_hold > 0.3 and not caster.casting:
				_fire_variant("beam")
		else:
			_cast_hold = 0.0
	# Neutral combat-ready stance: staff out with Zoltraak equipped, she hovers a
	# hand's breadth off the ground while standing.
	var ready := staff != null and staff.out and _zoltraak_equipped() and not flying and is_on_floor() and velocity.length() < 0.4 and not _casting
	var goal := 0.1 if ready else 0.0
	if not is_equal_approx(goal, _combat_goal):
		_combat_goal = goal
		_lift_idle_goal = maxf(0.38 if hover_idle else 0.0, goal)
		_refresh_lift_goal()


# --- Interaction ------------------------------------------------------------------

func _update_focus() -> void:
	var best: Node = null
	if has_control() and not _casting:
		var best_score := INF
		var fwd := model.global_basis.z
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.has_method("can_interact") or not n.can_interact(self):
				continue
			var p: Vector3 = n.interaction_point()
			var to := p - global_position
			to.y = 0.0
			var d := to.length()
			if d > interact_range:
				continue
			var facing := fwd.dot(to.normalized()) if d > 0.01 else 1.0
			var score := d - facing * 0.8
			if score < best_score:
				best_score = score
				best = n
	if best != focus:
		focus = best
		focus_changed.emit(focus)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("aim") and has_control():
		get_viewport().set_input_as_handled()
		_begin_focus_aim()
		return
	if event.is_action_released("aim") and focus_aim:
		get_viewport().set_input_as_handled()
		_end_focus_aim(true)
		return
	if not has_control():
		return
	if focus_aim:
		# While aiming the same keys fire the Zoltraak modes.
		if (event.is_action_pressed("cast") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) or event.is_action_pressed("cast_alt"):
			get_viewport().set_input_as_handled()
			_cast_hold = 0.0
			_fire_variant("quick")
			return
		if event.is_action_pressed("summon"):
			get_viewport().set_input_as_handled()
			_fire_variant("burst")
			return
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_fire_variant("volley")
			return
	if event.is_action_pressed("interact") and focus:
		get_viewport().set_input_as_handled()
		focus.interact(self)
	elif (event.is_action_pressed("cast") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) or event.is_action_pressed("cast_alt"):
		get_viewport().set_input_as_handled()
		_cast_with_staff()
	elif event.is_action_pressed("spell_1") or event.is_action_pressed("spell_2") or event.is_action_pressed("spell_3") or event.is_action_pressed("spell_4"):
		if not caster.casting:
			caster.equip(0 if event.is_action_pressed("spell_1") else (1 if event.is_action_pressed("spell_2") else (2 if event.is_action_pressed("spell_3") else 3)))
	elif event.is_action_pressed("fly"):
		toggle_flight()
	elif event.is_action_pressed("interrupt"):
		interrupt_cast()
	elif event.is_action_pressed("summon") and staff:
		get_viewport().set_input_as_handled()
		if staff.out:
			staff.stow()
		elif not is_indoors():
			staff.summon()


## Freyja summons her staff out of thin air before casting if it isn't out.
func _cast_with_staff() -> void:
	if staff and not staff.out:
		if is_indoors() or staff.busy or not can_start_cast():
			var r := caster.try_cast()  # let the caster explain (e.g. indoors)
			if r != "" and r != "busy":
				GameState.toast.emit(r)
			return
		await staff.summon()
	var reason := caster.try_cast()
	if reason == "" and staff:
		staff.touch()
	# (The staff hand keeps its grip; the free hand stays relaxed.)
	elif reason != "" and reason != "busy":
		GameState.toast.emit(reason)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	model.rotation.y = yaw
	if camera_rig:
		camera_rig.snap_behind(yaw)


func face_towards(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		model.rotation.y = atan2(to.x, to.z)
