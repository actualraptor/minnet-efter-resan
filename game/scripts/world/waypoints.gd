class_name Waypoints
extends Node3D
## Where to go next, shown the way the world would: a column of sunlit haze and
## drifting motes over the objective (visible from afar, gone when she arrives) and
## a small firefly that flits ahead of her toward it when it is far. No arrows,
## no compass: just the meadow pointing.

const NEAR := 7.0          # the beacon is gone inside this distance
const WISP_FROM := 15.0    # the firefly shows beyond this

var _terrain: MeadowTerrain
var _player: Player
var _edda: NPC
var _pippa: NPC
var _shaft: MeshInstance3D
var _shaft_mat: ShaderMaterial
var _motes: GPUParticles3D
var _wisp: Node3D
var _wisp_light: OmniLight3D
var _wisp_mesh: MeshInstance3D
var _wisp_trail: GPUParticles3D
var _shown := 0.0
var _wisp_shown := 0.0
var _t := 0.0


func setup(terrain: MeadowTerrain, player: Player, edda: NPC, pippa: NPC) -> void:
	_terrain = terrain
	_player = player
	_edda = edda
	_pippa = pippa
	_build_beacon()
	_build_wisp()
	set_process(true)


## The world position of what she should do next, or null when it is up to her.
func objective() -> Variant:
	var g := GameState.quest("garden_of_jonas")
	match g:
		"none":
			return _pippa.global_position if not GameState.has_flag("pippa_met") else _edda.global_position
		"active":
			return WorldLayout.GARDEN_MEADOW
		"bloomed":
			return _edda.global_position
	var j := GameState.quest("jonas_stone")
	var st := GameState.quest("statue_by_the_road")
	if st == "complete":
		return null
	if st == "found":
		return _pippa.global_position
	if st == "active":
		return _ground(StoneQuests.STATUE_POS)
	if j == "complete":
		return _pippa.global_position
	if j == "book":
		return null
	if j == "planted":
		return _edda.global_position
	if j == "active":
		return _ground(StoneQuests.STONE_POS)
	return _pippa.global_position


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, _terrain.height_at(p.x, p.y), p.y)


func _build_beacon() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.95
	cyl.height = 30.0
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_shaft = MeshInstance3D.new()
	_shaft.mesh = cyl
	_shaft_mat = ShaderMaterial.new()
	_shaft_mat.shader = preload("res://shaders/beacon_shaft.gdshader")
	_shaft.material_override = _shaft_mat
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shaft.visible = false
	add_child(_shaft)
	_motes = GPUParticles3D.new()
	_motes.amount = 36
	_motes.lifetime = 5.0
	_motes.emitting = false
	_motes.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 14, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.1
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.color = Color(1.0, 0.92, 0.6)
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.25, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_motes.process_material = pm
	_motes.draw_pass_1 = SpellCaster._mote_mesh(0.11)
	add_child(_motes)


func _build_wisp() -> void:
	_wisp = Node3D.new()
	add_child(_wisp)
	_wisp_mesh = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.7)
	sph.material = m
	_wisp_mesh.mesh = sph
	_wisp.add_child(_wisp_mesh)
	_wisp_light = OmniLight3D.new()
	_wisp_light.light_color = Color(1.0, 0.88, 0.55)
	_wisp_light.omni_range = 3.5
	_wisp_light.light_energy = 0.0
	_wisp_light.shadow_enabled = false
	_wisp.add_child(_wisp_light)
	_wisp_trail = GPUParticles3D.new()
	_wisp_trail.amount = 22
	_wisp_trail.lifetime = 1.4
	_wisp_trail.local_coords = false
	_wisp_trail.emitting = false
	_wisp_trail.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.05, 0)
	pm.color = Color(1.0, 0.93, 0.65)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	_wisp_trail.process_material = pm
	_wisp_trail.draw_pass_1 = SpellCaster._mote_mesh(0.07)
	_wisp.add_child(_wisp_trail)
	_wisp.visible = false


func _process(delta: float) -> void:
	_t += delta
	var obj: Variant = objective() if _player != null else null
	var ppos := _player.global_position
	var want_beacon := 0.0
	var want_wisp := 0.0
	if obj != null:
		var target := obj as Vector3
		var flat := Vector2(target.x - ppos.x, target.z - ppos.z)
		var d := flat.length()
		want_beacon = smoothstep(NEAR, NEAR + 8.0, d)
		want_wisp = smoothstep(WISP_FROM, WISP_FROM + 6.0, d)
		_shaft.global_position = target + Vector3(0, 15.0, 0)
		_motes.global_position = target + Vector3(0, 0.3, 0)
		if want_wisp > 0.0:
			var dir := flat.normalized() if d > 0.1 else Vector2.ZERO
			var side := Vector2(-dir.y, dir.x)
			var ahead := Vector2(ppos.x, ppos.z) + dir * 5.5 + side * sin(_t * 1.1) * 1.1
			var aim := Vector3(ahead.x, _terrain.height_at(ahead.x, ahead.y) + 1.55 + sin(_t * 2.3) * 0.22, ahead.y)
			if not _wisp.visible or _wisp_shown < 0.05:
				_wisp.global_position = ppos + Vector3(dir.x * 2.0, 1.6, dir.y * 2.0)
			_wisp.global_position = _wisp.global_position.lerp(aim, 1.0 - exp(-2.4 * delta))
	_shown = move_toward(_shown, want_beacon, delta * 0.8)
	_wisp_shown = move_toward(_wisp_shown, want_wisp, delta * 1.0)
	_shaft.visible = _shown > 0.01
	_shaft_mat.set_shader_parameter("fade", _shown)
	_motes.emitting = _shown > 0.05
	_wisp.visible = _wisp_shown > 0.01
	_wisp_light.light_energy = 0.9 * _wisp_shown
	_wisp_mesh.scale = Vector3.ONE * (0.6 + 0.4 * _wisp_shown)
	_wisp_trail.emitting = _wisp_shown > 0.2
