shader_type canvas_item;
// Keep the selected world through the zoom; peripheral labels dissolve early.
uniform vec2 focus_uv = vec2(0.5);
uniform vec2 source_size = vec2(1440.0, 900.0);
uniform float progress = 0.0;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float distance_px = length((UV - focus_uv) * source_size);
	float radius = mix(length(source_size), min(source_size.x, source_size.y) * 0.23, smoothstep(0.0, 0.48, progress));
	pixel.a *= 1.0 - smoothstep(radius * 0.55, radius, distance_px);
	COLOR = pixel * COLOR;
}
