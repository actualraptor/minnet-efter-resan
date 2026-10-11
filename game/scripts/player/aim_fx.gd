class_name AimFx
extends Node3D
## The diegetic parts of Zoltraak's focus aim (see the concept sheet): the
## six-petal circle held in front of the staff, a small petalled marker where the
## spell will land, and delicate brackets around valid targets. No crosshair
## chrome; everything lives in the world and fades with the aim state.

var player: Player
var circle: SixPetalCircle
var impact: SixPetalCircle
var _brackets: Array[SixPetalCircle] = []
var _ready_pulse := 0.0


func setup(p: Player) -> void:
	player = p
	top_level = true
	circle = SixPetalCircle.new(0.7, Color(0.78, 0.9, 1.0))
	add_child(circle)
	circle.set_aperture(0.22)
	circle.set_energy(2.6)
	circle.set_alpha(0.0)
	impact = SixPetalCircle.new(0.3, Color(0.65, 0.85, 1.0))
	add_child(impact)
	impact.set_charge(0.15)
	impact.set_alpha(0.0)
	for i in 3:
		var b := SixPetalCircle.new(0.38, Color(0.7, 0.88, 1.0))
		add_child(b)
		b.set_charge(0.05)
		b.set_alpha(0.0)
		_brackets.append(b)


func _process(delta: float) -> void:
	if player == null:
		return
	var blend := player.aim_blend
	var cam := get_viewport().get_camera_3d()
	# The big circle, held just in front of the staff head.
	var show_circle := blend > 0.02 and player.staff != null and player.staff.out
	if show_circle:
		var dir := ZoltraakShots.aim(player, player.model.global_basis.z)
		circle.global_position = ZoltraakShots.muzzle(player) + dir * 0.55
		circle.face(dir)
		var c := player.aim_charge
		circle.set_charge(c)
		var pulse := 0.0
		if c >= 0.99:
			_ready_pulse += delta * 7.0
			pulse = 0.12 * sin(_ready_pulse)
		circle.set_alpha(blend * (0.85 + pulse))
		circle.scale = Vector3.ONE * (0.55 + 0.45 * smoothstep(0.0, 0.25, blend) + 0.12 * c)
	else:
		circle.set_alpha(0.0)
	# Impact marker where the aim ray lands, kept a steady size on screen.
	if blend > 0.05 and cam:
		var p := player.aim_point()
		var dist := cam.global_position.distance_to(p)
		impact.global_position = p
		impact.face(cam.global_position - p)
		var s := clampf(dist * 0.02, 0.35, 1.6)
		impact.scale = Vector3.ONE * s
		impact.set_alpha(blend * 0.9)
	else:
		impact.set_alpha(0.0)
	# Target brackets.
	var targets: Array[Node3D] = []
	if blend > 0.05 and cam:
		var from := cam.global_position
		var fwd := -cam.global_basis.z
		for n in get_tree().get_nodes_in_group("zoltraak_target"):
			var t := n as Node3D
			if t == null:
				continue
			var d := t.global_position - from
			if d.length() < 60.0 and d.angle_to(fwd) < deg_to_rad(38.0):
				targets.append(t)
		targets.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	for i in _brackets.size():
		var b := _brackets[i]
		if i < targets.size() and cam:
			var t := targets[i]
			var pos := t.global_position + Vector3(0, 1.0, 0)
			b.global_position = pos
			b.face(cam.global_position - pos)
			b.scale = Vector3.ONE * clampf(cam.global_position.distance_to(pos) * 0.045, 0.8, 3.2)
			b.set_alpha(blend * 0.75)
		else:
			b.set_alpha(0.0)
