extends Node
## Automated playthrough of milestone 001, run with:
##   godot --headless --path game -- --smoke-test
## It drives the real scene (terrain, physics raycasts, dialogue runner, spell
## system, flower field, save/load). It is NOT a substitute for a human
## playtest: it cannot judge visuals, feel or camera behaviour.

var main: Node
var results: Array[String] = []
var failures := 0
var _choices: Array = []


func _ready() -> void:
	main = get_parent()
	await _frames(30)
	await _run()
	print("\n==== SMOKE TEST ====")
	for r in results:
		print(r)
	print("==== %s (%d failures) ====" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(name: String, ok: bool, detail: String = "") -> void:
	results.append(("[ok]   " if ok else "[FAIL] ") + name + ("" if detail == "" else "  — " + detail))
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _talk(npc: NPC, picks: Array[int]) -> String:
	var director: DialogueDirector = main.director
	var runner := director.runner
	_choices = []
	var cb := func(c): _choices = c
	runner.choices_shown.connect(cb)
	var lines: Array[String] = []
	var line_cb := func(line, info): lines.append("%s: %s" % [info.get("name", "?"), line["text"]])
	runner.line_shown.connect(line_cb)
	if not director.start_conversation(npc.dialogue_id, npc, main.player):
		runner.choices_shown.disconnect(cb)
		runner.line_shown.disconnect(line_cb)
		return "<could not start>"
	var guard := 0
	while runner.active and guard < 200:
		guard += 1
		if not _choices.is_empty():
			var pick: int = picks.pop_front() if not picks.is_empty() else 0
			pick = mini(pick, _choices.size() - 1)
			var c: Dictionary = _choices[pick]
			lines.append("  > %s" % c["text"])
			_choices = []
			runner.choose(c)
		else:
			runner.advance()
		await get_tree().process_frame
	runner.choices_shown.disconnect(cb)
	runner.line_shown.disconnect(line_cb)
	return "
".join(lines) + "
"


func _run() -> void:
	var player: Player = main.player
	var terrain: MeadowTerrain = main.terrain
	var field := FlowerField.instance

	# World
	var h := terrain.height_at(0, 20)
	check("terrain height is finite", is_finite(h), "h(0,20)=%.2f" % h)
	var grass_chunks := main.get_node("Grass").get_child_count()
	check("grass chunks generated", grass_chunks > 20, str(grass_chunks))
	var props: int = main.world.get_child_count()
	check("world props placed", props > 80, str(props))
	check("cottage imported", main.world.cottage != null and main.world.cottage.find_children("*", "MeshInstance3D").size() > 0)
	await _frames(60)
	check("player standing on terrain", player.is_on_floor(), "y=%.2f ground=%.2f" % [player.global_position.y, terrain.height_at(player.global_position.x, player.global_position.z)])
	check("player model has animations", CharacterVisual.find_animation_player(player.model) != null and CharacterVisual.find_animation_player(player.model).has_animation(&"Cast"))
	check("staff tip attachment found", player.model.find_child("StaffTip", true, false) != null)
	var ap := CharacterVisual.find_animation_player(player.model)
	var nonloop := []
	for clip in ["Idle", "Walk", "Run", "IdleStaff", "WalkStaff", "RunStaff"]:
		if ap.has_animation(clip) and ap.get_animation(clip).loop_mode != Animation.LOOP_LINEAR:
			nonloop.append(clip)
	check("locomotion clips loop", nonloop.is_empty(), str(nonloop))
	check("staff starts stowed", player.staff != null and not player.staff.out)
	await player.staff.summon()
	check("staff summoned from thin air", player.staff.out)
	check("hair/cloth spring bones active", player.secondary != null and player.secondary.setting_count >= 20, "%d chains" % (player.secondary.setting_count if player.secondary else 0))
	# Camera fade must return to exactly 0: any transparency puts her in the alpha
	# pass, where her eyes sort in front of her face.
	for i in 30:
		player.set_model_fade(0.6 if i < 10 else 0.0)
	check("model fade returns to fully opaque", player._fade == 0.0, "fade %f" % player._fade)
	check("head look-at modifier active", player._look_mod != null and player._look_mod.active)
	# VRoid faces drive gaze through their own eye bones/shapes, not iris bones.
	var face_ok := player.face != null and player.face.blend_shape_count() >= 6
	check("face rig ready (expression blend shapes)", face_ok, "shapes %d, iris %d" % [player.face.blend_shape_count(), player.face._iris_bones.size()])

	# Intro monologue
	var t0 := await _talk_monologue()
	check("intro monologue plays protagonist lines", t0.contains("Freyja:"), t0.get_slice("\n", 1))

	# Pippa
	var pippa: NPC = main.pippa
	player.teleport(pippa.global_position + Vector3(0, 0.2, 2.0), PI)
	await _frames(10)
	var t1 := await _talk(pippa, [1])
	check("Pippa first conversation", GameState.has_flag("pippa_met"), "%d lines" % t1.count("\n"))
	check("dialogue shows both NPC and protagonist", t1.contains("Pippa:") and t1.contains("Freyja:"))

	# Edda: enter the cottage and talk.
	var door: Door = main.world.door
	var edda: NPC = main.edda
	# Walk in through the doorway (regression: a wall rail once blocked it).
	var dc := door.interaction_point()
	var n := door.global_basis.z
	n.y = 0.0
	n = n.normalized()
	if n.dot(edda.global_position - dc) < 0.0:
		n = -n
	var outside := dc - n * 2.2
	player.teleport(Vector3(outside.x, terrain.height_at(outside.x, outside.z) + 0.2, outside.z), atan2(n.x, n.z))
	player.camera_rig.yaw = atan2(-n.x, -n.z)
	await _frames(10)
	door.set_open(true)
	await _seconds(0.8)
	Input.action_press("move_forward")
	await _seconds(2.6)
	Input.action_release("move_forward")
	await _frames(20)
	check("walks in through the open door", player.is_indoors(), "stopped %.2f m past the door" % n.dot(player.global_position - dc))
	door.set_open(true)
	await _seconds(0.8)
	player.teleport(edda.global_position + Vector3(-0.6, 0.2, 1.4), PI)
	await _frames(30)
	check("player registers as indoors", player.is_indoors())
	var reason := player.caster.try_cast()
	check("Field of Flowers refuses to cast indoors", reason.begins_with("Not indoors"), reason)
	var t2 := await _talk(edda, [1, 2])
	check("Edda quest started", GameState.quest("garden_of_jonas") == "active", GameState.quest("garden_of_jonas"))
	check("choice-conditional flag recorded", GameState.has_flag("asked_what_jonas_planted"))
	var t2b := await _talk(edda, [])
	check("Edda has distinct 'active' follow-up", t2b.contains("disappointed"), t2b.get_slice("\n", 0))

	# Cast in the meadow behind the cottage.
	var m := WorldLayout.GARDEN_MEADOW
	player.teleport(Vector3(m.x, terrain.height_at(m.x, m.z) + 0.3, m.z), 0.0)
	await _frames(40)
	check("player outdoors again", not player.is_indoors())
	player.caster.mana = player.caster.max_mana
	reason = player.caster.try_cast()
	check("cast accepted in meadow", reason == "", reason)
	await _seconds(6.0)
	var total := field.total()
	check("flowers grew", total > 300, "%d flowers" % total)
	check("flower patch recorded", field.patches().size() == 1)
	check("no flower inside the cottage footprint", _no_flowers_in_cottage(field))
	check("quest moved to 'bloomed'", GameState.quest("garden_of_jonas") == "bloomed")

	# Recast performance/caps.
	var t_start := Time.get_ticks_usec()
	for i in 4:
		player.caster.mana = player.caster.max_mana
		player.caster._cooldowns.clear()
		player.teleport(Vector3(m.x + 8 - i * 5, terrain.height_at(m.x + 8 - i * 5, m.z + 6) + 0.3, m.z + 6), 0.0)
		await _frames(5)
		player.caster.try_cast()
		await _seconds(4.0)
	var after := field.total()
	check("recasts stay within caps", after <= FlowerField.MAX_PER_VARIANT * field.variant_count(), "%d flowers after 5 casts" % after)
	print("recast phase took %.1fs (wall)" % ((Time.get_ticks_usec() - t_start) / 1e6))

	# Bench conversation and memory.
	player.teleport(edda.global_position + Vector3(0.0, 0.3, 1.5), PI)
	await _frames(20)
	var t3 := await _talk(edda, [0])
	check("bench conversation completes quest", GameState.quest("garden_of_jonas") == "complete")
	var mem := GameState.get_memory("memory_cottage_garden_restored")
	check("memory event recorded", not mem.is_empty())
	check("memory has participants/location/spell/date", mem.get("participants", []).has("char_edda") and mem.has("location") and mem.get("spell") == "spell_field_of_flowers" and mem.has("world_date"))
	check("memory captures the Teodor seed", (mem.get("seeds", []) as Array).has("teodor_bought_seeds_for_her"))
	check("future-callback flag set", GameState.has_flag("resolve_visit_teodor"))
	var t4 := await _talk(pippa, [])
	check("Pippa after-quest line interpolates count", t4.contains("I counted") and not t4.contains("{"), t4.get_slice("\n", 0))

	# Save / load roundtrip.
	var before_flowers := field.total()
	check("save written", GameState.save_game())
	field.clear()
	GameState.reset()
	check("state cleared", GameState.quest("garden_of_jonas") == "none" and field.total() == 0)
	check("load succeeded", GameState.load_game())
	await _frames(2)
	check("quest restored", GameState.quest("garden_of_jonas") == "complete")
	check("memory restored", GameState.has_memory("memory_cottage_garden_restored"))
	check("flowers re-planted deterministically", field.total() == before_flowers, "%d vs %d" % [field.total(), before_flowers])
	print("\n---- transcript sample ----\n" + t3)


func _talk_monologue() -> String:
	var director: DialogueDirector = main.director
	var lines: Array[String] = []
	var cb := func(line, info): lines.append("%s: %s" % [info.get("name", "?"), line["text"]])
	director.runner.line_shown.connect(cb)
	director.start_monologue("intro", main.player)
	var guard := 0
	while director.runner.active and guard < 50:
		guard += 1
		director.runner.advance()
		await get_tree().process_frame
	director.runner.line_shown.disconnect(cb)
	return "
".join(lines) + "
"


func _no_flowers_in_cottage(field: FlowerField) -> bool:
	for mmi in field.get_children():
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in mm.visible_instance_count:
			var p := mm.get_instance_transform(i).origin
			if WorldLayout.cottage_rect_contains(p, 0.2):
				return false
	return true
