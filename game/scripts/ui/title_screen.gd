class_name TitleScreen
extends Control
## The front door: Begin, Continue (when there is a saved journal), Options,
## Credits, Quit. Shown over the live meadow; Main decides what Begin and
## Continue do.

signal begin_pressed
signal continue_pressed

var _continue_btn: Button
var _options: OptionsPanel
var _credits: CreditsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.menu_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.05, 0.09, 0.42)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(520, 0)
	row.add_child(col)
	col.add_child(_label(EndCard.TITLE, 78, UiStyle.CREAM, true))
	col.add_child(_label(EndCard.TAGLINE, 28, UiStyle.GOLD, false, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	var begin := _button("Begin", func(): begin_pressed.emit())
	col.add_child(begin)
	_continue_btn = _button("Continue", func(): continue_pressed.emit())
	col.add_child(_continue_btn)
	col.add_child(_button("Options", func(): _page(_options)))
	col.add_child(_button("Credits", func(): _page(_credits)))
	col.add_child(_button("Quit", func(): get_tree().quit()))
	col.add_child(_label("Demo 1: The Cottage", 18, Color(UiStyle.CREAM, 0.65)))
	begin.grab_focus()

	var pages := CenterContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pages)
	_options = OptionsPanel.new()
	_options.visible = false
	_options.closed.connect(func(): _options.visible = false)
	pages.add_child(_options)
	_credits = CreditsPanel.new()
	_credits.visible = false
	_credits.closed.connect(func(): _credits.visible = false)
	pages.add_child(_credits)


func set_continue_enabled(on: bool) -> void:
	_continue_btn.disabled = not on


func _page(p: Control) -> void:
	_options.visible = p == _options and not p.visible
	_credits.visible = p == _credits and not p.visible


func _label(text: String, size: int, color: Color, title := false, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiStyle.title_font(700) if title else UiStyle.body_font(italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.08, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b
