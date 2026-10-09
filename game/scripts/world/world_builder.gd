class_name WorldBuilder
extends Node3D
## Dresses the meadow: environment and light, the cottage, hand-placed props,
## the tree ring, distant mountains and ambient life (smoke, butterflies,
## pollen). Placement is authored here and in WorldLayout; randomness is seeded.

const NATURE := "res://assets/models/nature/%s.glb"
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const BUTTERFLY_SHADER := preload("res://shaders/butterfly.gdshader")

var terrain: MeadowTerrain
var cottage: Node3D
var door: Door
var sun: DirectionalLight3D
var fire_light: OmniLight3D
var _fire_base := 2.4
var _placed: Array[Vector2] = []
var _pollen: GPUParticles3D


func build(t: MeadowTerrain) -> void:
	terrain = t
	_environment()
	_cottage()
	_props()
	_tree_ring()
	_mountains()
	_ambient_life()


func _process(_delta: float) -> void:
	if fire_light:
		var t := GameState.game_time()
		fire_light.light_energy = _fire_base * (0.86 + 0.08 * sin(t * 13.0) + 0.06 * sin(t * 7.3 + 1.0) + 0.04 * sin(t * 23.0))
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and _pollen:
		_pollen.global_position = p.global_position + Vector3(0, 1.2, 0)


# --- Environment ---------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sm.set_shader_parameter("cloud_noise", WorldMaterials.patch_noise())
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.9
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.78, 0.86, 0.93)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_depth_begin = 35.0
	env.fog_depth_end = 340.0
	env.fog_depth_curve = 1.6
	env.fog_density = 0.85
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.03
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 70.0
	cam_attr.dof_blur_far_transition = 60.0
	cam_attr.dof_blur_amount = 0.06
	we.camera_attributes = cam_attr
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.84, 0.62)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Low golden-hour sun from the west, slightly south: side light models the cottage front.
	sun.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-70.0), 0.0)
	add_child(sun)


# --- Cottage -----------------------------------------------------------------------

func _cottage() -> void:
	var c := WorldLayout.COTTAGE_POS
	var base := Vector3(c.x, terrain.pad_height(), c.z)
	var scene: PackedScene = load("res://assets/models/buildings/cottage.glb")
	cottage = scene.instantiate()
	cottage.name = "Cottage"
	add_child(cottage)
	cottage.global_position = base
	WorldMaterials.stylise(cottage)
	for n in cottage.find_children("*", "StaticBody3D", true, false):
		(n as StaticBody3D).add_to_group("building")
		(n as StaticBody3D).collision_layer = 1 | 32

	# Door, hinged at its left edge in the front wall.
	door = Door.new()
	door.name = "FrontDoor"
	door.label = "Door"
	door.open_angle = deg_to_rad(100.0)
	add_child(door)
	door.global_position = base + Vector3(-0.575, WorldLayout.COTTAGE_FLOOR, 3.35)
	var panel := AnimatableBody3D.new()
	panel.name = "Panel"
	panel.collision_layer = 1 | 32
	door.add_child(panel)
	var dscene: PackedScene = load("res://assets/models/buildings/door.glb")
	var dmodel := dscene.instantiate()
	panel.add_child(dmodel)
	WorldMaterials.stylise(dmodel)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.13, 2.18, 0.1)
	cs.shape = bs
	cs.position = Vector3(0.575, 1.1, 0)
	panel.add_child(cs)
	door.panel = panel

	# Interior volume (camera, footsteps, spell rules, ambience).
	var iv := IndoorVolume.new()
	iv.name = "Interior"
	var ivs := CollisionShape3D.new()
	var ib := BoxShape3D.new()
	ib.size = Vector3(8.3, 3.2, 6.3)
	ivs.shape = ib
	iv.add_child(ivs)
	add_child(iv)
	iv.global_position = base + Vector3(0, WorldLayout.COTTAGE_FLOOR + 1.6, 0)

	# Lights: hearth (flickering), a warm room fill and the door lantern.
	fire_light = OmniLight3D.new()
	fire_light.name = "HearthLight"
	fire_light.light_color = Color(1.0, 0.62, 0.3)
	fire_light.light_energy = _fire_base
	fire_light.omni_range = 7.5
	fire_light.shadow_enabled = true
	add_child(fire_light)
	fire_light.global_position = base + Vector3(3.3, WorldLayout.COTTAGE_FLOOR + 0.7, -1.2)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.82, 0.6)
	fill.light_energy = 0.9
	fill.omni_range = 7.0
	add_child(fill)
	fill.global_position = base + Vector3(-1.0, WorldLayout.COTTAGE_FLOOR + 2.7, 0.0)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.78, 0.45)
	lantern.light_energy = 0.8
	lantern.omni_range = 3.5
	add_child(lantern)
	lantern.global_position = base + Vector3(0.95, WorldLayout.COTTAGE_FLOOR + 2.0, 3.75)
	var hearth_sound := AudioStreamPlayer3D.new()
	add_child(hearth_sound)
	hearth_sound.global_position = fire_light.global_position

	# Chimney smoke.
	var smoke := GPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.amount = 36
	smoke.lifetime = 7.0
	smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.18, 0.12, 0.05)
	pm.scale_min = 0.9
	pm.scale_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 2.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.95, 0.95, 0.0))
	grad.add_point(0.15, Color(0.93, 0.92, 0.9, 0.45))
	grad.set_color(grad.get_point_count() - 1, Color(0.9, 0.92, 0.95, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = MoteTexture.get_texture()
	q.material = qm
	smoke.draw_pass_1 = q
	add_child(smoke)
	smoke.global_position = base + Vector3(4.3, 7.6, -1.2)


# --- Props ---------------------------------------------------------------------------

func place(model: String, x: float, z: float, yaw_deg: float = 0.0, scale: float = 1.0, sink: float = 0.04) -> Node3D:
	var path := NATURE % model
	if not ResourceLoader.exists(path):
		push_warning("Missing prop " + path)
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	add_child(n)
	n.global_position = Vector3(x, terrain.height_at(x, z) - sink * scale, z)
	n.rotation.y = deg_to_rad(yaw_deg)
	n.scale = Vector3.ONE * scale
	WorldMaterials.stylise(n)
	_placed.append(Vector2(x, z))
	return n


func _fence_line(a: Vector2, b: Vector2) -> void:
	var seg := 2.4
	var d := b - a
	var n := int(ceil(d.length() / seg))
	for i in n:
		var p := a + d * (float(i) / n)
		var yaw := rad_to_deg(atan2(-d.y, d.x))
		var f := place("fence_segment", p.x, p.y, yaw, d.length() / n / seg)
		if f:
			f.scale = Vector3(d.length() / n / seg, 1, 1)


func _props() -> void:
	# Front yard fence with a gap for the path (Edda's "gate").
	_fence_line(Vector2(-9.0, 2.6), Vector2(-1.4, 2.6))
	_fence_line(Vector2(2.6, 2.6), Vector2(11.0, 2.6))
	_fence_line(Vector2(11.0, 2.6), Vector2(11.0, -6.0))
	_fence_line(Vector2(-9.0, 2.6), Vector2(-9.0, -5.0))
	# Pippa's garden bed and the woodpile "past the corner of the house".
	place("garden_bed", 6.4, -0.2, 0.0)
	place("woodpile", 6.3, -9.6, 90.0)
	place("signpost", 6.5, 38.0, 15.0)
	# Bench overlooking the back meadow, under an old oak.
	var bp := WorldLayout.BENCH_POS
	var to_meadow := WorldLayout.GARDEN_MEADOW - bp
	place("bench", bp.x, bp.z, rad_to_deg(atan2(to_meadow.x, to_meadow.z)), 1.0, 0.02)
	place("tree_oak_c", 10.0, -17.5, 40.0)
	# The standing stones where the bluebells "go".
	place("stone_standing_a", -7.5, -26.5, 20.0)
	place("stone_standing_b", -5.6, -28.6, -35.0)
	place("stone_standing_b", 0.8, -30.5, 70.0, 0.85)
	place("rock_a", -12.0, -18.0, 30.0)
	# Specimen trees framing the cottage and meadow.
	place("tree_oak_a", -13.0, -4.0, 10.0)
	place("tree_birch_a", -17.0, -20.0, 0.0)
	place("tree_birch_b", -19.5, -25.5, 50.0)
	place("tree_birch_a", -15.5, -31.0, 120.0, 0.9)
	place("tree_oak_b", 15.0, 6.0, 200.0)
	place("tree_oak_a", -10.0, 22.0, 80.0, 0.95)
	place("tree_birch_b", 12.0, 26.0, 0.0)
	place("tree_oak_b", 18.0, -28.0, 300.0, 1.1)
	# Shrubs hugging the cottage and the yard.
	for b in [["bush_rose", -5.2, -2.0], ["bush_white", 5.2, -2.1], ["bush_a", -5.4, -9.5], ["bush_b", 4.8, -10.8],
			["bush_a", -10.0, 1.8], ["bush_rose", 10.2, 1.6], ["bush_b", -3.6, 2.1], ["bush_white", 3.4, 3.0],
			["bush_a", -16.0, -12.0], ["bush_b", 14.0, -9.0], ["bush_rose", -12.5, 12.0], ["bush_a", 8.5, 16.0],
			["bush_white", -20.0, -16.0], ["bush_b", 16.5, -20.0]]:
		place(b[0], b[1], b[2], float(int(b[1] * 37.0) % 360))
	# Rocks along the path and meadow edges.
	for r in [["rock_b", 3.6, 14.0], ["rock_a", -6.5, 28.0], ["rock_c", 13.0, 34.0], ["rock_b", -9.0, 8.0],
			["rock_c", -22.0, -4.0], ["rock_b", 20.0, -6.0], ["rock_a", 4.0, -35.0], ["rock_b", -3.0, 46.0]]:
		place(r[0], r[1], r[2], float(int(r[2] * 53.0) % 360))


func _tree_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldLayout.SEED + 404
	var near := ["tree_oak_a", "tree_oak_b", "tree_oak_c", "tree_birch_a", "tree_birch_b"]
	var far := ["tree_pine_a", "tree_pine_b", "tree_oak_c", "tree_pine_a"]
	var tries := 0
	var count := 0
	while count < 120 and tries < 2000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(40.0, 92.0)
		var p := Vector2(cos(a), sin(a)) * r
		if WorldLayout.distance_to_polyline(p, WorldLayout.PATH_MAIN) < 6.5:
			continue
		var ok := true
		for q in _placed:
			if q.distance_to(p) < (5.0 if r < 60 else 6.5):
				ok = false
				break
		if not ok:
			continue
		var list: Array = near if r < 58.0 else far
		var model: String = list[rng.randi() % list.size()]
		var bush_chance := rng.randf()
		if r < 55.0 and bush_chance < 0.3:
			place(["bush_a", "bush_b", "bush_white"][rng.randi() % 3], p.x, p.y, rng.randf() * 360.0, rng.randf_range(0.9, 1.4))
		else:
			place(model, p.x, p.y, rng.randf() * 360.0, rng.randf_range(0.85, 1.35))
		count += 1


func _mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = WorldLayout.SEED + 77
	noise.frequency = 1.6
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 220
	var r0 := 150.0
	var r1 := 330.0
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	var prev_h := 0.0
	for i in segs + 1:
		var a := TAU * i / segs
		var dir := Vector3(cos(a), 0, sin(a))
		var h := 55.0 + noise.get_noise_1d(a) * 55.0 + noise.get_noise_1d(a * 3.0 + 10.0) * 22.0
		# Lower the range where the road leaves south so the view opens up.
		h *= 1.0 - 0.45 * exp(-pow(angle_difference(a, PI * 0.5) / 0.5, 2.0))
		var vin := dir * r0 + Vector3(0, -6, 0)
		var vout := dir * r1 + Vector3(0, h, 0)
		if i > 0:
			var c0 := _mount_col(prev_h)
			var c1 := _mount_col(h)
			st.set_color(Color(0.42, 0.55, 0.45))
			st.add_vertex(prev_in)
			st.set_color(c0)
			st.add_vertex(prev_out)
			st.set_color(c1)
			st.add_vertex(vout)
			st.set_color(Color(0.42, 0.55, 0.45))
			st.add_vertex(prev_in)
			st.set_color(c1)
			st.add_vertex(vout)
			st.set_color(Color(0.42, 0.55, 0.45))
			st.add_vertex(vin)
		prev_in = vin
		prev_out = vout
		prev_h = h
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mount_col(h: float) -> Color:
	var rock := Color(0.52, 0.56, 0.66)
	var snow := Color(0.95, 0.96, 1.0)
	return rock.lerp(snow, smoothstep(80.0, 100.0, h))


func _ambient_life() -> void:
	# Butterflies drifting over the meadows.
	for center in [Vector3(-4, 0, -22), Vector3(6, 0, 12), Vector3(-10, 0, 6)]:
		var bf := GPUParticles3D.new()
		bf.amount = 10
		bf.lifetime = 14.0
		bf.preprocess = 14.0
		bf.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 8, 40))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(12, 0.6, 12)
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.8
		pm.spread = 180.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.2
		pm.turbulence_noise_speed_random = 0.5
		pm.turbulence_noise_scale = 4.0
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.95, 0.6))
		grad.add_point(0.5, Color(0.98, 0.7, 0.85))
		grad.set_color(grad.get_point_count() - 1, Color(0.75, 0.85, 1.0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_initial_ramp = gt
		bf.process_material = pm
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.16, 0.11)
		var sm := ShaderMaterial.new()
		sm.shader = BUTTERFLY_SHADER
		plane.material = sm
		bf.draw_pass_1 = plane
		add_child(bf)
		bf.global_position = center + Vector3(0, terrain.height_at(center.x, center.z) + 1.0, 0)
	# Pollen motes catching the light around the player.
	_pollen = GPUParticles3D.new()
	_pollen.amount = 70
	_pollen.lifetime = 6.0
	_pollen.preprocess = 6.0
	_pollen.local_coords = false
	_pollen.visibility_aabb = AABB(Vector3(-15, -5, -15), Vector3(30, 12, 30))
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(9, 2.5, 9)
	pp.gravity = Vector3(0.05, -0.02, 0.02)
	pp.turbulence_enabled = true
	pp.turbulence_noise_strength = 0.4
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pp.scale_curve = ct
	pp.color = Color(1.0, 0.95, 0.75, 0.7)
	_pollen.process_material = pp
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = MoteTexture.get_texture()
	q.material = qm
	_pollen.draw_pass_1 = q
	add_child(_pollen)
