class_name AimReticle
extends Control
## Zoltraak's minimal in-universe reticle (concept sheet panels 1 and 3): in the
## neutral combat-ready state only a tiny six-petalled rune at the centre; in
## focus aim a thin soft ring that tightens as the circle charges, the rune a
## little larger. No crosshair lines, no numbers.

var player: Player
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _rose(c: Vector2, radius: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 72
	for i in n + 1:
		var a := TAU * i / n
		var r := radius * (0.3 + 0.7 * pow(absf(cos(3.0 * (a + rot))), 0.7))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var staff_out := player.staff != null and player.staff.out
	var armed := staff_out and player.caster.current_spell() != null and player.caster.current_spell().aim
	var blend := player.aim_blend
	var neutral := 0.5 if armed else 0.0
	var a := maxf(neutral * (1.0 - blend), blend)
	if a <= 0.01 or player.get_viewport().get_camera_3d() == null:
		return
	var c := size * 0.5
	var col := Color(0.72, 0.88, 1.0)
	var charge := player.aim_charge if player.focus_aim else 0.0
	var rune_r := lerpf(6.0, 11.0, blend)
	draw_polyline(_rose(c, rune_r, _t * 0.4), Color(col, a * 0.95), 1.4, true)
	draw_circle(c, 1.6, Color(1, 1, 1, a))
	if blend > 0.02:
		var ring_r := lerpf(46.0, 28.0, charge)
		draw_arc(c, ring_r, 0.0, TAU, 64, Color(col, blend * 0.35), 1.2, true)
		# A brighter arc builds around the ring as the circle charges.
		if charge > 0.01:
			draw_arc(c, ring_r, -PI * 0.5, -PI * 0.5 + TAU * charge, 64, Color(col, blend * 0.9), 2.0, true)
		if charge >= 0.99:
			var pulse := 0.5 + 0.5 * sin(_t * 8.0)
			draw_polyline(_rose(c, ring_r + 5.0, _t * 0.8), Color(1, 1, 1, blend * (0.35 + 0.4 * pulse)), 1.2, true)
