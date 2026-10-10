class_name HandPoser
extends SkeletonModifier3D
## Procedural fingers. The clips don't key finger bones; this curls them every
## frame from a per-hand pose that blends smoothly between:
##   relaxed - soft natural curl, pinky curled a little more than the index
##   grip    - closed around the staff shaft (thumb wrapped over the fingers)
##   open    - fingers extended and slightly spread (gestures, summoning)
## Finger bones are built so local +X is the curl axis (positive = toward palm).

const FINGERS := ["index", "middle", "ring", "pinky"]
## Degrees per joint (proximal, middle, distal).
const RELAXED := [16.0, 26.0, 16.0]
const RELAXED_CASCADE := [0.0, 4.0, 9.0, 14.0]   # extra curl index -> pinky
const GRIP := [42.0, 70.0, 62.0]   # keep in sync with grip_centre in art/blender/freyja_hands.py
const OPEN := [-4.0, -3.0, -2.0]
const THUMB_RELAXED := [4.0, 10.0, 8.0]
const THUMB_GRIP := [12.0, 22.0, 26.0]  # thumb lies along the shaft, tip pressing in
const THUMB_OPEN := [-6.0, -4.0, 0.0]

## Target pose per hand: {"grip": 0..1, "open": 0..1}; relaxed when both are 0.
var target := {"L": {"grip": 0.0, "open": 0.0}, "R": {"grip": 0.0, "open": 0.0}}
var _cur := {"L": {"grip": 0.0, "open": 0.0}, "R": {"grip": 0.0, "open": 0.0}}
var _bones := {}   # "L"/"R" -> {"f": [[id, id, id] x4], "t": [id, id, id]}
var _rest := {}    # bone id -> Quaternion


func setup() -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	for s in ["L", "R"]:
		var fingers := []
		for f in FINGERS:
			var ids := []
			for k in 3:
				ids.append(sk.find_bone("f_%s_%d.%s" % [f, k + 1, s]))
			fingers.append(ids)
		var thumb := []
		for k in 3:
			thumb.append(sk.find_bone("thumb_%d.%s" % [k + 1, s]))
		_bones[s] = {"f": fingers, "t": thumb}
		for ids in fingers + [thumb]:
			for i in ids:
				if i < 0:
					_bones.clear()   # not this rig's finger layout (e.g. VRoid): stay inert
					_rest.clear()
					active = false
					return false
				_rest[i] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	return true


## pose: "relaxed", "grip" or "open". Blends over a short time.
func set_pose(side: String, pose: String) -> void:
	target[side] = {"grip": 1.0 if pose == "grip" else 0.0, "open": 1.0 if pose == "open" else 0.0}


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _bones.is_empty():
		return
	for s in ["L", "R"]:
		for key in ["grip", "open"]:
			# Closing around the staff is quick; letting go is a touch slower.
			var rate := 16.0 if target[s][key] > _cur[s][key] else 9.0
			_cur[s][key] = lerpf(_cur[s][key], target[s][key], 1.0 - exp(-rate * delta))
		var g: float = _cur[s]["grip"]
		var o: float = _cur[s]["open"]
		var b: Dictionary = _bones[s]
		for fi in 4:
			for k in 3:
				var relaxed: float = RELAXED[k] + RELAXED_CASCADE[fi] * (1.0 if k == 0 else 0.6)
				var ang := lerpf(lerpf(relaxed, GRIP[k], g), OPEN[k] + (fi - 1.5) * 0.0, o)
				_apply(sk, b["f"][fi][k], ang)
		for k in 3:
			var ang_t := lerpf(lerpf(THUMB_RELAXED[k], THUMB_GRIP[k], g), THUMB_OPEN[k], o)
			_apply(sk, b["t"][k], ang_t)


func _apply(sk: Skeleton3D, bone: int, deg: float) -> void:
	sk.set_bone_pose_rotation(bone, _rest[bone] * Quaternion(Vector3.RIGHT, deg_to_rad(deg)))
