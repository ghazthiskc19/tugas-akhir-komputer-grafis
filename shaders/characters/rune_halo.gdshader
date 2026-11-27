shader_type spatial;
// Soft additive halo behind a rune: camera-facing quad, brightness follows the same `energy` as rune_glow.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.15, 0.95, 0.85, 1.0);
uniform float energy = 0.6;
uniform float phase = 0.0;
uniform float dissolve : hint_range(0.0, 1.3) = 0.0;

void vertex() {
	// Billboard: keep the node's position and scale, face the camera.
	mat4 m = INV_VIEW_MATRIX;
	m[3] = MODEL_MATRIX[3];
	float s = length(MODEL_MATRIX[0].xyz);
	m[0] *= s;
	m[1] *= s;
	m[2] *= s;
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float falloff = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float pulse = 0.9 + 0.1 * sin(TIME * 2.4 + phase);
	float a = falloff * clamp(energy * pulse * 0.28, 0.0, 0.9) * (1.0 - smoothstep(0.7, 1.0, dissolve));
	ALBEDO = color.rgb;
	ALPHA = a;
}
