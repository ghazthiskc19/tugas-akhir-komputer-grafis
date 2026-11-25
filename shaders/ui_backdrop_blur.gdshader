shader_type canvas_item;
render_mode blend_mix;

// Screen-space backdrop blur for full-screen UI dimmers (Compatibility renderer supported: hint_screen_texture).
// Intensity is the node's own alpha (modulate.a), so the existing reveal/dismiss/fade tweens crossfade
// sharp scene -> blurred+tinted scene without any extra per-frame code.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius_px : hint_range(0.0, 32.0) = 7.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.35);

const int TAPS = 24;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius_px;
	// Vogel-disc spiral: even coverage, rotated per pixel to hide banding.
	float rot = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
	vec3 sum = texture(screen_tex, SCREEN_UV).rgb;
	float weight = 1.0;
	for (int i = 0; i < TAPS; i++) {
		float t = (float(i) + 0.5) / float(TAPS);
		float r = sqrt(t);
		float a = float(i) * GOLDEN_ANGLE + rot;
		float w = 1.0 - 0.6 * t;
		sum += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r * px).rgb * w;
		weight += w;
	}
	vec3 blurred = sum / weight;
	COLOR = vec4(mix(blurred, tint.rgb, tint.a), COLOR.a);
}
