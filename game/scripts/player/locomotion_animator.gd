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
	var sets := {"loco_free": ["Idle", "Walk", "Run"], "loco_staff": ["IdleStaff", "WalkStaff", "RunStaff"]}
	var y := 0
	for key in sets:
		var bs := AnimationNodeBlendSpace1D.new()
		bs.min_space = 0.0
		bs.max_space = 2.0
		bs.sync = true
		for i in 3:
			var clip: String = sets[key][i]
			if not anim_player.has_animation(clip):
				clip = sets["loco_free"][i]
			var a := AnimationNodeAnimation.new()
			a.animation = clip
			bs.add_blend_point(a, float(i))
		bt.add_node(key, bs, Vector2(0, y))
		y += 160
	var mix := AnimationNodeBlend2.new()
	mix.sync = true
	bt.add_node("staffmix", mix, Vector2(200, 0))
	bt.connect_node("staffmix", 0, "loco_free")
	bt.connect_node("staffmix", 1, "loco_staff")
	bt.add_node("stride", AnimationNodeTimeScale.new(), Vector2(400, 0))
	bt.connect_node("stride", 0, "staffmix")
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
	# Landing absorb (mocap) on the lower body + spine, after a real fall.
	var land_clip := AnimationNodeAnimation.new()
	land_clip.animation = "Land" if anim_player.has_animation("Land") else "Idle"
	bt.add_node("LandClip", land_clip, Vector2(400, 480))
	var lshot := AnimationNodeOneShot.new()
	lshot.fadein_time = 0.05
	lshot.fadeout_time = 0.2
	lshot.filter_enabled = true
	for bone in ["hips", "spine", "chest", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
		lshot.set_filter_path(NodePath("%s:%s" % [_skeleton_path(anim_player), _bone(anim_player, bone)]), true)
	bt.add_node("land", lshot, Vector2(500, 0))
	bt.connect_node("land", 0, "state")
	bt.connect_node("land", 1, "LandClip")
	_has_land = anim_player.has_animation("Land")
	var cast := AnimationNodeAnimation.new()
	cast.animation = "Cast"
	_cast_clip = cast
	bt.add_node("CastClip", cast, Vector2(400, 300))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.15
	shot.fadeout_time = 0.3
	bt.add_node("cast", shot, Vector2(600, 0))
	bt.connect_node("cast", 0, "land")
	bt.connect_node("cast", 1, "CastClip")
	var summon_clip := AnimationNodeAnimation.new()
	_summon_clip = summon_clip
	summon_clip.animation = "Summon"
	bt.add_node("SummonClip", summon_clip, Vector2(600, 300))
	var sshot := AnimationNodeOneShot.new()
	sshot.fadein_time = 0.12
	sshot.fadeout_time = 0.25
	sshot.filter_enabled = true
	for bone in ["upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L", "spine", "chest", "neck", "head"]:
		sshot.set_filter_path(NodePath("%s:%s" % [_skeleton_path(anim_player), _bone(anim_player, bone)]), true)
	bt.add_node("summon", sshot, Vector2(800, 0))
	bt.connect_node("summon", 0, "cast")
	bt.connect_node("summon", 1, "SummonClip")
	bt.connect_node("output", 0, "summon")
	tree = AnimationTree.new()
	tree.name = "LocomotionTree"
	tree.tree_root = bt
	anim_player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	_anim = anim_player
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
	tree.set("parameters/loco_free/blend_position", _blend)
	tree.set("parameters/loco_staff/blend_position", _blend)
	_staff = move_toward(_staff, _staff_target, delta / 0.35)
	tree.set("parameters/staffmix/blend_amount", _staff)
	# Stride matching: play the clips at the rate the feet actually cover ground.
	var natural := lerpf(walk_natural, run_natural, clampf(_blend - 1.0, 0.0, 1.0))
	var scale := 1.0
	if _blend > 0.15:
		scale = clampf(speed / natural, 0.4, 1.6)
	tree.set("parameters/stride/scale", scale)
	if not grounded:
		_air += delta
	else:
		if _air > 0.25 and _has_land:
			tree.set("parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_air = 0.0
	var want := "ground"
	if not grounded:
		want = "jump" if vertical > 0.5 else "fall"
	elif talking and speed < 0.2:
		want = "talk"
	if want != _state:
		_state = want
		tree.set("parameters/state/transition_request", want)


var _staff := 0.0
var _staff_target := 0.0
var _air := 0.0
var _has_land := false


static func _bone(anim_player: AnimationPlayer, legacy: String) -> String:
	var root := anim_player.get_node(anim_player.root_node)
	for sk in root.find_children("*", "Skeleton3D", true, false):
		return RigNames.resolve(sk, legacy)
	return legacy


static func _skeleton_path(anim_player: AnimationPlayer) -> String:
	var root := anim_player.get_node(anim_player.root_node)
	for sk in root.find_children("*", "Skeleton3D", true, false):
		return String(root.get_path_to(sk))
	return "Skeleton3D"


func set_staff(on: bool) -> void:
	_staff_target = 1.0 if on else 0.0


var _summon_clip: AnimationNodeAnimation
var _cast_clip: AnimationNodeAnimation
var _anim: AnimationPlayer


func summon(clip: String = "Summon") -> void:
	_summon_clip.animation = clip
	tree.set("parameters/summon/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## `clip`: the gesture to play (a spell's cast_animation); falls back to "Cast".
func cast(clip: StringName = &"Cast") -> void:
	_cast_clip.animation = clip if _anim != null and _anim.has_animation(clip) else &"Cast"
	tree.set("parameters/cast/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
