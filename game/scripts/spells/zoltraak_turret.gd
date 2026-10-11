class_name ZoltraakTurret
extends StaticBody3D
## A hostile Zoltraak emitter (team 1) for testing the barrier and for practice
## targets: fires the same bolts and beams as the player, in either visual
## family. Barriers of team 0 stop them; solid things take the hit.

var kind := ZoltraakVisuals.Kind.WHITE
var team := 1
var _beams: Array[ZoltraakBeam] = []


func _ready() -> void:
	add_to_group("zoltraak_target")
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.34
	shape.height = 2.0
	cs.shape = shape
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.34
	cm.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.28, 0.4)
	mat.roughness = 0.8
	cm.material = mat
	m.mesh = cm
	m.position = Vector3(0, 0.8, 0)
	add_child(m)
	var eye := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	var em := StandardMaterial3D.new()
	em.emission_enabled = true
	em.emission = Color(0.7, 0.8, 1.0) if kind == ZoltraakVisuals.Kind.WHITE else Color(0.5, 0.2, 1.0)
	em.emission_energy_multiplier = 2.5
	sm.material = em
	eye.mesh = sm
	eye.position = Vector3(0, 1.75, 0)
	add_child(eye)


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.75, 0)


func fire_bolt(at: Vector3, speed := 45.0, size := 1.0) -> ZoltraakBolt:
	var dir := (at - muzzle()).normalized()
	return ZoltraakShots.spawn_bolt(get_parent(), self, muzzle(), dir, speed, size, kind, team)


func fire_volley(at: Vector3, count := 4) -> void:
	for i in count:
		var spread := Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))
		var dir := (at + spread - muzzle()).normalized()
		ZoltraakShots.spawn_bolt(get_parent(), self, muzzle(), dir, 40.0, 0.9, kind, team)
		await get_tree().create_timer(0.09).timeout


## A beam toward a fixed world point for `seconds`.
func fire_beam(at: Vector3, seconds := 2.0, radius := 0.22) -> ZoltraakBeam:
	var b := ZoltraakBeam.new()
	b.kind = kind
	b.team = team
	b.mode = ZoltraakBeam.Mode.SUSTAINED
	b.base_radius = radius
	b.seals = 3
	b.seal_radius = 0.8
	b.power = 1.0
	b.reach = 60.0
	var src := self
	b.aim_fn = func() -> Array:
		return [src.muzzle(), (at - src.muzzle()).normalized()]
	get_parent().add_child(b)
	b.setup()
	_beams.append(b)
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(b):
			b.release())
	return b


func zoltraak_hit(_damage: float, _dir: Vector3) -> void:
	pass
