shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque, cull_disabled;
// Calm river / fountain water: deep teal tinted by the sky, two slow scrolling
// ripple layers, a soft foam line along the banks. UV.x runs bank to bank (0..1),
// UV.y along the flow.

uniform vec3 shallow : source_color = vec3(0.36, 0.64, 0.66);
uniform vec3 deep : source_color = vec3(0.08, 0.27, 0.38);
uniform float flow_speed = 0.35;
uniform float ripple_scale = 0.5;
uniform float opacity = 0.9;
uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 uv = UV;
	float t = TIME * flow_speed;
	vec2 a = vec2(uv.x * 3.0, uv.y * ripple_scale - t * 0.18);
	vec2 b = vec2(uv.x * 5.5 + 0.37, uv.y * ripple_scale * 1.7 - t * 0.31);
	float n1 = texture(ripples, a).r;
	float n2 = texture(ripples, b).r;
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.35 + (n2 - 0.5) * 0.2, 1.0, (n2 - 0.5) * 0.3 - (n1 - 0.5) * 0.15));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.9));

	float across = abs(uv.x - 0.5) * 2.0;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, shallow, smoothstep(0.1, 1.0, across) * 0.8 + n1 * 0.18);
	col = mix(col, vec3(0.62, 0.78, 0.9), fres * 0.55);
	// Foam where the water meets the bank.
	float foam = smoothstep(0.8, 0.97, across + (n2 - 0.5) * 0.18) * (0.55 + 0.45 * n1);
	col = mix(col, vec3(0.92, 0.96, 0.98), foam * 0.8);

	ALBEDO = col;
	ROUGHNESS = 0.07 + foam * 0.5;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	ALPHA = opacity;
}
