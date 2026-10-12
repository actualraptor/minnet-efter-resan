extends Node3D
## Milestone-001 scene controller: builds the world, places the cast and runs
## the small story "The Garden Behind the Cottage" by reacting to dialogue
## events and spell casts. Story state itself lives in GameState.

const QUEST := "garden_of_jonas"
const MEMORY_ID := "memory_cottage_garden_restored"

@onready var terrain: MeadowTerrain = $Terrain
@onready var world: WorldBuilder = $World
@onready var player: Player = $Player
@onready var edda: NPC = $Edda
@onready var pippa: NPC = $Pippa
@onready var director: DialogueDirector = $DialogueDirector
@onready var fade: ColorRect = $UI/Fade
@onready var title: Label = $UI/Title

var _stone_quests: StoneQuests
var _waypoints: Waypoints
var _time_of_day: TimeOfDay
var _bloom_pending := false
var _ending_running := false
## Tests switch the ending off so a finished errand does not take the scene over.
var ending_enabled := true
var end_card: EndCard


func _ready() -> void:
	world.build(terrain)
	_build_time_of_day()
	_place_cast()
	_build_stone_errands()
	director.runner.event_fired.connect(_on_dialogue_event)
	director.conversation_finished.connect(_on_conversation_finished)
	GameState.spell_cast.connect(_on_spell_cast)
	GameState.quest_changed.connect(_on_quest_changed)
	player.caster.cast_failed.connect(_on_cast_failed)
	Audio.ambience("meadow", -12.0, 3.0)
	Audio.ambience("birds", -14.0, 4.0)
	Audio.ambience("fireplace", -40.0, 0.1)
	Audio.music("meadow_theme", -16.0, 6.0)
	var args := OS.get_cmdline_user_args()
	if "--dbg" in args:
		fade.visible = false
		title.visible = false
		# Dev audits: --dbg --face|--spell|--pose|--walk (default: staff walk).
		var dbg := "staffwalk"
		for k in ["face", "spell", "pose", "walk", "waist", "feet", "side", "hand", "jump", "outfit", "vroid", "clips", "float", "staff", "fly", "aim", "physics", "zoltraak", "input", "range", "teaser", "book", "probe", "npc", "yard", "perf", "clip", "clipcal", "clipshots"]:
			if "--" + k in args:
				dbg = k
		add_child(load("res://tests/_dbg_%s.gd" % dbg).new())
		return
	if Array(args).any(func(a): return a.begins_with("--motion")):
		fade.visible = false
		title.visible = false
		add_child(load("res://tests/motion_tour.gd").new())
		return
	if "--smoke-test" in args or "--tour" in args:
		fade.visible = false
		title.visible = false
		var t: Node = load("res://tests/smoke_test.gd" if "--smoke-test" in args else "res://tests/screenshot_tour.gd").new()
		add_child(t)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_range_yard()
	_show_title()


## The front door over the live meadow. Begin runs the opening; Continue loads the
## saved journal and drops her back on the road.
func _show_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.lock_input()
	$UI/Hud.visible = false
	var t := TitleScreen.new()
	t.name = "TitleScreen"
	$UI.add_child(t)
	t.set_continue_enabled(GameState.has_save())
	t.begin_pressed.connect(func():
		t.queue_free()
		$UI/Hud.visible = true
		player.unlock_input()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_opening())
	t.continue_pressed.connect(func():
		if GameState.load_game():
			t.queue_free()
			$UI/Hud.visible = true
			fade.visible = false
			title.visible = false
			player.unlock_input()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


## The dedicated practice range east of the road (see PracticeRange): walk there,
## press E at the pedestal, and step into a lane to try the barrier.
func _build_range_yard() -> void:
	var r := PracticeRange.new()
	add_child(r)
	r.setup(terrain, player)


## The old in-meadow range (dev tools and the teaser film still build it):
## straw dummies to hit, and two shooters (Mörkstråk beam, Solstråk volley) that
## hunt her on a telegraphed line so the barrier can be tried against them.
func _build_practice_range() -> void:
	var root := Node3D.new()
	root.name = "PracticeRange"
	add_child(root)
	var dummies := [Vector2(-9, 23), Vector2(-3, 19), Vector2(4, 24), Vector2(10, 20), Vector2(-14, 29)]
	for d in dummies:
		var dm := PracticeDummy.new()
		root.add_child(dm)
		dm.global_position = _ground(d.x, d.y)
		dm.rotation.y = randf_range(-0.4, 0.4)
	var black := ZoltraakTurret.new()
	black.kind = ZoltraakVisuals.Kind.BLACK
	black.monster = "dummy"
	root.add_child(black)
	black.global_position = _ground(9.0, 12.0)
	black.auto_target = player
	black.interval = 9.0
	var white := ZoltraakTurret.new()
	white.kind = ZoltraakVisuals.Kind.WHITE
	white.monster = "dummy"
	root.add_child(white)
	white.global_position = _ground(-13.0, 14.0)
	white.auto_target = player
	white.volley = true
	white.interval = 7.0
	white._clock = 3.0


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


var _routines: Array[NpcRoutine] = []


func _place_cast() -> void:
	var s := WorldLayout.PLAYER_START
	player.teleport(_ground(s.x, s.z) + Vector3.UP * 0.1, PI)
	# Edda by the armchair, facing the door; Pippa by her carrots.
	var pad := terrain.pad_height() + WorldLayout.COTTAGE_FLOOR
	var c := WorldLayout.COTTAGE_POS
	edda.set_home(Vector3(c.x + 1.4, pad + 0.05, c.z - 1.6), atan2(-1.4, 4.95))
	pippa.set_home(_ground(4.6, 0.9) + Vector3.UP * 0.05, -0.5)
	_start_routines()


## Edda and Pippa live their day (NpcPlans: where the story and the clock put
## them; NpcRoutine: the walking, sitting, noticing and barking). After a load
## they are put where the plan says at once.
func _start_routines() -> void:
	var plans := NpcPlans.new(terrain)
	for n in [edda, pippa]:
		var r := NpcRoutine.new()
		r.name = "Routine"
		n.add_child(r)
		r.setup(n, player, world.door, plans)
		r.snap_to_plan()
		_routines.append(r)
	GameState.save_loaded.connect(func():
		for r in _routines:
			r.snap_to_plan())


func _opening() -> void:
	title.label_settings.font = UiStyle.title_font(600)
	fade.visible = true
	fade.modulate.a = 1.0
	title.visible = true
	title.modulate.a = 0.0
	player.lock_input()
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 1.6)
	tw.tween_interval(1.8)
	tw.tween_property(title, "modulate:a", 0.0, 1.2)
	tw.tween_property(fade, "modulate:a", 0.0, 2.4)
	tw.tween_callback(func():
		fade.visible = false
		player.unlock_input()
		director.start_monologue("intro", player))


# --- Story reactions ---------------------------------------------------------------

func _on_spell_cast(spell_id: String, origin: Vector3, _target: Vector3) -> void:
	if spell_id != "spell_field_of_flowers":
		return
	var in_meadow := Vector2(origin.x - WorldLayout.GARDEN_MEADOW.x, origin.z - WorldLayout.GARDEN_MEADOW.z).length() <= WorldLayout.GARDEN_MEADOW_RADIUS
	var state := GameState.quest(QUEST)
	if state == "active" and in_meadow and not _bloom_pending:
		_bloom_pending = true
		await get_tree().create_timer(3.4, false).timeout
		_garden_bloomed()
	elif state == "active" and not in_meadow:
		await get_tree().create_timer(2.0, false).timeout
		GameState.toast.emit("Lovely — but Jonas's meadow is behind the cottage.")
		_pippa_bark_if_near("Wrong meadow! But pretty!")
	elif state == "none":
		_pippa_bark_if_near("WHOA.")


func _garden_bloomed() -> void:
	_bloom_pending = false
	var counted := clampi(int(FlowerField.instance.total() / 6.0) if FlowerField.instance else 120, 40, 400)
	GameState.set_flag("flowers_counted", counted)
	GameState.set_flag("garden_bloomed", true)
	GameState.set_quest(QUEST, "bloomed")
	pippa.set_home(_ground(-0.5, -13.0) + Vector3.UP * 0.05, atan2(-3.5, -11.0))
	pippa.play(&"Hop")
	pippa.bark("GRANDMA! GRANDMA, COME AND LOOK!", 3.5)
	Audio.music_volume(-11.0, 3.0)


func _pippa_bark_if_near(text: String) -> void:
	if pippa.global_position.distance_to(player.global_position) < 26.0:
		pippa.bark(text)


func _on_cast_failed(_spell: SpellDefinition, reason: String) -> void:
	if reason.begins_with("Not indoors"):
		GameState.set_flag("tried_cast_indoors", true)


func _on_quest_changed(id: String, state: String) -> void:
	if id != QUEST:
		return
	if state == "active":
		Audio.sfx("quest_start", -8.0)


func _on_conversation_finished(id: String) -> void:
	if id == "pippa" and GameState.quest(QUEST) == "bloomed":
		pippa.play(&"Hop")
	if id == "pippa" and ending_enabled and _ending_ready():
		_start_ending()


func _ending_ready() -> bool:
	return not _ending_running and not GameState.has_flag("demo_complete") \
		and GameState.quest(QUEST) == "complete" and GameState.quest(StoneQuests.STONE) == "complete" \
		and GameState.quest(StoneQuests.STATUE) == "complete"


## The last beat: dusk on the road, Pippa says good evening to the statue, she
## walks on, and the end card comes up (then she may keep wandering).
func _start_ending() -> void:
	_ending_running = true
	player.lock_input()
	for r in _routines:
		r.paused = true
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 1.6)
	await tw.finished
	GameState.world_date["hour"] = 19.4
	player.teleport(_ground(-3.0, 37.0) + Vector3.UP * 0.15, 0.0)
	pippa.set_home(_ground(-5.3, 38.4) + Vector3.UP * 0.05, atan2(2.3, -1.4))
	await get_tree().create_timer(0.5).timeout
	tw = create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 1.6)
	await tw.finished
	fade.visible = false
	player.unlock_input()
	director.start_conversation("ending", pippa, player)
	while true:
		var done: String = await director.conversation_finished
		if done == "ending":
			break
	_record_ending_memory()
	# She walks on down the road while the light goes out.
	player.scripted_yaw = PI
	player.scripted_walk = Vector2(0.0, -1.0)
	fade.visible = true
	fade.modulate.a = 0.0
	tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(fade, "modulate:a", 1.0, 3.0)
	await tw.finished
	player.scripted_walk = Vector2.ZERO
	GameState.set_flag("demo_complete")
	_ending_running = false
	for r in _routines:
		r.paused = false
	end_card.show_card()


func _on_dialogue_event(event: String, _dialogue_id: String) -> void:
	if event == "memory:" + MEMORY_ID:
		_record_garden_memory()


func _record_garden_memory() -> void:
	var notes: Array[String] = []
	var text := "Grew Jonas Brenn's garden back behind the cottage at Brenn's Meadow. Edda came out to the bench and very deliberately did not cry."
	if GameState.has_flag("heard_jonas_story"):
		text += " He proposed with a radish. She remembered his hat for forty-six years."
		notes.append("heard_jonas_story")
	if GameState.has_flag("conceded_wilt"):
		text += " I told her flowers wilt. She said she'd have had a summer. She was right."
		notes.append("conceded_wilt")
	if GameState.has_flag("heard_teodor_seed_story"):
		text += " Teodor bought seeds from Jonas, fifty years ago — 'for a friend who'd outlive us all.' I should ask him what for."
		notes.append("teodor_bought_seeds_for_her")
	text += " She said weeks, not years. Writing it down so that I do."
	var meadow := WorldLayout.GARDEN_MEADOW
	GameState.record_memory({
		"id": MEMORY_ID,
		"title": "The garden behind Edda's cottage",
		"kind": "shared_moment",
		"participants": [GameState.PROTAGONIST_ID, "char_edda", "char_pippa"],
		"absent_but_present": ["char_jonas_brenn", "char_teodor"],
		"location": {
			"id": "loc_brenn_cottage_back_meadow",
			"region": "reg_brenns_meadow",
			"position": [meadow.x, terrain.height_at(meadow.x, meadow.z), meadow.z],
		},
		"spell": "spell_field_of_flowers",
		"outcome": {
			"garden_restored": true,
			"flower_patches": FlowerField.instance.patches_near(meadow, WorldLayout.GARDEN_MEADOW_RADIUS + 4.0) if FlowerField.instance else 0,
			"flowers_counted_by_pippa": GameState.flag("flowers_counted", 0),
		},
		"relationships": {
			"char_edda": GameState.relationship("char_edda").duplicate(true),
			"char_pippa": GameState.relationship("char_pippa").duplicate(true),
		},
		"promises": [{
			"id": "promise_return_to_edda", "to": "char_edda",
			"text": "Come back in a few weeks. Not years.", "due_in_days": 21, "kept": null,
		}],
		"seeds": notes,
		"tags": ["garden", "jonas", "promise", "mortality", "flowers"],
		"journal_text": text,
	})
	GameState.change_affinity("char_edda", 1, "memory_cottage_garden_restored")


func _record_ending_memory() -> void:
	GameState.record_memory({
		"id": "memory_dusk_on_the_road",
		"title": "Dusk on the road",
		"kind": "journey",
		"participants": [GameState.PROTAGONIST_ID, "char_pippa"],
		"absent_but_present": ["char_edda", "char_jonas_brenn"],
		"location": {"id": "loc_roadside_statue", "region": "reg_brenns_meadow", "position": [StoneQuests.STATUE_POS.x, 0.0, StoneQuests.STATUE_POS.y]},
		"tags": ["leaving", "promise", "counting"],
		"promises": [{"id": "promise_return_to_edda", "to": "char_edda", "text": "Weeks, not years.", "due_in_days": 21, "kept": null}],
		"journal_text": "Left Brenn's Meadow at dusk, down the road, the way most things go. Edda is counting weeks. Pippa is counting from zero, and says it starts when I go. I wrote the date down so that I would.",
	})


## Sun, sky and fog follow the in-game clock.
func _build_time_of_day() -> void:
	_time_of_day = TimeOfDay.new()
	_time_of_day.name = "TimeOfDay"
	add_child(_time_of_day)
	var we := world.get_node("WorldEnvironment") as WorldEnvironment
	_time_of_day.setup(world.sun, we.environment)


## The stone and statue errands, the way-showing beacons, and the spellbook /
## satchel screen.
func _build_stone_errands() -> void:
	_stone_quests = StoneQuests.new()
	_stone_quests.name = "StoneQuests"
	add_child(_stone_quests)
	_stone_quests.setup(terrain, director)
	_waypoints = Waypoints.new()
	_waypoints.name = "Waypoints"
	add_child(_waypoints)
	_waypoints.setup(terrain, player, edda, pippa)
	var book := Spellbook.new()
	book.name = "Spellbook"
	book.player = player
	$UI.add_child(book)
	end_card = EndCard.new()
	end_card.name = "EndCard"
	$UI.add_child(end_card)
