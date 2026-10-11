shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Defensive barrier: a translucent dome (mesh centred on its own origin, facing
// +Z) tiled with glowing hexagonal cells. Idle it is almost transparent: a faint
// outline and a rim. Hits light the cells around the impact, send an outward
// ripple along the hexagon outlines, and persistent contacts (a beam pressing
// on the shield) keep their cells lit. Under stress the cells brighten and
// flicker; failed regions open as ragged holes (the physics side uses the same
// hole list, so what you see is what stops attacks).
//
// imp_dir[i]  xyz = unit direction from the dome centre in dome-local space,
//             w   = age in seconds (< 0 = unused slot)
// imp_data[i] x = strength 0..2, y = 1 for a persistent contact,
//             z = hole radius in metres along the surface (0 = intact)

uniform vec3 tint : source_color = vec3(0.12, 0.6, 1.0);
uniform vec3 stress_tint : source_color = vec3(1.0, 0.72, 0.4);
uniform float radius = 1.7;
uniform float cell = 0.26;
uniform float appear = 1.0;
uniform float stress = 0.0;
uniform float idle_alpha = 0.62;
uniform float ripple_speed = 3.0;
uniform vec4 imp_dir[8];
uniform vec4 imp_data[8];

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

// Hex grid: returns (edge distance 0..0.5 normalised, cell centre xy).
vec4 hexcell(vec2 q) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(q, s) - s * 0.5;
	vec2 b = mod(q - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	float e = max(dot(abs(g), vec2(0.5, 0.8660254)), abs(g.x));
	return vec4(e, q - g, 0.0);
}

vec2 plane(vec3 d) {
	float el = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, max(d.z, 0.0001));
	return vec2(az * cos(el), el) * (radius / cell);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 d = normalize(lpos);
	if (d.z < 0.02) {
		discard;
	}
	vec2 q = plane(d);
	vec4 hx = hexcell(q);
	float e = hx.x;
	vec2 cid = hx.yz;
	float outline = smoothstep(0.33, 0.46, e);

	// Distance (in cells) from the dome's centre line: the formation assembles
	// outward from the middle when it appears.
	float cdist = length(plane(d));
	float reveal = smoothstep(0.0, 1.0, appear * 1.35 - cdist * 0.05);

	float glow_fill = 0.0;
	float glow_edge = 0.0;
	float holes = 1.0;
	float hole_edge = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 dir = imp_dir[i];
		vec4 dat = imp_data[i];
		if (dir.w < 0.0) {
			continue;
		}
		vec2 ip = plane(normalize(dir.xyz));
		float dp = length(cid - ip);                        // in cells
		float dpx = length(q - ip);
		float age = dir.w;
		float st = dat.x;
		float life = dat.y > 0.5 ? 1.0 : exp(-age * 1.6);
		// Lit cells around the impact.
		float spread = 1.2 + 1.6 * st;
		glow_fill += exp(-dp * dp / (spread * spread)) * life * st;
		// Outward ripple along the outlines.
		float rr = age * ripple_speed / cell;
		float rg = exp(-pow((dpx - rr) / 0.9, 2.0)) * exp(-age * 1.2) * st;
		if (dat.y > 0.5) {
			// A pressed contact pulses outward continuously.
			float ph = mod(age * 1.4, 1.0);
			rg = exp(-pow((dpx - ph * 5.0) / 0.8, 2.0)) * (1.0 - ph) * st * 0.9;
		}
		glow_edge += rg;
		// Failure holes.
		if (dat.z > 0.001) {
			float hr = dat.z / cell;
			float ragged = (hash2(cid) - 0.5) * 0.9;
			float inside = 1.0 - smoothstep(hr - 0.5, hr + 0.5, dp + ragged);
			holes = min(holes, 1.0 - inside);
			hole_edge += exp(-pow((dp + ragged - hr) / 0.55, 2.0));
		}
	}
	glow_fill = min(glow_fill, 2.0);
	glow_edge = min(glow_edge, 2.0);

	// Rim: brighter toward the dome's silhouette.
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0 + hash2(cid) * 6.28) * step(0.4, stress);

	vec3 base = mix(tint, stress_tint, smoothstep(0.55, 1.0, stress));
	float lit = clamp(glow_fill + glow_edge, 0.0, 1.0);
	float line = outline * (idle_alpha + glow_edge * 0.8 + glow_fill * 0.5 + stress * 0.3) * flicker;
	float fill = (1.0 - outline) * (0.10 + glow_fill * 0.30 + stress * 0.08 * hash2(cid)) * flicker;
	float edge = rim * (0.22 + 0.15 * stress);
	float a = clamp(line + fill + edge, 0.0, 1.0) * holes * reveal * appear;
	// Torn rims of holes burn white-hot.
	a = clamp(a + hole_edge * 0.8 * appear * reveal, 0.0, 1.0);
	vec3 col = mix(base, vec3(0.85, 0.97, 1.0), lit * 0.75);
	ALBEDO = col * (1.0 + 1.4 * lit + hole_edge * 0.8);
	ALPHA = a;
}
