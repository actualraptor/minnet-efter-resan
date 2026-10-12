class_name Inspectable
extends Node3D
## A thing in the world that can be looked at (E starts a monologue, so the
## dialogue file picks what she says from the flags) and, if `cleanable`, rid of
## its moss by the Fläckfri spell. Used for Jonas's stone and the roadside statue.

signal cleaned(id: String)

@export var id := ""
@export var dialogue_id := ""
@export var prompt := "Look closer"
## Seconds the moss takes to come off.
@export var clean_time := 2.4

var grime := 1.0
## Optional text on the thing itself, faded in once the moss is gone.
var plaque: Label3D
var _mat: ShaderMaterial
var _tween: Tween


func setup(material: ShaderMaterial) -> void:
	_mat = material
	_mat.set_shader_parameter("grime", grime)
	add_to_group("interactable")
	add_to_group("cleanable")


func is_dirty() -> bool:
	return grime > 0.02


func clean() -> bool:
	if not is_dirty():
		return false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_grime, grime, 0.0, clean_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		cleaned.emit(id)
		if plaque:
			create_tween().tween_property(plaque, "modulate:a", 1.0, 1.2))
	return true


## Instantly in a given state (a save was loaded).
func set_clean(on: bool) -> void:
	if _tween:
		_tween.kill()
	_set_grime(0.0 if on else 1.0)
	if plaque:
		plaque.modulate.a = 1.0 if on else 0.0


func _set_grime(v: float) -> void:
	grime = v
	_mat.set_shader_parameter("grime", v)


# --- interaction ---------------------------------------------------------------------

func can_interact(_who: Node) -> bool:
	return dialogue_id != ""


func interaction_point() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func interaction_prompt() -> String:
	return prompt


func interact(who: Node) -> void:
	if DialogueDirector.instance:
		DialogueDirector.instance.start_monologue(dialogue_id, who)
