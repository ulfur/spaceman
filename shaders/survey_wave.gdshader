shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float age = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float radius = age * 0.46;
	float edge = exp(-abs(r - radius) * 150.0);
	ALBEDO = vec3(0.3, 0.85, 0.74);
	EMISSION = ALBEDO * 0.6;
	ALPHA = edge * (1.0 - smoothstep(1.0, 2.0, age)) * 0.62;
}
