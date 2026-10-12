class_name StoneQuests
extends Node
## The two small stone errands after the garden: flowers for Jonas's headstone
## (Edda gives her mother's book; studying it teaches Fläckfri) and the mossed-over
## statue by the road (clean it, read it, tell Pippa). Builds both props, watches
## casts and reading, and keeps the props in step with GameState flags, so
## save/load needs nothing more.

const STONE := "jonas_stone"
const STATUE := "statue_by_the_road"
const STAIN_FREE := "spell_stain_free"
const STONE_POS := Vector2(12.8, -15.6)
const STATUE_POS := Vector2(-8.0, 40.0)

var _terrain: MeadowTerrain
var _stone: Inspectable
var _statue: Inspectable
var _marker: GPUParticles3D


func setup(terrain: MeadowTerrain, director: DialogueDirector, marker: GPUParticles3D) -> void:
	_terrain = terrain
	_marker = marker
	_stone = _build_stone(_moss_material())
	_statue = _build_statue(_moss_material())
	_stone.cleaned.connect(_on_cleaned)
	_statue.cleaned.connect(_on_cleaned)
	GameState.spell_cast.connect(_on_spell_cast)
	GameState.spells_changed.connect(_sync)
	GameState.quest_changed.connect(func(_q, _s): _sync())
	director.runner.event_fired.connect(_on_dialogue_event)
	_sync()


## One material per prop: each one's moss recedes on its own.
func _moss_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grime_stone.gdshader")
	mat.set_shader_parameter("noise", ZoltraakVisuals.noise())
	return mat


func _place(p: Vector2, yaw: float, n: Node3D) -> void:
	add_child(n)
	n.global_position = Vector3(p.x, _terrain.height_at(p.x, p.y), p.y)
	n.rotation.y = yaw


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	_body(parent, b, pos, mat)


func _body(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


func _plaque(parent: Node3D, text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0028
	l.outline_size = 0
	l.modulate = Color(0.2, 0.17, 0.14, 0.0)
	l.position = pos
	parent.add_child(l)
	return l


func _build_stone(mat: ShaderMaterial) -> Inspectable:
	var s := Inspectable.new()
	s.name = "JonasStone"
	s.id = "jonas_stone"
	s.dialogue_id = "grave"
	s.prompt = "Read the stone"
	# Faces the bench, so she reads it as she walks up from there.
	var to_bench := WorldLayout.BENCH_POS - Vector3(STONE_POS.x, 0, STONE_POS.y)
	_place(STONE_POS, atan2(to_bench.x, to_bench.z), s)
	_box(s, Vector3(0.62, 0.95, 0.14), Vector3(0, 0.47, 0), mat)
	_box(s, Vector3(0.5, 0.14, 0.12), Vector3(0, 0.97, 0), mat)
	_box(s, Vector3(0.95, 0.12, 1.55), Vector3(0, 0.05, 0.85), mat)   # the grave kerb, in front of the stone
	s.setup(mat)
	s.plaque = _plaque(s, "JONAS BRENN\nHe hummed when he weeded.", Vector3(0, 0.6, 0.085))
	return s


func _build_statue(mat: ShaderMaterial) -> Inspectable:
	var s := Inspectable.new()
	s.name = "RoadsideStatue"
	s.id = "statue"
	s.dialogue_id = "statue"
	s.prompt = "Look at the statue"
	_place(STATUE_POS, deg_to_rad(90.0), s)   # faces the road (+x)
	_box(s, Vector3(1.25, 0.7, 1.25), Vector3(0, 0.35, 0), mat)
	var robe := CylinderMesh.new()
	robe.top_radius = 0.2
	robe.bottom_radius = 0.42
	robe.height = 1.55
	_body(s, robe, Vector3(0, 1.47, 0), mat)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_body(s, head, Vector3(0, 2.4, 0), mat)
	_box(s, Vector3(0.78, 0.22, 0.34), Vector3(0, 2.1, 0), mat)   # shoulders
	var hat := CylinderMesh.new()   # a hat she has never owned
	hat.top_radius = 0.0
	hat.bottom_radius = 0.34
	hat.height = 0.55
	_body(s, hat, Vector3(0, 2.8, 0), mat)
	var staff := CylinderMesh.new()
	staff.top_radius = 0.035
	staff.bottom_radius = 0.045
	staff.height = 2.5
	_body(s, staff, Vector3(0.42, 1.95, 0.12), mat)
	s.setup(mat)
	s.plaque = _plaque(s, "FREYJA\nwho made it rain on one tomato,\nand then on all of us.", Vector3(0, 0.36, 0.64))
	return s


# --- story ---------------------------------------------------------------------------

func _on_spell_cast(spell_id: String, origin: Vector3, _target: Vector3) -> void:
	if spell_id != "spell_field_of_flowers" or GameState.quest(STONE) != "active":
		return
	if Vector2(origin.x - STONE_POS.x, origin.z - STONE_POS.y).length() > 8.0:
		return
	await get_tree().create_timer(3.4, false).timeout
	GameState.set_flag("stone_planted")
	GameState.set_quest(STONE, "planted")


func _on_cleaned(id: String) -> void:
	GameState.set_flag("clean_" + id)


func _on_dialogue_event(event: String, _dialogue_id: String) -> void:
	if event == "memory:memory_statue_by_the_road":
		_record_statue_memory()


## Learning Fläckfri from the book is what completes the first errand.
func _sync() -> void:
	if GameState.quest(STONE) == "book" and GameState.knows_spell(STAIN_FREE):
		GameState.set_quest(STONE, "complete")
		_record_stone_memory()
	for i in [_stone, _statue]:
		var want_clean := GameState.has_flag("clean_" + i.id)
		if want_clean == i.is_dirty():
			i.set_clean(want_clean)
	var target := STONE_POS if GameState.quest(STONE) in ["active"] else STATUE_POS
	_marker.global_position = Vector3(target.x, _terrain.height_at(target.x, target.y) + 0.8, target.y)
	_marker.emitting = GameState.quest(STONE) == "active" or (GameState.quest(STATUE) == "active" and not GameState.has_flag("clean_statue"))


func _record_stone_memory() -> void:
	var p := STONE_POS
	GameState.record_memory({
		"id": "memory_jonas_stone_flowers",
		"title": "Flowers at Jonas's stone",
		"kind": "gift",
		"participants": [GameState.PROTAGONIST_ID, "char_edda", "char_pippa"],
		"absent_but_present": ["char_jonas_brenn"],
		"location": {"id": "loc_jonas_stone", "region": "reg_brenns_meadow", "position": [p.x, _terrain.height_at(p.x, p.y), p.y]},
		"spell": "spell_field_of_flowers",
		"outcome": {"learned_spell": STAIN_FREE, "item": "household_book"},
		"tags": ["grave", "jonas", "household", "inheritance", "small_magic"],
		"journal_text": "Planted blue flowers at Jonas Brenn's stone while Edda watched from the window and did not watch. She gave me her mother's household book. The rhyme for stains in it is a real spell: two hours of study, and it's mine. Her mother used it on gravy for forty years and never knew.",
	})
	GameState.change_affinity("char_edda", 1, "memory_jonas_stone_flowers")


func _record_statue_memory() -> void:
	var text := "The statue by the road is me. 'Freyja, who made it rain on one tomato, and then on all of us.' I made it rain on a plant for an afternoon and never looked behind me."
	if GameState.has_flag("statue_forgot"):
		text += " I told Pippa I didn't remember. She said she'd said good morning to it every day. I wrote that down so that I would."
	else:
		text += " Pippa wanted to know if it had the ears. It has the wrong hat."
	var p := STATUE_POS
	GameState.record_memory({
		"id": "memory_statue_by_the_road",
		"title": "Good morning, statue",
		"kind": "shared_moment",
		"participants": [GameState.PROTAGONIST_ID, "char_pippa"],
		"location": {"id": "loc_roadside_statue", "region": "reg_brenns_meadow", "position": [p.x, _terrain.height_at(p.x, p.y), p.y]},
		"spell": STAIN_FREE,
		"outcome": {"statue_cleaned": true, "plaque_read": true},
		"tags": ["statue", "remembering", "pippa", "small_magic"],
		"journal_text": text,
	})
	GameState.change_affinity("char_pippa", 2, "memory_statue_by_the_road")
