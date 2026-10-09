extends Node
## Captures real runtime screenshots (needs a GPU window, not --headless):
##   godot --path game -- --tour --out=<absolute dir>
## Shots: outdoors, interior with Edda, dialogue, spell mid-cast, aftermath.

var main: Node
var out_dir := "user://screenshots"


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(2.5)
	await _tour()
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _shot(name: String, clean := true) -> void:
	var ui: CanvasLayer = main.get_node("UI")
	ui.visible = not clean
	for n in get_tree().get_nodes_in_group("npc"):
		(n as NPC)._bark.visible = not clean
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT ", path)


func _pose(pos: Vector3, model_yaw: float, cam_yaw: float, pitch_deg: float) -> void:
	var p: Player = main.player
	p.teleport(pos, model_yaw)
	var rig: CameraRig = p.camera_rig
	rig.yaw = cam_yaw
	rig.pitch = deg_to_rad(pitch_deg)
	rig.global_position = pos + Vector3.UP * rig.height


func _tour() -> void:
	var t: MeadowTerrain = main.terrain
	var p: Player = main.player
	# 1. Arriving on the path, cottage ahead.
	var a := Vector3(1.4, 0, 13.5)
	a.y = t.height_at(a.x, a.z) + 0.1
	_pose(a, PI + 0.15, 0.25, -8.0)
	await _wait(1.5)
	await _shot("01_meadow_arrival")
	# 2. Wide establishing view from the hillside.
	var b := Vector3(-14.0, 0, 18.0)
	b.y = t.height_at(b.x, b.z) + 0.1
	_pose(b, PI * 0.75, deg_to_rad(-40.0), -12.0)
	await _wait(1.2)
	await _shot("02_cottage_establishing")
	# 3. Interior with Edda.
	main.world.door.set_open(true)
	var e: NPC = main.edda
	var c := e.global_position + Vector3(-1.9, 0.1, 1.4)
	var to_e := e.global_position - c
	var my := atan2(to_e.x, to_e.z)
	_pose(c, my, my + PI + 0.35, -8.0)
	await _wait(1.6)
	await _shot("03_cottage_interior")
	# 4. Dialogue framing.
	main.director.start_conversation("edda", e, p)
	await _wait(1.4)
	main.director.box._text.visible_characters = -1
	await _wait(0.3)
	await _shot("04_dialogue", false)
	main.director.runner.stop()
	await _wait(0.5)
	# 5. Casting in the meadow.
	GameState.set_quest("garden_of_jonas", "active")
	var m := WorldLayout.GARDEN_MEADOW + Vector3(2.0, 0, 6.0)
	m.y = t.height_at(m.x, m.z) + 0.1
	_pose(m, PI * 0.9, deg_to_rad(10.0), -14.0)
	await _wait(1.0)
	p.caster.try_cast()
	await _wait(0.75)
	await _shot("05_casting_gather")
	await _wait(1.1)
	await _shot("06_flower_wave")
	await _wait(4.5)
	# 6. Aftermath from a lower, wider angle.
	_pose(m + Vector3(-3.0, 0, 5.0), PI, deg_to_rad(-15.0), -6.0)
	await _wait(1.5)
	await _shot("07_flowered_aftermath")
	_pose(m + Vector3(0.0, 0, 3.0), PI * 0.5, deg_to_rad(160.0), -10.0)
	await _wait(1.0)
	await _shot("08_flowers_closeup")
	# 7. Hero: flowers in the front meadow, looking back up the path at the cottage.
	var hpos := Vector3(-4.5, 0, 11.0)
	hpos.y = t.height_at(hpos.x, hpos.z) + 0.1
	p.caster._cooldowns.clear()
	p.caster.mana = p.caster.max_mana
	_pose(hpos, PI, 0.0, -4.0)
	await _wait(0.6)
	p.caster.try_cast()
	await _wait(6.5)
	var cam_pos := Vector3(-2.2, 0, 17.5)
	cam_pos.y = t.height_at(cam_pos.x, cam_pos.z) + 0.1
	_pose(cam_pos, PI + 0.3, 0.12, -3.0)
	p.camera_rig.outdoor_length = 3.4
	await _wait(1.6)
	await _shot("00_hero")
