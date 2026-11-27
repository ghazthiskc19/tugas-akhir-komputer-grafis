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

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
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
	ALBEDO = mix(vec3(l), c, saturation) * grade;
	ROUGHNESS = 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
