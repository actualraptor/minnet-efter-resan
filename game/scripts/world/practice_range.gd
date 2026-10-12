class_name PracticeRange
extends Node3D
## A dedicated range east of the road: two lanes, a shooter at one end and a
## straw target at the other, with the line of fire between them:
##
##     shooter  X ----------------------------------- | target
##
## Walk into a lane to try the defensive barrier in front of a beam. A stone
## pedestal behind the shooters switches the range on and off (E). While on, the
## shooters fire continuously: a black Mörkstråk beam held for seconds at a time
## (so a barrier is broken, heals in the gap, and is broken again) and a stream of
## white Solstråk bolts.

const ORIGIN := Vector2(27.0, 21.0)     # the shooters' end of the first lane
const LANE_LEN := 20.0
const LANE_GAP := 7.0
const POST_EVERY := 4.0

var active := false
var _terrain: MeadowTerrain
var _player: Node3D
var _turrets: Array[ZoltraakTurret] = []
var _orb_mat: StandardMaterial3D
var _orb_light: OmniLight3D


func setup(terrain: MeadowTerrain, player: Node3D) -> void:
	_terrain = terrain
	_player = player
	name = "PracticeRange"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.2)
	wood.roughness = 0.9
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.6, 0.6, 0.58)
	stone.roughness = 0.95
	for k in 2:
		var z := ORIGIN.y + k * LANE_GAP
		var black := k == 0
		var end_x := ORIGIN.x + LANE_LEN
		var target := PracticeDummy.new()
		add_child(target)
		target.global_position = _ground(end_x, z)
		target.rotation.y = -PI / 2.0
		# A stone backstop so a missed bolt never leaves the range.
		_box(Vector3(0.7, 2.4, 3.4), _ground(end_x + 1.8, z) + Vector3(0, 1.2, 0), stone)
		var t := ZoltraakTurret.new()
		t.kind = ZoltraakVisuals.Kind.BLACK if black else ZoltraakVisuals.Kind.WHITE
		t.monster = "dummy"
		t.volley = not black
		t.lane_end = _ground(end_x, z) + Vector3(0, 1.15, 0)
		add_child(t)
		t.global_position = _ground(ORIGIN.x, z)
		_turrets.append(t)
		# Lane posts, both sides.
		var n := int(LANE_LEN / POST_EVERY) + 1
		for i in n:
			var px := ORIGIN.x + 3.0 + i * POST_EVERY
			if px > end_x - 1.0:
				break
			for side in [-1.0, 1.0]:
				_box(Vector3(0.14, 0.75, 0.14), _ground(px, z + side * 1.7) + Vector3(0, 0.37, 0), wood)
	_build_switch(wood, stone)
	_build_sign()
	set_process(true)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain.height_at(x, z), z)


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	add_child(m)
	m.global_position = at


func _build_sign() -> void:
	var at := _ground(ORIGIN.x - 5.0, ORIGIN.y + LANE_GAP * 0.5)
	var l := Label3D.new()
	l.text = "PRACTICE RANGE\nStand in a lane. Raise your barrier."
	l.font_size = 40
	l.pixel_size = 0.004
	l.outline_size = 6
	l.outline_modulate = Color(0.1, 0.07, 0.12, 0.8)
	l.modulate = Color(1.0, 0.95, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	l.global_position = at + Vector3(0, 2.6, 0)


func _build_switch(wood: Material, stone: Material) -> void:
	var sw := RangeSwitch.new()
	sw.range_ref = self
	add_child(sw)
	var at := _ground(ORIGIN.x - 3.0, ORIGIN.y + LANE_GAP * 0.5)
	sw.global_position = at
	var ped := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.55, 1.0, 0.55)
	ped.mesh = b
	ped.material_override = stone
	ped.position = Vector3(0, 0.5, 0)
	sw.add_child(ped)
	var orb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.4
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = _orb_mat
	orb.mesh = s
	orb.position = Vector3(0, 1.25, 0)
	sw.add_child(orb)
	_orb_light = OmniLight3D.new()
	_orb_light.omni_range = 4.5
	_orb_light.shadow_enabled = false
	_orb_light.position = Vector3(0, 1.25, 0)
	sw.add_child(_orb_light)
	_paint()


func set_active(on: bool) -> void:
	active = on
	for t in _turrets:
		t.lane_active = on
	_paint()
	GameState.toast.emit("The range hums awake. Mind the lanes." if on else "The range goes quiet.")


func _paint() -> void:
	if _orb_mat == null:
		return
	_orb_mat.albedo_color = Color(1.0, 0.85, 0.45) if active else Color(0.35, 0.28, 0.5)
	_orb_light.light_color = Color(1.0, 0.8, 0.4) if active else Color(0.55, 0.4, 0.9)
	_orb_light.light_energy = 1.4 if active else 0.5


## It stops itself when she has walked well away.
func _process(_delta: float) -> void:
	if active and _player != null and _player.global_position.distance_to(global_position) > 80.0:
		set_active(false)


# The pedestal she presses E at.
class RangeSwitch extends Node3D:
	var range_ref: PracticeRange

	func _ready() -> void:
		add_to_group("interactable")

	func can_interact(_who: Node) -> bool:
		return range_ref != null

	func interaction_point() -> Vector3:
		return global_position + Vector3(0, 1.0, 0)

	func interaction_prompt() -> String:
		return "Stop the range" if range_ref.active else "Start the range"

	func interact(_who: Node) -> void:
		range_ref.set_active(not range_ref.active)
