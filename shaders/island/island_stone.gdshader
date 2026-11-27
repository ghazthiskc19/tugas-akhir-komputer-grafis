// Rocks and ruin pieces (KayKit palette texture): moss on upward faces, dirt at the base, faint cool rim.
// Applied as material_override by island_atmosphere.gd; Compatibility-safe.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 moss_color : source_color = vec3(0.3, 0.46, 0.2);
uniform float moss_amount = 0.7;
uniform float base_height = 1.2;   // metres above the mesh origin over which base dirt fades out

varying vec3 v_world;
varying vec3 v_normal;
varying float v_local_y;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_local_y = v_world.y - origin.y;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 wn = normalize(v_normal);
	float noise = texture(noise_tex, v_world.xz * 0.35 + v_world.y * 0.11).r;
	float noise2 = texture(noise_tex, v_world.xz * 1.3 + v_world.y * 0.4).r;

	// Per-piece brightness variation from its world position.
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	c *= 0.9 + 0.2 * h;

	// Moss: upward faces, broken up by noise, thicker low on the piece.
	float topness = smoothstep(0.55, 0.95, wn.y);
	float low = 1.0 - smoothstep(0.5, 3.0, v_local_y);
	float m = topness * smoothstep(0.35, 0.6, noise * 0.7 + noise2 * 0.3 + low * 0.25) * moss_amount;
	c = mix(c, moss_color * (0.8 + 0.4 * noise2), clamp(m, 0.0, 1.0));

	// Dirt/grime at the base.
	float dirt = 1.0 - smoothstep(0.0, base_height, v_local_y);
	c = mix(c, c * vec3(0.55, 0.48, 0.4), dirt * 0.6);

	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.95, m);
	SPECULAR = 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rim * 0.12;
}
