shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 f = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float broad = noise(p * 0.07);
	float grain = noise(p * 2.8) * 0.6 + noise(p * 13.0) * 0.4;
	float strata = sin(p.x * 0.4 + p.y * 0.18 + noise(p * 0.18) * 5.0) * 0.5 + 0.5;
	vec3 basalt = vec3(0.09, 0.115, 0.12);
	vec3 mineral = vec3(0.26, 0.22, 0.16);
	ALBEDO = mix(basalt, mineral, smoothstep(0.3, 0.8, broad) * 0.75 + strata * 0.12);
	ALBEDO *= 0.75 + grain * 0.4;
	ROUGHNESS = 0.96;
}
