shader_type canvas_item;
// Photographic field: a backdrop, never catalogue data.
uniform vec2 drift = vec2(0.0);
uniform float aspect = 1.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
	vec2 p = UV * vec2(aspect, 1.0) + drift * 0.005;
	float cloud = noise(p * 5.0) * 0.55 + noise(p * 13.0) * 0.3 + noise(p * 38.0) * 0.15;
	float band = exp(-pow((p.y + p.x * 0.43 - 0.91 + cloud * 0.14) * 4.0, 2.0));
	vec3 color = vec3(0.019, 0.033, 0.048) + mix(vec3(0.05,0.032,0.024),vec3(0.015,0.075,0.11),cloud) * band * cloud * 1.7;
	for (int layer=0; layer<2; layer++) {
		float scale = 150.0 + float(layer) * 94.0;
		vec2 grid = p * scale + drift * float(layer) * 0.12;
		vec2 cell = floor(grid), local = fract(grid) - vec2(hash(cell),hash(cell+37.0));
		float seed = hash(cell + 11.0);
		float star = exp(-length(local) * (32.0 + float(layer)*16.0)) * step(0.962, seed);
		color += mix(vec3(0.35,0.58,0.82),vec3(0.88,0.76,0.56),hash(cell+82.0)) * star;
	}
	float vignette = 1.0 - smoothstep(0.2, 0.8, length(UV-0.5));
	COLOR = vec4(color * (0.58 + vignette*0.42), 1.0);
}
