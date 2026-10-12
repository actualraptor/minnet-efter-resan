extends Node
## Dev: screenshots of the spellbook, satchel, study screen, HUD hotbar and the
## mossy/clean stone and statue.
##   godot --path game -- --dbg --book --out=<dir>
var _out := ""
var _book: Spellbook
var _p: Player


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(label + ".png"))
	print("BOOK snap %s" % label)


func _view(pos: Vector2, from_dir: Vector2, dist: float, zoom: float) -> void:
	var terrain: MeadowTerrain = get_parent().terrain
	var at := pos + from_dir.normalized() * dist
	var yaw := atan2(-from_dir.x, -from_dir.y)
	_p.teleport(Vector3(at.x, terrain.height_at(at.x, at.y) + 0.2, at.y), yaw)
	var rig: CameraRig = _p.camera_rig
	rig.zoom = zoom
	rig.pitch = deg_to_rad(-8.0)
	rig.yaw = yaw + PI + 0.9   # over the shoulder, so she does not hide the prop


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main := get_parent()
	main.get_node("UI").visible = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_p = main.player
	_book = main.get_node("UI/Spellbook")
	var quests: StoneQuests = main.get_node("StoneQuests")
	GameState.set_quest("garden_of_jonas", "complete")
	GameState.set_quest("jonas_stone", "book")
	GameState.give_item("household_book")
	await _wait(1.5)
	await _snap("hud_before")

	_book.open_book(Spellbook.Tab.SPELLS)
	await _wait(0.3)
	await _snap("book_spells")
	_book.open_book(Spellbook.Tab.SATCHEL)
	await _wait(0.3)
	await _snap("book_satchel")

	# Study: mid-clock and the result.
	_book._study("household_book")
	await _wait(3.0)
	await _snap("study_overlay")
	await _wait(5.0)
	await _snap("book_after_study")
	_book._select("spell_stain_free")
	await _wait(0.2)
	await _snap("book_spells_new")
	_book.close_book()
	await _wait(0.5)
	await _snap("hud_after")

	# Props: moss, then clean.
	var sp := StoneQuests.STONE_POS
	var to_bench := (Vector2(WorldLayout.BENCH_POS.x, WorldLayout.BENCH_POS.z) - sp)
	_view(sp, to_bench, 3.6, 0.9)
	await _wait(0.6)
	await _snap("stone_moss")
	quests._stone.clean()
	await _wait(0.5)
	await _snap("stone_cleaning")
	await _wait(3.0)
	await _snap("stone_clean")
	var st := StoneQuests.STATUE_POS
	_view(st, Vector2(1, 0.25), 7.0, 1.1)
	await _wait(0.6)
	await _snap("statue_moss")
	quests._statue.clean()
	await _wait(4.5)
	_view(st, Vector2(1, 0.25), 4.2, 0.8)
	await _wait(0.4)
	await _snap("statue_clean")
	get_tree().quit()
