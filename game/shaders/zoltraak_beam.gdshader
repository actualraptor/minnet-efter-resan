shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Zoltraak beam body, drawn on a tube lying along its axis.
//
// The body is SOLID: a pure-white HDR shaft (or, for the original spell, a solid
// black one) that reads as a thick beam from any angle, including looking
// straight down it from behind the caster (then it is simply a bright disc).
// Only when it is seen from the side does it get a soft silhouette: a deep-blue
// speckled edge (white variant) or a violet fringe (black variant), which keeps
// it legible against a bright sky or a dark night.

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float core_energy = 3.0;
uniform vec3 rim_color : source_color = vec3(0.2, 0.3, 1.0);
uniform float rim_energy = 1.3;
uniform float opacity = 1.0;
uniform float core_width = 0.8;
uniform float grain = 1.0;
uniform float flow = 2.4;
uniform float dark = 0.0;
uniform float length_m = 10.0;
uniform float start_fade = 0.12;
uniform vec3 outline_color : source_color = vec3(0.16, 0.28, 0.95);
uniform float outline_start = 0.9;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying float v_along;

void vertex() {
	v_along = VERTEX.y + length_m * 0.5;
	// The black beam breathes: slow irregular distortion of its outline.
	float wob = 1.0 + dark * 0.13 * sin(v_along * 2.3 - TIME * 7.0) * sin(v_along * 0.7 + TIME * 2.1);
	VERTEX.xz *= wob;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float r = sqrt(max(1.0 - ndv * ndv, 0.0));         // 0 centre .. 1 silhouette edge
	// 1 when looking along the beam: the silhouette no longer exists then.
	vec3 axis_v = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float endon = smoothstep(0.45, 0.85, abs(dot(axis_v, normalize(VIEW))));
	float side = 1.0 - endon;

	vec2 uv1 = vec2(v_along * 0.55 - TIME * flow * 0.5, r * 1.7 + TIME * 0.35);
	vec2 uv2 = vec2(v_along * 1.9 - TIME * flow * 1.3, r * 3.1 - TIME * 0.6);
	float n1 = texture(noise, uv1).r;
	float n2 = texture(noise, uv2).r;
	float rr = r + ((n1 - 0.5) * 0.07 + (n2 - 0.5) * 0.10) * grain;

	// Solid shaft; its edge only softens when seen from the side.
	float edge_soft = 1.0 - smoothstep(0.9, 1.0, rr);
	float a = mix(1.0, edge_soft, side);
	float speck = step(0.78, texture(noise, uv2 * 2.7 + 0.37).r) * smoothstep(0.7, 0.9, r) * (1.0 - smoothstep(0.9, 1.0, r));
	a = clamp(a + speck * 0.7 * grain * side, 0.0, 1.0);

	vec3 white_col = mix(core_color * core_energy, rim_color * rim_energy, smoothstep(core_width, core_width + 0.15, rr) * side);
	white_col = mix(white_col, outline_color, smoothstep(outline_start, outline_start + 0.1, rr) * side);
	// Black variant: solid black, a thin violet fringe at the edge, seen from the side.
	vec3 dark_col = mix(vec3(0.0), rim_color * rim_energy, smoothstep(0.7, 0.97, rr) * side);
	vec3 col = mix(white_col, dark_col, dark);

	float fade = smoothstep(0.0, max(start_fade, 0.01), v_along);
	ALBEDO = col;
	ALPHA = a * opacity * fade;
}
