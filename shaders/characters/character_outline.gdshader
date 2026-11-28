shader_type spatial;
// Inverted-hull outline: back faces pushed along the normal, flat dark colour. Used as next_pass of toon_character
// (one extra draw per surface). Width grows slightly with distance so the line stays about one pixel at gameplay range.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float width = 0.012;
uniform float dissolve : hint_range(0.0, 1.3) = 0.0;
uniform float sway = 0.0;
uniform float sway_top = 1.3;

varying vec3 wpos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	if (sway > 0.0) {
		float hang = clamp((sway_top - VERTEX.y) / 0.9, 0.0, 1.0);
		float wave = sin(TIME * 3.1 + VERTEX.y * 6.0 + VERTEX.x * 3.0) + 0.5 * sin(TIME * 5.3 + VERTEX.x * 7.0);
		VERTEX += NORMAL * wave * sway * hang;
	}
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * width * clamp(dist / 7.0, 0.8, 3.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (dissolve > 0.0 && vnoise(wpos * 4.5) < dissolve) {
		discard;
	}
	ALBEDO = color.rgb;
}
