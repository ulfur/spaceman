shader_type canvas_item;

uniform float warmth : hint_range(0.0, 1.0) = 0.0;
uniform float water : hint_range(0.0, 1.0) = 0.0;
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float world_seed = 17.0;
uniform bool rocky = false;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.13, 0.71, 0.37));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float terrain(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.07) * 0.26 + noise(p * 4.13) * 0.13 + noise(p * 8.17) * 0.06;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.28;
	float r = length(p);
	vec3 atmosphere = rocky ? vec3(0.25, 0.33, 0.38) : mix(vec3(0.24, 0.52, 0.64), vec3(0.25, 0.65, 0.85), warmth);
	if (r > 1.0) {
		float halo = exp(-(r - 1.0) * 36.0) * 0.32 * (1.0 - smoothstep(1.0, 1.13, r));
		COLOR = vec4(atmosphere, halo);
	} else {
		vec3 normal = vec3(p, sqrt(max(0.0, 1.0 - dot(p, p))));
		float angle = TIME * 0.018;
		vec3 surface = vec3(normal.x * cos(angle) + normal.z * sin(angle), normal.y,
			-normal.x * sin(angle) + normal.z * cos(angle));
		vec3 coordinate = surface * 3.7 + vec3(world_seed);
		float height = terrain(coordinate);
		float detail = noise(coordinate * 29.0);
		vec3 ice = mix(vec3(0.23, 0.38, 0.45), vec3(0.80, 0.90, 0.88), smoothstep(0.28, 0.75, height));
		vec3 land = mix(vec3(0.20, 0.17, 0.12), vec3(0.45, 0.38, 0.26), height);
		land = mix(land, vec3(0.13, 0.31, 0.19) * (0.8 + height), life * 0.9);
		vec3 ocean = mix(vec3(0.025, 0.10, 0.16), vec3(0.055, 0.28, 0.34), height);
		vec3 ground = mix(land, ocean, 1.0 - smoothstep(0.32 + water * 0.29, 0.34 + water * 0.29, height));
		float polar = smoothstep(0.64 + warmth * 0.22, 0.96, abs(surface.y));
		ground = mix(ground, ice, max(1.0 - warmth, polar));
		if (rocky) {
			ground = mix(vec3(0.18, 0.20, 0.23), vec3(0.58, 0.56, 0.49), height);
		}
		ground *= 0.88 + detail * 0.2;
		float clouds = smoothstep(0.56, 0.74, terrain(surface * 5.0 + vec3(TIME * 0.007, 7.0, 2.0)));
		if (!rocky) {
			ground = mix(ground, vec3(0.85, 0.9, 0.88), clouds * (0.1 + water * 0.9));
		}
		vec3 light = normalize(vec3(-0.65, -0.4, 0.85));
		float diffuse = max(dot(normal, light), 0.0);
		vec3 color = ground * (0.055 + diffuse * 1.16);
		float rim = pow(1.0 - normal.z, 3.5) * (0.12 + diffuse * 0.45);
		color += atmosphere * rim;
		COLOR = vec4(color, 1.0 - smoothstep(0.994, 1.0, r));
	}
}
