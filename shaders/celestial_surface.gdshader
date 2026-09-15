shader_type spatial;
render_mode unshaded;
// Body-fixed procedural reconstruction. Illumination is in the stellar frame.
uniform float world_seed = 17.0;
uniform float warmth = 0.0;
uniform float water = 0.0;
uniform float life = 0.0;
uniform float air = 0.0;
uniform float cloud_phase = 0.0;
uniform bool rocky = false;
uniform vec3 sun_direction = vec3(1, 0, 0);
// Instrument data, supplied from the same region priors as the inspector.
uniform int survey_mode = 0;
uniform sampler2D survey_data : filter_nearest, repeat_disable;
varying vec3 body_normal;
varying vec3 world_normal;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.13, 0.71, 0.37)); p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float terrain(vec3 p) {
	return noise(p) * 0.51 + noise(p * 2.03) * 0.27 + noise(p * 4.09) * 0.14 + noise(p * 8.13) * 0.08;
}
void vertex() {
	body_normal = NORMAL;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
	vec3 surface = normalize(body_normal);
	vec3 n = normalize(world_normal);
	vec3 sun = normalize(sun_direction);
	vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 coord = surface * 4.1 + vec3(world_seed);
	float height = terrain(coord + noise(coord * 0.7) * 0.7);
	float grain = noise(coord * 80.0);
	float ridge = 1.0 - abs(noise(coord * 18.0) * 2.0 - 1.0);
	float shore = 0.29 + water * 0.34;
	float sea = (1.0 - smoothstep(shore, shore + 0.012, height)) * step(0.01, water);
	vec3 land = mix(vec3(0.12, 0.08, 0.052), vec3(0.51, 0.39, 0.25), height);
	land = mix(land, mix(vec3(0.038, 0.09, 0.05), vec3(0.25, 0.34, 0.12), height), life * 0.84);
	land = mix(land, vec3(0.40, 0.37, 0.32), smoothstep(0.64, 0.83, height) * ridge);
	vec3 ocean = mix(vec3(0.008, 0.028, 0.052), vec3(0.025, 0.20, 0.22), smoothstep(shore - 0.07, shore, height));
	vec3 ground = mix(land, ocean, sea);
	float frost = max((1.0 - warmth) * smoothstep(0.37, 0.52, height), smoothstep(0.54 + warmth * 0.32, 0.99, abs(surface.y) + height * 0.07));
	vec3 ice = mix(vec3(0.16, 0.25, 0.28), vec3(0.75, 0.82, 0.83), smoothstep(0.32, 0.69, height + ridge * 0.09));
	ground = mix(ground, ice, frost);
	if (rocky) ground = mix(vec3(0.12, 0.12, 0.115), vec3(0.47, 0.43, 0.36), height) * (0.6 + smoothstep(0.25, 0.35, noise(coord * 8.0)) * 0.5);
	ground *= 0.74 + grain * 0.31 + ridge * 0.13;
	float day = dot(n, sun);
	float diffuse = max(day, 0.0);
	float atmosphere = rocky ? 0.0 : clamp(air * 2.0, 0.0, 1.0);
	vec3 cloud_p = surface * 5.4 + vec3(cloud_phase, 0, cloud_phase * 0.3);
	float vapor = terrain(cloud_p + vec3(2, 7, world_seed * 0.13));
	float clouds = smoothstep(0.53, 0.73, vapor + noise(cloud_p * 15.0) * 0.11) * atmosphere * (0.2 + water * 0.72);
	vec3 color = ground * (vec3(0.004, 0.006, 0.009) + diffuse * vec3(1.28, 1.18, 1.07));
	color *= 1.0 - clouds * 0.28;
	float glint = pow(max(dot(reflect(-sun, n), eye), 0.0), 90.0);
	color += vec3(0.78, 0.72, 0.51) * glint * sea * warmth * (1.0 - clouds) * 0.7;
	color = mix(color, vec3(0.86, 0.88, 0.87) * (0.003 + diffuse), clouds);
	float rim = pow(1.0 - max(dot(n, eye), 0.0), 4.0) * atmosphere;
	color += vec3(0.16, 0.40, 0.67) * rim * (0.01 + diffuse * 0.65);
	color += vec3(0.57, 0.16, 0.035) * exp(-abs(day) * 30.0) * rim * 0.45;
	if (survey_mode > 0) {
		vec2 geo = vec2((atan(surface.x, surface.z) + PI) / TAU, (PI * 0.5 - asin(surface.y)) / PI);
		vec3 priors = texture(survey_data, geo).rgb;
		float value = survey_mode == 1 ? priors.r : (survey_mode == 2 ? priors.g : priors.b);
		float level = clamp(value / 2.5, 0.0, 1.0);
		vec3 heat = mix(vec3(0.018, 0.085, 0.14), vec3(0.08, 0.62, 0.67), smoothstep(0.0, 0.6, level));
		heat = mix(heat, vec3(0.96, 0.73, 0.34), smoothstep(0.5, 1.0, level));
		vec2 cell = fract(geo * vec2(72.0, 36.0));
		float grid = 1.0 - smoothstep(0.0, 0.018, min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y)));
		// Emissive instrument overlay remains readable on the night hemisphere;
		// the terminator still shows actual illumination beneath the map.
		color = heat * (0.65 + diffuse * 0.35) + color * 0.18 + vec3(0.15, 0.48, 0.55) * grid * 0.18;
	}
	ALBEDO = color;
}
