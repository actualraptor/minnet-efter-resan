class_name FlowerField
extends Node3D
## Owns every flower the mage has grown. One MultiMesh per variant with a fixed
## capacity used as a ring buffer, so recasting stays cheap: the oldest flowers
## are recycled once the cap is reached. Patches (centre, radius, seed) are the
## persistent record; flowers are re-planted deterministically on load.

static var instance: FlowerField

const MAX_PER_VARIANT := 3200
const MAX_PER_CAST := 1700
const SAVE_KEY := "flower_field"

var _variants: Array[String] = []
var _mm: Array[MultiMesh] = []
var _next: Array[int] = []
var _used: Array[int] = []
var _patches: Array[Dictionary] = []
var _flower_shader: Shader = preload("res://shaders/flower.gdshader")


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	GameState.register_provider(SAVE_KEY, self)
	for id in FlowerMeshBuilder.VARIANTS:
		var v: Dictionary = FlowerMeshBuilder.VARIANTS[id]
		var mesh := FlowerMeshBuilder.build(id)
		var mat := ShaderMaterial.new()
		mat.shader = _flower_shader
		mat.set_shader_parameter("head_height", v["head"])
		mat.set_shader_parameter("petal_a", v["a"])
		mat.set_shader_parameter("petal_b", v["b"])
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = MAX_PER_VARIANT
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-130, -30, -130), Vector3(260, 80, 260))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Flowers_" + id
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_variants.append(id)
		_mm.append(mm)
		_next.append(0)
		_used.append(0)


func _exit_tree() -> void:
	GameState.unregister_provider(SAVE_KEY)
	if instance == self:
		instance = null


func variant_count() -> int:
	return _variants.size()


func total() -> int:
	var t := 0
	for u in _used:
		t += u
	return t


func add_flower(f: Dictionary, birth: float) -> void:
	var vi: int = f["variant"]
	var mm := _mm[vi]
	var i := _next[vi]
	var up: Vector3 = (f["normal"] as Vector3).lerp(Vector3.UP, 0.6).normalized()
	var basis := _basis_from_up(up, f["yaw"]).scaled(Vector3.ONE * float(f["scale"]))
	mm.set_instance_transform(i, Transform3D(basis, f["pos"]))
	mm.set_instance_custom_data(i, Color(birth, f["rnd"], 0.0, 0.0))
	_next[vi] = (i + 1) % MAX_PER_VARIANT
	_used[vi] = mini(_used[vi] + 1, MAX_PER_VARIANT)
	mm.visible_instance_count = _used[vi]


func record_patch(center: Vector3, radius: float, patch_seed: int) -> void:
	_patches.append({"center": [center.x, center.y, center.z], "radius": radius, "seed": patch_seed})


func patches() -> Array[Dictionary]:
	return _patches


func clear() -> void:
	_patches.clear()
	for vi in _mm.size():
		_mm[vi].visible_instance_count = 0
		_next[vi] = 0
		_used[vi] = 0


func save_state() -> Dictionary:
	return {"patches": _patches.duplicate(true)}


func load_state(data: Dictionary) -> void:
	clear()
	var space := get_world_3d().direct_space_state
	for p in data.get("patches", []):
		var c: Array = p["center"]
		var center := Vector3(c[0], c[1], c[2])
		var flowers := plan_patch(space, center, float(p["radius"]), int(p["seed"]), _variants.size())
		for f in flowers:
			add_flower(f, -1000.0)
		record_patch(center, float(p["radius"]), int(p["seed"]))


## Counts recorded patches whose centre lies within `radius` of `point`.
func patches_near(point: Vector3, radius: float) -> int:
	var n := 0
	for p in _patches:
		var c: Array = p["center"]
		if Vector2(c[0] - point.x, c[2] - point.z).length() <= radius:
			n += 1
	return n


static func _basis_from_up(up: Vector3, yaw: float) -> Basis:
	var b := Basis(Vector3.UP, yaw)
	var axis := Vector3.UP.cross(up)
	if axis.length() > 0.0001:
		b = Basis(axis.normalized(), Vector3.UP.angle_to(up)) * b
	return b


## Deterministically plans a natural-looking patch: drifts of one dominant
## colour plus scattered singles. Each candidate is validated against real
## collision: it must land on terrain (not a floor, roof or rock), on gentle
## slope, off paths and outside the cottage.
static func plan_patch(space: PhysicsDirectSpaceState3D, center: Vector3, radius: float, patch_seed: int, variants: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = patch_seed
	var weights: Array[float] = []
	for id in FlowerMeshBuilder.VARIANTS:
		weights.append(float(FlowerMeshBuilder.VARIANTS[id]["weight"]))
	var candidates: Array[Dictionary] = []
	var area := PI * radius * radius
	var clusters := int(area * 0.085)
	for c in clusters:
		var cp := _disc(rng, radius * 0.95)
		var vi := rng.rand_weighted(PackedFloat32Array(weights))
		var cr := rng.randf_range(0.8, 2.3)
		var n := rng.randi_range(10, 34)
		for k in n:
			var off := Vector2(rng.randfn(0.0, cr * 0.5), rng.randfn(0.0, cr * 0.5))
			var p := cp + off
			if p.length() > radius:
				continue
			var v := vi if rng.randf() < 0.82 else rng.rand_weighted(PackedFloat32Array(weights))
			candidates.append({"xz": p, "variant": mini(v, variants - 1)})
	var singles := int(area * 0.7)
	for s in singles:
		candidates.append({"xz": _disc(rng, radius), "variant": mini(rng.rand_weighted(PackedFloat32Array(weights)), variants - 1)})

	var out: Array[Dictionary] = []
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1
	for cand in candidates:
		if out.size() >= MAX_PER_CAST:
			break
		var xz: Vector2 = cand["xz"]
		var x := center.x + xz.x
		var z := center.z + xz.y
		if WorldLayout.cottage_rect_contains(Vector3(x, 0, z), 0.7):
			continue
		if WorldLayout.path_amount(x, z) > 0.35:
			continue
		q.from = Vector3(x, center.y + 8.0, z)
		q.to = Vector3(x, center.y - 8.0, z)
		var hit := space.intersect_ray(q)
		var rnd := rng.randf()
		var yaw := rng.randf() * TAU
		var scale := rng.randf_range(1.35, 2.1)
		if hit.is_empty():
			continue
		var col: Object = hit["collider"]
		if col == null or not (col as Node).is_in_group("terrain"):
			continue
		var normal: Vector3 = hit["normal"]
		if normal.y < 0.8:
			continue
		out.append({
			"pos": hit["position"], "normal": normal, "variant": cand["variant"],
			"yaw": yaw, "scale": scale, "rnd": rnd, "dist": xz.length(),
		})
	out.sort_custom(func(a, b): return a["dist"] < b["dist"])
	return out


static func _disc(rng: RandomNumberGenerator, r: float) -> Vector2:
	var a := rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r
