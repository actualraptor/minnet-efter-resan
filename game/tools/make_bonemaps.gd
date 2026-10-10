extends SceneTree
## Writes Godot BoneMap resources for humanoid retargeting (SkeletonProfileHumanoid):
##   assets/animations/retarget/ual_bonemap.tres     Quaternius UAL (Rigify DEF- names)
##   assets/animations/retarget/vroid_bonemap.tres   Freyja's game model (already humanoid names)
## godot --headless --path game -s tools/make_bonemaps.gd

func _init() -> void:
	var prof := SkeletonProfileHumanoid.new()
	var ual := {"Root": "root", "Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002",
		"UpperChest": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head"}
	for s in [["Left", "L"], ["Right", "R"]]:
		var S: String = s[0]
		var x: String = s[1]
		ual[S + "Shoulder"] = "DEF-shoulder." + x
		ual[S + "UpperArm"] = "DEF-upper_arm." + x
		ual[S + "LowerArm"] = "DEF-forearm." + x
		ual[S + "Hand"] = "DEF-hand." + x
		ual[S + "UpperLeg"] = "DEF-thigh." + x
		ual[S + "LowerLeg"] = "DEF-shin." + x
		ual[S + "Foot"] = "DEF-foot." + x
		ual[S + "Toes"] = "DEF-toe." + x
		for f in [["Index", "f_index"], ["Middle", "f_middle"], ["Ring", "f_ring"], ["Little", "f_pinky"]]:
			ual[S + f[0] + "Proximal"] = "DEF-%s.01.%s" % [f[1], x]
			ual[S + f[0] + "Intermediate"] = "DEF-%s.02.%s" % [f[1], x]
			ual[S + f[0] + "Distal"] = "DEF-%s.03.%s" % [f[1], x]
		ual[S + "ThumbMetacarpal"] = "DEF-thumb.01." + x
		ual[S + "ThumbProximal"] = "DEF-thumb.02." + x
		ual[S + "ThumbDistal"] = "DEF-thumb.03." + x
	var a := BoneMap.new()
	a.profile = prof
	var b := BoneMap.new()
	b.profile = prof
	for i in prof.bone_size:
		var n := prof.get_bone_name(i)
		if ual.has(n):
			a.set_skeleton_bone_name(n, ual[n])
		if n not in ["Root", "LeftEye", "RightEye", "Jaw"]:
			b.set_skeleton_bone_name(n, n)
	ResourceSaver.save(a, "res://assets/animations/retarget/ual_bonemap.tres")
	ResourceSaver.save(b, "res://assets/animations/retarget/vroid_bonemap.tres")
	print("BONEMAPS written")
	quit()
