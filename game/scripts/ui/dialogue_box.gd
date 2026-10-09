class_name DialogueBox
extends Control
## Subtitle-style dialogue panel: speaker name plate, typewriter text that can
## be completed early, an advance indicator and numbered choices.

const CHARS_PER_SECOND := 48.0

var runner: DialogueRunner:
	set(v):
		runner = v
		runner.started.connect(_on_started)
		runner.line_shown.connect(_on_line)
		runner.choices_shown.connect(_on_choices)
		runner.finished.connect(_on_finished)

var _panel: PanelContainer
var _name_plate: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _arrow: Label
var _typing := false
var _pause_left := 0.0
var _showing_choices := false
var _choice_data: Array = []
var _line_started_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 1.0
	margin.offset_top = -250
	margin.add_theme_constant_override("margin_left", 160)
	margin.add_theme_constant_override("margin_right", 160)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.add_theme_constant_override("separation", -6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var plate_row := HBoxContainer.new()
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(plate_row)
	var plate_pad := Control.new()
	plate_pad.custom_minimum_size = Vector2(26, 0)
	plate_row.add_child(plate_pad)
	_name_plate = PanelContainer.new()
	_name_plate.add_theme_stylebox_override("panel", UiStyle.plate(Color("#9fc79a")))
	_name_plate.z_index = 1
	plate_row.add_child(_name_plate)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", UiStyle.title_font())
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color("#2f2433"))
	_name_plate.add_child(_name_label)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.parchment())
	_panel.custom_minimum_size = Vector2(0, 150)
	stack.add_child(_panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	_panel.add_child(inner)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", UiStyle.body_font())
	_text.add_theme_font_override("italics_font", UiStyle.body_font(true))
	_text.add_theme_font_size_override("normal_font_size", 25)
	_text.add_theme_font_size_override("italics_font_size", 25)
	_text.add_theme_color_override("default_color", Color("#33283a"))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	inner.add_child(_choices)
	_arrow = Label.new()
	_arrow.text = "▸"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.add_theme_color_override("font_color", Color("#8a5f86"))
	_arrow.add_theme_font_size_override("font_size", 26)
	inner.add_child(_arrow)


func _on_started(_id: String) -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _on_line(line: Dictionary, info: Dictionary) -> void:
	_clear_choices()
	var speaker_name: String = info.get("name", "")
	_name_plate.visible = speaker_name != ""
	_name_label.text = speaker_name
	_name_plate.add_theme_stylebox_override("panel", UiStyle.plate(Color(info.get("color", "#e9dfc8"))))
	var text: String = line.get("text", "")
	if line.get("speaker", "") == "narrator":
		_text.text = "[center][i]%s[/i][/center]" % text
	else:
		_text.text = text
	_text.visible_characters = 0
	_pause_left = float(line.get("pause", 0.0))
	_typing = true
	_arrow.visible = false
	_line_started_at = Time.get_ticks_msec()


func _on_choices(choices: Array) -> void:
	_showing_choices = true
	_choice_data = choices
	_arrow.visible = false
	_clear_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in choices.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, choices[i]["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiStyle.body_font())
		b.add_theme_font_size_override("font_size", 23)
		UiStyle.apply_choice_button(b)
		b.pressed.connect(_pick.bind(i))
		_choices.add_child(b)
	(_choices.get_child(0) as Button).grab_focus()


func _pick(i: int) -> void:
	if not _showing_choices or i >= _choice_data.size():
		return
	_showing_choices = false
	Audio.sfx("ui_choice", -8.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var c: Dictionary = _choice_data[i]
	_clear_choices()
	runner.choose(c)


func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()


func _on_finished(_id: String) -> void:
	_showing_choices = false
	_clear_choices()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var total := _text.get_total_character_count()
	_text.visible_characters = mini(total, _text.visible_characters + maxi(1, int(ceil(CHARS_PER_SECOND * delta))))
	if _text.visible_characters >= total:
		_typing = false
		_arrow.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or runner == null or not runner.active:
		return
	if _showing_choices:
		for i in _choice_data.size():
			if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_1 + i:
				get_viewport().set_input_as_handled()
				_pick(i)
				return
		return
	if event.is_action_pressed("advance"):
		get_viewport().set_input_as_handled()
		# Ignore the same press that opened the conversation.
		if Time.get_ticks_msec() - _line_started_at < 120:
			return
		if _typing:
			_pause_left = 0.0
			_text.visible_characters = -1
			_typing = false
			_arrow.visible = true
		else:
			Audio.sfx("ui_advance", -14.0)
			runner.advance()
