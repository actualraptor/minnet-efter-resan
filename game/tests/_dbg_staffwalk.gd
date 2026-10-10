extends Node
var main: Node
func _ready() -> void:
	main = get_parent()
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var sk: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var th := sk.find_bone("thigh.L")
	var tree: AnimationTree = p.loco.tree
	await p.staff.summon()
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_back")
	for i in 30:
		await get_tree().create_timer(0.05).timeout
		var q := sk.get_bone_pose_rotation(th)
		print("t=%d thighL=%s staffmix=%.2f blend=%.2f stride=%.2f state=%s summon_active=%s cast_active=%s" % [i, q, tree.get("parameters/staffmix/blend_amount"), tree.get("parameters/loco_staff/blend_position"), tree.get("parameters/stride/scale"), tree.get("parameters/state/current_state"), tree.get("parameters/summon/active"), tree.get("parameters/cast/active")])
	Input.action_release("move_back")
	get_tree().quit()
