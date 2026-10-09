shader_type sky;
// Painterly golden-hour sky: saturated blue zenith, warm luminous horizon,
// a bright sun halo and big soft cumulus with lit tops and shaded bellies.

uniform vec3 zenith : source_color = vec3(0.16, 0.42, 0.86);
uniform vec3 mid_sky : source_color = vec3(0.42, 0.66, 0.93);
uniform vec3 horizon : source_color = vec3(0.86, 0.9, 0.92);
uniform vec3 warm_horizon : source_color = vec3(1.0, 0.86, 0.62);
uniform vec3 ground : source_color = vec3(0.5, 0.58, 0.46);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 cloud_sunlit : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.68, 0.82);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover = 0.5;

float fbm(vec2 uv) {
	return texture(cloud_noise, uv).r * 0.55 + texture(cloud_noise, uv * 2.3 + 0.17).r * 0.3 + texture(cloud_noise, uv * 5.1 + 0.6).r * 0.15;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.4, 0.3));
	float sd = max(dot(d, sun_dir), 0.0);
	float hh = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon, mid_sky, smoothstep(0.0, 0.25, hh));
	col = mix(col, zenith, smoothstep(0.2, 0.9, hh));
	col = mix(col, warm_horizon, pow(sd, 4.0) * (1.0 - smoothstep(0.0, 0.5, hh)) * 0.9);
	col = mix(col, ground, smoothstep(0.0, -0.1, h));
	col += vec3(1.0, 0.88, 0.62) * pow(sd, 10.0) * 0.35;
	if (!AT_CUBEMAP_PASS) {
		col += vec3(1.0, 0.94, 0.8) * (pow(sd, 1200.0) * 10.0 + pow(sd, 90.0) * 0.6);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.07 + vec2(TIME * 0.0012, TIME * 0.0005);
		float n = fbm(uv);
		// Clouds bunch toward the horizon like towering cumulus.
		float cover = cloud_cover - (1.0 - smoothstep(0.05, 0.45, h)) * 0.08;
		float c = smoothstep(cover, cover + 0.09, n) * smoothstep(0.0, 0.1, h);
		// Fake volume: sample toward the sun; denser there means shadowed belly.
		float toward = fbm(uv + sun_dir.xz * 0.025);
		float lit = clamp((n - toward) * 6.0 + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_light, lit);
		cc = mix(cc, cloud_sunlit, pow(sd, 3.0) * 0.7);
		// Bright silver lining near the sun.
		cc += vec3(1.0, 0.9, 0.7) * pow(sd, 18.0) * (1.0 - c) * 2.0 * step(0.01, c);
		cc = mix(cc, horizon, (1.0 - smoothstep(0.0, 0.18, h)) * 0.35);
		col = mix(col, cc, c);
	}
	COLOR = col;
}
