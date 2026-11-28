// Island sky for the Compatibility renderer: vertical gradient that meets the depth-fog colour at the horizon,
// a soft sun glow and two layers of slowly drifting procedural clouds. No textures; clouds skip the radiance pass.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.2, 0.43, 0.8);
uniform vec3 mid_color : source_color = vec3(0.42, 0.65, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.81, 0.86); // MUST match the environment fog colour
uniform vec3 ground_color : source_color = vec3(0.72, 0.81, 0.86);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 cloud_shade : source_color = vec3(0.64, 0.72, 0.84);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float cloud_cover = 0.5;    // 0 clear, 1 overcast
uniform float cloud_speed = 0.006;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	float up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, up));
	col = mix(col, zenith_color, smoothstep(0.12, 0.85, up));
	// Below the horizon the sky settles into the fog colour so the sea edge and sky share one seam.
	col = mix(col, ground_color, 1.0 - smoothstep(-0.06, 0.0, h));

	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	float sd = max(dot(dir, sun_dir), 0.0);
	col += sun_color * (pow(sd, 6.0) * 0.18 + pow(sd, 400.0) * 1.2) * step(0.0, LIGHT0_ENERGY);

	if (!AT_CUBEMAP_PASS && h > 0.0) {
		// Project onto a flat cloud deck; fade into the horizon haze so the deck never shows a hard edge.
		vec2 uv = dir.xz / (h + 0.12);
		float t = TIME * cloud_speed;
		float base = fbm(uv * 0.55 + vec2(t * 6.0, t * 2.0));
		float detail = fbm(uv * 1.6 - vec2(t * 10.0, 0.0));
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, base * 0.8 + detail * 0.3);
		// Cheap lighting: sample toward the sun for self-shadowing, silver lining on thin edges.
		float toward = fbm(uv * 0.55 + vec2(t * 6.0, t * 2.0) + sun_dir.xz * 0.35);
		float lit = clamp(0.55 + (base - toward) * 2.4, 0.0, 1.0);
		vec3 ccol = mix(cloud_shade, cloud_light, lit);
		ccol += sun_color * pow(sd, 8.0) * 0.25 * (1.0 - dens);
		float fade = smoothstep(0.0, 0.2, h);
		col = mix(col, ccol, dens * fade * 0.92);
	}
	COLOR = col;
}
