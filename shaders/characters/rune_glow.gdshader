shader_type spatial;
// Unshaded rune glow. `energy` is driven by the guard's state (idle dim, windup rising, strike flash); the slow
// breathing pulse is done here from TIME so idle needs no per-frame script. Bright values wash toward white
// because the Compatibility renderer clamps colour (no HDR glow).
render_mode unshaded, shadows_disabled;

uniform vec4 color : source_color = vec4(0.15, 0.95, 0.85, 1.0);
uniform float energy = 0.6;
uniform float phase = 0.0;
uniform float dissolve : hint_range(0.0, 1.3) = 0.0;

void fragment() {
	float pulse = 0.88 + 0.12 * sin(TIME * 2.4 + phase);
	float e = energy * pulse;
	vec3 c = color.rgb * clamp(e, 0.0, 1.0);
	c = mix(c, vec3(1.0), clamp((e - 1.0) / 3.0, 0.0, 1.0) * 0.85);
	ALBEDO = c;
	ALPHA = 1.0 - smoothstep(1.0, 1.15, dissolve);
}
