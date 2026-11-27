// Stylised ground for the island (Compatibility-safe: no screen/depth reads). Vertex colour (painted in
// island_terrain.gd from biome, shore, slope, route and pad data) is the base; this shader adds
//   - large-scale warm/cool colour drift and mid-scale patches (world space, so no tiling seams),
//   - triplanar grain, so steep faces do not stretch,
//   - stratified rock on steep faces (horizontal bands by world height) with a grass lip on ledges,
//   - sand ripples on pale flat ground, wet darkening around the waterline.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float water_y = 0.0;
uniform vec3 rock_dark : source_color = vec3(0.4, 0.37, 0.35);
uniform vec3 rock_light : source_color = vec3(0.6, 0.54, 0.47);

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float n(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec3 wp = v_world;
	vec3 wn = normalize(v_normal);
	float up = clamp(wn.y, 0.0, 1.0);
	vec3 base = COLOR.rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));

	// Colour drift: broad warm/cool shift plus smaller patches.
	float macro = n(wp.xz * 0.009);
	float patch = n(wp.xz * 0.045 + vec2(0.31, 0.77));
	base *= mix(vec3(0.9, 0.95, 0.92), vec3(1.1, 1.06, 0.92), smoothstep(0.3, 0.7, macro));
	base *= 0.88 + 0.26 * patch;

	// Triplanar grain.
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	float g = n(wp.zy * 0.33) * bw.x + n(wp.xz * 0.33) * bw.y + n(wp.xy * 0.33) * bw.z;
	float g2 = n(wp.xz * 1.7) * bw.y + n(wp.zy * 1.7) * bw.x + n(wp.xy * 1.7) * bw.z;
	base *= 0.9 + 0.16 * g + 0.08 * (g2 - 0.5);

	// Cliffs: stratified rock keyed to world height so bands stay level whatever the facing.
	float cliff = smoothstep(0.16, 0.42, 1.0 - up);
	float strata = n(vec2(wp.x + wp.z, wp.y * 2.3) * 0.11);
	float band = 0.5 + 0.5 * sin(wp.y * 2.6 + strata * 5.0);
	vec3 rock = mix(rock_dark, rock_light, clamp(strata * 0.7 + band * 0.4, 0.0, 1.0));
	rock *= 0.85 + 0.3 * g;
	// Grass lip: the flatter fringe of a cliff keeps the ground colour.
	float lip = smoothstep(0.42, 0.16, 1.0 - up) * smoothstep(0.1, 0.2, 1.0 - up);
	base = mix(base, rock, cliff * 0.85);
	base = mix(base, base * vec3(0.95, 1.08, 0.9), lip * 0.4);

	// Pale flat ground (sand) gets faint wind ripples.
	float sandy = smoothstep(0.62, 0.78, lum) * step(base.b, base.r * 0.85) * up;
	float ripple = sin((wp.x * 0.6 + wp.z * 0.35 + n(wp.xz * 0.05) * 6.0) * 2.4);
	base *= 1.0 + sandy * ripple * 0.035;

	// Wet sand near the waterline.
	float wet = 1.0 - smoothstep(0.0, 0.8, wp.y - water_y);
	base *= mix(1.0, 0.72, wet);

	ALBEDO = base;
	ROUGHNESS = mix(0.95, 0.8, wet);
	SPECULAR = 0.15 + 0.25 * wet;
}
