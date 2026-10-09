class_name Hud
extends Control
## Minimal fantasy HUD: equipped spell + mana, interaction prompt, quest
## tracker, gentle toasts and a "memory recorded" card.

@export var player_path: NodePath

var _player: Player
var _spell_name: Label
var _mana_bar: ProgressBar
var _prompt: PanelContainer
var _prompt_label: Label
var _quest_box: VBoxContainer
var _quest_title: Label
var _quest_obj: Label
var _toast: Label
var _memory_card: PanelContainer
var _memory_title: Label
var _memory_body: Label
var _date: Label
var _quests: Dictionary = {}
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests = DialogueRunner._read_json("res://data/quests/quests.json")
	_build()
	_player = get_node_or_null(player_path) as Player
	if _player:
		_player.focus_changed.connect(_on_focus)
		_player.caster.mana_changed.connect(_on_mana)
		_player.caster.equipped_changed.connect(_on_spell)
		_on_spell(_player.caster.current_spell())
	GameState.quest_changed.connect(_on_quest)
	GameState.toast.connect(show_toast)
	GameState.memory_recorded.connect(_on_memory)
	if DialogueDirector.instance:
		DialogueDirector.instance.conversation_started.connect(func(_id): _fade_world_ui(0.0))
		DialogueDirector.instance.conversation_finished.connect(func(_id): _fade_world_ui(1.0))
	_refresh_quest()


func _label(size: int, color: Color, title := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiStyle.title_font() if title else UiStyle.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.12, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	# Spell (bottom-left)
	var spell := PanelContainer.new()
	spell.name = "SpellPanel"
	spell.add_theme_stylebox_override("panel", UiStyle.pill())
	spell.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	spell.position = Vector2(34, -104)
	spell.anchor_top = 1.0
	spell.anchor_bottom = 1.0
	spell.offset_top = -104
	spell.offset_left = 34
	add_child(spell)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	spell.add_child(sv)
	var row := HBoxContainer.new()
	sv.add_child(row)
	var glyph := _label(26, UiStyle.GOLD, true)
	glyph.text = "❀ "
	row.add_child(glyph)
	_spell_name = _label(26, UiStyle.CREAM, true)
	row.add_child(_spell_name)
	var hint := _label(16, Color(UiStyle.CREAM, 0.7))
	hint.text = "   LMB / F"
	row.add_child(hint)
	_mana_bar = ProgressBar.new()
	_mana_bar.custom_minimum_size = Vector2(230, 7)
	_mana_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#bfe39a")
	fill.set_corner_radius_all(4)
	_mana_bar.add_theme_stylebox_override("background", bg)
	_mana_bar.add_theme_stylebox_override("fill", fill)
	sv.add_child(_mana_bar)

	# Interaction prompt (centre, lower third)
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiStyle.pill(0.7))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -200
	_prompt.offset_bottom = -152
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.visible = false
	add_child(_prompt)
	_prompt_label = _label(22, UiStyle.CREAM)
	_prompt.add_child(_prompt_label)

	# Quest tracker (top-right)
	_quest_box = VBoxContainer.new()
	_quest_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_box.anchor_left = 1.0
	_quest_box.anchor_right = 1.0
	_quest_box.offset_left = -470
	_quest_box.offset_right = -36
	_quest_box.offset_top = 30
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quest_box)
	_quest_title = _label(27, UiStyle.GOLD, true)
	_quest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_box.add_child(_quest_title)
	_quest_obj = _label(19, UiStyle.CREAM)
	_quest_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_box.add_child(_quest_obj)

	# Date (top-left)
	_date = _label(19, Color(UiStyle.CREAM, 0.85))
	_date.position = Vector2(36, 30)
	_date.text = "Brenn's Meadow  ·  " + GameState.format_date()
	add_child(_date)

	# Toast (top-centre)
	_toast = _label(24, UiStyle.CREAM)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 90
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)

	# Memory card
	_memory_card = PanelContainer.new()
	_memory_card.add_theme_stylebox_override("panel", UiStyle.parchment())
	_memory_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_memory_card.anchor_left = 0.5
	_memory_card.anchor_right = 0.5
	_memory_card.offset_left = -330
	_memory_card.offset_right = 330
	_memory_card.offset_top = 120
	_memory_card.modulate.a = 0.0
	_memory_card.visible = false
	add_child(_memory_card)
	var mv := VBoxContainer.new()
	_memory_card.add_child(mv)
	var mh := _label(18, UiStyle.PLUM)
	mh.remove_theme_color_override("font_shadow_color")
	mh.text = "✦  A memory, written down  ✦"
	mh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(mh)
	_memory_title = _label(30, UiStyle.INK, true)
	_memory_title.remove_theme_color_override("font_shadow_color")
	_memory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_memory_title)
	_memory_body = _label(19, UiStyle.INK)
	_memory_body.remove_theme_color_override("font_shadow_color")
	_memory_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_memory_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_memory_body)


func _on_focus(target: Node) -> void:
	if target and target.has_method("interaction_prompt"):
		_prompt_label.text = "E   " + target.interaction_prompt()
		_prompt.visible = true
	else:
		_prompt.visible = false


func _on_mana(mana: float, max_mana: float) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana


func _on_spell(spell: SpellDefinition) -> void:
	_spell_name.text = spell.display_name if spell else "—"


func _on_quest(_id: String, _state: String) -> void:
	_refresh_quest()
	var q: Dictionary = _quests.get(_id, {})
	if _state == "active":
		show_toast("New errand:  " + str(q.get("title", _id)))


func _refresh_quest() -> void:
	for id in _quests:
		var state := GameState.quest(id)
		if state != "none":
			_quest_title.text = _quests[id]["title"]
			_quest_obj.text = _quests[id]["states"].get(state, "")
			_quest_box.visible = true
			return
	_quest_box.visible = false


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _on_memory(memory: Dictionary) -> void:
	_memory_title.text = memory.get("title", "")
	_memory_body.text = memory.get("journal_text", "")
	_memory_card.visible = true
	Audio.sfx("memory_chime", -6.0, 0.0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_memory_card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(6.5)
	tw.tween_property(_memory_card, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _memory_card.visible = false)


func _fade_world_ui(a: float) -> void:
	for n in [_quest_box, _date]:
		create_tween().tween_property(n, "modulate:a", a, 0.3)
	var spell_panel := get_node("SpellPanel")
	create_tween().tween_property(spell_panel, "modulate:a", a, 0.3)
	if a < 0.5:
		_prompt.visible = false
