shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Fläckfri's wipe: a soft bright band that sweeps across a surface twice (a cloth
// going over it), with a faint diagonal shimmer inside the band.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float strength = 1.0;

void fragment() {
	float u = fract(t * 2.0);
	float centre = mix(-0.25, 1.25, u);
	float band = 1.0 - smoothstep(0.0, 0.22, abs(UV.x - centre));
	float shimmer = 0.65 + 0.35 * sin((UV.x * 1.0 + UV.y * 0.7) * 70.0 + t * 30.0);
	float edge = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
	float life = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.9, 1.0, t));
	ALBEDO = tint.rgb * band * shimmer * edge * life * strength;
}
