shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	vec2 cell = fract(UV * vec2(8.0, 5.0));
	float seam = step(0.95, cell.x) + step(0.94, cell.y);
	float wires = step(0.95, fract(UV.y * 65.0)) * 0.25;
	ALBEDO = mix(vec3(0.018, 0.059, 0.11), vec3(0.20, 0.33, 0.4), clamp(seam + wires, 0.0, 1.0));
	METALLIC = 0.45; ROUGHNESS = 0.28;
}
