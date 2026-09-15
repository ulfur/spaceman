shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 sand_color : source_color = vec4(0.43, 0.29, 0.18, 1.0);
uniform vec4 stone_color : source_color = vec4(0.22, 0.25, 0.26, 1.0);
uniform float frost = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p), local = fract(p); vec2 f = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(cell), hash(cell+vec2(1,0)),f.x), mix(hash(cell+vec2(0,1)),hash(cell+vec2(1)),f.x),f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = world_position.xz;
	float broad = noise(p * 0.075), grain = noise(p * 3.2);
	float strata = sin(world_position.y * 5.5 + noise(p * 0.13) * 3.0) * 0.5 + 0.5;
	float ripple = sin(p.x * 7.2 + p.y * 3.1 + noise(p * 0.32) * 9.0) * 0.5 + 0.5;
	float slope = 1.0 - smoothstep(0.45, 0.96, world_normal.y);
	vec3 rock = stone_color.rgb * (0.74 + strata * 0.3 + grain * 0.12);
	vec3 sand = sand_color.rgb * (0.75 + grain * 0.16 + broad * 0.2 + ripple * 0.035);
	ALBEDO = mix(sand, rock, clamp(slope + smoothstep(0.51, 0.76, broad) * 0.65, 0.0, 1.0));
	float ice = frost * smoothstep(0.47, 0.74, broad) * (1.0 - slope);
	ALBEDO = mix(ALBEDO, vec3(0.52, 0.66, 0.68), ice * 0.7);
	// Optical relief; foundations and resource cells stay exact.
	float relief = grain * 0.10 + ripple * 0.022;
	vec3 tangent_x = dFdx(VERTEX), tangent_y = dFdy(VERTEX);
	vec3 gradient = cross(tangent_y, NORMAL) * dFdx(relief) + cross(NORMAL, tangent_x) * dFdy(relief);
	NORMAL = normalize(NORMAL - gradient * 0.32);
	ROUGHNESS = mix(0.92, 0.72, ice);
}
