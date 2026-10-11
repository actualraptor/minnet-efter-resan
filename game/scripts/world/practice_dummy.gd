class_name PracticeDummy
extends StaticBody3D
## A straw practice dummy for testing spells: flinches and flashes when struck by
## Solstråk/Mörkstråk and keeps a running damage count above its head. It is a
## "zoltraak_target", so the tracking missiles and lock-on find it.

var damage_taken := 0.0
## Show the running damage count above the head.
var show_count := true
var _label: Label3D
var _flash: StandardMaterial3D
var _tilt := Vector3.ZERO
var _tilt_v := Vector3.ZERO
var _visual: Node3D


func _ready() -> void:
	add_to_group("zoltraak_target")
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.9
	cs.shape = shape
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.31, 0.2)
	wood.roughness = 0.9
	_flash = StandardMaterial3D.new()
	_flash.albedo_color = Color(0.86, 0.74, 0.45)
	_flash.roughness = 0.95
	_flash.emission_enabled = true
	_flash.emission = Color(1, 1, 1)
	_flash.emission_energy_multiplier = 0.0
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.08
	pm.height = 1.9
	pm.material = wood
	post.mesh = pm
	post.position = Vector3(0, 0.95, 0)
	_visual.add_child(post)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.05
	am.bottom_radius = 0.05
	am.height = 1.3
	am.material = wood
	arm.mesh = am
	arm.rotation_degrees = Vector3(0, 0, 90)
	arm.position = Vector3(0, 1.35, 0)
	_visual.add_child(arm)
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.36
	sm.height = 0.8
	sm.material = _flash
	sack.mesh = sm
	sack.position = Vector3(0, 0.78, 0)
	_visual.add_child(sack)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.4
	hm.material = _flash
	head.mesh = hm
	head.position = Vector3(0, 1.82, 0)
	_visual.add_child(head)
	_label = Label3D.new()
	_label.text = ""
	_label.font_size = 48
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.35, 0)
	_label.modulate = Color(1.0, 0.95, 0.8, 0.0)
	_label.no_depth_test = true
	add_child(_label)


func zoltraak_hit(damage: float, dir: Vector3) -> void:
	damage_taken += damage
	_flash.emission_energy_multiplier = 3.0
	# A shove away from the attack, sprung back.
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	_tilt_v += Vector3(flat.z, 0.0, -flat.x) * clampf(damage * 0.08, 0.3, 2.0)
	if show_count:
		_label.text = "%d" % int(damage_taken)
		_label.modulate.a = 1.0


func _process(delta: float) -> void:
	_tilt_v += (-_tilt * 90.0 - _tilt_v * 7.0) * delta
	_tilt += _tilt_v * delta
	_visual.rotation = Vector3(_tilt.x, 0.0, _tilt.z)
	_flash.emission_energy_multiplier = move_toward(_flash.emission_energy_multiplier, 0.0, delta * 5.0)
	_label.modulate.a = move_toward(_label.modulate.a, 0.0, delta * 0.25)
