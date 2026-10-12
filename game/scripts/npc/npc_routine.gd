class_name NpcRoutine
extends Node
## Gives an NPC a day: ordered stops she walks (or jogs) between, waits at, sits or
## crouches at, and barks at. The plan itself comes from NpcPlans and is chosen
## by story state and time of day; this node only follows it. It also notices
## Freyja: stops and turns to her when she comes near, and keeps out of the way of
## a conversation. A stuck walker is snapped to her stop so a plan never wedges.

const NOTICE_DIST := 3.4
const BARK_RANGE := 15.0

var npc: NPC
var player: Node3D
var door: Door
var plans: NpcPlans
## Test hook: scales every wait (1 = normal).
var wait_scale := 1.0
## Held while a scripted scene (the ending) places her by hand.
var paused := false

var _plan_key := ""
var _stops: Array = []
var _i := 0
var _via: Array = []
var _state := "wait"   # wait | walk
var _wait_left := 0.0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
var _bark_cd := 12.0
var _noticed := false
var _notice_cd := 0.0
var _noticed_t := 0.0
var _replan_cd := 0.0


func setup(npc_: NPC, player_: Node3D, door_: Door, plans_: NpcPlans) -> void:
	npc = npc_
	player = player_
	door = door_
	plans = plans_
	_replan(true)


## Where the current plan puts her first, applied at once (a save was loaded, or
## the scene has just started): no walking from the old place.
func snap_to_plan() -> void:
	_replan(true)
	if _stops.is_empty():
		return
	var s: Dictionary = _stops[_i]
	npc.global_position = s["p"]
	npc.model.rotation.y = float(s.get("face", npc.model.rotation.y))
	_enter_stop(s)


func _process(delta: float) -> void:
	if npc == null or not is_instance_valid(npc) or paused:
		return
	_replan_cd -= delta
	if _replan_cd <= 0.0:
		_replan_cd = 1.0
		_replan(false)
	if npc._talking or _stops.is_empty():
		npc.stop_walk()
		return
	_notice_player(delta)
	if _noticed:
		npc.stop_walk()
		return
	_ambient_bark(delta)
	if _state == "walk":
		_walk(delta)
	else:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_next_stop()


func _replan(force: bool) -> void:
	var p: Dictionary = plans.plan_for(npc.character_id)
	var key: String = p.get("key", "")
	if not force and key == _plan_key:
		return
	_plan_key = key
	_stops = p.get("stops", [])
	_i = 0
	_via = []
	if _stops.is_empty():
		return
	# Start at the stop nearest to where she already is, so a change of plan is a walk
	# from here, not a jump.
	var best := 0
	var best_d := INF
	for k in _stops.size():
		var d := npc.global_position.distance_to(_stops[k]["p"])
		if d < best_d:
			best_d = d
			best = k
	_i = best
	if best_d > 0.6:
		_begin_walk_to(_i)
	else:
		_enter_stop(_stops[_i])


func _next_stop() -> void:
	_i = (_i + 1) % _stops.size()
	if npc.seated:
		npc.sit(false)
	_begin_walk_to(_i)


func _begin_walk_to(idx: int) -> void:
	var s: Dictionary = _stops[idx]
	_via = []
	var route: Array = s.get("via", [])
	# A stop's route is a polyline: join it at the point nearest to where she is,
	# and skip it entirely when she is already close to the stop.
	if not route.is_empty() and npc.global_position.distance_to(s["p"]) > 2.0:
		var from := 0
		var best := INF
		for k in route.size():
			var d := npc.global_position.distance_to(route[k])
			if d < best:
				best = d
				from = k
		_via = route.slice(from)
	_via.append(s["p"])
	_state = "walk"
	_stuck_t = 0.0
	_stuck_from = npc.global_position


func _walk(delta: float) -> void:
	var target: Vector3 = _via[0]
	var s: Dictionary = _stops[_i]
	var speed: float = float(s.get("speed", plans.walk_speed(npc.character_id)))
	var left := npc.walk_toward(target, speed)
	_open_door_if_near()
	# Stuck? Snap to the stop (never wedge a plan against a chair or a flower).
	_stuck_t += delta
	if _stuck_t >= 1.6:
		if npc.global_position.distance_to(_stuck_from) < 0.12:
			npc.global_position = _stops[_i]["p"]
			_via.clear()
			left = 0.0
		_stuck_t = 0.0
		_stuck_from = npc.global_position
	if left < 0.18:
		_via.pop_front()
		if _via.is_empty():
			npc.stop_walk()
			_enter_stop(s)


func _enter_stop(s: Dictionary) -> void:
	_state = "wait"
	npc.stop_walk()
	var w: Vector2 = s.get("wait", Vector2(8.0, 14.0))
	_wait_left = randf_range(w.x, w.y) * wait_scale
	var pose: StringName = s.get("pose", &"stand")
	if pose == &"sit":
		npc.sit(true)
	elif pose == &"crouch":
		npc.play(&"Crouch")
	else:
		if npc.seated:
			npc.sit(false)
		npc.play(&"Idle")
	if s.has("face"):
		var tw := npc.create_tween()
		var start := npc.model.rotation.y
		tw.tween_property(npc.model, "rotation:y", start + wrapf(float(s["face"]) - start, -PI, PI), 0.5)
	if s.has("bark") and player != null and npc.global_position.distance_to(player.global_position) < BARK_RANGE:
		npc.bark(str(s["bark"]))


func _open_door_if_near() -> void:
	if door == null:
		return
	var doorway := door.global_position + Vector3(0.575, 0, 0)
	if Vector2(npc.global_position.x - doorway.x, npc.global_position.z - doorway.z).length() < 2.4 and not door.is_open:
		door.set_open(true)


func _notice_player(delta: float) -> void:
	_notice_cd -= delta
	if player == null:
		return
	var d := npc.global_position.distance_to(player.global_position)
	if _noticed:
		_noticed_t += delta
		# Do not stand there forever just because she is nearby.
		if d > NOTICE_DIST + 1.6 or _noticed_t > 9.0:
			_noticed = false
			if _state == "wait":
				_enter_stop(_stops[_i])
	elif d < NOTICE_DIST and _notice_cd <= 0.0:
		_noticed = true
		_noticed_t = 0.0
		_notice_cd = 45.0
		npc.face_point(player.global_position, 0.35)
		if npc.seated:
			npc.play(&"Idle")   # maps to the seated idle
		var greet := plans.greeting(npc.character_id)
		if greet != "":
			npc.bark(greet)


func _ambient_bark(delta: float) -> void:
	_bark_cd -= delta
	if _bark_cd > 0.0 or player == null:
		return
	_bark_cd = randf_range(28.0, 55.0)
	if npc.global_position.distance_to(player.global_position) > BARK_RANGE:
		return
	var line := plans.pick_bark(npc.character_id)
	if line != "":
		npc.bark(line)
