shader_type sky;
// Unresolved background directions, stationary in the same inertial frame.
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void sky() {
	vec3 direction = normalize(EYEDIR);
	vec3 cell = direction * 380.0;
	float candidate = step(0.993, hash(floor(cell)));
	float spot = exp(-length(fract(cell) - 0.5) * 14.0) * candidate;
	vec3 color = mix(vec3(0.5, 0.64, 0.8), vec3(1.0, 0.82, 0.57), hash(floor(cell) + 7.0));
	COLOR = vec3(0.002, 0.004, 0.008) + color * spot * 3.0;
}
