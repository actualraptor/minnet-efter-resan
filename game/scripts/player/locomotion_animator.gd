class_name LocomotionAnimator
extends RefCounted
## Builds an AnimationTree for a character with Idle/Walk/Run (+ Jump, Fall,
## Talk, Cast) clips:
##   locomotion: BlendSpace1D (0 idle, 1 walk, 2 run), phase-synced,
##               time-scaled so stride matches actual ground speed (no foot slide)
##   state:      Transition ground / jump / fall / talk (cross-faded)
##   cast:       OneShot layered on top
## Natural clip speeds come from data/characters/<name>_locomotion.json (mocap).

var tree: AnimationTree
var walk_natural := 1.25
var run_natural := 3.0
var _blend := 0.0
var _state := "ground"


func setup(anim_player: AnimationPlayer, character: String) -> AnimationTree:
	var path := "res://data/characters/%s_locomotion.json" % character
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			walk_natural = float(d["natural_speed"].get("Walk", walk_natural))
			run_natural = float(d["natural_speed"].get("Run", run_natural))
	var bt := AnimationNodeBlendTree.new()
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 2.0
	bs.sync = true
	for p in [["Idle", 0.0], ["Walk", 1.0], ["Run", 2.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = p[0]
		bs.add_blend_point(a, p[1])
	bt.add_node("loco", bs, Vector2(0, 0))
	bt.add_node("stride", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("stride", 0, "loco")
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = 0.22
	for i in 4:
		tr.add_input(["ground", "jump", "fall", "talk"][i])
	bt.add_node("state", tr, Vector2(400, 0))
	bt.connect_node("state", 0, "stride")
	var names := ["Jump", "Fall", "Talk"]
	for i in names.size():
		var a := AnimationNodeAnimation.new()
		a.animation = names[i]
		bt.add_node(names[i], a, Vector2(200, 120 * (i + 1)))
		bt.connect_node("state", i + 1, names[i])
	var cast := AnimationNodeAnimation.new()
	cast.animation = "Cast"
	bt.add_node("CastClip", cast, Vector2(400, 300))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.15
	shot.fadeout_time = 0.3
	bt.add_node("cast", shot, Vector2(600, 0))
	bt.connect_node("cast", 0, "state")
	bt.connect_node("cast", 1, "CastClip")
	bt.connect_node("output", 0, "cast")
	tree = AnimationTree.new()
	tree.name = "LocomotionTree"
	tree.tree_root = bt
	anim_player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	tree.active = true
	return tree


## speed: horizontal ground speed (m/s); walk/run: the controller's speeds.
func update(delta: float, speed: float, walk_speed: float, run_speed: float, grounded: bool, vertical: float, talking: bool) -> void:
	var target: float
	if speed <= walk_speed:
		target = speed / maxf(walk_speed, 0.01)
	else:
		target = 1.0 + clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	_blend = lerpf(_blend, target, 1.0 - exp(-10.0 * delta))
	tree.set("parameters/loco/blend_position", _blend)
	# Stride matching: play the clips at the rate the feet actually cover ground.
	var natural := lerpf(walk_natural, run_natural, clampf(_blend - 1.0, 0.0, 1.0))
	var scale := 1.0
	if _blend > 0.35:
		scale = clampf(speed / natural, 0.75, 1.6)
	tree.set("parameters/stride/scale", scale)
	var want := "ground"
	if not grounded:
		want = "jump" if vertical > 0.5 else "fall"
	elif talking and speed < 0.2:
		want = "talk"
	if want != _state:
		_state = want
		tree.set("parameters/state/transition_request", want)


func cast() -> void:
	tree.set("parameters/cast/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
