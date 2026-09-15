shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float top = (1.0 - smoothstep(0.0, 0.20, UV.y)) * 0.88;
	float bottom = smoothstep(0.84, 1.0, UV.y) * 0.92;
	COLOR = vec4(0.018, 0.032, 0.037, max(top, bottom));
}
