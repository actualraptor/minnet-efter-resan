shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Painterly meadow ground: warm grass tones broken by large soft colour patches,
// worn dirt paths, and the luminous Field of Flowers wave travelling over it.

global uniform float game_time;
global uniform vec4 spell_wave;          // xyz = centre, w = radius
global uniform float spell_wave_strength;

uniform vec3 grass_light : source_color = vec3(0.55, 0.74, 0.29);
uniform vec3 grass_dark : source_color = vec3(0.27, 0.49, 0.20);
uniform vec3 grass_warm : source_color = vec3(0.72, 0.76, 0.33);
uniform vec3 hill_tint : source_color = vec3(0.42, 0.58, 0.36);
uniform vec3 dirt_light : source_color = vec3(0.70, 0.58, 0.42);
uniform vec3 dirt_dark : source_color = vec3(0.50, 0.39, 0.28);
uniform vec3 wave_color : source_color = vec3(0.85, 1.0, 0.55);
// Towns: cobbled streets (vertex alpha = 1 - cobble) and wet river banks.
uniform vec3 cobble_light : source_color = vec3(0.66, 0.62, 0.56);
uniform vec3 cobble_dark : source_color = vec3(0.42, 0.40, 0.38);
uniform vec3 mud : source_color = vec3(0.40, 0.33, 0.25);
uniform float water_level = -1000.0;
uniform sampler2D patch_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec4 vcol;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	vec2 p = world_pos.xz;
	float patch = texture(patch_noise, p * 0.011).r;
	float patch2 = texture(patch_noise, p * 0.037 + vec2(0.3, 0.7)).r;
	float detail = texture(detail_noise, p * 0.35).r;

	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.25, 0.75, patch));
	grass = mix(grass, grass_warm, smoothstep(0.55, 0.85, patch2) * 0.55);
	grass *= 0.88 + detail * 0.24;
	grass = mix(grass, hill_tint, vcol.b * 0.45);

	float path = vcol.r;
	float pebbles = texture(detail_noise, p * 1.7).r;
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.3, 0.8, detail));
	dirt = mix(dirt, dirt_light * 1.12, step(0.78, pebbles) * 0.6);
	// Ragged path edge so it never looks like a vector stroke.
	float edge = smoothstep(0.35, 0.65, path + (detail - 0.5) * 0.45);
	vec3 col = mix(grass, dirt, edge);

	// Cobbles: running-bond stones with a tone per stone and dark joints.
	float cob = 1.0 - vcol.a;
	if (cob > 0.01) {
		vec2 q = p * vec2(2.3, 3.4);
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5 + row * 0.173;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float tone = texture(detail_noise, (cell + 0.5) * 0.0731).r;
		vec3 stone = mix(cobble_dark, cobble_light, smoothstep(0.2, 0.8, tone));
		stone *= 0.92 + 0.16 * texture(detail_noise, p * 2.9).r;
		float joint = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y) * 1.4);
		stone = mix(cobble_dark * 0.5, stone, smoothstep(0.03, 0.13, joint));
		col = mix(col, stone, smoothstep(0.3, 0.62, cob + (detail - 0.5) * 0.3));
	}
	// River banks go to wet mud near the waterline.
	float wet = 1.0 - smoothstep(water_level + 0.02, water_level + 0.55, world_pos.y);
	col = mix(col, mud * (0.8 + detail * 0.4), wet * 0.9);

	// Field of Flowers wave: a bright band at the travelling radius and a faint
	// fading glow inside it. It is computed in world space, so it hugs terrain.
	float d = distance(world_pos.xz, spell_wave.xz);
	float band = exp(-pow((d - spell_wave.w) / 0.55, 2.0));
	float inner = (1.0 - smoothstep(0.0, spell_wave.w + 0.01, d)) * 0.12;
	float shimmer = 0.75 + 0.25 * sin(d * 3.0 - game_time * 9.0);
	float wave = (band * shimmer + inner) * spell_wave_strength;

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.85, edge);
	SPECULAR = 0.25;
	EMISSION = wave_color * wave * 1.7;
}
