extends Node3D
## Defensive barrier: a circle snaps open in front of her, then a dome swells out
## of it. Held until release(); hit(point) sends a ripple across the surface and
## kicks her staff hand. Everything is placed relative to the caster so the dome
## stays put in front of her while held.

const COLOR := Color(0.62, 0.86, 1.0)
const DOME_RADIUS := 1.55
const DOME_FORWARD := 0.95
const DOME_HEIGHT := 1.05

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float amount = 0.0;
uniform vec3 hit_pos = vec3(0.0);
uniform float hit_age = 10.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	float bands = smoothstep(0.88, 1.0, abs(sin(wpos.y * 6.0 - TIME * 0.5)));
	float d = distance(wpos, hit_pos);
	float ring = exp(-pow((d - hit_age * 5.0) * 2.2, 2.0)) * exp(-hit_age * 2.2);
	float flash = exp(-hit_age * 5.0) * exp(-d * 0.5);
	vec3 c = tint.rgb * (0.10 + fres * 0.85 + bands * 0.12 + ring * 1.6 + flash * 1.2);
	ALBEDO = c * amount;
	ALPHA = clamp(amount, 0.0, 1.0);
}
"""

var _caster: Node3D
var _dome: MeshInstance3D
var _mat: ShaderMaterial
var _circle: MagicCircle
var _light: OmniLight3D
var _t := 0.0
var _hit_age := 10.0
var _released := false
var _fade := 0.0
var _fwd := Vector3.FORWARD


func start(ctx: SpellContext) -> void:
	_caster = ctx.caster
	_fwd = Vector3(ctx.direction.x, 0.0, ctx.direction.z).normalized()
	_circle = MagicCircle.new()
	add_child(_circle)
	_circle.build(DOME_RADIUS * 0.8, COLOR, MagicCircle.Style.RUNE)
	_circle.alpha = 0.0
	var sm := SphereMesh.new()
	sm.radius = DOME_RADIUS
	sm.height = DOME_RADIUS
	sm.is_hemisphere = true
	sm.radial_segments = 36
	sm.rings = 14
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("tint", COLOR)
	_mat.set_shader_parameter("amount", 0.0)
	_dome = MeshInstance3D.new()
	_dome.mesh = sm
	_dome.material_override = _mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.rotation_degrees = Vector3(90, 0, 0)   # curved side toward +Z
	add_child(_dome)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 4.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_place()


func _place() -> void:
	if _caster and is_instance_valid(_caster):
		var base := _caster.global_position + Vector3(0, DOME_HEIGHT, 0) + _fwd * DOME_FORWARD
		var b := Basis.looking_at(-_fwd, Vector3.UP)   # local +Z = forward
		global_transform = Transform3D(b, base)


func _process(delta: float) -> void:
	_t += delta
	_hit_age += delta
	_place()
	var open := smoothstep(0.0, 0.18, _t)                 # circle appears
	var swell := smoothstep(0.12, 0.5, _t)                # dome grows out of it
	var life := 1.0 - _fade
	if _released:
		_fade = minf(_fade + delta * 3.2, 1.0)
		life = 1.0 - _fade
	_circle.alpha = open * (1.0 - swell * 0.55) * life
	_circle.scale = Vector3.ONE * lerpf(0.6, 1.0, open)
	# The mesh's Y is the dome's height (turned to +Z): it swells out of the circle.
	var spread := lerpf(0.5, 1.0, swell) * lerpf(1.0, 0.85, _fade)
	_dome.scale = Vector3(spread, maxf(swell, 0.001) * lerpf(1.0, 0.85, _fade), spread)
	_mat.set_shader_parameter("amount", swell * 0.9 * life)
	_mat.set_shader_parameter("hit_age", _hit_age)
	_light.light_energy = swell * 1.4 * life + exp(-_hit_age * 6.0) * 2.5
	if _released and _fade >= 1.0:
		queue_free()


## Something struck the barrier at `point` (world); ripples out from there.
func hit(point: Vector3) -> void:
	_hit_age = 0.0
	_mat.set_shader_parameter("hit_pos", point)
	if _caster and _caster.has_method("barrier_impact"):
		_caster.call("barrier_impact", (global_position - point).normalized())


func release() -> void:
	_released = true
