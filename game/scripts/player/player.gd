class_name Player
extends CharacterBody3D
## Third-person mage controller: camera-relative movement, walk/run/jump,
## interaction focus, and the caster interface used by SpellCaster.

signal focus_changed(target: Node)

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
var grounder: FootGrounder
var hands: HandPoser
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
		caster.spells.append(load("res://data/spells/field_of_flowers.tres") as SpellDefinition)
		caster.equip(0)


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
	var fwd := model.global_basis.z
	var want := eye + fwd * 4.0
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
	return has_control() and is_on_floor() and not _casting


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


## Float `height` metres above the ground (0 = settle back down). The body keeps
## its ground position (spell effects, collision); only the visual model rises.
func set_levitation(height: float) -> void:
	_lift_goal = height
	if grounder:
		grounder.suspended = height > 0.0 or _lift > 0.02
	if _lift_motes:
		_lift_motes.emitting = height > 0.0


func is_casting() -> bool:
	return _casting


func hover_height() -> float:
	return _lift


func _update_levitation(delta: float) -> void:
	if _lift <= 0.001 and _lift_goal <= 0.0:
		if grounder and grounder.suspended:
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
	if not on_floor:
		velocity.y -= gravity * delta
		_coyote -= delta
	else:
		_coyote = 0.12
	_jump_buffer -= delta

	var input := Vector2.ZERO
	var running := false
	if has_control() and not _casting:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		running = Input.is_action_pressed("run")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = 0.13

	var yaw := camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var target_speed := (run_speed if running else walk_speed) * minf(input.length(), 1.0)
	var target := dir.normalized() * target_speed if dir.length() > 0.01 else Vector3.ZERO
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	var accel := (acceleration if target.length() >= cur.length() else deceleration) if on_floor else air_acceleration
	var hv := cur.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		Audio.sfx("jump", -10.0)

	_apply_soft_boundary()
	move_and_slide()

	if dir.length() > 0.05:
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
	_lean = lerpf(_lean, bank, 1.0 - exp(-6.0 * delta))
	var pitch := clampf(accel_fwd * 0.012, -0.06, 0.08) if on_floor else 0.0
	model.rotation.z = _lean
	model.rotation.x = lerpf(model.rotation.x, pitch, 1.0 - exp(-5.0 * delta))

	if on_floor and not _was_on_floor and velocity.y <= 0.0:
		_footstep(-6.0)
	_was_on_floor = on_floor
	_update_footsteps(delta, hv.length())
	_update_animation(hv.length())
	_update_focus()
	_update_look(delta)
	_update_levitation(delta)
	RenderingServer.global_shader_parameter_set("player_position", global_position)


func _apply_soft_boundary() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var over := flat.length() - WorldLayout.PLAY_RADIUS
	if over > 0.0:
		var push := -flat.normalized() * over * 6.0
		velocity.x += push.x
		velocity.z += push.y


func _update_footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.4:
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
	if not has_control():
		return
	if event.is_action_pressed("interact") and focus:
		get_viewport().set_input_as_handled()
		focus.interact(self)
	elif (event.is_action_pressed("cast") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) or event.is_action_pressed("cast_alt"):
		get_viewport().set_input_as_handled()
		_cast_with_staff()
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
