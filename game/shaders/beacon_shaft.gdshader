shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// A column of sunlit haze over an objective: brightest at the foot, thinning
// upward, soft at the edges (so it reads as light in the air, not a tube).

uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float fade = 1.0;

void fragment() {
	float h = 1.0 - UV.y;                       // 0 at the top of the cylinder, 1 at the foot
	float rim = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	float pulse = 0.82 + 0.18 * sin(TIME * 1.3 + h * 6.0);
	ALBEDO = tint.rgb * rim * pow(h, 1.4) * pulse * 0.55 * fade;
}
