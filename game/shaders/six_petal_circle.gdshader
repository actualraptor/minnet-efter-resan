shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Zoltraak's six-petalled magic circle (after the concept sheet), drawn on a quad
// facing +Z. `charge` (0..1) builds it up: stage 1 a basic petal ring, stage 2
// more runes and gathering lines, full charge a dense radiant sigil.

uniform vec3 tint : source_color = vec3(0.55, 0.78, 1.0);
uniform float charge = 0.0;
uniform float alpha = 1.0;
uniform float spin_speed = 0.22;

varying vec2 p;

void vertex() {
	p = UV * 2.0 - 1.0;
}

float ln(float d, float w) {
	return smoothstep(w, 0.0, abs(d));
}

void fragment() {
	float r = length(p);
	if (r > 1.04) {
		discard;
	}
	float th = atan(p.y, p.x) + TIME * spin_speed;
	float s2 = smoothstep(0.25, 0.55, charge);
	float s3 = smoothstep(0.78, 1.0, charge);
	float w = 0.011 + 0.005 * charge;

	// Outer rings.
	float v = ln(r - 0.97, w * 1.5);
	v += ln(r - 0.9, w * 0.8) * (0.45 + 0.55 * s2);

	// The six petals: a rose curve with six lobes, outlined twice.
	float lobe = pow(abs(cos(3.0 * th)), 0.7);
	float petal_r = 0.14 + 0.72 * lobe;
	v += ln((r - petal_r) * 0.85, w * 1.3);
	float lobe2 = pow(abs(cos(3.0 * (th + 0.5236))), 0.7);
	v += ln((r - (0.1 + 0.46 * lobe2)) * 0.85, w) * s2;
	v += ln((r - (0.08 + 0.3 * lobe)) * 0.85, w * 0.9) * s3;

	// Inner ring and a hexagram that only appears at full charge.
	v += ln(r - 0.2, w);
	float a3 = mod(th, 2.0944) - 1.0472;
	float a3b = mod(th + 1.0472, 2.0944) - 1.0472;
	float star = ln(r * cos(a3) - 0.5, w) + ln(r * cos(a3b) - 0.5, w);
	v += star * s3 * step(r, 0.62) * 0.9;

	// Rune ring: dashed glyph-like cells around the edge.
	float cells = (th + 3.14159) / 6.28318 * 48.0;
	float h = fract(sin(floor(cells) * 12.9898) * 43758.5453);
	float rune = step(0.3, h) * step(abs(r - 0.935), 0.03) * step(fract(cells), 0.7);
	v += rune * s2 * 0.8;

	// Gathering lines drawing inward while it charges.
	float spokes = pow(abs(cos(th * 9.0)), 60.0) * smoothstep(1.0, 0.45, r) * (0.55 + 0.45 * sin(r * 26.0 + TIME * 7.0));
	v += spokes * s2 * 0.45 * (1.0 - s3 * 0.5);

	float glow = exp(-r * r * 5.5) * (0.12 + 0.55 * charge);
	float edge = smoothstep(1.03, 0.94, r);
	float inten = (v * (0.75 + 0.9 * charge) + glow) * edge * alpha;
	ALBEDO = tint * inten * (1.0 + charge * 0.7) + vec3(0.9, 0.95, 1.0) * glow * charge * alpha;
	ALPHA = clamp(inten, 0.0, 1.0);
}
