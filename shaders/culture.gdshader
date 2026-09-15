shader_type spatial;
uniform float density = 0.0;
uniform float liquid = 1.0;
uniform float phase = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 grid = UV * 38.0;
	vec2 cell = fract(grid) - 0.5;
	float mat = (1.0 - smoothstep(0.16, 0.42, length(cell + vec2(hash(floor(grid)) - 0.5) * 0.3)));
	float colony = step(hash(floor(grid) + 27.0), density) * mat;
	vec3 substrate = mix(vec3(0.19, 0.115, 0.07), vec3(0.035, 0.10, 0.115), liquid);
	ALBEDO = mix(substrate, vec3(0.10, 0.34, 0.19), colony * 0.88);
	float ripple = sin(UV.x * 90.0 + phase * 1.6) * sin(UV.y * 70.0 - phase);
	ROUGHNESS = mix(0.85, 0.22 + ripple * 0.045, liquid);
	METALLIC = 0.05;
}
