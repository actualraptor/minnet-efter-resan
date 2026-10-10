class_name CameraRig
extends Node3D
## Orbiting third-person camera. A SpringArm3D keeps the camera out of walls and
## terrain; indoors the arm shortens so the cottage interior stays readable.

@export var target_path: NodePath
@export var mouse_sensitivity := 0.0025
@export var pad_sensitivity := 2.6
@export var outdoor_length := 4.3
@export var indoor_length := 2.2
## Mouse-wheel zoom: 1 = default distance; small values frame her face.
@export var min_zoom := 0.18
@export var max_zoom := 1.6
var zoom := 1.0
var _zoom_smooth := 1.0
@export var height := 1.55
@export var follow_speed := 12.0
@export var min_pitch := deg_to_rad(-62.0)
@export var max_pitch := deg_to_rad(28.0)
@export var shoulder_offset := 0.35

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
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and target and target.has_control():
		zoom = clampf(zoom * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88), min_zoom, max_zoom)
		get_viewport().set_input_as_handled()
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
	# Zoomed in, the camera pivots on her face instead of her shoulders.
	var close_t := clampf((_zoom_smooth - min_zoom) / 0.55, 0.0, 1.0)
	var h := lerpf(1.47, height if not target.is_indoors() else height - 0.1, close_t)
	var goal := target.global_position + Vector3.UP * h
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_zoom_smooth = lerpf(_zoom_smooth, zoom, 1.0 - exp(-10.0 * delta))
	var want_len := (indoor_length if target.is_indoors() else outdoor_length) * _zoom_smooth
	_arm.spring_length = lerpf(_arm.spring_length, want_len, 1.0 - exp(-4.0 * delta))
	_apply()
	# Fade the mage out when walls push the camera right up against her.
	var hit := _arm.get_hit_length()
	var obstructed := hit < _arm.spring_length - 0.15
	target.set_model_fade(clampf((1.35 - hit) / 0.9, 0.0, 0.75) if camera.current and obstructed else 0.0)


func _apply() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	# Offset slightly over the shoulder for a more cinematic frame.
	var indoors := target != null and target.is_indoors()
	_arm.position = _arm.position.lerp(Vector3((minf(0.12, shoulder_offset) if indoors else shoulder_offset) * clampf((_zoom_smooth - min_zoom) / 0.55, 0.0, 1.0), 0.0, 0.0), 0.1)


func snap_behind(model_yaw: float) -> void:
	yaw = model_yaw + PI
	if target:
		global_position = target.global_position + Vector3.UP * height
	_apply()


func forward() -> Vector3:
	return -global_basis.z
