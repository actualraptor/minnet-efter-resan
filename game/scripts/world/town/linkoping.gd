extends Node3D
## Linköping, "the city of churches": a standalone slice of the world after the
## illustrated map. Freyja arrives on the lane from the south, crosses the stone
## bridge and walks up Storgatan to the square; the cathedral stands beyond it.
##   godot --path game res://scenes/linkoping.tscn

@onready var terrain: TownTerrain = $Terrain
@onready var world: TownBuilder = $World
@onready var player: Player = $Player


func _ready() -> void:
	world.build(terrain)
	player.play_radius = TownLayout.PLAY_RADIUS
	var s := TownLayout.PLAYER_START
	player.teleport(Vector3(s.x, terrain.height_at(s.x, s.z) + 0.1, s.z), PI)
	Audio.ambience("meadow", -14.0, 3.0)
	Audio.ambience("birds", -15.0, 4.0)
	Audio.music("meadow_theme", -18.0, 6.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if OS.get_environment("TOWN_WALK") != "":
		add_child(load("res://tests/town_walk.gd").new())
	var shots := OS.get_environment("TOWN_SHOTS")
	if shots != "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_child(load("res://tests/town_shots.gd").new())
