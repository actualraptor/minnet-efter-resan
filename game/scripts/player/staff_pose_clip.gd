class_name StaffPoseClip
extends RefCounted
## One authored staff performance, in a torso-anchored frame (origin at the
## upper chest, yaw of the body, x = her left, y = up, z = forward).
##
## The hands are the primary authoring handles: each key places the REAR fist
## (`rear`, metres) and the shaft direction (`rot`, euler degrees: pitch about x
## tips the head forward, yaw about y turns it to her left). The staff itself
## follows from those, so regripping never moves the rear hand and the front
## fist always lies on the shaft.
##
## Per-key values:
##   rear   Vector3  rear (staff-side) fist position
##   rot    Vector3  shaft pitch / yaw / roll, degrees
##   ry,fy  float    rear / front grip position along the shaft (m from the
##                   staff's carry origin)
##   gl     float    1 = left hand grips the staff, 0 = free
##   fh     Vector3  free left hand position (when gl < 1), fw its weight
##   fr     Vector3  free left hand orientation, degrees
##   lean   Vector3  torso pitch/yaw/roll, degrees (spine + chest)
##   hold   bool     ease to a stop at this key (otherwise continuous velocity)

var name := ""
var keys: Array[Dictionary] = []
var events: Array[Dictionary] = []     # {t, name}
## Normalised times: the spell takes effect at `release_t`; a sustained cast
## holds at `sustain_t` until released.
var release_t := 0.5
var sustain_t := -1.0
## Shaft yaw (deg, her left positive) at the aiming moment: the body turns so the
## staff, not her chest, points at the target.
var aim_yaw_deg := 0.0
var aims := false
## Shaft elevation (deg above horizontal) at the aiming moment; the rig tilts the
## shaft by the difference to the camera aim, within +-18 deg.
var aim_elev_deg := 0.0
## Key times are a parameter (flight speed 0..1) instead of normalised time; the
## owner sets StaffRig.param and the clip never finishes by itself.
var param_driven := false
## Shaft pitch keys are relative to the world horizontal, not the body: the rig
## subtracts the body's forward pitch so "90" always means level.
var level_to_world := false
## Repeat casts that arrive while this clip is still playing resume here instead
## of restarting from the carry pose (-1 = always restart).
var chain_t := -1.0


func key(t: float, rear: Vector3, rot: Vector3, o := {}) -> StaffPoseClip:
	var k := {
		"t": t, "rear": rear, "q": Quaternion.from_euler(rot * (PI / 180.0)),
		"ry": -0.55, "fy": -0.21, "gl": 1.0, "fh": Vector3.ZERO, "fw": 0.0,
		"fr": Vector3.ZERO, "lean": Vector3.ZERO, "hold": false,
	}
	for kk in o:
		k[kk] = o[kk]
	keys.append(k)
	return self


func event(t: float, event_name: String) -> StaffPoseClip:
	events.append({"t": t, "name": event_name})
	return self


## Pose at normalised time t (0..1).
func sample(t: float) -> Dictionary:
	var n := keys.size()
	if n == 0:
		return {}
	if t <= keys[0].t:
		return keys[0].duplicate()
	if t >= keys[n - 1].t:
		return keys[n - 1].duplicate()
	var i := 0
	while i < n - 2 and keys[i + 1].t <= t:
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var pre: Dictionary = keys[maxi(i - 1, 0)]
	var post: Dictionary = keys[mini(i + 2, n - 1)]
	var u: float = (t - a.t) / maxf(b.t - a.t, 1e-5)
	var eased := u * u * (3.0 - 2.0 * u)
	var stop := bool(a.hold) or bool(b.hold)
	var w := eased if stop else u
	var out := {}
	out["rear"] = (a.rear as Vector3).cubic_interpolate(b.rear, pre.rear, post.rear, w)
	out["q"] = (a.q as Quaternion).spherical_cubic_interpolate(b.q, pre.q, post.q, w)
	for f in ["ry", "fy", "gl", "fw"]:
		out[f] = lerpf(float(a[f]), float(b[f]), eased)
	for v in ["fh", "fr", "lean"]:
		out[v] = (a[v] as Vector3).lerp(b[v], eased)
	return out


## Maps spell time (cast_time → release, then recovery) onto clip time.
func clip_time(spell_t: float, cast_time: float, recovery_time: float) -> float:
	if spell_t <= cast_time:
		return release_t * spell_t / maxf(cast_time, 1e-3)
	return release_t + (1.0 - release_t) * clampf((spell_t - cast_time) / maxf(recovery_time, 1e-3), 0.0, 1.0)
