extends Node
## Drives Linnaea through a movement script for review videos:
##   godot --path game --audio-driver Dummy --write-movie out.avi --fixed-fps 30 -- --motion=<view>
## views: side (default), front, back, close

var main: Node
var view := "side"


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--motion="):
			view = a.substr(9)
	main.get_node("UI").visible = false
	await _run()
	get_tree().quit()


func _hold(actions: Array, seconds: float) -> void:
	for a in ["move_right", "move_left", "move_forward", "move_back", "run"]:
		Input.action_release(a)
	for a in actions:
		Input.action_press(a)
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	var p: Player = main.player
	var t: MeadowTerrain = main.terrain
	var start := Vector3(-14.0, 0, 6.0)
	start.y = t.height_at(start.x, start.z) + 0.1
	p.teleport(start, PI * 0.5)
	var rig: CameraRig = p.camera_rig
	rig.shoulder_offset = 0.0
	rig.outdoor_length = 3.4 if view != "close" else 2.0
	rig.pitch = deg_to_rad(-5.0)
	var cam_yaw: float = {"side": 0.0, "front": -PI * 0.5, "back": PI * 0.5, "close": 0.35}[view]
	rig.yaw = cam_yaw
	await get_tree().create_timer(1.5).timeout
	# Movement is camera-relative; map "forward along +X" to the right input for this view.
	var fwd: String = {"side": "move_right", "front": "move_back", "back": "move_forward", "close": "move_right"}[view]
	var back: String = {"side": "move_left", "front": "move_forward", "back": "move_back", "close": "move_left"}[view]
	await _hold([], 1.0)
	await _hold([fwd], 2.5)
	await _hold([fwd, "run"], 2.5)
	await _hold([], 1.5)
	await _hold([back], 1.2)
	await _hold([fwd], 0.8)
	await _hold([], 1.5)
