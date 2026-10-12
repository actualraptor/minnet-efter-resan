class_name CreditsPanel
extends PanelContainer
## Every licence in the build, from data/credits.json (kept in step with
## docs/ASSETS.md). Shared by the title screen and the pause menu.

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.parchment())
	custom_minimum_size = Vector2(620, 520)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(540, 0)
	text.add_theme_font_override("normal_font", UiStyle.body_font())
	text.add_theme_font_override("bold_font", UiStyle.title_font(700))
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("bold_font_size", 26)
	text.add_theme_color_override("default_color", UiStyle.INK)
	text.text = _build_text()
	scroll.add_child(text)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): closed.emit())
	col.add_child(back)


func _build_text() -> String:
	var data: Variant = DialogueRunner._read_json("res://data/credits.json")
	if not (data is Array):
		return "Credits unavailable."
	var t := ""
	for section in data:
		t += "[b]%s[/b]\n" % str(section.get("title", ""))
		for line in section.get("lines", []):
			t += "%s\n" % str(line)
		t += "\n"
	return t
