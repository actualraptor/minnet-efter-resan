class_name Glyph
extends Control
## Small drawn icons for spells (by school) and satchel items, so the spellbook
## and hotbar need no icon art. `kind`: flower, beam, barrier, sparkle, book, scroll.

var kind := "sparkle"
var tint := Color.WHITE


static func make(k: String, c: Color, px: float) -> Glyph:
	var g := Glyph.new()
	g.kind = k
	g.tint = c
	g.custom_minimum_size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func look_of(def: SpellDefinition) -> Dictionary:
	var k := "sparkle"
	match def.category:
		SpellDefinition.Category.ENVIRONMENTAL: k = "flower"
		SpellDefinition.Category.OFFENSIVE: k = "beam"
		SpellDefinition.Category.DEFENSIVE: k = "barrier"
	return {"kind": k, "tint": Color("#8a6bd6") if def.visual == &"black" else def.gather_color}


static func for_spell(def: SpellDefinition, px: float) -> Glyph:
	var l := look_of(def)
	return make(l["kind"], l["tint"], px)


static func for_item(item: Dictionary, px: float) -> Glyph:
	return make(str(item.get("kind", "book")), Color("#8a5a6e") if item.get("kind", "book") == "book" else UiStyle.CREAM, px)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 * 0.7
	# A dark badge, so pale tints (the white beam, a sparkle) read on cream parchment too.
	draw_circle(c, minf(size.x, size.y) * 0.5, Color(0.2, 0.15, 0.26, 0.92))
	draw_arc(c, minf(size.x, size.y) * 0.5 - 1.0, 0.0, TAU, 40, Color(UiStyle.GOLD, 0.6), 1.5)
	match kind:
		"flower":
			for i in 6:
				draw_circle(c + Vector2(r * 0.42, 0).rotated(i * TAU / 6.0), r * 0.3, tint)
			draw_circle(c, r * 0.24, UiStyle.GOLD)
		"beam":
			draw_arc(c, r * 0.9, 0.0, TAU, 40, Color(tint, 0.75), maxf(2.0, r * 0.08))
			draw_line(c + Vector2(-0.72, 0.72) * r, c + Vector2(0.72, -0.72) * r, Color(tint, 0.45), r * 0.5)
			draw_line(c + Vector2(-0.72, 0.72) * r, c + Vector2(0.72, -0.72) * r, Color.WHITE, r * 0.2)
		"barrier":
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 7:
				outer.append(c + Vector2(0, -r * 0.92).rotated(i * TAU / 6.0))
				inner.append(c + Vector2(0, -r * 0.5).rotated(i * TAU / 6.0))
			draw_polyline(outer, tint, maxf(2.0, r * 0.1))
			draw_polyline(inner, Color(tint, 0.7), maxf(1.5, r * 0.06))
			draw_circle(c, r * 0.12, tint)
		"book":
			var cover := Rect2(c + Vector2(-0.58, -0.78) * r, Vector2(1.16, 1.56) * r)
			draw_rect(cover, tint)
			draw_rect(Rect2(cover.position, Vector2(r * 0.22, cover.size.y)), tint.darkened(0.35))
			draw_rect(Rect2(cover.position + Vector2(r * 0.22, r * 0.12), cover.size - Vector2(r * 0.34, r * 0.24)), tint.lightened(0.12), false, maxf(1.5, r * 0.05))
			draw_circle(c + Vector2(r * 0.12, 0), r * 0.2, UiStyle.GOLD)
			draw_rect(Rect2(cover.position + Vector2(cover.size.x - r * 0.07, r * 0.08), Vector2(r * 0.07, cover.size.y - r * 0.16)), Color(UiStyle.CREAM, 0.9))
		"scroll":
			var body := Rect2(c + Vector2(-0.78, -0.34) * r, Vector2(1.56, 0.68) * r)
			draw_rect(body, tint)
			draw_circle(body.position + Vector2(0, body.size.y * 0.5), r * 0.38, tint.darkened(0.12))
			draw_circle(body.position + Vector2(body.size.x, body.size.y * 0.5), r * 0.38, tint.darkened(0.12))
			draw_rect(Rect2(c + Vector2(-0.06, -0.4) * r, Vector2(0.12, 0.8) * r), Color("#b0485a"))
		_:
			var pts := PackedVector2Array()
			for i in 8:
				pts.append(c + Vector2(0, -(r if i % 2 == 0 else r * 0.28)).rotated(i * TAU / 8.0))
			draw_colored_polygon(pts, tint)
			draw_circle(c + Vector2(r * 0.6, -r * 0.55), r * 0.08, tint)
