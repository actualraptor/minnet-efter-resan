class_name IndoorVolume
extends Area3D
## Marks an interior. Tells the player (camera length, footsteps, spell rules)
## and crossfades ambience between meadow and hearth.

@export var ambience_inside := "fireplace"
@export var ambience_outside := "meadow"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body is Player:
		body.set_indoors(true)
		Audio.ambience(ambience_inside, -6.0, 1.5)
		Audio.ambience(ambience_outside, -26.0, 1.5)
		Audio.ambience("birds", -40.0, 1.5)


func _on_exit(body: Node3D) -> void:
	if body is Player:
		body.set_indoors(false)
		Audio.ambience(ambience_inside, -40.0, 2.0)
		Audio.ambience(ambience_outside, -12.0, 2.0)
		Audio.ambience("birds", -14.0, 2.0)
