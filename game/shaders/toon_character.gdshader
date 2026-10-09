shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
// Soft cel shading for characters: a gentle two-tone ramp with a warm shadow
// tint and a thin rim light, so figures read clearly against the meadow.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.55, 0.72);
uniform float ramp_softness = 0.12;
uniform float rim_strength = 0.35;
uniform float emission_strength = 0.0;
uniform float light_scale = 0.62;
uniform float sheen = 0.0; // anime hair highlight band
// Materialise / dissolve from a point (the hand): visible within dissolve_radius,
// with a glowing, sparkling edge. A large radius means fully solid.
uniform vec3 dissolve_origin = vec3(0.0);
uniform float dissolve_radius = 1000.0;
uniform vec3 dissolve_glow : source_color = vec3(0.75, 1.0, 0.6);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	ALBEDO = c.rgb * COLOR.rgb;
	EMISSION = c.rgb * emission_strength;
	if (dissolve_radius < 100.0) {
		float d = distance(world_pos, dissolve_origin);
		vec3 cell = floor(world_pos * 90.0);
		float n = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		float edge = dissolve_radius - d + (n - 0.5) * 0.08;
		if (edge < 0.0) {
			discard;
		}
		EMISSION += dissolve_glow * (1.0 - smoothstep(0.0, 0.06, edge)) * 4.0;
	}
	if (sheen > 0.0) {
		// Angel-ring: a soft bright band where the view-space normal tilts slightly upward.
		float ny = NORMAL.y;
		float band = smoothstep(0.25, 0.4, ny) * (1.0 - smoothstep(0.5, 0.68, ny));
		EMISSION += vec3(1.0, 0.98, 1.0) * band * sheen;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-ramp_softness, ramp_softness, ndl);
	float shadow = smoothstep(0.25, 0.6, ATTENUATION);
	float lit = ramp * shadow;
	vec3 tone = mix(shadow_tint * 0.55, vec3(1.0), lit);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR / PI * light_scale;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	SPECULAR_LIGHT += rim * rim_strength * lit * LIGHT_COLOR / PI * ALBEDO * light_scale;
}
