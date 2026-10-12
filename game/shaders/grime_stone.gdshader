shader_type spatial;
// Weathered stone with moss. `grime` 1 = overgrown, 0 = clean; moss recedes in
// irregular patches (world-space noise) as it falls, so cleaning looks like a
// wipe and not a fade. The stone itself is worn: rain streaks, small pits, and
// damp moss gathering low on the thing.
// Optional alpha cut-out from a texture (hair cards, lashes on a statue of her).

uniform vec3 stone : source_color = vec3(0.66, 0.65, 0.62);
uniform vec3 moss : source_color = vec3(0.22, 0.38, 0.14);
uniform float grime = 1.0;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float base_y = 0.0;
uniform bool use_alpha_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = 0.5;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (use_alpha_tex) {
		ALPHA = texture(albedo_tex, UV).a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
	float n = texture(noise, wp.xz * 0.8 + wp.y * 0.55).r;
	float fine = texture(noise, wp.xz * 3.4 - wp.y * 2.1).r;
	float low = 1.0 - smoothstep(0.0, 2.0, wp.y - base_y);
	float s = grime * 1.3 - 0.58 + low * 0.22 - (n * 0.75 + fine * 0.25);
	float cov = smoothstep(0.0, 0.1, s);
	// Rain streaks run down; pits are small dark chips.
	float streak = texture(noise, vec2((wp.x + wp.z) * 0.9, wp.y * 0.12)).r;
	float pits = step(0.8, fine);
	vec3 base = stone * (0.82 + 0.2 * fine) * (0.82 + 0.3 * streak) * (1.0 - 0.35 * pits);
	ALBEDO = mix(base, moss * (0.8 + 0.5 * fine), cov);
	ROUGHNESS = mix(0.86, 0.96, cov);
}
