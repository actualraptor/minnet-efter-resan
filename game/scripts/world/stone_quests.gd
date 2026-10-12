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
const STATUE_MODEL := "res://assets/models/characters/freyja_vroid_game.glb"

var _terrain: MeadowTerrain
var _stone: Inspectable
var _statue: Inspectable
var _alpha_mats: Dictionary = {}


func setup(terrain: MeadowTerrain, director: DialogueDirector) -> void:
	_terrain = terrain
	_stone = _build_stone(_moss_material(STONE_POS))
	_statue = _build_statue()
	_stone.cleaned.connect(_on_cleaned)
	_statue.cleaned.connect(_on_cleaned)
	GameState.spell_cast.connect(_on_spell_cast)
	GameState.spells_changed.connect(_sync)
	GameState.quest_changed.connect(func(_q, _s): _sync())
	director.runner.event_fired.connect(_on_dialogue_event)
	_sync()


## One material set per prop: each one's moss recedes on its own. `at` is where
## the prop stands (moss gathers low, near the ground there).
func _moss_material(at: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grime_stone.gdshader")
	mat.set_shader_parameter("noise", ZoltraakVisuals.noise())
	mat.set_shader_parameter("base_y", _terrain.height_at(at.x, at.y))
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
	s.extent = Vector3(0.9, 1.1, 1.6)
	# Faces the bench, so she reads it as she walks up from there.
	var to_bench := WorldLayout.BENCH_POS - Vector3(STONE_POS.x, 0, STONE_POS.y)
	_place(STONE_POS, atan2(to_bench.x, to_bench.z), s)
	_box(s, Vector3(0.62, 0.95, 0.14), Vector3(0, 0.47, 0), mat)
	_box(s, Vector3(0.5, 0.14, 0.12), Vector3(0, 0.97, 0), mat)
	_box(s, Vector3(0.95, 0.12, 1.55), Vector3(0, 0.05, 0.85), mat)   # the grave kerb, in front of the stone
	s.setup(mat)
	s.plaque = _plaque(s, "JONAS BRENN\nHe hummed when he weeded.", Vector3(0, 0.6, 0.085))
	return s


## The statue is Freyja herself: her own game model posed holding a staff, every
## surface turned to weathered grey stone with the same moss. Hair cards and lashes
## keep their alpha cut-out. A pointed hat she has never owned sits on her head.
func _build_statue() -> Inspectable:
	var s := Inspectable.new()
	s.name = "RoadsideStatue"
	s.id = "statue"
	s.dialogue_id = "statue"
	s.prompt = "Look at the statue"
	s.extent = Vector3(1.6, 3.0, 1.6)
	_place(STATUE_POS, deg_to_rad(90.0), s)   # faces the road (+x)
	var plain := _moss_material(STATUE_POS)
	s.setup(plain)
	_box(s, Vector3(1.25, 0.7, 1.25), Vector3(0, 0.35, 0), plain)
	var scene := load(STATUE_MODEL) as PackedScene
	if scene == null:
		push_warning("Statue model missing: " + STATUE_MODEL)
	else:
		var model := scene.instantiate() as Node3D
		model.position = Vector3(0, 0.7, 0)
		model.scale = Vector3.ONE * 1.12
		s.add_child(model)
		_pose_statue(model)
		_turn_to_stone(model, s, plain)
		_add_hat_and_staff(model, s, plain)
	s.plaque = _plaque(s, "FREYJA\nwho made it rain on one tomato,\nand then on all of us.", Vector3(0, 0.36, 0.64))
	return s


func _pose_statue(model: Node3D) -> void:
	var anim := CharacterVisual.find_animation_player(model)
	if anim and CharacterVisual.use_humanoid_library(model) and anim.has_animation(&"Torch"):
		anim.play(&"Torch")
		anim.seek(0.5, true)
		anim.pause()


func _turn_to_stone(model: Node3D, prop: Inspectable, plain: ShaderMaterial) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.name == &"Staff":
			mi.visible = false   # her real staff is a prop of the player, not of the stone
			continue
		# Eyelets, laces and charms are a few millimetres: not worth a draw call in stone.
		if mi.get_aabb().size.length() < 0.07:
			mi.visible = false
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var cut := src is BaseMaterial3D and (src as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and (src as BaseMaterial3D).albedo_texture != null
			if not cut:
				mi.set_surface_override_material(i, plain)
				continue
			if not _alpha_mats.has(src):
				var m := _moss_material(STATUE_POS)
				var b := src as BaseMaterial3D
				m.set_shader_parameter("use_alpha_tex", true)
				m.set_shader_parameter("albedo_tex", b.albedo_texture)
				m.set_shader_parameter("alpha_cut", b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
				prop.add_material(m)
				_alpha_mats[src] = m
			mi.set_surface_override_material(i, _alpha_mats[src])


func _add_hat_and_staff(model: Node3D, prop: Inspectable, mat: ShaderMaterial) -> void:
	var sk: Skeleton3D = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	if sk == null:
		return
	var head := sk.find_bone("Head")
	if head >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "Head"
		sk.add_child(att)
		var hat := CylinderMesh.new()
		hat.top_radius = 0.0
		hat.bottom_radius = 0.17
		hat.height = 0.3
		_body(att, hat, Vector3(0, 0.2, 0.0), mat)
		var brim := CylinderMesh.new()
		brim.top_radius = 0.26
		brim.bottom_radius = 0.26
		brim.height = 0.015
		_body(att, brim, Vector3(0, 0.07, 0.0), mat)
	# A plain stone staff planted at her right hand (the bone pose is read here).
	var hand := sk.find_bone("RightHand")
	var at := Vector3(-0.34, 0.9, 0.12)
	if hand >= 0:
		var p := sk.global_transform * sk.get_bone_global_pose(hand).origin
		at = prop.to_local(p)
	var staff := CylinderMesh.new()
	staff.top_radius = 0.028
	staff.bottom_radius = 0.034
	staff.height = 2.35
	_body(prop, staff, Vector3(at.x, 0.7 + 2.35 * 0.5, at.z), mat)
	var orb := SphereMesh.new()
	orb.radius = 0.08
	orb.height = 0.16
	_body(prop, orb, Vector3(at.x, 0.7 + 2.38, at.z), mat)


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
		"journal_text": "Planted blue flowers at Jonas Brenn's stone while Edda watched from her bench and did not watch. She gave me her mother's household book. The rhyme for stains in it is a real spell: two hours of study, and it's mine. Her mother used it on gravy for forty years and never knew.",
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
