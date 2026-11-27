// Faint additive light shaft above a landmark so it reads above the tree line from far away.
// Unshaded, no depth write, fades upward and toward the silhouette edge; pulses slowly.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;

uniform vec4 beam_color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float intensity = 0.34;
uniform float pulse_speed = 0.9;
uniform float phase = 0.0;

void fragment() {
	// CylinderMesh side UV: v = 0 at the top, 1 at the bottom.
	float up = 1.0 - UV.y;
	float vertical = smoothstep(0.0, 0.12, up) * (1.0 - smoothstep(0.35, 1.0, up));
	float edge = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed + phase);
	ALBEDO = beam_color.rgb;
	ALPHA = vertical * edge * intensity * pulse;
}
