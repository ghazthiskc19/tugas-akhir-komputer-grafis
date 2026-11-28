shader_type spatial;
// Soft toon ramp + faction rim light + death dissolve for skinned characters (Compatibility renderer: only
// vertex/fragment/light, no screen texture, no extra buffers). Pair with character_outline.gdshader via next_pass.
// One material per character instance (parameters such as `dissolve` and `rim_energy` are driven per instance).

uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
// stone_mix = 1: keep only the palette luminance and repaint it with `tone` (ancient guards); 0: keep palette colours.
uniform vec4 tone : source_color = vec4(0.6, 0.57, 0.5, 1.0);
uniform float stone_mix = 0.0;
uniform float albedo_gain : hint_range(0.5, 1.5) = 1.0;

// Cool shade tint on the unlit side, soft stepped half-lambert between shade and light.
uniform vec4 shade_color : source_color = vec4(0.52, 0.58, 0.82, 1.0);
uniform float ramp_center : hint_range(0.2, 0.8) = 0.46;
uniform float ramp_width : hint_range(0.02, 0.5) = 0.2;
uniform float light_gain : hint_range(0.3, 1.5) = 0.82;
uniform float fill_amount : hint_range(0.0, 0.4) = 0.12;

uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.8;
uniform float rim_energy : hint_range(0.0, 4.0) = 0.55;

// Veins: emissive crack lines (boss), 0 = off.
uniform vec4 vein_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float vein_energy = 0.0;
uniform float vein_scale = 0.09;

// Death dissolve: 0 solid .. >1 gone. Ember-coloured burning edge.
uniform float dissolve : hint_range(0.0, 1.3) = 0.0;
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);

// Cape flutter amplitude in metres (0 = rigid). Cheap vertex wobble fading in with distance below the shoulders.
uniform float sway = 0.0;
uniform float sway_top = 1.3;

varying vec3 wpos;
varying vec3 lpos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	if (sway > 0.0) {
		float hang = clamp((sway_top - VERTEX.y) / 0.9, 0.0, 1.0);
		float wave = sin(TIME * 3.1 + VERTEX.y * 6.0 + VERTEX.x * 3.0) + 0.5 * sin(TIME * 5.3 + VERTEX.x * 7.0);
		VERTEX += NORMAL * wave * sway * hang;
	}
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float edge = 0.0;
	if (dissolve > 0.0) {
		float n = vnoise(wpos * 4.5);
		if (n < dissolve) {
			discard;
		}
		edge = 1.0 - smoothstep(dissolve, dissolve + 0.12, n);
	}
	vec3 base = texture(palette, UV).rgb * albedo_color.rgb;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, tone.rgb * (0.66 + 0.8 * luma), stone_mix) * albedo_gain;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;

	vec3 nrm = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(nrm, normalize(VIEW)), 0.0, 1.0), rim_power);
	// Stronger on surfaces facing up/away in view space so the rim hugs the silhouette's top and sides.
	float rim = fres * (0.55 + 0.45 * clamp(nrm.y * 0.5 + 0.5, 0.0, 1.0));
	vec3 glow = rim_color.rgb * rim * rim_energy;
	glow += base * shade_color.rgb * fill_amount;
	if (vein_energy > 0.0) {
		float v = vnoise(lpos * vein_scale * 10.0);
		float line = 1.0 - smoothstep(0.0, 0.05, abs(v - 0.5));
		float v2 = vnoise(lpos * vein_scale * 23.0 + 7.0);
		line = max(line, 0.7 * (1.0 - smoothstep(0.0, 0.04, abs(v2 - 0.5))));
		glow += vein_color.rgb * line * vein_energy;
	}
	glow += ember_color.rgb * edge * 3.5;
	EMISSION = glow;
}

void light() {
	float hl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float ramp = smoothstep(ramp_center - ramp_width, ramp_center + ramp_width, hl);
	vec3 lit = mix(shade_color.rgb * 0.45, vec3(1.0), ramp);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * ATTENUATION * light_gain / PI;
}
