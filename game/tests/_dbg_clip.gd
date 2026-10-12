extends Node
## Dev: objective clipping audit. Hair and the spring-driven garments are tested,
## through a scripted motion suite, against the body and the garments that stay
## put (see ClipAudit). Prints a table and exits with a non-zero code when the
## simulation adds clipped vertices beyond the limit.
##   godot --headless --path game -- --dbg --clip
const GROWTH_LIMIT := 0.25
## Cyclic phases whose pose is the same in both passes; the one-shots (a cast, a jump,
## a spell's levitation) land on different frames per pass, so they are informational.
const STEADY := ["idle", "walk", "run", "run+turn", "fly boost+turn", "fly hover"]
const HAIR_MESHES := ["Hair"]
const SPRING_GARMENTS := ["Capelet", "CreamRuffle01", "CreamRuffle02", "CreamRuffle03", "CreamSkirtLining",
	"PlumPanel01", "PlumPanel02", "PlumPanel03", "PlumPanel04", "SagePanel01", "SagePanel02", "SagePanel03", "SagePanel04"]
const FIXED_GARMENTS := ["Blouse", "Corset", "Tights", "Boots", "LeftGatheredSleeve", "RightGatheredSleeve",
	"RuffledCollar", "LeftRuffledCuff", "RightRuffledCuff"]

var _p: Player
var _audit := ClipAudit.new()
var _hair: Array = []
var _cloth: Array = []
var _body_occ: Array = []
var _all_occ: Array = []
var _rows: Array = []


func _find(sk: Skeleton3D, n: String) -> MeshInstance3D:
	return sk.get_node_or_null(n) as MeshInstance3D


func _ready() -> void:
	var main := get_parent()
	main.get_node("UI").visible = false
	await get_tree().create_timer(1.5).timeout
	_p = main.player
	var sk: Skeleton3D = _p.model.find_children("*", "Skeleton3D", true, false)[0]
	_audit.skeleton = sk
	var body := _find(sk, "Body")
	_hair.append({"mi": _find(sk, "Hair"), "surfaces": []})
	_hair.append({"mi": body, "surfaces": [1]})
	for n in SPRING_GARMENTS:
		var m := _find(sk, n)
		if m:
			_cloth.append({"mi": m, "surfaces": [0]})
	_body_occ.append({"mi": body, "surfaces": [0]})
	_body_occ.append({"mi": _find(sk, "Face"), "surfaces": []})
	for n in FIXED_GARMENTS:
		var m := _find(sk, n)
		if m:
			_body_occ.append({"mi": m, "surfaces": []})
	_all_occ = _body_occ.duplicate()
	for c in _cloth:
		_all_occ.append(c)
	print("CLIP subjects: hair %d, cloth %d; occluders: body+fixed %d, with spring garments %d" % [_hair.size(), _cloth.size(), _body_occ.size(), _all_occ.size()])
	var rig: CameraRig = _p.camera_rig
	rig.zoom = 1.0
	_p.caster.mana = _p.caster.max_mana
	await _p.staff.summon()

	# Two passes of the same scripted suite: the authored animation alone (the
	# spring simulation switched off), and with it. Only what the simulation adds
	# counts as clipping: the authored pose is what the offline deformation gate
	# already passes.
	var base_rows: Array = []
	if OS.get_environment("CLIP_SIM_ONLY") == "":
		_p.secondary.active = false
		base_rows = await _suite(rig)
		await _reset(rig)
	_p.secondary.active = true
	var sim_rows := await _suite(rig)

	# Authored overlaps are large and mostly hidden (hair tucked under the capelet,
	# the capelet's lining against the blouse): the depth numbers are informational.
	# What is gated is how many MORE vertices sit inside a body or garment volume when
	# the simulation runs than in the authored animation alone.
	print("CLIP %-14s | %-34s | %-34s" % ["phase", "hair inside: authored -> simulated", "cloth inside: authored -> simulated"])
	var worst_growth := 0.0
	for i in sim_rows.size():
		var b: Dictionary = base_rows[i]
		var r: Dictionary = sim_rows[i]
		var gh := (float(r["hair_in"]) - float(b["hair_in"])) / maxf(float(b["hair_in"]), 100.0)
		var gc := (float(r["cloth_in"]) - float(b["cloth_in"])) / maxf(float(b["cloth_in"]), 100.0)
		if r["phase"] in STEADY:
			worst_growth = maxf(worst_growth, maxf(gh, gc))
		print("CLIP %-14s | %5d -> %5d (%+4.0f%%) depth %4.1f cm | %5d -> %5d (%+4.0f%%) depth %4.1f cm" % [r["phase"], b["hair_in"], r["hair_in"], gh * 100.0, r["hair_d"], b["cloth_in"], r["cloth_in"], gc * 100.0, r["cloth_d"]])
	print("CLIP in the steady phases the simulation adds at most %.0f%% more clipped vertices than the authored animation (limit %.0f%%)" % [worst_growth * 100.0, GROWTH_LIMIT * 100.0])
	get_tree().quit(0 if worst_growth <= GROWTH_LIMIT else 1)


func _suite(rig: CameraRig) -> Array:
	_rows = []
	await _phase("idle", [], 1.0, rig, 0.0)
	await _phase("walk", ["move_forward"], 3.0, rig, 0.0)
	await _phase("run", ["move_forward", "run"], 3.0, rig, 0.0)
	await _phase("run+turn", ["move_forward", "run"], 4.0, rig, 1.4)
	await _phase("stop", [], 1.5, rig, 0.0)
	_p.caster.equip(1)
	_p.caster.mana = _p.caster.max_mana
	_p.caster._cooldowns.clear()
	_p._cast_with_staff()
	await _phase("cast", [], 1.8, rig, 0.0)
	await _phase("jump", ["move_forward", "jump"], 1.0, rig, 0.0)
	await _phase("land", [], 1.2, rig, 0.0)
	_p.caster.equip(0)
	_p.caster.mana = _p.caster.max_mana
	_p.caster._cooldowns.clear()
	_p.caster.try_cast()
	await _phase("flowers", [], 3.0, rig, 0.0)
	_p.start_flight()
	await _phase("fly climb", ["jump"], 1.5, rig, 0.0)
	await _phase("fly boost+turn", ["move_forward", "run"], 3.5, rig, 1.0)
	await _phase("fly hover", [], 1.5, rig, 0.0)
	return _rows.duplicate(true)


func _reset(rig: CameraRig) -> void:
	if _p.flying:
		_p.stop_flight()
	await get_tree().create_timer(2.5).timeout
	var t: MeadowTerrain = get_parent().terrain
	_p.teleport(Vector3(-3.5, t.height_at(-3.5, 33.0) + 0.2, 33.0), PI)
	rig.yaw = 0.0
	await get_tree().create_timer(1.0).timeout


func _phase(label: String, actions: Array, seconds: float, rig: CameraRig, yaw_rate: float) -> void:
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	var next_sample := 0.4
	var row := {"phase": label, "hair_in": 0, "hair_d": 0.0, "hair_n": 0, "cloth_in": 0, "cloth_d": 0.0, "cloth_n": 0, "worst": ""}
	while t < seconds:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		rig.yaw += yaw_rate * dt
		if t >= next_sample:
			next_sample += 0.5
			_sample(row)
	for a in actions:
		Input.action_release(a)
	_rows.append(row)


func _sample(row: Dictionary) -> void:
	var hair := _audit.measure(_hair, _all_occ, 5)
	for k in hair:
		var r: Dictionary = hair[k]
		row["hair_n"] += int(r["tested"])
		row["hair_in"] += int(r["inside"])
		if float(r["depth_cm"]) > float(row["hair_d"]):
			row["hair_d"] = r["depth_cm"]
			row["worst"] = "hair:%s by %s at %s" % [k, str(r["by"].keys()), str(_local(r["worst"]))]
	var cloth := _audit.measure(_cloth, _body_occ, 5)
	for k in cloth:
		var r: Dictionary = cloth[k]
		row["cloth_n"] += int(r["tested"])
		row["cloth_in"] += int(r["inside"])
		if float(r["depth_cm"]) > float(row["cloth_d"]):
			row["cloth_d"] = r["depth_cm"]
			row["worst"] = "cloth:%s by %s at %s" % [k, str(r["by"].keys()), str(_local(r["worst"]))]


## A world point in the character's frame: x right(+)/left(-), y up from the hips, z front(+)/back(-), in cm.
func _local(p: Vector3) -> Vector3i:
	var sk := _audit.skeleton
	var hips := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))
	var facing := Basis(Vector3.UP, _p.model.rotation.y)
	var d := p - hips.origin
	var l := facing.inverse() * d
	return Vector3i(int(l.x * 100.0), int(l.y * 100.0), int(l.z * 100.0))
