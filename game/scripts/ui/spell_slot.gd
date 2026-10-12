class_name SpellSlot
extends PanelContainer
## One number-key slot. In the spellbook it is interactive (click to bind the
## selected spell, drop a spell on it, right-click to clear, drag to move); on
## the HUD it only shows what is on the key, which one is ready and cooldown.

signal clicked(index: int)
signal dropped(index: int, spell_id: String)

var index := 0
var spell_id := ""
var equipped := false
var cooldown := 0.0   # 0..1 fraction still cooling down
var interactive := false
var _glyph: Glyph
var _key: Label
var _name: Label


static func make(i: int, px: float, interactive_: bool) -> SpellSlot:
	var s := SpellSlot.new()
	s.index = i
	s.interactive = interactive_
	s.custom_minimum_size = Vector2(px, px + (40.0 if interactive_ else 0.0))
	s.mouse_filter = Control.MOUSE_FILTER_STOP if interactive_ else Control.MOUSE_FILTER_IGNORE
	s._build(px)
	return s


func _build(px: float) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px) * 0.62
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(holder)
	_glyph = Glyph.make("sparkle", Color.WHITE, px * 0.62)
	_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_glyph)
	_key = Label.new()
	_key.text = str(index + 1)
	_key.add_theme_font_size_override("font_size", 15)
	_key.add_theme_color_override("font_color", UiStyle.GOLD)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	if interactive:
		_name = Label.new()
		_name.add_theme_font_size_override("font_size", 13)
		_name.add_theme_color_override("font_color", UiStyle.CREAM)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_name.max_lines_visible = 2
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_name)
	refresh()


func set_spell(id: String, is_equipped := false) -> void:
	spell_id = id
	equipped = is_equipped
	refresh()


func refresh() -> void:
	var def := SpellLibrary.get_def(spell_id) if spell_id != "" else null
	_glyph.visible = def != null
	if def:
		var l := Glyph.look_of(def)
		_glyph.kind = l["kind"]
		_glyph.tint = l["tint"]
		_glyph.queue_redraw()
	if _name:
		_name.text = def.display_name if def else "—"
	tooltip_text = def.display_name if def and interactive else ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.13, 0.2, 0.86 if def else 0.16)
	sb.set_corner_radius_all(12)
	sb.border_color = UiStyle.GOLD if equipped else Color(UiStyle.GOLD, 0.35 if def else 0.18)
	sb.set_border_width_all(3 if equipped else 1)
	add_theme_stylebox_override("panel", sb)
	queue_redraw()


func _draw() -> void:
	if cooldown > 0.01:
		var h := size.y * clampf(cooldown, 0.0, 1.0)
		draw_rect(Rect2(0, size.y - h, size.x, h), Color(0.05, 0.03, 0.08, 0.55))


# --- interaction (spellbook only) ----------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not interactive or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		dropped.emit(index, "")


func _get_drag_data(_at: Vector2) -> Variant:
	if not interactive or spell_id == "":
		return null
	var def := SpellLibrary.get_def(spell_id)
	set_drag_preview(Glyph.for_spell(def, 56.0))
	return {"spell": spell_id}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return interactive and data is Dictionary and data.has("spell")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(index, str(data["spell"]))
