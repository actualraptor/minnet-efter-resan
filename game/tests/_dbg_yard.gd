extends Node
## Dev: showcase captures for the NPCs, the statue, Fläckfri, the practice range,
## time of day and the waypoints.
##   godot --path game -- --dbg --yard --out=<dir>
var _out := ""
var _main: Node
var _p: Player
var _terrain: MeadowTerrain


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(label + ".png"))
	print("YARD snap ", label)


func _look(pos: Vector3, yaw: float, _dist: float, zoom := 1.0, pitch_deg := -8.0, side := 0.0) -> void:
	_p.teleport(pos, yaw)
	var rig: CameraRig = _p.camera_rig
	rig.zoom = zoom
	rig.pitch = deg_to_rad(pitch_deg)
	rig.yaw = yaw + PI + side


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain.height_at(x, z), z)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent()
	_main.get_node("UI").visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_p = _main.player
	_terrain = _main.terrain
	var quests: StoneQuests = _main.get_node("StoneQuests")
	var only := OS.get_environment("YARD_ONLY")
	await _wait(1.2)

	if only == "" or only == "npc":
		await _npcs()
	if only == "" or only == "statue":
		await _statue(quests)
	if only == "" or only == "range":
		await _range()
	if only == "" or only == "time":
		await _time()
	if only == "" or only == "way":
		await _waypoints()
	if only == "life":
		await _life()
	get_tree().quit()


func _npcs() -> void:
	# The real NPC scenes, in front of the camera, at the meadow's light.
	var z := 20.0
	var edda := (load("res://scenes/npc_edda.tscn") as PackedScene).instantiate() as NPC
	var pippa := (load("res://scenes/npc_pippa.tscn") as PackedScene).instantiate() as NPC
	_main.add_child(edda)
	_main.add_child(pippa)
	edda.global_position = _ground(-0.6, z)
	pippa.global_position = _ground(0.6, z)
	var cam := Camera3D.new()
	_main.add_child(cam)
	cam.make_current()
	cam.fov = 34.0
	await _wait(1.0)
	cam.global_position = _ground(0, z) + Vector3(0, 1.1, 5.0)
	cam.look_at(_ground(0, z) + Vector3(0, 0.85, 0), Vector3.UP)
	await _snap("npc_both")
	cam.global_position = _ground(-0.6, z) + Vector3(0.2, 1.38, 1.6)
	cam.look_at(_ground(-0.6, z) + Vector3(0, 1.3, 0), Vector3.UP)
	await _snap("npc_edda_face")
	cam.global_position = _ground(0.6, z) + Vector3(-0.2, 1.05, 1.5)
	cam.look_at(_ground(0.6, z) + Vector3(0, 1.0, 0), Vector3.UP)
	await _snap("npc_pippa_face")
	edda.play(&"Talk")
	pippa.play(&"Hop")
	await _wait(0.5)
	cam.global_position = _ground(0, z) + Vector3(0, 1.1, 5.0)
	cam.look_at(_ground(0, z) + Vector3(0, 0.85, 0), Vector3.UP)
	await _snap("npc_talk_hop")
	edda.queue_free()
	pippa.queue_free()
	cam.queue_free()
	_p.camera_rig.get_node("Pitch/SpringArm3D/Camera3D").call("make_current")


func _statue(quests: StoneQuests) -> void:
	GameState.learn_spell("spell_stain_free")
	var st := StoneQuests.STATUE_POS
	_look(_ground(st.x + 5.0, st.y + 1.0) + Vector3(0, 0.2, 0), -PI / 2.0 - 0.15, 5.0, 1.0, -6.0, 0.7)
	await _wait(0.8)
	await _snap("statue_moss")
	_p.caster.equip(_p.caster.spells.find(SpellLibrary.get_def("spell_stain_free")))
	_p.caster.mana = _p.caster.max_mana
	_p.caster._cooldowns.clear()
	_p.caster.try_cast()
	for t in [0.4, 0.5, 0.5, 0.5, 0.7, 0.9]:
		await _wait(t)
		await _snap("wipe_%d" % int(Time.get_ticks_msec() % 100000))
	await _wait(1.5)
	await _snap("statue_clean")
	_look(_ground(st.x + 3.2, st.y) + Vector3(0, 0.2, 0), -PI / 2.0, 3.2, 0.75, -4.0, 0.0)
	await _wait(0.5)
	await _snap("statue_front")


func _range() -> void:
	_main.call("_build_range_yard")
	await _wait(0.5)
	var r: PracticeRange = _main.get_node("PracticeRange") as PracticeRange
	var lane0 := Vector2(PracticeRange.ORIGIN.x, PracticeRange.ORIGIN.y)
	# Overview from behind the switch.
	_look(_ground(lane0.x - 8.0, lane0.y + 2.0) + Vector3(0, 0.2, 0), PI / 2.0, 8.0, 1.6, -12.0, 0.0)
	await _wait(0.6)
	await _snap("range_idle")
	r.set_active(true)
	await _wait(2.5)
	await _snap("range_firing")
	# Stand in the black lane with the barrier up.
	var bx := lane0.x + 8.0
	_look(_ground(bx, lane0.y) + Vector3(0, 0.2, 0), PI / 2.0, 4.0, 1.2, -8.0, -0.9)
	_p.caster.equip(_p.caster.spells.find(SpellLibrary.get_def("spell_barrier")))
	_p.caster.mana = _p.caster.max_mana
	_p.caster._cooldowns.clear()
	await _p.staff.summon()
	Input.action_press("cast")
	_p.caster.try_cast()
	for i in 5:
		await _wait(1.3)
		await _snap("range_barrier_%d" % i)
	Input.action_release("cast")
	r.set_active(false)


func _time() -> void:
	_look(_ground(-3.5, 33.0) + Vector3(0, 0.2, 0), PI, 4.0, 1.4, -7.0, 0.4)
	for h in [6.4, 9.0, 12.5, 16.0, 18.8, 20.0, 21.5]:
		GameState.world_date["hour"] = h
		await _wait(1.5)
		await _snap("time_%03d" % int(h * 10))
	GameState.world_date["hour"] = 16.0


func _waypoints() -> void:
	GameState.world_date["hour"] = 16.0
	GameState.set_flag("pippa_met")
	GameState.set_quest("garden_of_jonas", "active")
	_look(_ground(-3.5, 28.0) + Vector3(0, 0.2, 0), 0.0, 4.0, 1.6, -4.0, 0.0)
	_p.camera_rig.yaw = PI
	await _wait(3.0)
	await _snap("way_wisp_far")
	GameState.set_quest("garden_of_jonas", "complete")
	GameState.set_quest("jonas_stone", "active")
	var sp := StoneQuests.STONE_POS
	_look(_ground(sp.x + 11.0, sp.y + 12.0) + Vector3(0, 0.2, 0), atan2(-11.0, -12.0), 4.0, 1.5, -3.0, 0.0)
	await _wait(3.5)
	await _snap("way_beacon_stone")
	GameState.world_date["hour"] = 19.0
	await _wait(1.5)
	await _snap("way_beacon_dusk")


func _life() -> void:
	GameState.set_quest("garden_of_jonas", "complete")
	GameState.world_date["hour"] = 16.0
	GameState.set_flag("pippa_met")
	await _wait(0.5)
	for r in _main._routines:
		r.snap_to_plan()
	# From the meadow, looking at the bench and the stops round it.
	_look(_ground(1.0, -24.0) + Vector3(0, 0.2, 0), 0.25, 5.0, 1.4, -6.0, 0.0)
	await _wait(1.5)
	await _snap("life_bench_sit")
	var pr: NpcRoutine = _main.pippa.get_node("Routine")
	pr.wait_scale = 0.15
	for i in 6:
		await _wait(1.6)
		await _snap("life_t%d" % i)
	# Close on Edda, seated, and then talking.
	var e: NPC = _main.edda
	_look(_ground(e.global_position.x - 1.2, e.global_position.z + 1.8) + Vector3(0, 0.2, 0), atan2(1.2, -1.8), 3.0, 0.7, -4.0, 0.0)
	await _wait(0.8)
	await _snap("life_edda_close")
	e.play(&"Talk")
	await _wait(0.8)
	await _snap("life_edda_talk")
