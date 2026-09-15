shader_type canvas_item;
// Observed-world illustration, not a climate or orbital integrator.
uniform float warmth = 0.0;
uniform float water = 0.0;
uniform float life = 0.0;
uniform float world_seed = 17.0;
uniform float air = 0.35;
uniform float phase = 0.0;
uniform bool rocky = false;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.13, 0.71, 0.37)); p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float terrain(vec3 p) {
	return noise(p) * 0.51 + noise(p * 2.03) * 0.27 + noise(p * 4.09) * 0.14 + noise(p * 8.13) * 0.08;
}
vec3 rotate_world(vec3 p, float angle) {
	return vec3(p.x * cos(angle) + p.z * sin(angle), p.y, -p.x * sin(angle) + p.z * cos(angle));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.19;
	float r = length(p);
	vec3 sun = normalize(vec3(-0.74, -0.36, 0.55));
	vec3 haze = mix(vec3(0.18, 0.48, 0.75), vec3(0.18, 0.54, 0.68), warmth);
	float atmosphere = rocky ? 0.0 : clamp(air * 2.4, 0.0, 1.0);
	if (r > 1.0) {
		float day = smoothstep(-0.4, 0.9, dot(normalize(vec3(p, 0)), sun));
		float halo = exp(-(r - 1.0) * 62.0) * (0.18 + day * 0.55) * atmosphere;
		COLOR = vec4(haze * (0.6 + day * 0.8), halo * (1.0 - smoothstep(1.02, 1.08, r)));
	} else {
		vec3 n = vec3(p, sqrt(max(0.0, 1.0 - dot(p, p))));
		vec3 surface = rotate_world(n, phase * 0.012 + 0.4);
		vec3 coord = surface * 4.1 + vec3(world_seed);
		float height = terrain(coord + noise(coord * 0.7) * 0.7);
		float grain = noise(coord * 46.0);
		float ridge = 1.0 - abs(noise(coord * 13.0) * 2.0 - 1.0);
		float shore = 0.36 + water * 0.23;
		float sea = 1.0 - smoothstep(shore, shore + 0.018, height);
		vec3 land = mix(vec3(0.20, 0.145, 0.093), vec3(0.49, 0.38, 0.23), height);
		land = mix(land, mix(vec3(0.07, 0.16, 0.12), vec3(0.29, 0.37, 0.18), height), life * 0.84);
		land = mix(land, vec3(0.39, 0.37, 0.31), smoothstep(0.65, 0.83, height) * ridge);
		vec3 ocean = mix(vec3(0.012, 0.039, 0.081), vec3(0.055, 0.28, 0.33), smoothstep(shore - 0.12, shore, height));
		vec3 ground = mix(land, ocean, sea);
		float frost = max(1.0 - warmth, smoothstep(0.62 + warmth * 0.18, 0.99, abs(surface.y) + height * 0.08));
		vec3 ice = mix(vec3(0.18, 0.32, 0.39), vec3(0.73, 0.84, 0.87), smoothstep(0.32, 0.69, height + ridge * 0.09));
		ground = mix(ground, ice, frost);
		if (rocky) {
			float pits = smoothstep(0.24, 0.33, noise(coord * 7.0));
			ground = mix(vec3(0.15, 0.17, 0.18), vec3(0.52, 0.47, 0.37), height) * (0.66 + pits * 0.38);
		}
		ground *= 0.83 + grain * 0.22 + ridge * 0.1;
		float relief = height + grain * 0.016 + ridge * 0.05;
		vec3 bumped = normalize(n + vec3(-dFdx(relief), -dFdy(relief), 0) * 36.0 * (1.0 - sea * warmth));
		float diffuse = max(dot(bumped, sun), 0.0);
		float daylight = max(dot(n, sun), 0.0);
		vec3 cloud_p = rotate_world(n, phase * 0.016) * 5.4;
		cloud_p.xz += vec2(sin(cloud_p.y * 2.3), cos(cloud_p.y * 1.6)) * 0.34;
		float vapor = terrain(cloud_p + vec3(2.0, 7.0, world_seed * 0.13));
		float clouds = smoothstep(0.53, 0.73, vapor + noise(cloud_p * 15.0) * 0.11) * atmosphere * (0.2 + water * 0.72);
		vec3 color = ground * (vec3(0.019, 0.029, 0.045) + diffuse * vec3(1.12, 1.05, 0.96));
		color *= 1.0 - clouds * 0.28;
		float glint = pow(max(dot(reflect(-sun, n), vec3(0,0,1)), 0.0), 72.0);
		color += vec3(0.78, 0.72, 0.51) * glint * sea * warmth * (1.0 - clouds) * 0.7;
		color = mix(color, vec3(0.83, 0.87, 0.88) * (0.06 + daylight * 1.06), clouds);
		float rim = pow(1.0 - n.z, 3.4) * atmosphere;
		color += haze * rim * (0.055 + daylight * 0.8);
		color += vec3(0.62, 0.20, 0.065) * exp(-abs(dot(n, sun)) * 23.0) * rim * 0.5;
		COLOR = vec4(color, 1.0 - smoothstep(0.997, 1.0, r));
	}
}
