extends Node
## Dev: walk Freyja from the south lane over the bridge into the square and
## report whether she gets there (collision and ramps are walkable).
##   TOWN_WALK=1 godot --path game res://scenes/linkoping.tscn
const WAYPOINTS := [Vector2(7, 128), Vector2(1, 90), Vector2(0, 76), Vector2(0, 62), Vector2(0, 46), Vector2(0, 30), Vector2(0, 14), Vector2(0, 5)]


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	var p: Player = main.player
	var rig: CameraRig = p.camera_rig
	await get_tree().create_timer(1.5).timeout
	var wi := 1
	var t := 0.0
	var max_y := -99.0
	Input.action_press("move_forward")
	Input.action_press("run")
	while wi < WAYPOINTS.size() and t < 70.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var here := Vector2(p.global_position.x, p.global_position.z)
		var wp: Vector2 = WAYPOINTS[wi]
		if here.distance_to(wp) < 1.8:
			wi += 1
			continue
		var d := wp - here
		rig.yaw = atan2(-d.x, -d.y)
		max_y = maxf(max_y, p.global_position.y)
		if int(t * 10.0) % 30 == 0 and p.get_slide_collision_count() > 0:
			var c := p.get_last_slide_collision()
			print("TOWNWALK t=%.1f pos=(%.1f %.1f %.1f) hit=%s at (%.2f %.2f %.2f) n=(%.2f %.2f %.2f)" % [t, p.global_position.x, p.global_position.y, p.global_position.z, (c.get_collider() as CollisionObject3D).shape_owner_get_owner((c.get_collider() as CollisionObject3D).shape_find_owner(c.get_collider_shape_index())).transform, c.get_position().x, c.get_position().y, c.get_position().z, c.get_normal().x, c.get_normal().y, c.get_normal().z])
	Input.action_release("move_forward")
	Input.action_release("run")
	var ok := wi >= WAYPOINTS.size()
	print("TOWNWALK %s reached waypoint %d/%d at t=%.1fs pos=(%.1f, %.1f, %.1f) max_y=%.2f" % [
		"PASS" if ok else "FAIL", wi, WAYPOINTS.size(), t, p.global_position.x, p.global_position.y, p.global_position.z, max_y])
	get_tree().quit()
