class_name OptionsPanel
extends PanelContainer
## Volumes, mouse sensitivity and fullscreen. Shared by the title screen and the
## pause menu; every change is applied and saved at once.

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.parchment())
	custom_minimum_size = Vector2(560, 420)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var head := _lbl("Options", 34, true)
	col.add_child(head)
	_slider(col, "Master volume", Settings.master, 0.0, 1.0, func(v): Settings.master = v)
	_slider(col, "Music", Settings.music, 0.0, 1.0, func(v): Settings.music = v)
	_slider(col, "Ambience (wind, birds)", Settings.ambience, 0.0, 1.0, func(v): Settings.ambience = v)
	_slider(col, "Effects", Settings.effects, 0.0, 1.0, func(v): Settings.effects = v)
	_slider(col, "Mouse sensitivity", Settings.mouse, 0.3, 2.5, func(v): Settings.mouse = v)
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_color_override("font_color", UiStyle.INK)
	fs.add_theme_color_override("font_hover_color", UiStyle.INK)
	fs.toggled.connect(func(on: bool):
		Settings.fullscreen = on
		_changed())
	col.add_child(fs)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): closed.emit())
	col.add_child(back)


func _lbl(text: String, size: int, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiStyle.title_font(700) if title else UiStyle.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiStyle.INK)
	return l


func _slider(parent: Control, label: String, value: float, lo: float, hi: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var l := _lbl(label, 20)
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float):
		setter.call(v)
		_changed())
	row.add_child(s)


func _changed() -> void:
	Settings.apply()
	Settings.save_settings()
