class_name Door
extends Node3D
## A hinged door: the child "Panel" (AnimatableBody3D) swings around this
## node's origin. Interact to open/close; it auto-closes once the player has
## walked well away so the cottage keeps its warmth.

@export var open_angle := deg_to_rad(-100.0)
@export var swing_time := 0.7
@export var label := "Door"
@export var auto_close_distance := 7.0

var panel: AnimatableBody3D
var is_open := false
var _tween: Tween


func _ready() -> void:
	add_to_group("interactable")
	if panel == null:
		panel = get_node_or_null("Panel")


func can_interact(_who: Node) -> bool:
	return true


func interaction_point() -> Vector3:
	return global_position + global_basis.x * 0.6


func interaction_prompt() -> String:
	return ("Close " if is_open else "Open ") + label.to_lower()


func interact(_who: Node) -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", open_angle if open else 0.0, swing_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Audio.sfx("door_open" if open else "door_close", -6.0, 0.05, global_position)


func _process(_delta: float) -> void:
	if not is_open:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.global_position.distance_to(global_position) > auto_close_distance:
		set_open(false)
