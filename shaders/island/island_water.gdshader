// Compatibility-safe sea surface (no screen/depth texture, no compute). Palette: docs/desain/palettes/04, 06.
// Intended for a large subdivided PlaneMesh at sea level. Not visually reviewed by a human.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.376, 0.757, 0.898, 1.0); // #60C1E5
uniform vec4 deep_color : source_color = vec4(0.0, 0.353, 0.612, 1.0);      // #005A9C
uniform vec4 foam_color : source_color = vec4(0.627, 0.878, 0.937, 1.0);    // #A0E0EF
uniform float wave_speed = 0.6;
uniform float wave_height = 0.18;
uniform float wave_scale = 0.045;
uniform float foam_width = 0.06;
uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float fresnel_power = 3.0;

varying float v_height;
varying vec3 v_world;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale * 6.2832 + t) * 0.5
		+ sin((p.y * 0.8 + p.x * 0.3) * wave_scale * 9.0 - t * 1.3) * 0.35
		+ sin((p.x - p.y) * wave_scale * 14.0 + t * 0.7) * 0.15;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave(w.xz, t);
	VERTEX.y += h * wave_height;
	v_height = h;
	v_world = w;
	float e = 0.5;
	float hx = wave(w.xz + vec2(e, 0.0), t);
	float hz = wave(w.xz + vec2(0.0, e), t);
	NORMAL = normalize(vec3(-(hx - h) * wave_height / e * 6.0, 1.0, -(hz - h) * wave_height / e * 6.0));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(v_height * 0.5 + 0.55 + fres * 0.4, 0.0, 1.0));
	float crest = smoothstep(1.0 - foam_width * 6.0, 1.0, v_height * 0.5 + 0.5);
	col = mix(col, foam_color.rgb, crest * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	ALPHA = clamp(opacity + fres * 0.15, 0.0, 1.0);
}
