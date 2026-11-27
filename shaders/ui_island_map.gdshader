// Island map terrain. The bound texture is the island height field (single channel, metres); colour, hillshade, the
// coastline ink line and the foam band are all computed per screen pixel so the coast stays crisp at any map size.
shader_type canvas_item;

uniform sampler2D heights : filter_linear, repeat_disable;
uniform float water = -0.9;
uniform float top = 16.0;
uniform vec4 sea_deep : source_color = vec4(0.035, 0.1, 0.17, 1.0);
uniform vec4 sea_shallow : source_color = vec4(0.1, 0.3, 0.4, 1.0);
uniform vec4 foam : source_color = vec4(0.56, 0.72, 0.76, 1.0);
uniform vec4 ink : source_color = vec4(0.1, 0.075, 0.05, 1.0);
uniform vec4 parchment : source_color = vec4(0.93, 0.82, 0.58, 1.0);

float height_at(vec2 uv) {
	return texture(heights, uv).r;
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(heights, 0));
	float h = height_at(UV);
	float fw = max(fwidth(h), 0.003);
	float d = (h - water) / fw; // signed distance to the shoreline in screen pixels (+ land)

	vec3 col;
	if (h < water) {
		float depth = clamp((h + 6.0) / (6.0 + water), 0.0, 1.0);
		col = mix(sea_deep.rgb, sea_shallow.rgb, depth);
		col += 0.018 * sin((UV.x + UV.y) * 260.0) * smoothstep(8.0, 40.0, -d);
		col = mix(col, foam.rgb, 0.4 * (1.0 - smoothstep(0.0, 16.0, -d)));
		col = mix(col, vec3(0.1, 0.25, 0.3), 0.08);
	} else {
		float t = clamp((h - water) / (top - water), 0.0, 1.0);
		vec3 green = mix(vec3(0.298, 0.478, 0.278), vec3(0.478, 0.541, 0.306), clamp(t / 0.45, 0.0, 1.0));
		vec3 rock = mix(vec3(0.478, 0.541, 0.306), vec3(0.725, 0.690, 0.627), clamp((t - 0.45) / 0.55, 0.0, 1.0));
		col = t < 0.45 ? green : rock;
		vec3 sand = vec3(0.788, 0.71, 0.514);
		col = mix(sand, col, smoothstep(0.15, 0.45, h));
		float gx = height_at(UV + vec2(px.x, 0.0)) - height_at(UV - vec2(px.x, 0.0));
		float gy = height_at(UV + vec2(0.0, px.y)) - height_at(UV - vec2(0.0, px.y));
		float shade = clamp((gx + gy) * 0.1, -0.35, 0.35);
		col = shade > 0.0 ? mix(col, vec3(1.0), shade) : mix(col, vec3(0.0), -shade);
		col = mix(col, parchment.rgb, 0.1);
		col = mix(col, foam.rgb, 0.3 * (1.0 - smoothstep(1.5, 9.0, d)));
	}
	// Coastline ink line, about two pixels wide.
	float line = 1.0 - smoothstep(0.7, 1.7, abs(d));
	col = mix(col, ink.rgb, line * 0.85);
	COLOR = vec4(col, 1.0);
}
