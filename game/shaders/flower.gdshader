shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Field of Flowers bloom. INSTANCE_CUSTOM.r = birth time (game_time seconds),
// INSTANCE_CUSTOM.g = per-flower random 0..1. COLOR.a marks the mesh part:
// 0 = stem/leaf, 0.5 = flower centre, 1 = petal.

global uniform float game_time;
global uniform float wind_strength;

uniform float head_height = 0.3;
uniform vec3 petal_a : source_color = vec3(1.0);
uniform vec3 petal_b : source_color = vec3(1.0);
uniform vec3 glow_color : source_color = vec3(0.85, 1.0, 0.5);
uniform float grow_time = 0.9;
uniform float bloom_time = 1.3;

varying float part;
varying float age;
varying float rnd;

float ease_out_back(float x) {
	float c1 = 1.9;
	float c3 = c1 + 1.0;
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0);
}

void vertex() {
	part = COLOR.a;
	rnd = INSTANCE_CUSTOM.g;
	age = game_time - INSTANCE_CUSTOM.r;
	float sprout = smoothstep(0.0, grow_time, age);
	float bloom_lin = clamp((age - grow_time * 0.65) / bloom_time, 0.0, 1.0);
	float bloom = bloom_lin > 0.0 ? ease_out_back(bloom_lin) : 0.0;
	vec3 head = vec3(0.0, head_height, 0.0);
	if (part < 0.25) {
		VERTEX.y *= sprout;
		VERTEX.xz *= mix(0.35, 1.0, sprout);
	} else {
		vec3 local = VERTEX - head;
		VERTEX = head * vec3(1.0, sprout, 1.0) + local * bloom;
	}
	// Unborn flowers collapse to nothing.
	VERTEX *= step(0.0, age);
	// Gentle sway, stronger at the head.
	float h = clamp(VERTEX.y / max(head_height, 0.01), 0.0, 1.2);
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(game_time * 1.9 + wp.x * 0.6 + wp.z * 0.4 + rnd * 6.0) * 0.035 * wind_strength;
	VERTEX.x += sway * h * h;
	VERTEX.z += sway * 0.6 * h * h;
}

void fragment() {
	vec3 petal = mix(petal_a, petal_b, rnd) * COLOR.rgb;
	vec3 col = COLOR.rgb;
	if (part > 0.75) {
		col = petal;
	}
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = part > 0.75 ? petal * 0.45 : vec3(0.12, 0.2, 0.06);
	// Newly bloomed flowers glow, then settle into ordinary, real flowers.
	float glow = smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(1.2, 4.5, age));
	EMISSION = glow_color * glow * (part > 0.25 ? 1.1 : 0.35);
}
