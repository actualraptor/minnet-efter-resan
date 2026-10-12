class_name Spellbook
extends Control
## B: the spellbook (every spell she knows, bound to number keys by click, drag or
## key) and I: the satchel (items; a book or scroll can be studied, which spends
## in-game hours, like waiting, and teaches its spell). The world is paused while
## it is open.

signal studied(item_id: String, spell_id: String)

enum Tab { SPELLS, SATCHEL }

var player: Player
var _tab := Tab.SPELLS
var _selected := ""
var _studying := false
var _title: Label
var _content: Control
var _tab_buttons: Array[Button] = []
var _grid: GridContainer
var _detail: VBoxContainer
var _hotbar_wrap: VBoxContainer
var _slots: Array[SpellSlot] = []
var _overlay: Control
var _ov_glyph_box: Control
var _ov_name: Label
var _ov_clock: Label
var _ov_note: Label


# A selectable card in the list (spell or item).
class Card extends PanelContainer:
	signal picked(id: String)
	var id := ""
	var drag_spell := false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(id)

	func _get_drag_data(_at: Vector2) -> Variant:
		if not drag_spell:
			return null
		set_drag_preview(Glyph.for_spell(SpellLibrary.get_def(id), 56.0))
		picked.emit(id)
		return {"spell": id}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.menu_theme()
	_build()
	visible = false
	GameState.spells_changed.connect(_refresh_if_open)
	GameState.inventory_changed.connect(_refresh_if_open)


func _lbl(text: String, size: int, color := UiStyle.INK, title := false, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiStyle.title_font(700) if title else UiStyle.body_font(italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.1, 0.62)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content = center
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.parchment())
	panel.custom_minimum_size = Vector2(1140, 660)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	_title = _lbl("Spellbook", 42, UiStyle.INK, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	for t in [["Spells  (B)", Tab.SPELLS], ["Satchel  (I)", Tab.SATCHEL]]:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(t[1]))
		header.add_child(b)
		_tab_buttons.append(b)
	var close := Button.new()
	close.text = "Close  (Esc)"
	close.pressed.connect(close_book)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)

	_hotbar_wrap = VBoxContainer.new()
	_hotbar_wrap.add_theme_constant_override("separation", 6)
	root.add_child(_hotbar_wrap)
	_hotbar_wrap.add_child(_lbl("On your number keys: click a slot, drop a spell on it, or press 1-9 with a spell selected. Right-click empties a slot.", 16, Color(UiStyle.INK, 0.7), false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_wrap.add_child(row)
	for i in GameState.HOTBAR_SLOTS:
		var s := SpellSlot.make(i, 88.0, true)
		s.clicked.connect(_on_slot_clicked)
		s.dropped.connect(_on_slot_dropped)
		row.add_child(s)
		_slots.append(s)

	_overlay = Control.new()
	_overlay.visible = false
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color(0.04, 0.03, 0.07, 1.0)
	_overlay.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var oc := CenterContainer.new()
	_overlay.add_child(oc)
	oc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 14)
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	oc.add_child(ov)
	_ov_glyph_box = CenterContainer.new()
	ov.add_child(_ov_glyph_box)
	_ov_name = _lbl("", 34, UiStyle.CREAM, true)
	_ov_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_ov_name)
	_ov_clock = _lbl("", 96, UiStyle.GOLD, true)
	_ov_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_ov_clock)
	_ov_note = _lbl("", 22, Color(UiStyle.CREAM, 0.8), false, true)
	_ov_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_ov_note)


# --- open / close ------------------------------------------------------------------

func _can_open() -> bool:
	if get_tree().paused or _studying:
		return false
	if DialogueDirector.instance != null and DialogueDirector.instance.runner.active:
		return false
	return player == null or player.has_control()


func open_book(tab: Tab) -> void:
	_tab = tab
	_selected = ""
	_populate()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_book() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event is InputEventMouse:
		return
	if _studying:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
		return
	var want_spells := event.is_action_pressed("spellbook")
	var want_items := event.is_action_pressed("inventory")
	if visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("journal"):
			close_book()
		elif want_spells or want_items:
			var t := Tab.SPELLS if want_spells else Tab.SATCHEL
			if t == _tab:
				close_book()
			else:
				_set_tab(t)
		else:
			for i in GameState.HOTBAR_SLOTS:
				if event.is_action_pressed("spell_%d" % (i + 1)) and _tab == Tab.SPELLS and _selected != "":
					GameState.bind_spell(i, _selected)
					break
			return
		get_viewport().set_input_as_handled()
	elif (want_spells or want_items) and _can_open():
		get_viewport().set_input_as_handled()
		open_book(Tab.SPELLS if want_spells else Tab.SATCHEL)


func _set_tab(t: Tab) -> void:
	_tab = t
	_selected = ""
	_populate()


func _refresh_if_open() -> void:
	if visible:
		_populate()


# --- list and detail -----------------------------------------------------------------

func _populate() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_title.text = "Spellbook" if _tab == Tab.SPELLS else "Satchel"
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == int(_tab)
	var ids: Array = GameState.known_spells.duplicate() if _tab == Tab.SPELLS else GameState.inventory.keys()
	if not _selected in ids:
		_selected = str(ids[0]) if not ids.is_empty() else ""
	for id in ids:
		_grid.add_child(_make_card(str(id)))
	_hotbar_wrap.visible = _tab == Tab.SPELLS
	_show_detail()
	_refresh_slots()


func _make_card(id: String) -> Card:
	var card := Card.new()
	card.id = id
	card.drag_spell = _tab == Tab.SPELLS
	card.custom_minimum_size = Vector2(285, 76)
	card.picked.connect(_select)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55) if id == _selected else Color(1, 1, 1, 0.22)
	sb.set_corner_radius_all(12)
	sb.border_color = UiStyle.PLUM if id == _selected else Color(UiStyle.GOLD, 0.5)
	sb.set_border_width_all(3 if id == _selected else 1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var label := ""
	var sub := ""
	if _tab == Tab.SPELLS:
		var def := SpellLibrary.get_def(id)
		row.add_child(Glyph.for_spell(def, 54.0))
		label = def.display_name
		sub = "%s  ·  %d mana" % [str(SpellDefinition.Category.keys()[def.category]).capitalize(), int(def.mana_cost)]
		var slot := GameState.hotbar.find(id)
		if slot >= 0:
			sub += "  ·  key %d" % (slot + 1)
	else:
		var item := ItemLibrary.get_item(id)
		row.add_child(Glyph.for_item(item, 54.0))
		label = str(item.get("name", id))
		sub = str(item.get("kind", "item")).capitalize()
		if int(GameState.inventory.get(id, 1)) > 1:
			sub += "  ×%d" % int(GameState.inventory[id])
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_lbl(label, 23, UiStyle.INK, true))
	col.add_child(_lbl(sub, 15, Color(UiStyle.INK, 0.7)))
	row.add_child(col)
	return card


func _select(id: String) -> void:
	_selected = id
	_populate()


func _show_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if _selected == "":
		var msg := "Nothing here yet." if _tab == Tab.SPELLS else "Your satchel holds a pressed flower, a hair ribbon, and a surprising amount of lint. Nothing worth a name yet."
		var l := _lbl(msg, 20, Color(UiStyle.INK, 0.75), false, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_detail.add_child(head)
	var title_col := VBoxContainer.new()
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var desc := ""
	if _tab == Tab.SPELLS:
		var def := SpellLibrary.get_def(_selected)
		head.add_child(Glyph.for_spell(def, 88.0))
		title_col.add_child(_lbl(def.display_name, 40, UiStyle.INK, true))
		title_col.add_child(_lbl(str(SpellDefinition.Category.keys()[def.category]).capitalize() + " magic", 18, UiStyle.PLUM, false, true))
		desc = def.description
	else:
		var item := ItemLibrary.get_item(_selected)
		head.add_child(Glyph.for_item(item, 88.0))
		title_col.add_child(_lbl(str(item.get("name", _selected)), 36, UiStyle.INK, true))
		title_col.add_child(_lbl(str(item.get("kind", "item")).capitalize(), 18, UiStyle.PLUM, false, true))
		desc = str(item.get("desc", ""))
	head.add_child(title_col)
	var d := _lbl(desc, 19, UiStyle.INK, false, true)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(d)
	if _tab == Tab.SPELLS:
		_spell_stats(SpellLibrary.get_def(_selected))
	else:
		_item_actions(ItemLibrary.get_item(_selected))


func _spell_stats(def: SpellDefinition) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 4)
	_detail.add_child(g)
	var rows := [
		["Mana", "%d" % int(def.mana_cost)],
		["Cooldown", "%.1f s" % def.cooldown],
		["Cast time", "%.1f s" % def.cast_time],
		["Indoors", "Yes" if def.allowed_indoors else "No"],
	]
	if def.study_hours > 0.0:
		rows.append(["Took to learn", "%s of study" % _hours(def.study_hours)])
	for r in rows:
		g.add_child(_lbl(r[0], 18, Color(UiStyle.INK, 0.7)))
		g.add_child(_lbl(r[1], 18))
	var slot := GameState.hotbar.find(str(def.id))
	var bound := _lbl("On key %d." % (slot + 1) if slot >= 0 else "Not on a number key yet.", 19, UiStyle.PLUM, false, true)
	_detail.add_child(bound)


func _item_actions(item: Dictionary) -> void:
	var spell_id := str(item.get("teaches", ""))
	var def := SpellLibrary.get_def(spell_id) if spell_id != "" else null
	if def == null:
		return
	var known := GameState.knows_spell(spell_id)
	var info := _lbl("Teaches %s. %s" % [def.display_name, "You know it already." if known else "About %s of study." % _hours(def.study_hours)], 19, UiStyle.PLUM, false, true)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(info)
	var b := Button.new()
	b.text = "Already learned" if known else "Study  (%s)" % _hours(def.study_hours)
	b.disabled = known
	b.pressed.connect(_study.bind(_selected))
	_detail.add_child(b)


func _refresh_slots() -> void:
	var cur := player.caster.current_spell() if player else null
	for i in _slots.size():
		var id := str(GameState.hotbar[i])
		_slots[i].set_spell(id, cur != null and id != "" and str(cur.id) == id)


func _on_slot_clicked(i: int) -> void:
	if _selected != "" and _tab == Tab.SPELLS:
		GameState.bind_spell(i, _selected)


func _on_slot_dropped(i: int, id: String) -> void:
	GameState.bind_spell(i, id)


static func _hours(h: float) -> String:
	return "%d hour%s" % [int(ceilf(h)), "" if ceilf(h) == 1.0 else "s"]


static func _clock_text(h: float) -> String:
	h = fmod(h, 24.0)
	return "%02d:%02d" % [int(h), int((h - floorf(h)) * 60.0)]


# --- studying ----------------------------------------------------------------------

## Reads the item for the spell's study time: the clock runs forward, the calendar
## moves on, and the spell is hers. A book stays in the satchel; a scroll is used up.
func _study(item_id: String) -> void:
	var item := ItemLibrary.get_item(item_id)
	var spell_id := str(item.get("teaches", ""))
	var def := SpellLibrary.get_def(spell_id)
	if def == null or GameState.knows_spell(spell_id) or _studying:
		return
	if player != null and not player.is_on_floor():
		GameState.toast.emit("Not while hovering. The words keep sliding off.")
		return
	_studying = true
	var hours := maxf(def.study_hours, 0.5)
	var start := float(GameState.world_date["hour"])
	for c in _ov_glyph_box.get_children():
		c.queue_free()
	_ov_glyph_box.add_child(Glyph.for_item(item, 130.0))
	_ov_name.text = "Studying  ·  " + str(item.get("name", item_id))
	_ov_clock.text = _clock_text(start)
	_ov_note.text = "%s pass." % _hours(hours)
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	_content.visible = false
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "modulate:a", 1.0, 0.6)
	await fade_in.finished
	var secs := clampf(1.8 + hours * 0.6, 2.5, 9.0)
	var run := create_tween()
	run.tween_method(func(t: float): _ov_clock.text = _clock_text(start + t), 0.0, hours, secs)
	await run.finished
	GameState.advance_time(hours)
	GameState.learn_spell(spell_id)
	if bool(item.get("consumed", false)):
		GameState.take_item(item_id)
	_ov_clock.text = _clock_text(float(GameState.world_date["hour"]))
	_ov_note.text = "%s is yours." % def.display_name
	var slot := GameState.hotbar.find(spell_id)
	if slot >= 0:
		_ov_note.text += "  Number key %d." % (slot + 1)
	await get_tree().create_timer(2.2).timeout
	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "modulate:a", 0.0, 0.6)
	await fade_out.finished
	_overlay.visible = false
	_content.visible = true
	_studying = false
	studied.emit(item_id, spell_id)
	_tab = Tab.SPELLS
	_selected = spell_id
	_populate()
