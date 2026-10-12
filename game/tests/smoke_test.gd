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
	var wp: Waypoints = main.get_node("Waypoints")
	main.ending_enabled = false   # the ending has its own check at the end

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
	check("waypoint: the garden meadow", wp.objective() == WorldLayout.GARDEN_MEADOW)
	check("Edda and Pippa wear the shared VRoid library", main.edda.model.scale.x < 1.0 and main.pippa.model.scale.x < main.edda.model.scale.x and CharacterVisual.find_animation_player(main.edda.model).has_animation(&"Talk") and CharacterVisual.find_animation_player(main.pippa.model).has_animation(&"Idle"))

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

	# --- Errand: Flowers for Jonas (stone, book, study, Fläckfri) ---------------------
	check("Pippa offers Jonas's stone after the garden", GameState.quest("jonas_stone") == "active", GameState.quest("jonas_stone"))
	check("waypoint: Jonas's stone", (wp.objective() as Vector3).distance_to(Vector3(StoneQuests.STONE_POS.x, terrain.height_at(StoneQuests.STONE_POS.x, StoneQuests.STONE_POS.y), StoneQuests.STONE_POS.y)) < 0.5)
	var stone_pos := StoneQuests.STONE_POS
	var quests: StoneQuests = main.get_node("StoneQuests")
	check("stone and statue props exist", quests._stone != null and quests._statue != null and quests._stone.is_dirty() and quests._statue.is_dirty())
	player.teleport(Vector3(stone_pos.x - 3.0, terrain.height_at(stone_pos.x - 3.0, stone_pos.y + 3.0) + 0.3, stone_pos.y + 3.0), 0.0)
	await _frames(30)
	player.caster.mana = player.caster.max_mana
	player.caster._cooldowns.clear()
	reason = player.caster.try_cast()
	check("cast accepted at the stone", reason == "", reason)
	await _seconds(6.0)
	check("flowers at the stone move the errand on", GameState.quest("jonas_stone") == "planted", GameState.quest("jonas_stone"))
	check("waypoint: back to Edda", (wp.objective() as Vector3).is_equal_approx(main.edda.global_position))
	var t_stone := await _talk_monologue("grave")
	check("stone shows the planted line", t_stone.contains("Blue by the kerb"), t_stone.get_slice("\n", 0))
	player.teleport(edda.global_position + Vector3(0.0, 0.3, 1.5), PI)
	await _frames(20)
	var t5 := await _talk(edda, [])
	check("Edda gives her mother's book", GameState.has_item("household_book") and GameState.quest("jonas_stone") == "book", GameState.quest("jonas_stone"))
	check("Fläckfri is not known before studying", not GameState.knows_spell("spell_stain_free"))
	check("waypoint: none while studying", wp.objective() == null)
	var hud0: Hud = main.get_node("UI/Hud")
	check("tracker shows the study objective", hud0._quest_title.text == "Flowers for Jonas" and hud0._quest_obj.text.contains("study"), hud0._quest_obj.text)

	# Mid-errand save and load keeps the book and the errand.
	check("mid-errand save written", GameState.save_game())
	field.clear()
	GameState.reset()
	check("mid-errand state cleared", GameState.quest("jonas_stone") == "none" and not GameState.has_item("household_book"))
	check("mid-errand load succeeded", GameState.load_game())
	await _frames(2)
	check("mid-errand state restored", GameState.quest("jonas_stone") == "book" and GameState.has_item("household_book") and GameState.quest("garden_of_jonas") == "complete")

	# Study: the clock moves on by the spell's study time and the spell is learned.
	var book: Spellbook = main.get_node("UI/Spellbook")
	var hour0 := float(GameState.world_date["hour"])
	var hours := SpellLibrary.get_def("spell_stain_free").study_hours
	await book._study("household_book")
	var moved := fposmod(float(GameState.world_date["hour"]) - hour0, 24.0)
	check("study moved the clock by the spell's study time", absf(moved - hours) < 0.15, "%.2f h of %.2f" % [moved, hours])
	check("studying taught Fläckfri", GameState.knows_spell("spell_stain_free"))
	check("new spell took the first free number key", GameState.hotbar.find("spell_stain_free") == 4, "slot %d" % GameState.hotbar.find("spell_stain_free"))
	check("book is kept after studying", GameState.has_item("household_book"))
	check("Flowers for Jonas completes on learning", GameState.quest("jonas_stone") == "complete")
	check("waypoint: Pippa after the book", (wp.objective() as Vector3).is_equal_approx(main.pippa.global_position))
	check("stone memory recorded", GameState.has_memory("memory_jonas_stone_flowers"))
	var key5 := InputEventAction.new()
	key5.action = "spell_5"
	key5.pressed = true
	check("number key 5 maps to slot 5", player._hotbar_slot(key5) == 4)
	GameState.bind_spell(0, "spell_stain_free")
	check("binding swaps with the old occupant", GameState.hotbar[0] == "spell_stain_free" and GameState.hotbar[4] == "spell_field_of_flowers")
	GameState.bind_spell(0, "spell_field_of_flowers")
	check("binding back restores the slots", GameState.hotbar[0] == "spell_field_of_flowers" and GameState.hotbar[4] == "spell_stain_free")

	# Fläckfri lifts the moss off the stone.
	player.caster.equip(player.caster.spells.find(SpellLibrary.get_def("spell_stain_free")))
	player.teleport(Vector3(stone_pos.x, terrain.height_at(stone_pos.x, stone_pos.y + 2.2) + 0.3, stone_pos.y + 2.2), PI)
	await _frames(30)
	player.caster.mana = player.caster.max_mana
	player.caster._cooldowns.clear()
	reason = player.caster.try_cast()
	check("Fläckfri cast accepted", reason == "", reason)
	await _seconds(4.5)
	check("Fläckfri cleaned Jonas's stone", GameState.has_flag("clean_jonas_stone") and not quests._stone.is_dirty())
	var t_clean_stone := await _talk_monologue("grave")
	check("clean stone is readable", t_clean_stone.contains("HE HUMMED WHEN HE WEEDED"), t_clean_stone.get_slice("\n", 0))
	check("cleaning the stone leaves the statue mossy", quests._statue.is_dirty() and quests._statue.shader_grime() > 0.99)

	# --- Errand: Good morning, statue ---------------------------------------------
	player.teleport(pippa.global_position + Vector3(0, 0.2, 2.0), PI)
	await _frames(10)
	var t6 := await _talk(pippa, [])
	check("Pippa asks for the statue", GameState.quest("statue_by_the_road") == "active", GameState.quest("statue_by_the_road"))
	check("waypoint: the statue", (wp.objective() as Vector3).distance_to(Vector3(StoneQuests.STATUE_POS.x, terrain.height_at(StoneQuests.STATUE_POS.x, StoneQuests.STATUE_POS.y), StoneQuests.STATUE_POS.y)) < 0.5)
	var statue_meshes := quests._statue.find_children("*", "MeshInstance3D", true, false).size()
	check("statue is built from her own model (many meshes, alpha cut-outs kept)", statue_meshes > 40 and not quests._alpha_mats.is_empty(), "%d meshes, %d cut-out materials" % [statue_meshes, quests._alpha_mats.size()])
	var sp := StoneQuests.STATUE_POS
	player.teleport(Vector3(sp.x + 3.0, terrain.height_at(sp.x + 3.0, sp.y) + 0.3, sp.y), -PI / 2.0)
	await _frames(30)
	var t_moss := await _talk_monologue("statue")
	check("mossed statue has no readable plaque", t_moss.contains("moss") and not t_moss.contains("TOMATO"), t_moss.get_slice("\n", 0))
	player.caster.mana = player.caster.max_mana
	player.caster._cooldowns.clear()
	player.caster.try_cast()
	await _seconds(4.5)
	check("Fläckfri cleaned the statue", GameState.has_flag("clean_statue") and not quests._statue.is_dirty())
	var t_plate := await _talk_monologue("statue")
	check("clean statue shows the plaque and moves the errand on", t_plate.contains("TOMATO") and GameState.quest("statue_by_the_road") == "found", GameState.quest("statue_by_the_road"))
	check("waypoint: back to Pippa", (wp.objective() as Vector3).is_equal_approx(main.pippa.global_position))
	player.teleport(pippa.global_position + Vector3(0, 0.2, 2.0), PI)
	await _frames(10)
	var t7 := await _talk(pippa, [1])
	check("Pippa closes the statue errand", GameState.quest("statue_by_the_road") == "complete" and GameState.has_memory("memory_statue_by_the_road"))
	check("statue choice recorded in the memory", GameState.get_memory("memory_statue_by_the_road").get("journal_text", "").contains("I told Pippa I didn't remember"))
	check("waypoint: none once the errands are done", wp.objective() == null)

	# Time of day: the sun is brighter at noon than at night, and moves.
	var tod: TimeOfDay = main.get_node("TimeOfDay")
	tod.apply(12.5)
	var noon_energy: float = main.world.sun.light_energy
	tod.apply(23.0)
	var night_energy: float = main.world.sun.light_energy
	tod.apply(float(GameState.world_date["hour"]))
	check("sun is dimmer at night than at noon", night_energy < noon_energy * 0.4, "%.2f vs %.2f" % [night_energy, noon_energy])
	var clock0 := float(GameState.world_date["hour"])
	await _seconds(6.0)
	check("the clock keeps running in play", float(GameState.world_date["hour"]) != clock0)

	# Practice range: two lanes fire continuously along fixed lines when started.
	var yard := PracticeRange.new()
	main.add_child(yard)
	yard.setup(terrain, player)
	yard.set_active(true)
	await _seconds(2.0)
	var beam_up: bool = yard._turrets.size() == 2 and is_instance_valid(yard._turrets[0]._lane_beam)
	check("range: the black lane holds a beam while on", beam_up)
	yard.set_active(false)
	await _seconds(0.5)
	check("range: it stops when switched off", yard._turrets[0]._lane_beam == null)
	yard.queue_free()

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
	check("satchel, spells and number keys restored", GameState.has_item("household_book") and GameState.knows_spell("spell_stain_free") and GameState.hotbar[4] == "spell_stain_free")
	check("caster list follows the loaded spells", player.caster.spells.any(func(sp2: SpellDefinition): return sp2.id == &"spell_stain_free"))
	check("stone and statue restored clean", not quests._stone.is_dirty() and not quests._statue.is_dirty())
	var hud: Hud = main.get_node("UI/Hud")
	check("tracker shows the latest finished errand", hud._quest_title.text == "Good Morning, Statue", hud._quest_title.text)

	# After a load the cast is where the plan says (Edda out on her bench), not where the scene started.
	var bench := WorldLayout.BENCH_POS
	check("after a load Edda is back on the bench", Vector2(main.edda.global_position.x - bench.x, main.edda.global_position.z - bench.z).length() < 1.3 and main.edda.seated, "%.1f m, seated=%s" % [Vector2(main.edda.global_position.x - bench.x, main.edda.global_position.z - bench.z).length(), main.edda.seated])

	# The cast has a day: they walk between stops, and go home when the light goes.
	var pr: NpcRoutine = main.pippa.get_node("Routine")
	var er: NpcRoutine = main.edda.get_node("Routine")
	pr.wait_scale = 0.04
	var travelled := 0.0
	var last_pos: Vector3 = main.pippa.global_position
	for k in 50:
		await _seconds(0.3)
		travelled += main.pippa.global_position.distance_to(last_pos)
		last_pos = main.pippa.global_position
	check("Pippa moves around on her own", travelled > 3.0, "%.1f m" % travelled)
	pr.wait_scale = 1.0
	var hour_now := float(GameState.world_date["hour"])
	GameState.world_date["hour"] = 22.0
	await _seconds(2.2)
	check("at night both go home", pr._plan_key == "pippa_home" and er._plan_key == "edda_home", "%s / %s" % [pr._plan_key, er._plan_key])
	GameState.world_date["hour"] = hour_now
	await _seconds(2.2)
	check("in daylight Edda is back to the bench plan", er._plan_key == "edda_bench", er._plan_key)

	# Locomotion has weight: speed builds, a stop takes time, a hard turn costs speed.
	var loco_r := await _loco_response()
	print("LOCO walk t90 %.2fs  run t90 %.2fs  stop from run %.2fs  pivot min speed %.2f m/s (run %.2f)" % [loco_r["walk_t90"], loco_r["run_t90"], loco_r["stop_run"], loco_r["pivot_min"], player.run_speed])
	check("a walk takes about half a second to get going", loco_r["walk_t90"] > 0.35 and loco_r["walk_t90"] < 1.1, "%.2f s" % loco_r["walk_t90"])
	check("stepping up from a walk to a run takes a beat", loco_r["run_t90"] > 0.4 and loco_r["run_t90"] < 1.7, "%.2f s" % loco_r["run_t90"])
	check("stopping from a run is not instant", loco_r["stop_run"] > 0.4 and loco_r["stop_run"] < 1.4, "%.2f s" % loco_r["stop_run"])
	check("a 180 degree turn at a run costs speed", loco_r["pivot_min"] < player.run_speed * 0.8 and loco_r["pivot_min"] > 0.2, "%.2f m/s" % loco_r["pivot_min"])

	# Front door and options.
	Settings.ensure_buses()
	check("option buses exist", AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Ambience") >= 0 and AudioServer.get_bus_index("Effects") >= 0)
	var credits: Variant = DialogueRunner._read_json("res://data/credits.json")
	check("credits list every licence group", credits is Array and (credits as Array).size() >= 5)
	var ts := TitleScreen.new()
	main.get_node("UI").add_child(ts)
	await _frames(2)
	ts.set_continue_enabled(false)
	check("title screen builds with Begin, Continue, Options, Credits, Quit", ts.get_child_count() >= 2 and ts._continue_btn != null and ts._continue_btn.disabled)
	ts.queue_free()

	# The ending: dusk on the road, the closing conversation, then the end card.
	main.ending_enabled = true
	check("ending is ready once all three errands are done", main._ending_ready())
	main.call("_start_ending")
	var guard_end := 0
	while not main.end_card.visible and guard_end < 900:
		guard_end += 1
		if main.director.runner.active:
			main.director.runner.advance()
		await _frames(10)
	check("end card shows after the closing conversation", main.end_card.visible and GameState.has_flag("demo_complete"))
	check("closing beat happens at dusk", float(GameState.world_date["hour"]) >= 19.0)
	check("ending is written into the journal", GameState.has_memory("memory_dusk_on_the_road"))
	main.end_card.visible = false
	get_tree().paused = false

	print("\n---- transcript sample ----\n" + t3)


func _talk_monologue(id := "intro") -> String:
	var director: DialogueDirector = main.director
	var lines: Array[String] = []
	var cb := func(line, info): lines.append("%s: %s" % [info.get("name", "?"), line["text"]])
	director.runner.line_shown.connect(cb)
	director.start_monologue(id, main.player)
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



## Step responses of the ground movement, measured with real input events.
func _loco_response() -> Dictionary:
	var p: Player = main.player
	var out := {}
	p.teleport(Vector3(-3.5, main.terrain.height_at(-3.5, 33.0) + 0.2, 33.0), PI)
	p.camera_rig.yaw = 0.0
	await _seconds(0.5)
	var sp := func() -> float: return Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_press("move_forward")
	var t := 0.0
	while sp.call() < p.walk_speed * 0.9 and t < 4.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	out["walk_t90"] = t
	await _seconds(0.8)
	Input.action_press("run")
	t = 0.0
	while sp.call() < p.run_speed * 0.9 and t < 6.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	out["run_t90"] = t
	await _seconds(0.6)
	Input.action_release("move_forward")
	Input.action_release("run")
	t = 0.0
	while sp.call() > 0.15 and t < 4.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	out["stop_run"] = t
	# Pivot: run, then the camera (and so the input) swings round 180 degrees.
	p.teleport(Vector3(-3.5, main.terrain.height_at(-3.5, 31.0) + 0.2, 31.0), PI)
	p.camera_rig.yaw = 0.0
	Input.action_press("move_forward")
	Input.action_press("run")
	await _seconds(2.6)
	p.camera_rig.yaw = PI
	var lo := 99.0
	for i in 70:
		await get_tree().physics_frame
		lo = minf(lo, sp.call())
	out["pivot_min"] = lo
	Input.action_release("move_forward")
	Input.action_release("run")
	p.camera_rig.yaw = 0.0
	await _seconds(1.2)
	return out
