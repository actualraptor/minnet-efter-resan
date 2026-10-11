shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Zoltraak beam body, drawn on a cylinder lying along its axis. Radial position
// across the beam comes from the view angle (1 - |N.V| on a cylinder is exactly
// the screen-space offset), so the profile is correct from every direction.
//
// White variant: a pure-white HDR core, a narrow cool falloff and a speckled blue
// rim that keeps the silhouette readable against a bright sky. Black variant
// (dark = 1): a black body with faint violet edging and a wobbling outline.

uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float core_energy = 7.0;
uniform vec3 rim_color : source_color = vec3(0.42, 0.55, 1.0);
uniform float rim_energy = 1.7;
uniform float opacity = 1.0;
uniform float core_width = 0.58;
// Deep-blue outline: keeps the white shaft readable against a bright sky (the
// anime beams carry a speckled blue-violet edge for the same reason).
uniform vec3 outline_color : source_color = vec3(0.16, 0.28, 0.95);
uniform float outline_start = 0.8;
uniform float grain = 1.0;
uniform float flow = 2.4;
uniform float dark = 0.0;
uniform float length_m = 10.0;
uniform float start_fade = 0.6;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying float v_along;

void vertex() {
	// Mesh-local Y runs 0 .. length after the offset below.
	v_along = VERTEX.y + length_m * 0.5;
	// The black beam breathes: slow irregular distortion of its outline.
	float wob = 1.0 + dark * 0.13 * sin(v_along * 2.3 - TIME * 7.0) * sin(v_along * 0.7 + TIME * 2.1);
	VERTEX.xz *= wob;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float r = sqrt(max(1.0 - ndv * ndv, 0.0));         // 0 centre .. 1 silhouette edge
	vec2 uv1 = vec2(v_along * 0.55 - TIME * flow * 0.5, r * 1.7 + TIME * 0.35);
	vec2 uv2 = vec2(v_along * 1.9 - TIME * flow * 1.3, r * 3.1 - TIME * 0.6);
	float n1 = texture(noise, uv1).r;
	float n2 = texture(noise, uv2).r;
	// Body outline breaks up only a little (the core stays a clean white shaft);
	// the grain lives mostly in the rim.
	float jag = (n1 - 0.5) * 0.07 + (n2 - 0.5) * 0.10;
	float rr = r + jag * grain;

	float core = 1.0 - smoothstep(core_width - 0.05, core_width + 0.1, rr);
	float body = 1.0 - smoothstep(0.86, 0.99, rr);
	// Speckled rim: sparse grains cling just outside the solid body.
	float speck = step(0.78, texture(noise, uv2 * 2.7 + 0.37).r) * (1.0 - smoothstep(0.9, 1.0, r)) * smoothstep(0.7, 0.9, r);
	float a = clamp(body + speck * 0.75 * grain, 0.0, 1.0);

	vec3 white_rim = rim_color * rim_energy;
	vec3 col = mix(white_rim, core_color * core_energy, core);
	// A hair of cool falloff inside the core so it is not a flat disc of white.
	col = mix(col, core_color * core_energy * vec3(0.94, 0.97, 1.0), (1.0 - core) * 0.0);
	// Dark variant: the body is black; only a thin violet fringe and speckle glow.
	// The black body is solid black to within a thin violet fringe at the edge.
	vec3 dark_col = mix(rim_color * rim_energy, vec3(0.0), smoothstep(0.08, 0.30, 1.0 - rr));
	col = mix(col, dark_col, dark);
	col = mix(col, outline_color, smoothstep(outline_start, outline_start + 0.12, rr) * (1.0 - dark));

	float fade = smoothstep(0.0, max(start_fade, 0.01), v_along);
	ALBEDO = col;
	ALPHA = a * opacity * fade;
}
