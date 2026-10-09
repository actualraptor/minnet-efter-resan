shader_type sky;
// Warm painterly afternoon sky: soft blue zenith, creamy horizon, gentle sun
// glow and slow drifting cumulus made from a seamless noise texture.

uniform vec3 zenith : source_color = vec3(0.24, 0.5, 0.88);
uniform vec3 horizon : source_color = vec3(0.86, 0.9, 0.9);
uniform vec3 warm_horizon : source_color = vec3(0.99, 0.88, 0.72);
uniform vec3 ground : source_color = vec3(0.55, 0.62, 0.52);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.76, 0.86);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover = 0.47;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.5, 0.3));
	float sd = max(dot(d, sun_dir), 0.0);
	vec3 hor = mix(horizon, warm_horizon, pow(sd, 3.0) * 0.8);
	vec3 col = mix(hor, zenith, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, ground, smoothstep(0.0, -0.12, h));
	if (AT_CUBEMAP_PASS == false) {
		col += vec3(1.0, 0.92, 0.75) * (pow(sd, 900.0) * 6.0 + pow(sd, 60.0) * 0.35 + pow(sd, 6.0) * 0.12);
	} else {
		col += vec3(1.0, 0.92, 0.75) * pow(sd, 6.0) * 0.12;
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * 0.09 + vec2(TIME * 0.0016, TIME * 0.0006);
		float n = texture(cloud_noise, uv).r * 0.7 + texture(cloud_noise, uv * 2.7 + 0.3).r * 0.3;
		float c = smoothstep(cloud_cover, cloud_cover + 0.12, n) * smoothstep(0.0, 0.18, h);
		float lit = smoothstep(0.4, 0.95, texture(cloud_noise, uv + sun_dir.xz * 0.02).r);
		vec3 cc = mix(cloud_light, cloud_shade, lit * 0.6);
		cc = mix(cc, warm_horizon, (1.0 - smoothstep(0.0, 0.3, h)) * 0.35);
		col = mix(col, cc, c * 0.9);
	}
	COLOR = col;
}
