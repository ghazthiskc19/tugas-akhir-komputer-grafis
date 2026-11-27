// Compatibility-safe sea surface (no screen/depth texture, no compute). Palette: docs/desain/palettes/04, 06.
// Large subdivided PlaneMesh at sea level. Normals and shore are evaluated per fragment, so the look stays smooth even
// though the plane is coarse far from the island. `shore_tex` (R8, built by island_atmosphere.gd from terrain.height_at)
// stores signed depth to the water line: 0.5 = shoreline, >0.5 land, <0.5 water. Without it the sea is plain deep water.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.376, 0.757, 0.898, 1.0); // #60C1E5
uniform vec4 deep_color : source_color = vec4(0.0, 0.353, 0.612, 1.0);      // #005A9C
uniform vec4 foam_color : source_color = vec4(0.82, 0.95, 0.98, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.72, 0.84, 0.93, 1.0);
uniform float wave_speed = 0.6;
uniform float wave_height = 0.12;
uniform float wave_scale = 0.045;
uniform float opacity : hint_range(0.0, 1.0) = 0.86;
uniform float fresnel_power = 3.0;
uniform sampler2D shore_tex : hint_default_black, filter_linear, repeat_disable;
uniform float shore_half_extent = 125.0;
uniform float shore_range = 6.0;       // metres encoded either side of the shoreline

varying vec3 v_world;

float swell(vec2 p, float t) {
	return sin(p.x * wave_scale * 6.2832 + t) * 0.5
		+ sin((p.y * 0.8 + p.x * 0.3) * wave_scale * 9.0 - t * 1.3) * 0.35
		+ sin((p.x - p.y) * wave_scale * 14.0 + t * 0.7) * 0.15;
}

// Analytic slope of a few cheap ripple layers (per fragment; resolution independent).
vec2 ripple_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	vec2 d1 = vec2(0.8, 0.6);
	vec2 d2 = vec2(-0.5, 0.86);
	vec2 d3 = vec2(0.2, -0.98);
	s += d1 * cos(dot(p, d1) * 0.9 + t * 1.3) * 0.9;
	s += d2 * cos(dot(p, d2) * 1.7 - t * 1.7) * 0.55;
	s += d3 * cos(dot(p, d3) * 3.1 + t * 2.3) * 0.28;
	return s;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(w.xz - INV_VIEW_MATRIX[3].xz);
	float near = 1.0 - smoothstep(40.0, 130.0, dist);
	VERTEX.y += swell(w.xz, TIME * wave_speed) * wave_height * near;
	v_world = w;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME;
	vec2 slope = ripple_slope(p, t) * 0.07;
	float dist = length(p - INV_VIEW_MATRIX[3].xz);
	slope *= 1.0 - smoothstep(25.0, 150.0, dist) * 0.9;
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	// View-space normal for lighting.
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Signed distance to shore in metres (negative = water depth).
	vec2 uv = (p + vec2(shore_half_extent)) / (shore_half_extent * 2.0);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float d = mix(-shore_range, (texture(shore_tex, uv).r - 0.5) * 2.0 * shore_range, inside);
	float depth = clamp(-d, 0.0, shore_range);

	float fres = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float tint = smoothstep(0.0, 3.5, depth);
	vec3 col = mix(shallow_color.rgb * 1.05, deep_color.rgb, tint);
	col = mix(col, horizon_color.rgb, clamp(fres * 0.4, 0.0, 0.45));
	// Broad glints on crests.
	float crest = smoothstep(0.55, 1.0, (slope.x + slope.y) * 6.0 + 0.5);
	col += foam_color.rgb * crest * 0.05;

	// Shore: animated wash line + soft foam band; also thins the water so the sand shows through.
	float wash = 0.22 * sin(t * 0.9 + p.x * 0.35 + p.y * 0.2) + 0.28;
	float band = 1.0 - smoothstep(0.04, 0.3, abs(depth - wash));
	float lace = 0.75 + 0.25 * sin(p.x * 1.9 + t * 0.8) * sin(p.y * 1.6 - t * 0.6);
	float foam = clamp(band * lace, 0.0, 1.0) * inside * step(0.001, texture(shore_tex, uv).r);
	foam *= step(d, 0.15);
	col = mix(col, foam_color.rgb, foam * 0.85);

	ALBEDO = col;
	ROUGHNESS = 0.14;
	SPECULAR = 0.7;
	float shallow_alpha = mix(0.55, opacity, smoothstep(0.0, 1.6, depth));
	ALPHA = clamp(shallow_alpha + fres * 0.12 + foam * 0.3, 0.0, 1.0);
}
