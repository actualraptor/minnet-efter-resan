class_name SixPetalCircle
extends Node3D
## Zoltraak's geometric seal as a quad with the magic_seal shader. `radius` is
## the world radius of the outer ring; `charge` builds up its detail; the
## aperture opens a clear centre (fraction of the radius) for the beam to pass.

const SHADER := preload("res://shaders/magic_seal.gdshader")

var radius := 0.6
var _mi: MeshInstance3D
var _mat: ShaderMaterial


func _init(r := 0.6, color := Color(0.78, 0.9, 1.0), petals := 6) -> void:
	radius = r
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_mat.set_shader_parameter("petals", petals)
	q.material = _mat
	_mi = MeshInstance3D.new()
	_mi.mesh = q
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.scale = Vector3(r, r, r)
	add_child(_mi)


func set_charge(c: float) -> void:
	_mat.set_shader_parameter("charge", clampf(c, 0.0, 1.0))


func set_alpha(a: float) -> void:
	_mat.set_shader_parameter("alpha", a)
	visible = a > 0.01


func set_aperture(h: float) -> void:
	_mat.set_shader_parameter("hole", h)


func set_haze(h: float) -> void:
	_mat.set_shader_parameter("haze", h)


func set_energy(e: float) -> void:
	_mat.set_shader_parameter("energy", e)


func set_spin(s: float) -> void:
	_mat.set_shader_parameter("spin_speed", s)


func set_radius(r: float) -> void:
	radius = r
	_mi.scale = Vector3(r, r, r)


## Orient so the circle's normal (+Z) is `dir`.
func face(dir: Vector3) -> void:
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(-d, up)
