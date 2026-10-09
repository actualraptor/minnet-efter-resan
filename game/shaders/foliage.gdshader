shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Painterly foliage for scripted tree/bush meshes. Vertex COLOR.r = sway
// weight, COLOR.g = per-clump tint. Soft wrap lighting + subsurface-like
// backlight keep canopies glowing rather than flat green blobs.

global uniform float game_time;
global uniform float wind_strength;

uniform vec4 albedo : source_color = vec4(0.37, 0.6, 0.28, 1.0);
uniform vec3 tint_light : source_color = vec3(0.72, 0.84, 0.4);
uniform vec3 tint_dark : source_color = vec3(0.2, 0.38, 0.22);
uniform float sway = 0.06;
uniform float is_leaf = 1.0;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_leaf_tex = false;

varying float vsway;
varying float vtint;
varying vec3 wpos;

void vertex() {
	vsway = COLOR.r;
	vtint = COLOR.g;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float t = game_time;
	float w = sin(t * 1.3 + phase) * 0.6 + sin(t * 2.7 + phase * 1.7 + VERTEX.y) * 0.25;
	float flutter = sin(t * 6.0 + wpos.x * 3.0 + wpos.z * 2.0) * 0.15 * is_leaf;
	vec3 off = vec3(0.8, 0.0, 0.5) * (w + flutter) * sway * vsway * wind_strength;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	vec3 base = albedo.rgb;
	if (is_leaf > 0.5) {
		float hl = smoothstep(0.35, 1.0, vsway);
		base = mix(tint_dark, base, 0.55 + 0.45 * hl);
		base = mix(base, tint_light, hl * 0.35 + (vtint - 0.5) * 0.18);
	}
	if (use_leaf_tex) {
		vec4 lt = texture(leaf_tex, UV);
		ALPHA = lt.a;
		ALPHA_SCISSOR_THRESHOLD = 0.45;
		base *= mix(0.72, 1.18, lt.r);
	}
	ALBEDO = base;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = is_leaf > 0.5 ? vec3(0.32, 0.42, 0.12) : vec3(0.0);
}

void light() {
	// Half-lambert wrap for soft, illustrated canopies.
	float ndl = dot(NORMAL, LIGHT);
	float wrap = is_leaf > 0.5 ? clamp(ndl * 0.6 + 0.4, 0.0, 1.0) : clamp(ndl, 0.0, 1.0);
	DIFFUSE_LIGHT += wrap * ATTENUATION * LIGHT_COLOR / PI;
}
