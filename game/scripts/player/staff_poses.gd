class_name StaffPoses
extends RefCounted
## Authored staff performances (see StaffPoseClip for the frame). Her arm reach
## is short: shoulder to wrist ~0.41 m, to the fist ~0.46 m, shoulders at
## (+-0.10, +0.09, -0.02) from the anchor. Every key keeps both fists inside
## that, and the staff's butt outside her torso (forward-pointing poses are held
## off to her right side, like a rifle at the hip, with the body turned to match).

static var _cache := {}


static func get_clip(clip_name: StringName) -> StaffPoseClip:
	if _cache.has(clip_name):
		return _cache[clip_name]
	var c: StaffPoseClip = null
	match clip_name:
		&"zoltraak":
			c = _zoltraak()
		&"flower":
			c = _flower()
		&"barrier":
			c = _barrier()
		&"zoltraak_aim":
			c = _zoltraak_aim()
		&"fly":
			c = _fly()
	_cache[clip_name] = c
	return c


## Fast, precise, repeatable. Prepare -> aim (steady) -> release -> follow-through
## -> recovery. The shaft is yawed 22 deg to her left of her chest line, so the
## body turns right by that much when aiming and the staff points at the target.
static func _zoltraak() -> StaffPoseClip:
	var c := StaffPoseClip.new()
	c.name = "zoltraak"
	c.aims = true
	c.aim_yaw_deg = 22.0
	c.release_t = 0.5
	c.chain_t = 0.42
	c.aim_elev_deg = 9.0
	c.key(0.00, Vector3(-0.22, -0.26, 0.10), Vector3(6, 0, 0), {"gl": 0.0, "hold": true})
	c.key(0.20, Vector3(-0.20, -0.14, 0.05), Vector3(52, 14, 0), {"gl": 1.0, "lean": Vector3(2, 4, 0)})
	c.key(0.42, Vector3(-0.20, -0.09, 0.00), Vector3(81, 22, 0), {"gl": 1.0, "lean": Vector3(3, 10, 0), "hold": true})
	c.key(0.50, Vector3(-0.20, -0.09, 0.00), Vector3(81, 22, 0), {"gl": 1.0, "lean": Vector3(3, 10, 0), "hold": true})
	# Release: the rear hand gives a hair of recoil; the staff stays under control.
	c.key(0.56, Vector3(-0.20, -0.08, -0.025), Vector3(83, 22, 0), {"gl": 1.0, "lean": Vector3(1, 10, 0)})
	c.key(0.72, Vector3(-0.20, -0.09, -0.005), Vector3(81, 22, 0), {"gl": 1.0, "lean": Vector3(2, 8, 0)})
	c.key(1.00, Vector3(-0.22, -0.26, 0.10), Vector3(6, 0, 0), {"gl": 0.0, "hold": true})
	c.event(0.42, "charge_full")
	c.event(0.50, "release")
	return c


## Held aim for Zoltraak's focus mode: raise to the aiming pose and hold there
## (sustained) until the aim is released, then lower.
static func _zoltraak_aim() -> StaffPoseClip:
	var c := StaffPoseClip.new()
	c.name = "zoltraak_aim"
	c.aims = true
	c.aim_yaw_deg = 22.0
	c.aim_elev_deg = 9.0
	c.release_t = 0.3
	c.sustain_t = 0.3
	c.key(0.00, Vector3(-0.22, -0.26, 0.10), Vector3(6, 0, 0), {"gl": 0.0, "hold": true})
	c.key(0.14, Vector3(-0.20, -0.14, 0.05), Vector3(52, 14, 0), {"gl": 1.0, "lean": Vector3(2, 4, 0)})
	c.key(0.30, Vector3(-0.20, -0.09, 0.00), Vector3(81, 22, 0), {"gl": 1.0, "lean": Vector3(3, 10, 0), "hold": true})
	c.key(1.00, Vector3(-0.22, -0.26, 0.10), Vector3(6, 0, 0), {"gl": 0.0, "hold": true})
	return c


## Flying with the staff, after the flight concept sheet: key time is speed
## (0 = hovering, 1 = full boost). The staff stays physically in the right hand:
## upright at her side while she hovers, then carried forward and a little up as
## she glides, while the free arm opens out behind for balance. Shaft pitch is
## relative to the world horizontal (the rig subtracts her small body lean).
static func _fly() -> StaffPoseClip:
	var c := StaffPoseClip.new()
	c.name = "fly"
	c.param_driven = true
	c.level_to_world = true
	c.key(0.00, Vector3(-0.24, -0.30, 0.10), Vector3(4, 0, 0), {"gl": 0.0, "hold": true})
	c.key(0.22, Vector3(-0.25, -0.16, 0.14), Vector3(30, -3, 0), {"gl": 0.0, "fh": Vector3(0.30, -0.18, 0.0), "fr": Vector3(0, 0, 14), "fw": 0.7})
	c.key(0.55, Vector3(-0.34, -0.06, 0.20), Vector3(54, -9, 0), {"gl": 0.0, "fh": Vector3(0.35, -0.04, -0.10), "fr": Vector3(0, 0, 6), "fw": 1.0, "lean": Vector3(-2, 0, 0)})
	c.key(1.00, Vector3(-0.35, -0.02, 0.24), Vector3(62, -10, 0), {"gl": 0.0, "fh": Vector3(0.34, 0.0, -0.16), "fr": Vector3(0, 0, 0), "fw": 1.0, "lean": Vector3(-3, 0, 0)})
	return c


## Gentle, graceful: gather the staff to the chest, lift it, sweep a broad circle
## (the head traces a wide arc), bloom, open the free hand outward, hold, relax.
static func _flower() -> StaffPoseClip:
	var c := StaffPoseClip.new()
	c.name = "flower"
	c.release_t = 0.56
	c.sustain_t = -1.0
	c.key(0.00, Vector3(-0.24, -0.30, 0.10), Vector3(4, 0, 0), {"gl": 0.0, "hold": true})
	c.key(0.12, Vector3(-0.10, -0.20, 0.20), Vector3(5, 0, 0), {"gl": 1.0, "lean": Vector3(5, 0, 0), "hold": true})
	c.key(0.24, Vector3(-0.12, -0.03, 0.20), Vector3(10, 0, 0), {"gl": 1.0, "lean": Vector3(-2, 0, 0)})
	# The arc: the rear fist circles ~10 cm, the head sweeps a broad circle.
	c.key(0.31, Vector3(-0.21, 0.01, 0.24), Vector3(20, -22, 0), {"gl": 1.0, "lean": Vector3(0, -6, 3)})
	c.key(0.38, Vector3(-0.11, 0.09, 0.26), Vector3(32, 0, 0), {"gl": 1.0, "lean": Vector3(-3, 0, 0)})
	c.key(0.45, Vector3(-0.01, 0.01, 0.24), Vector3(20, 24, 0), {"gl": 1.0, "lean": Vector3(0, 7, -3)})
	c.key(0.51, Vector3(-0.11, -0.07, 0.22), Vector3(6, 0, 0), {"gl": 1.0, "lean": Vector3(2, 0, 0)})
	c.key(0.56, Vector3(-0.21, 0.01, 0.24), Vector3(20, -22, 0), {"gl": 1.0, "lean": Vector3(0, -4, 2)})
	# Bloom: the free hand lets go and opens outward; the staff rests to the right.
	c.key(0.68, Vector3(-0.30, -0.03, 0.14), Vector3(78, -42, 0), {"gl": 0.0, "fh": Vector3(0.33, 0.0, 0.20), "fr": Vector3(160, 0, 20), "fw": 1.0, "lean": Vector3(-2, 0, 0), "hold": true})
	c.key(0.82, Vector3(-0.30, -0.01, 0.15), Vector3(76, -44, 0), {"gl": 0.0, "fh": Vector3(0.35, 0.03, 0.18), "fr": Vector3(165, 0, 24), "fw": 1.0, "lean": Vector3(-1, 0, 0), "hold": true})
	c.key(1.00, Vector3(-0.24, -0.30, 0.10), Vector3(4, 0, 0), {"gl": 0.0, "fw": 0.0, "hold": true})
	c.event(0.56, "release")
	return c


## Defensive: raise the staff upright in both hands, channel (the circle forms in
## front), hold while the barrier is needed, then lower.
static func _barrier() -> StaffPoseClip:
	var c := StaffPoseClip.new()
	c.name = "barrier"
	c.release_t = 0.45
	c.sustain_t = 0.55
	c.key(0.00, Vector3(-0.24, -0.30, 0.10), Vector3(4, 0, 0), {"gl": 0.0, "hold": true})
	c.key(0.20, Vector3(-0.12, -0.10, 0.22), Vector3(-2, 0, 0), {"gl": 1.0, "lean": Vector3(-2, 0, 0)})
	c.key(0.45, Vector3(-0.12, 0.00, 0.30), Vector3(12, 0, 0), {"gl": 1.0, "lean": Vector3(3, 0, 0), "hold": true})
	c.key(0.55, Vector3(-0.12, 0.02, 0.32), Vector3(7, 0, 0), {"gl": 1.0, "lean": Vector3(1, 0, 0), "hold": true})
	c.key(1.00, Vector3(-0.24, -0.30, 0.10), Vector3(4, 0, 0), {"gl": 0.0, "hold": true})
	c.event(0.45, "release")
	return c
