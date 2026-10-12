class_name NpcPlans
extends RefCounted
## What each person does with the day: which stops, in which order, chosen by the
## story (where the errands have put them) and by the clock. Positions are hand
## placed in the meadow's layout; routes go round the cottage by the side path so
## a straight line never crosses a wall. Barks live in data/dialogue/barks.json.

const BARKS := "res://data/dialogue/barks.json"

## Home to the bench, through the door and round the east side of the cottage.
## Walked forward or backward; a walker joins it at the point nearest to her.
const ROUTE := [
	Vector2(1.4, -7.4), Vector2(1.0, -5.2), Vector2(0.15, -3.5), Vector2(0.1, -1.8),
	Vector2(0.9, 0.9), Vector2(4.8, 1.7), Vector2(7.4, 0.5), Vector2(9.0, -5.0), Vector2(8.0, -11.0),
]

var terrain: MeadowTerrain
var _barks: Dictionary = {}


func _init(t: MeadowTerrain) -> void:
	terrain = t
	var d: Variant = DialogueRunner._read_json(BARKS)
	_barks = d if d is Dictionary else {}


func walk_speed(id: String) -> float:
	return 1.9 if id == "char_pippa" else 0.85


func _g(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z) + 0.05, z)


func _route(from_idx: int, to_idx: int) -> Array:
	var out: Array = []
	var step := 1 if to_idx >= from_idx else -1
	var i := from_idx
	while true:
		out.append(_g(ROUTE[i].x, ROUTE[i].y))
		if i == to_idx:
			break
		i += step
	return out


func _night() -> bool:
	return GameState.daypart() == "night"


func plan_for(id: String) -> Dictionary:
	var g := GameState.quest("garden_of_jonas")
	var out_back := g in ["bloomed", "complete"]
	if id == "char_edda":
		return _edda(out_back)
	if id == "char_pippa":
		return _pippa(out_back)
	return {"key": "none", "stops": []}


func _edda(out_back: bool) -> Dictionary:
	var c := WorldLayout.COTTAGE_POS
	var pad := terrain.pad_height() + WorldLayout.COTTAGE_FLOOR
	var home := Vector3(c.x + 1.4, pad + 0.05, c.z - 1.6)
	var door_yaw := atan2(-1.4, 4.95)
	if not out_back or _night():
		return {"key": "edda_home", "stops": [
			{"p": home, "pose": &"sit", "wait": Vector2(60.0, 100.0), "face": door_yaw, "via": _route(ROUTE.size() - 1, 0)},
			{"p": home, "pose": &"stand", "wait": Vector2(5.0, 9.0), "face": door_yaw + 0.6},
		]}
	var b := WorldLayout.BENCH_POS
	var to_meadow := WorldLayout.GARDEN_MEADOW - b
	var bench_yaw := atan2(to_meadow.x, to_meadow.z)
	var seat := _g(b.x, b.z) - Vector3(sin(bench_yaw), 0, cos(bench_yaw)) * 0.1
	return {"key": "edda_bench", "stops": [
		{"p": seat, "pose": &"sit", "wait": Vector2(70.0, 120.0), "face": bench_yaw,
			"via": _route(0, ROUTE.size() - 1)},
		{"p": _g(7.7, 1.1), "pose": &"stand", "wait": Vector2(12.0, 18.0), "face": -2.36,
			"via": _route(ROUTE.size() - 1, 6), "bark": "These carrots are optimistic."},
	]}


func _pippa(out_back: bool) -> Dictionary:
	if _night():
		return {"key": "pippa_home", "stops": [
			{"p": _g(-0.9, -4.1), "pose": &"stand", "wait": Vector2(30.0, 50.0), "face": 0.0, "via": _route(ROUTE.size() - 1, 2)},
		]}
	if out_back:
		return {"key": "pippa_meadow", "stops": [
			{"p": _g(-0.5, -13.0), "pose": &"stand", "wait": Vector2(8.0, 14.0), "face": atan2(-3.5, -11.0)},
			{"p": _g(-5.5, -18.5), "pose": &"crouch", "wait": Vector2(10.0, 16.0), "face": 2.4, "bark": "Fact: the blue ones are still blue."},
			{"p": _g(3.0, -17.5), "pose": &"stand", "wait": Vector2(6.0, 10.0), "face": -1.0},
			{"p": _g(4.3, -12.4), "pose": &"stand", "wait": Vector2(8.0, 14.0), "face": 0.9, "bark": "Grandma, it's still there."},
		]}
	return {"key": "pippa_yard", "stops": [
		{"p": _g(4.8, 1.4), "pose": &"crouch", "wait": Vector2(14.0, 22.0), "face": 2.36},
		{"p": _g(0.8, 1.8), "pose": &"stand", "wait": Vector2(6.0, 10.0), "face": 0.0, "bark": "Anyone coming?"},
		{"p": _g(7.6, -7.6), "pose": &"stand", "wait": Vector2(8.0, 12.0), "face": 1.6,
			"via": [_g(7.4, 0.5), _g(9.0, -5.0)]},
		{"p": _g(7.4, 0.5), "pose": &"stand", "wait": Vector2(4.0, 7.0), "face": 3.0},
	]}


func greeting(id: String) -> String:
	return _pick(id, "greet")


func pick_bark(id: String) -> String:
	return _pick(id, "idle")


func _pick(id: String, kind: String) -> String:
	var entry: Dictionary = _barks.get(id, {})
	var options: Array = []
	for line in entry.get(kind, []):
		var cond := str(line.get("if", ""))
		if cond == "" or _eval(cond):
			options.append(str(line.get("text", "")))
	return str(options[randi() % options.size()]) if not options.is_empty() else ""


func _eval(cond: String) -> bool:
	var expr := Expression.new()
	if expr.parse(cond) != OK:
		return false
	var r: Variant = expr.execute([], GameState, false)
	return not expr.has_execute_failed() and bool(r)
