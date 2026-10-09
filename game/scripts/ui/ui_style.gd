class_name UiStyle
extends RefCounted
## Shared look for the HUD and menus: parchment panels, sage/plum/gold accents,
## Cormorant Garamond for names and titles, Nunito for readable body text.

const CREAM := Color("#f6eedb")
const INK := Color("#33283a")
const SAGE := Color("#9fc79a")
const PLUM := Color("#7b4f7a")
const GOLD := Color("#d8b25a")

static var _fonts: Dictionary = {}


static func _font(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[key] = fv
	return fv


static func body_font(italic := false, weight := 520) -> Font:
	return _font("res://assets/fonts/Nunito-Italic-Variable.ttf" if italic else "res://assets/fonts/Nunito-Variable.ttf", weight)


static func title_font(weight := 650) -> Font:
	return _font("res://assets/fonts/CormorantGaramond-Variable.ttf", weight)


static func parchment() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CREAM, 0.94)
	s.set_corner_radius_all(16)
	s.border_color = Color(GOLD, 0.85)
	s.set_border_width_all(2)
	s.shadow_color = Color(0.1, 0.05, 0.12, 0.35)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 26
	s.content_margin_bottom = 14
	return s


static func plate(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color.lerp(CREAM, 0.15)
	s.set_corner_radius_all(10)
	s.border_color = Color(GOLD, 0.9)
	s.set_border_width_all(2)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	return s


static func pill(alpha := 0.82) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.17, 0.13, 0.2, alpha)
	s.set_corner_radius_all(22)
	s.border_color = Color(GOLD, 0.6)
	s.set_border_width_all(1)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func apply_choice_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.0)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(SAGE, 0.45)
	hover.border_color = Color(PLUM, 0.6)
	hover.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color("#24182a"))
	b.add_theme_color_override("font_focus_color", Color("#24182a"))


static func menu_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(CREAM, 0.92)
	btn.set_corner_radius_all(12)
	btn.border_color = Color(GOLD, 0.8)
	btn.set_border_width_all(2)
	btn.content_margin_left = 20
	btn.content_margin_right = 20
	btn.content_margin_top = 10
	btn.content_margin_bottom = 10
	var hov := btn.duplicate() as StyleBoxFlat
	hov.bg_color = SAGE.lerp(CREAM, 0.35)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("focus", "Button", hov)
	t.set_stylebox("pressed", "Button", hov)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_color", "Label", CREAM)
	return t
