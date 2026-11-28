// Low-poly leaf clump for grouped canopies (visual only; added around existing trees by island_atmosphere.gd).
// Per-instance colour comes from the instance colour channel; faceted lighting, light-top gradient, soft wind.
shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_back;

uniform vec3 dark_green : source_color = vec3(0.12, 0.34, 0.12);
uniform vec3 light_green : source_color = vec3(0.45, 0.72, 0.2);
uniform float wind_speed = 1.1;

varying float v_h;
varying float v_y;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_h = fract(sin(dot(origin.xz + origin.y, vec2(12.9898, 78.233))) * 43758.5453);
	v_y = VERTEX.y * 0.5 + 0.5;
	VERTEX.x += sin(TIME * wind_speed + origin.x * 0.31 + origin.z * 0.23) * 0.05 * v_y;
}

void fragment() {
	vec3 tint = mix(vec3(1.1, 1.05, 0.8), vec3(0.85, 1.0, 1.1), v_h);
	vec3 c = mix(dark_green, light_green, smoothstep(0.1, 1.0, v_y)) * tint;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * 0.025 + vec3(0.7, 1.0, 0.4) * c * rim * 0.12;
}
