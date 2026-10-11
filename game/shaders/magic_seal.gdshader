shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Zoltraak's geometric seal, drawn on a quad facing +Z (UV 0..1 across it).
//   * two outer rings framing a band of pseudo-runic glyph cells
//   * a rose curve with `petals` lobes, double-outlined (six for Zoltraak)
//   * `petals` satellite circles, each with a core dot, on a middle ring
//   * an inner ring and a star of crossing chords
//   * a central aperture (`hole`): transparent in the middle, ringed in light,
//     so the beam visibly passes through the formation.
// `charge` (0..1) builds the detail: first the petal ring, then runes, rings and
// satellites, finally the inner star and a denser band. `energy` is HDR.

uniform vec3 tint : source_color = vec3(0.78, 0.9, 1.0);
uniform float energy = 2.4;
uniform float charge = 1.0;
uniform float alpha = 1.0;
uniform float spin_speed = 0.18;
uniform float hole = 0.0;
uniform int petals = 6;
uniform float haze = 0.05;

varying vec2 p;

void vertex() {
	p = UV * 2.0 - 1.0;
}

float ln(float d, float w) {
	return smoothstep(w, 0.0, abs(d));
}

float hash(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	float r = length(p);
	if (r > 1.03) {
		discard;
	}
	float n = float(petals);
	float th = atan(p.y, p.x);
	float spin = TIME * spin_speed;
	float counter = -TIME * spin_speed * 0.6;
	float s1 = smoothstep(0.0, 0.3, charge);
	float s2 = smoothstep(0.25, 0.65, charge);
	float s3 = smoothstep(0.7, 1.0, charge);
	float w = 0.0085 + 0.004 * charge;
	float v = 0.0;

	// Outer rings.
	v += ln(r - 0.985, w * 1.6);
	v += ln(r - 0.925, w);
	v += ln(r - 0.78, w) * s1;

	// Rune band between 0.78 and 0.925: glyph cells of one arc-width each.
	float cells = 56.0;
	float ang = (th + counter + 3.14159265) / 6.2831853 * cells;
	float id = floor(ang);
	vec2 cuv = vec2(fract(ang), (r - 0.78) / (0.925 - 0.78));
	float inband = step(0.0, cuv.y) * step(cuv.y, 1.0);
	float h = hash(id);
	float glyph = 0.0;
	float cw = 0.07;
	if (h < 0.22) {
		glyph = ln(cuv.x - 0.5, cw) * step(0.12, cuv.y) * step(cuv.y, 0.88);
	} else if (h < 0.44) {
		glyph = ln(length(cuv - 0.5) - 0.22, cw);
	} else if (h < 0.62) {
		glyph = ln((cuv.x - 0.5) - (cuv.y - 0.5) * 0.7, cw) * step(0.1, cuv.y) * step(cuv.y, 0.9);
		glyph += ln(cuv.y - 0.25, cw) * step(0.2, cuv.x) * step(cuv.x, 0.8);
	} else if (h < 0.78) {
		glyph = ln(cuv.y - 0.5, cw) * step(0.15, cuv.x) * step(cuv.x, 0.85);
		glyph += ln(cuv.x - 0.5, cw) * step(0.5, cuv.y) * step(cuv.y, 0.85);
	}
	v += glyph * inband * mix(s1, 1.0, s2) * 0.9;

	// Rose curve: n lobes, outlined twice, turning slowly.
	float lobe = pow(abs(cos(0.5 * n * (th + spin))), 0.72);
	float petal_r = 0.12 + 0.62 * lobe;
	v += ln((r - petal_r) * 0.9, w * 1.4);
	float lobe2 = pow(abs(cos(0.5 * n * (th + spin) + 1.5708)), 0.72);
	v += ln((r - (0.1 + 0.4 * lobe2)) * 0.9, w) * s2;
	v += ln((r - (0.08 + 0.26 * lobe)) * 0.9, w * 0.9) * s3;

	// Satellite circles with a core dot, on a ring at r = 0.60.
	v += ln(r - 0.60, w * 0.8) * s2;
	float sec = 6.2831853 / n;
	float sa = mod(th + counter * 0.5 + sec * 0.5, sec) - sec * 0.5;
	vec2 sp = vec2(r * cos(sa) - 0.60, r * sin(sa));
	float sd = length(sp);
	v += (ln(sd - 0.115, w) + ln(sd - 0.065, w * 0.8) * s3 + smoothstep(0.02, 0.0, sd) * 0.9) * s2;

	// Inner ring and the star of crossing chords.
	v += ln(r - 0.30, w) * s1;
	float chord_a = mod(th + spin * 1.4, 6.2831853 / n) - 3.14159265 / n;
	v += ln(r * cos(chord_a) - 0.18, w * 0.9) * s3 * step(r, 0.34);
	float chord_b = mod(th - spin * 1.4 + 3.14159265 / n, 6.2831853 / n) - 3.14159265 / n;
	v += ln(r * cos(chord_b) - 0.18, w * 0.9) * s3 * step(r, 0.34);

	// Aperture: clear in the middle, a bright ring on its edge.
	float aperture = 1.0;
	if (hole > 0.001) {
		aperture = smoothstep(hole * 0.92, hole, r);
		v += ln(r - hole, w * 1.8) * 1.3;
		v *= 1.0;
	}

	float glow = exp(-pow(max(r - 0.45, 0.0), 2.0) * 7.0) * (0.04 + 0.1 * charge) * aperture * haze * 20.0;
	float edge = smoothstep(1.03, 0.97, r);
	float inten = (v * aperture + glow) * edge * alpha;
	ALBEDO = tint * inten * energy;
	ALPHA = clamp(inten * 1.4, 0.0, 1.0);
}
