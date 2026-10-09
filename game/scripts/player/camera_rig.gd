class_name CameraRig
extends Node3D
## Orbiting third-person camera. A SpringArm3D keeps the camera out of walls and
## terrain; indoors the arm shortens so the cottage interior stays readable.

@export var target_path: NodePath
@export var mouse_sensitivity := 0.0025
@export var pad_sensitivity := 2.6
@export var outdoor_length := 4.3
@export var indoor_length := 2.5
@export var height := 1.55
@export var follow_speed := 12.0
@export var min_pitch := deg_to_rad(-62.0)
@export var max_pitch := deg_to_rad(28.0)

var yaw := 0.0
var pitch := deg_to_rad(-14.0)
var target: Player

@onready var _pitch_node: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	target = get_node_or_null(target_path) as Player
	if target:
		target.camera_rig = self
		_arm.add_excluded_object(target.get_rid())
		global_position = target.global_position + Vector3.UP * height
	_arm.collision_mask = 1
	var s := SphereShape3D.new()
	s.radius = 0.22
	_arm.shape = s
	_arm.margin = 0.12
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and target and target.has_control():
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and target and target.has_control():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if target == null:
		return
	if target.has_control():
		var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if look.length() > 0.15:
			yaw -= look.x * pad_sensitivity * delta
			pitch = clampf(pitch - look.y * pad_sensitivity * delta, min_pitch, max_pitch)
	var goal := target.global_position + Vector3.UP * (height if not target.is_indoors() else height - 0.1)
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	var want_len := indoor_length if target.is_indoors() else outdoor_length
	_arm.spring_length = lerpf(_arm.spring_length, want_len, 1.0 - exp(-4.0 * delta))
	_apply()


func _apply() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	# Offset slightly over the shoulder for a more cinematic frame.
	_arm.position = Vector3(0.35, 0.0, 0.0)


func snap_behind(model_yaw: float) -> void:
	yaw = model_yaw + PI
	if target:
		global_position = target.global_position + Vector3.UP * height
	_apply()


func forward() -> Vector3:
	return -global_basis.z
