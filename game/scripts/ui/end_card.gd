class_name EndCard
extends Control
## The demo's last screen: title and tagline, what she did, and three buttons
## (keep wandering, begin again, quit). Reached from Main._start_ending().

const TITLE := "Minnet efter resan"
const TAGLINE := "A small errand, a long memory"

var _summary: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.menu_theme()
	visible = false
	var black := ColorRect.new()
	black.color = Color(0.04, 0.03, 0.07, 1.0)
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	col.add_child(_label(TITLE, 84, UiStyle.CREAM, true))
	col.add_child(_label(TAGLINE, 30, UiStyle.GOLD, false, true))
	col.add_child(Control.new())
	col.add_child(_label("Demo 1: The Cottage", 22, Color(UiStyle.CREAM, 0.7)))
	_summary = _label("", 20, Color(UiStyle.CREAM, 0.85))
	col.add_child(_summary)
	col.add_child(Control.new())
	for item in [["Keep wandering", _keep], ["Begin again", _again], ["Quit", _quit]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(300, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(item[1])
		col.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("journal")):
		get_viewport().set_input_as_handled()


func _label(text: String, size: int, color: Color, title := false, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.title_font(700) if title else UiStyle.body_font(italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func show_card() -> void:
	var names := ["The Garden Behind the Cottage", "Flowers for Jonas", "Good Morning, Statue"]
	_summary.text = "Three errands, kept:\n%s\n\n%d memories written down  ·  %d spells known\n%s" % [
		"  ·  ".join(names), GameState.memories.size(), GameState.known_spells.size(), GameState.format_date()]
	modulate.a = 0.0
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	create_tween().tween_property(self, "modulate:a", 1.0, 1.6)


func _keep() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var fade := get_tree().current_scene.get_node_or_null("UI/Fade") as ColorRect
	if fade:
		create_tween().tween_property(fade, "modulate:a", 0.0, 1.2).finished.connect(func(): fade.visible = false)


func _again() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()
