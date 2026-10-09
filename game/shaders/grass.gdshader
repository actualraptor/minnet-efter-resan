shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Stylised grass blades for MultiMesh clumps. COLOR.a of the mesh = height along
// blade (0 root .. 1 tip). Wind sways tips; the player gently parts the grass.

global uniform float game_time;
global uniform float wind_strength;
global uniform vec3 player_position;
global uniform vec4 spell_wave;
global uniform float spell_wave_strength;

uniform vec3 base_color : source_color = vec3(0.2, 0.4, 0.15);
uniform vec3 tip_color : source_color = vec3(0.62, 0.8, 0.3);
uniform vec3 warm_tip : source_color = vec3(0.88, 0.82, 0.38);
uniform vec3 cool_tip : source_color = vec3(0.45, 0.72, 0.5);
uniform vec3 dry_tip : source_color = vec3(0.86, 0.74, 0.45);
uniform vec3 wave_color : source_color = vec3(0.85, 1.0, 0.55);
uniform sampler2D patch_noise : filter_linear_mipmap, repeat_enable;

varying float tip;
varying vec3 world_pos;
varying float tint;

void vertex() {
	tip = COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = INSTANCE_CUSTOM.r;
	float sway_mask = tip * tip;
	float t = game_time;
	float gust = texture(patch_noise, wp.xz * 0.02 + vec2(t * 0.035, t * 0.02)).r;
	vec2 wind = vec2(0.8, 0.45) * (sin(t * 1.7 + wp.x * 0.35 + wp.z * 0.2) * 0.12 + gust * 0.38) * wind_strength;
	vec3 offset = vec3(wind.x, 0.0, wind.y) * sway_mask;
	// Part the grass around the player.
	vec2 away = wp.xz - player_position.xz;
	float pd = length(away);
	float push = (1.0 - smoothstep(0.3, 1.3, pd)) * step(abs(wp.y - player_position.y), 1.5);
	offset.xz += normalize(away + vec2(0.0001)) * push * 0.45 * sway_mask;
	offset.y -= push * 0.25 * sway_mask;
	// Convert world-space offset to model space (instances are uniformly scaled/rotated).
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
	world_pos = wp;
	// Point normals mostly up so blades shade like a soft field, not slivers.
	NORMAL = mix(NORMAL, (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.8);
}

void fragment() {
	float patch = texture(patch_noise, world_pos.xz * 0.011).r;
	vec3 tipc = mix(tip_color, warm_tip, smoothstep(0.45, 0.9, patch) * 0.6 + tint * 0.2);
	float patch_b = texture(patch_noise, world_pos.xz * 0.045 + vec2(0.5, 0.1)).r;
	tipc = mix(tipc, cool_tip, smoothstep(0.55, 0.85, patch_b) * 0.5);
	tipc = mix(tipc, dry_tip, step(0.93, tint) * 0.7);
	vec3 col = mix(base_color, tipc, smoothstep(0.0, 1.0, tip));
	col *= 0.9 + tint * 0.2;
	float d = distance(world_pos.xz, spell_wave.xz);
	float band = exp(-pow((d - spell_wave.w) / 1.1, 2.0)) * spell_wave_strength;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35, 0.45, 0.15) * tip;
	EMISSION = wave_color * band * tip * 0.45;
	AO = mix(0.55, 1.0, tip);
	AO_LIGHT_AFFECT = 0.6;
}
