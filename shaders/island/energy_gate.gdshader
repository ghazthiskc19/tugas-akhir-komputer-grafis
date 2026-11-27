// Translucent rune-barrier used for the boss gate seal and the arena entrance barrier.
// Dark base + thin emissive rune lines (frame, ring, spokes, flowing columns); unshaded, no depth write, Compatibility-safe.
// progress: 1 = fully sealed, 0 = gone (dissolves bottom-up with a bright edge). open_mix shifts the line colour to open_color.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 line_color : source_color = vec4(0.95, 0.5, 0.28, 1.0);
uniform vec4 open_color : source_color = vec4(0.4, 1.0, 0.6, 1.0);
uniform vec4 base_color : source_color = vec4(0.035, 0.025, 0.05, 1.0);
uniform vec2 gate_size = vec2(9.0, 5.8);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float open_mix : hint_range(0.0, 1.0) = 0.0;
uniform float base_alpha = 0.34;
uniform float line_alpha = 0.78;
uniform float pulse_speed = 1.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.035, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * gate_size;
	float t = TIME;

	// Frame: two nested borders, the inner one with corner gaps.
	float edge = min(gate_size.x * 0.5 - abs(p.x), gate_size.y * 0.5 - abs(p.y));
	float frame = line(edge - 0.14, 0.07) + 0.6 * line(edge - 0.38, 0.04);

	// Central ring, dashed inner ring and slowly turning spokes.
	vec2 c = p - vec2(0.0, 0.2);
	float r = length(c);
	float ang = atan(c.y, c.x);
	float ring = line(r - 1.9, 0.07);
	float dashes = step(0.45, fract((ang + t * 0.25) * 8.0 / 6.28318)) * line(r - 1.5, 0.05);
	float spokes = step(0.82, fract((ang - t * 0.12) * 12.0 / 6.28318)) * step(2.15, r) * step(r, 2.55) * 0.9;
	float core = (1.0 - smoothstep(0.0, 0.9, r)) * 0.35;

	// Vertical flow lines with energy pulses rising along them.
	float col_id = floor(p.x / 0.75 + 0.5);
	float col_line = line(fract(p.x / 0.75 + 0.5) - 0.5, 0.05) * 0.35 * step(abs(p.x), gate_size.x * 0.5 - 0.5);
	float flow = pow(0.5 + 0.5 * sin(p.y * 1.4 - t * 1.3 + hash(vec2(col_id, 1.0)) * 6.28), 6.0);
	float columns = col_line * (0.35 + 1.1 * flow);

	// Horizontal scan band.
	float scan = line(fract(t * 0.12 + 0.0) * gate_size.y - (p.y + gate_size.y * 0.5), 0.28) * 0.18;

	float lines = clamp(frame + ring + dashes + spokes + columns + core * 0.4, 0.0, 1.0);
	float pulse = 0.85 + 0.15 * sin(t * pulse_speed * 2.0 + p.y * 0.5);

	// Bottom-up dissolve; wobble is blocky noise so the front is ragged rather than a clean wipe.
	float height = 1.0 - UV.y;
	float wobble = hash(floor(p * 5.0)) * 0.18;
	float cut = (1.0 - progress) * 1.25;
	float alive = smoothstep(cut - 0.02, cut + 0.02, height + wobble);
	float front = (1.0 - smoothstep(0.0, 0.1, abs(height + wobble - cut))) * step(0.001, 1.0 - progress) * step(0.001, progress);

	vec3 lc = mix(line_color.rgb, open_color.rgb, open_mix);
	vec3 col = mix(base_color.rgb, lc, clamp(lines * pulse, 0.0, 1.0));
	col += lc * (scan + front * 0.8);
	float a = (base_alpha + lines * line_alpha * pulse + scan + front * 0.5) * alive;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * smoothstep(0.0, 0.08, progress);
}
