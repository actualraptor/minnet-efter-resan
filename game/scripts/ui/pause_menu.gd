class_name PauseMenu
extends Control
## Escape: pause, the mage's journal (errands + recorded memories), save/load,
## controls and quit.

var _root: PanelContainer
var _journal: RichTextLabel
var _main: VBoxContainer
var _quests: Dictionary = {}
var _options: OptionsPanel
var _credits: CreditsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.menu_theme()
	_quests = DialogueRunner._read_json("res://data/quests/quests.json")
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	center.add_child(row)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	_main.custom_minimum_size = Vector2(300, 0)
	row.add_child(_main)
	var title := Label.new()
	title.text = "Minnet efter resan"
	title.add_theme_font_override("font", UiStyle.title_font(700))
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiStyle.CREAM)
	_main.add_child(title)
	var sub := Label.new()
	sub.text = "Demo 1: The Cottage"
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(UiStyle.CREAM, 0.7))
	_main.add_child(sub)
	for item in [["Resume", _resume], ["Save journal", _save], ["Load journal", _load], ["Options", _show_options], ["Credits", _show_credits], ["Begin again", _again], ["Quit", _quit]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1])
		_main.add_child(b)
	var controls := Label.new()
	controls.text = "WASD move · Shift run · Space jump\nMouse look · E interact / talk\nLMB or F cast · 1-9 spells · B spellbook · I satchel\nTab journal · Esc pause · F5/F9 save/load"
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color(UiStyle.CREAM, 0.8))
	_main.add_child(controls)

	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", UiStyle.parchment())
	_root.custom_minimum_size = Vector2(620, 520)
	row.add_child(_root)
	_journal = RichTextLabel.new()
	_journal.bbcode_enabled = true
	_journal.add_theme_font_override("normal_font", UiStyle.body_font())
	_journal.add_theme_font_override("bold_font", UiStyle.title_font(700))
	_journal.add_theme_font_override("italics_font", UiStyle.body_font(true))
	_journal.add_theme_font_size_override("normal_font_size", 19)
	_journal.add_theme_font_size_override("bold_font_size", 28)
	_journal.add_theme_font_size_override("italics_font_size", 19)
	_journal.add_theme_color_override("default_color", UiStyle.INK)
	_root.add_child(_journal)
	_options = OptionsPanel.new()
	_options.visible = false
	_options.closed.connect(_show_journal)
	row.add_child(_options)
	_credits = CreditsPanel.new()
	_credits.visible = false
	_credits.closed.connect(_show_journal)
	row.add_child(_credits)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		elif not _dialogue_active():
			_open()
	elif event.is_action_pressed("journal") and not _dialogue_active():
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		else:
			_open()
	elif event.is_action_pressed("quick_save") and not visible:
		GameState.save_game()
	elif event.is_action_pressed("quick_load") and not visible:
		GameState.load_game()


func _dialogue_active() -> bool:
	return DialogueDirector.instance != null and DialogueDirector.instance.runner.active


func _open() -> void:
	_refresh_journal()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_main.get_child(2) as Button).grab_focus()


func _show_journal() -> void:
	_options.visible = false
	_credits.visible = false
	_root.visible = true


func _show_options() -> void:
	_root.visible = false
	_credits.visible = false
	_options.visible = true


func _show_credits() -> void:
	_root.visible = false
	_options.visible = false
	_credits.visible = true


func _again() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()


func _resume() -> void:
	_show_journal()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save() -> void:
	GameState.save_game()
	_refresh_journal()


func _load() -> void:
	if GameState.load_game():
		_resume()


func _quit() -> void:
	get_tree().quit()


func _refresh_journal() -> void:
	var t := "[b]Journal[/b]\n[i]%s[/i]\n\n" % GameState.format_date()
	var any_q := false
	for id in _quests:
		var state := GameState.quest(id)
		if state == "none":
			continue
		any_q = true
		t += "[b]%s[/b]\n%s\n\n" % [_quests[id]["title"], _quests[id]["journal"].get(state, "")]
	if not any_q:
		t += "Nothing pressing. A road, a cottage, smoke from a chimney.\n\n"
	if not GameState.memories.is_empty():
		t += "[b]Memories[/b]\n"
		for m in GameState.memories:
			t += "[i]%s[/i]\n%s\n\n" % [m.get("title", m.get("id")), m.get("journal_text", "")]
	_journal.text = t
