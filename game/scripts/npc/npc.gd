class_name NPC
extends CharacterBody3D
## A named, persistent character the mage can talk to. Identity (stable id,
## name, birth year) comes from data/characters/cast.json; behaviour here is
## intentionally small: idle, turn to face the speaker, talk, bark.

signal talked(npc: NPC)

@export var character_id := "char_unknown"
@export var dialogue_id := ""
@export var prompt_verb := "Talk"
@export var head_height := 1.55
## One shared VRoid body becomes a person through these (see NpcLook): overall
## size, hair and clothes tint (white = none), a forward stoop in degrees, spectacles.
@export var body_scale := 1.0
@export var hair_tint := Color(1, 1, 1, 1)
@export var cloth_tint := Color(1, 1, 1, 1)
@export var stoop_deg := 0.0
@export var glasses := false
## Cloth cones over the sample body (alpha 0 = none): a long skirt, a shawl.
@export var long_skirt := Color(0, 0, 0, 0)
@export var shawl := Color(0, 0, 0, 0)

@onready var model: Node3D = $Model
var _anim: AnimationPlayer
var _bark: Label3D
var _home_yaw := 0.0
var _talking := false
var _look_target: Vector3


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1
	_anim = CharacterVisual.find_animation_player(model)
	model.scale = Vector3.ONE * body_scale
	# VRM bodies carry no animations of their own: give them the shared library.
	if CharacterVisual.use_humanoid_library(model):
		NpcLook.apply(model, hair_tint, cloth_tint, stoop_deg, glasses, long_skirt, shawl)
	CharacterVisual.prepare(model)
	_home_yaw = model.rotation.y
	_bark = Label3D.new()
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.position = Vector3(0, head_height + 0.55, 0)
	_bark.font_size = 44
	_bark.outline_size = 12
	_bark.outline_modulate = Color(0.16, 0.12, 0.2, 0.85)
	_bark.modulate = Color(1, 0.97, 0.9, 0)
	_bark.no_depth_test = true
	_bark.width = 600
	_bark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_bark)


func display_name() -> String:
	var info: Dictionary = DialogueDirector.instance.runner.speaker_info(character_id) if DialogueDirector.instance else {}
	return info.get("name", character_id)


func can_interact(_who: Node) -> bool:
	return dialogue_id != "" and not _talking


func interaction_point() -> Vector3:
	return global_position


func interaction_prompt() -> String:
	return "%s with %s" % [prompt_verb, display_name()]


func interact(who: Node) -> void:
	if DialogueDirector.instance:
		DialogueDirector.instance.start_conversation(dialogue_id, self, who)
	talked.emit(self)


func head_position() -> Vector3:
	return global_position + Vector3(0, head_height, 0)


func begin_talk(with: Node3D) -> void:
	_talking = true
	_look_target = with.global_position
	_face(with.global_position, 0.35)


func end_talk() -> void:
	_talking = false
	play(&"Idle")


func play(anim_name: StringName) -> void:
	# The shared library has no "Hop"; a small jump does the same job.
	if anim_name == &"Hop" and _anim and not _anim.has_animation(&"Hop") and _anim.has_animation(&"Jump"):
		anim_name = &"Jump"
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.3)
	elif _anim and _anim.has_animation(&"Idle"):
		_anim.play(&"Idle", 0.3)


func _face(point: Vector3, time: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var yaw := atan2(to.x, to.z)
	var tw := create_tween()
	var start := model.rotation.y
	var target := start + wrapf(yaw - start, -PI, PI)
	tw.tween_property(model, "rotation:y", target, time).set_trans(Tween.TRANS_SINE)


func set_home(pos: Vector3, yaw: float) -> void:
	global_position = pos
	model.rotation.y = yaw
	_home_yaw = yaw


func bark(text: String, duration := 2.8) -> void:
	_bark.text = text
	var tw := create_tween()
	tw.tween_property(_bark, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(_bark, "modulate:a", 0.0, 0.6)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 15.0 * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
