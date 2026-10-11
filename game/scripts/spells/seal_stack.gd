class_name SealStack
extends Node3D
## A row of seals along the firing axis (local +Z), each facing it, the beam
## passing through their apertures: the formation Zoltraak fires through.
## assemble() raises them one after another; retract() folds them away. Sizes
## grow with distance like the anime's stacked circles.

var _seals: Array[SixPetalCircle] = []
var _target := 0.0
var _a := 0.0
var _charge := 1.0
var _delay := 0.05
var _alpha_scale := 1.0


func build(count: int, base_radius: float, spacing: float, kind: ZoltraakVisuals.Kind) -> SealStack:
	for i in count:
		var r := base_radius * (1.0 + 0.32 * i)
		var s := SixPetalCircle.new(r, ZoltraakVisuals.seal_tint(kind), 6 if i % 2 == 0 else 8)
		add_child(s)
		s.position = Vector3(0, 0, 0.35 + spacing * i)
		s.set_aperture(0.2 + 0.03 * i)
		s.set_energy(2.6 if kind == ZoltraakVisuals.Kind.WHITE else 2.0)
		s.set_spin((0.16 + 0.04 * i) * (1.0 if i % 2 == 0 else -1.0))
		s.set_haze(0.05 if kind == ZoltraakVisuals.Kind.WHITE else 0.0)
		s.set_alpha(0.0)
		_seals.append(s)
	return self


func set_charge(c: float) -> void:
	_charge = c


func set_alpha_scale(a: float) -> void:
	_alpha_scale = a


func assemble(delay_per_seal := 0.05) -> void:
	_target = 1.0
	_delay = delay_per_seal


func retract() -> void:
	_target = 0.0


func is_gone() -> bool:
	return _target <= 0.0 and _a <= 0.01


func seal_count() -> int:
	return _seals.size()


func _process(delta: float) -> void:
	_a = move_toward(_a, _target, delta * (3.2 if _target > _a else 4.5))
	for i in _seals.size():
		var s := _seals[i]
		# Each seal starts a little after the previous one and snaps into place.
		var k := clampf((_a - i * _delay * 3.0) / maxf(1.0 - i * _delay * 3.0, 0.2), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		s.set_alpha(k * _alpha_scale * (0.95 - 0.07 * i))
		s.set_charge(_charge * (0.55 + 0.45 * k))
		s.scale = Vector3.ONE * lerpf(0.55, 1.0, k)
