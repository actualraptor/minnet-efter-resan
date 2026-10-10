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

var _marker: GPUParticles3D
var _bloom_pending := false


func _ready() -> void:
	world.build(terrain)
	_place_cast()
	_build_quest_marker()
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
		for k in ["face", "spell", "pose", "walk", "waist", "feet", "side", "hand", "jump", "outfit", "vroid"]:
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
	_opening()


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


func _place_cast() -> void:
	var s := WorldLayout.PLAYER_START
	player.teleport(_ground(s.x, s.z) + Vector3.UP * 0.1, PI)
	# Edda by the armchair, facing the door; Pippa by her carrots.
	var pad := terrain.pad_height() + WorldLayout.COTTAGE_FLOOR
	var c := WorldLayout.COTTAGE_POS
	edda.set_home(Vector3(c.x + 1.4, pad + 0.05, c.z - 1.6), atan2(-1.4, 4.95))
	pippa.set_home(_ground(4.6, 0.9) + Vector3.UP * 0.05, -0.5)
	if GameState.quest(QUEST) in ["bloomed", "complete"]:
		_move_edda_to_bench()


func _move_edda_to_bench() -> void:
	var b := WorldLayout.BENCH_POS
	var to_meadow := WorldLayout.GARDEN_MEADOW - b
	var yaw := atan2(to_meadow.x, to_meadow.z)
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var p := b + side * 1.2
	edda.set_home(_ground(p.x, p.z) + Vector3.UP * 0.05, yaw)


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
	_move_edda_to_bench()
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
	_marker.emitting = state == "active"
	if state == "active":
		Audio.sfx("quest_start", -8.0)


func _on_conversation_finished(id: String) -> void:
	if id == "pippa" and GameState.quest(QUEST) == "bloomed":
		pippa.play(&"Hop")


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


func _build_quest_marker() -> void:
	_marker = GPUParticles3D.new()
	_marker.name = "GardenMarker"
	_marker.amount = 40
	_marker.lifetime = 4.0
	_marker.emitting = GameState.quest(QUEST) == "active"
	_marker.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.color = Color(1.0, 0.92, 0.55)
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.4, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_marker.process_material = pm
	_marker.draw_pass_1 = SpellCaster._mote_mesh(0.09)
	add_child(_marker)
	var m := WorldLayout.GARDEN_MEADOW
	_marker.global_position = _ground(m.x, m.z) + Vector3.UP * 0.8
