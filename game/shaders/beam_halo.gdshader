shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Soft additive halo around a Zoltraak beam: brightest on the axis, falling off
// to nothing at the silhouette (1 - |N.V| is the screen-space radial position on
// a cylinder). It gives the white beam its cool bloom and the black beam a violet
// aura, so the black core stays readable against a dark scene.

uniform vec3 color : source_color = vec3(0.6, 0.75, 1.0);
uniform float energy = 1.2;
uniform float falloff = 1.6;
uniform float length_m = 10.0;
uniform float start_fade = 0.8;

varying float v_along;

void vertex() {
	v_along = VERTEX.y + length_m * 0.5;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 axis_v = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float endon = smoothstep(0.5, 0.9, abs(dot(axis_v, normalize(VIEW))));
	float a = mix(pow(ndv, falloff), 0.0, endon);
	float f = smoothstep(0.0, max(start_fade, 0.01), v_along);
	ALBEDO = color * energy * a * f;
	ALPHA = a * f;
}
