shader_type spatial;
// Weathered stone with moss. `grime` 1 = overgrown, 0 = clean; moss recedes in
// irregular patches (world-space noise) as it falls, so cleaning looks like a
// wipe and not a fade.

uniform vec3 stone : source_color = vec3(0.66, 0.65, 0.62);
uniform vec3 moss : source_color = vec3(0.22, 0.38, 0.14);
uniform float grime = 1.0;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise, wp.xz * 0.8 + wp.y * 0.55).r;
	float fine = texture(noise, wp.xz * 3.4 - wp.y * 2.1).r;
	float s = grime * 1.3 - 0.58 - (n * 0.75 + fine * 0.25);
	float cov = smoothstep(0.0, 0.1, s);
	vec3 base = stone * (0.9 + 0.2 * fine);
	ALBEDO = mix(base, moss * (0.8 + 0.5 * fine), cov);
	ROUGHNESS = mix(0.82, 0.96, cov);
}
