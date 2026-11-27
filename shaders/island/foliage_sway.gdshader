// KayKit forest tree/bush material (single palette texture) plus a cheap wind sway and a mild olive grade.
// Replaces the imported StandardMaterial3D on tree/bush MultiMeshes only (see island_atmosphere.gd).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float inv_height = 0.2;     // 1 / height at which the sway reaches full amplitude (mesh space)
uniform float amplitude = 0.1;      // metres of lateral sway at full weight
uniform float wind_speed = 1.3;
uniform float saturation = 0.9;
uniform vec3 grade = vec3(1.0, 0.99, 0.93);
uniform float variation = 0.5;     // per-instance hue / brightness spread for green parts
uniform float rim_strength = 0.22;  // soft backlit translucency at grazing angles
uniform vec3 rim_color : source_color = vec3(0.85, 1.0, 0.45);
uniform float base_ao = 0.35;       // darkening at the very bottom of the mesh (contact shadow)

varying float v_hash;
varying float v_up;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_hash = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_up = clamp(VERTEX.y * inv_height, 0.0, 1.0);
	float phase = origin.x * 0.31 + origin.z * 0.23;
	float w = clamp(VERTEX.y * inv_height, 0.0, 1.0);
	w *= w;
	float gust = 0.65 + 0.35 * sin(TIME * 0.37 + origin.x * 0.05);
	VERTEX.x += sin(TIME * wind_speed + phase) * amplitude * w * gust;
	VERTEX.z += sin(TIME * wind_speed * 0.8 + phase * 1.3 + 1.7) * amplitude * 0.6 * w * gust;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * grade;
	// Green parts only (trunks keep their colour): per-instance shift between yellow-green and blue-green.
	float greenness = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	vec3 shifted = c * mix(vec3(1.12, 1.04, 0.78), vec3(0.84, 1.02, 1.12), v_hash);
	shifted *= 0.88 + 0.24 * fract(v_hash * 7.31);
	c = mix(c, shifted, greenness * variation);
	// Contact shadow at the base and slightly brighter crown.
	c *= mix(1.0 - base_ao, 1.0, smoothstep(0.0, 0.3, v_up)) * (0.94 + 0.12 * v_up);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = rim_color * c * rim * rim_strength * greenness;
}
