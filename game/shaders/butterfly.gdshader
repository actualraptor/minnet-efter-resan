shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Particle butterflies: a flat plane whose two halves flap; wing shape and
// markings are drawn from UVs, colour comes from the particle.

varying vec3 tint;

void vertex() {
	float id = float(INSTANCE_ID);
	float flap = sin(TIME * 16.0 + id * 1.7) * 0.5 + 0.5;
	float side = sign(VERTEX.x);
	float ang = mix(0.15, 1.25, flap);
	float x = abs(VERTEX.x);
	VERTEX.x = side * x * cos(ang);
	VERTEX.y += x * sin(ang);
	tint = COLOR.rgb;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ax = abs(p.x);
	// Upper and lower wing lobes on each side, with a thin body.
	float upper = length((vec2(ax, p.y) - vec2(0.5, -0.3)) / vec2(0.5, 0.55));
	float lower = length((vec2(ax, p.y) - vec2(0.38, 0.45)) / vec2(0.36, 0.42));
	float wing = min(upper, lower);
	float body = step(ax, 0.06) * step(abs(p.y), 0.7);
	if (wing > 1.0 && body < 0.5) {
		discard;
	}
	vec3 c = tint;
	c = mix(c, c * 0.45, smoothstep(0.75, 1.0, wing));
	c = mix(c, vec3(1.0), smoothstep(0.25, 0.0, length(vec2(ax, p.y) - vec2(0.55, -0.35))) * 0.6);
	if (body > 0.5) {
		c = vec3(0.2, 0.16, 0.2);
	}
	ALBEDO = c;
	BACKLIGHT = c * 0.6;
	ROUGHNESS = 0.8;
}
