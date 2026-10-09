shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Soft cel shading for characters: a gentle two-tone ramp with a warm shadow
// tint and a thin rim light, so figures read clearly against the meadow.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.55, 0.72);
uniform float ramp_softness = 0.12;
uniform float rim_strength = 0.35;
uniform float emission_strength = 0.0;

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	ALBEDO = c.rgb * COLOR.rgb;
	EMISSION = c.rgb * emission_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-ramp_softness, ramp_softness, ndl);
	float shadow = smoothstep(0.25, 0.6, ATTENUATION);
	float lit = ramp * shadow;
	vec3 tone = mix(shadow_tint * 0.55, vec3(1.0), lit);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	SPECULAR_LIGHT += rim * rim_strength * lit * LIGHT_COLOR / PI * ALBEDO;
}
