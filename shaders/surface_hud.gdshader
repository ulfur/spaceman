shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float top = (1.0 - smoothstep(0.0, 0.20, UV.y)) * 0.88;
	float bottom = smoothstep(0.67, 1.0, UV.y) * 0.92;
	float middle = smoothstep(0.12, 0.19, UV.y) * (1.0 - smoothstep(0.51, 0.68, UV.y));
	float sides = max(1.0 - smoothstep(0.02, 0.28, UV.x), smoothstep(0.72, 0.98, UV.x)) * middle * 0.72;
	COLOR = vec4(0.018, 0.032, 0.037, max(max(top, bottom), sides));
}
