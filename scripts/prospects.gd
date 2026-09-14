extends RefCounted
## Reproducible synthetic prospects. Truth is generated once; evidence is separate.
## Units: light years, AU, solar luminosity, Earth mass/radius/gravity, bar, K.
## Stellar activity is qualitative and illustrative, not a calibrated dose model.
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prospects.json"))
var worlds: Dictionary = {}
var state: Dictionary

func _init(seed: int = 1701) -> void:
	reset(seed)

func reset(seed: int = 1701) -> void:
	worlds.clear()
	state = {"version": 1, "seed": seed, "records": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index in range(CONFIG.names.size()):
		var spec: Dictionary = CONFIG.stars[(index + seed) % CONFIG.stars.size()]
		var id: String = "prospect_%d" % index
		var luminosity: float = rng.randf_range(spec.luminosity[0], spec.luminosity[1])
		var age: float = rng.randf_range(0.3, 8.0)
		var activity: float = (spec.activity_floor + spec.activity_youth * exp(-age / spec.activity_decay_gyr)) * rng.randf_range(0.7, 1.4)
		var angle: float = index * TAU / CONFIG.names.size() + rng.randf_range(-0.15, 0.15) + 0.45
		var distance: float = rng.randf_range(CONFIG.distance_ly[0], CONFIG.distance_ly[1])
		var flux: float = exp(rng.randf_range(log(CONFIG.flux_earth[0]), log(CONFIG.flux_earth[1])))
		var mass: float = rng.randf_range(CONFIG.mass_earth[0], CONFIG.mass_earth[1])
		var radius: float = pow(mass / rng.randf_range(CONFIG.density_earth[0], CONFIG.density_earth[1]), 1.0 / 3.0)
		var pressure: float = exp(rng.randf_range(log(CONFIG.pressure_bar[0]), log(CONFIG.pressure_bar[1])))
		var albedo: float = rng.randf_range(0.12, 0.55)
		var ice: float = rng.randf_range(0.2, 1.5) * (1.0 if flux < 1.1 else 0.25)
		var orbit: float = sqrt(luminosity / flux)
		worlds[id] = {"id": id, "name": CONFIG.names[index], "type": spec.type,
			"x_ly": cos(angle) * distance, "y_ly": sin(angle) * distance,
			"luminosity": luminosity, "age_gyr": age, "activity": activity,
			"flux": flux, "orbit_au": orbit, "mass": mass, "radius": radius,
			"gravity": mass / (radius * radius), "pressure": pressure, "albedo": albedo,
			"equilibrium_k": 278.3 * pow(flux * (1.0 - albedo), 0.25),
			"ice_factor": ice, "ore_factor": rng.randf_range(0.35, 1.8),
			"field_earth": exp(rng.randf_range(log(0.01), log(1.5))),
			"locked": orbit < 0.15, "terrain_seed": rng.randi_range(1, 999999),
			"spectrum_hint": "CO₂ absorption; pressure unresolved" if pressure > 0.2 else "Weak atmospheric features; composition unresolved"}
		state.records[id] = {}

func definitions() -> Dictionary:
	var result := {"systems": [], "bodies": []}
	for world in worlds.values():
		result.systems.append({"id": world.id, "name": world.name.to_upper(), "subtitle": "Uncharted prospect", "x_ly": world.x_ly, "y_ly": world.y_ly, "generated": true})
		result.bodies.append({"id": world.id + "_b", "system": world.id, "name": world.name + " b", "kind": "world",
			"description": "Mapped landing region. Surface climate and exposed-life viability remain unresolved; use the prospect dossier.",
			"baseline": world.equilibrium_k, "temperature": world.equilibrium_k, "deposit": 0.0, "seed": float(world.terrain_seed), "generated": true})
		result.bodies.append({"id": world.id + "_c", "system": world.id, "name": world.name + " c", "kind": "moon",
			"description": "An industrial companion. Survey its accessible feedstock before committing a module.",
			"baseline": world.equilibrium_k, "temperature": world.equilibrium_k, "deposit": 350.0 * world.ore_factor, "seed": float(world.terrain_seed + 1), "generated": true})
	return result

func evidence(id: String) -> Dictionary:
	if not worlds.has(id):
		return {}
	var world: Dictionary = worlds[id]
	var record: Dictionary = state.records[id]
	# Only return fields supported by an acquired observation. UI never reads truth.
	var known := {"id": id, "name": world.name, "type": world.type,
		"x_ly": world.x_ly, "y_ly": world.y_ly, "luminosity": world.luminosity,
		"age_low": maxf(0.1, world.age_gyr * 0.65), "age_high": world.age_gyr * 1.35,
		"records": record.duplicate(true), "planet_name": world.name + " b"}
	if record.has("photometry") or record.has("probe"):
		var error: float = 0.02 if record.has("probe") else 0.3
		known.flux_low = world.flux * (1.0 - error)
		known.flux_high = world.flux * (1.0 + error)
		known.orbit_low = world.orbit_au * (1.0 - error * 0.4)
		known.orbit_high = world.orbit_au * (1.0 + error * 0.4)
	if record.has("spectrum") or record.has("probe"):
		known.spectrum_hint = world.spectrum_hint
	if record.has("monitor") or record.has("probe"):
		known.activity_band = "HIGH" if world.activity > 1.3 else ("ELEVATED" if world.activity > 0.55 else "LOW")
	if record.has("probe"):
		known.gravity = world.gravity
		known.pressure = world.pressure
		known.field_earth = world.field_earth
		known.locked = world.locked
		known.ice_factor = world.ice_factor
		known.ore_factor = world.ore_factor
		known.solar_factor = minf(1.8, world.flux)
		known.equilibrium_k = world.equilibrium_k
		known.atmospheric_column = world.pressure * 100000.0 / (world.gravity * 9.81)
	return known

func can_observe(id: String, method: String, current_system: String) -> Dictionary:
	if not worlds.has(id) or not CONFIG.observations.has(method):
		return {"ok": false, "message": "Select a generated prospect and a supported instrument."}
	var record: Dictionary = state.records[id]
	if method == "probe" and current_system != id:
		return {"ok": false, "message": "A local probe requires arrival in this system."}
	if method == "spectrum" and not record.has("photometry") and not record.has("probe"):
		return {"ok": false, "message": "Resolve the orbit before taking a targeted spectrum."}
	if record.has(method):
		return {"ok": false, "message": "This observing programme is complete. Its dated result is retained."}
	return {"ok": true, "message": "Instrument ready."}

func observe(id: String, method: String, current_system: String, received_hour: int, distance_ly: float) -> Dictionary:
	var allowed := can_observe(id, method, current_system)
	if not allowed.ok:
		return allowed
	state.records[id][method] = {"received_hour": received_hour,
		"source_hour": received_hour - int(round(distance_ly * 8766.0)) if method != "probe" else received_hour}
	return {"ok": true, "message": "%s: %s acquired. Evidence updated; the world has not changed." % [worlds[id].name, CONFIG.observations[method].label]}

func surface_context(body_id: String) -> Dictionary:
	for id in worlds:
		if body_id == id + "_b":
			var world: Dictionary = worlds[id]
			return {"seed": world.terrain_seed, "solar_factor": minf(1.8, world.flux), "ore_factor": world.ore_factor, "ice_factor": world.ice_factor}
	return {}

func save_json() -> String:
	return JSON.stringify(state, "\t", true, true)

func restore_json(contents: String, now_hour: int) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "Invalid prospect save."}
	var candidate: Dictionary = parser.data
	var seed: Variant = candidate.get("seed")
	if candidate.get("version") != 1 or not (seed is float or seed is int) or not is_finite(float(seed)) or seed != floor(seed) or seed < 1 or seed > 999999 or not candidate.get("records") is Dictionary:
		return {"ok": false, "message": "Invalid catalogue seed or record."}
	var expected = load("res://scripts/prospects.gd").new(int(seed))
	if candidate.records.size() != expected.worlds.size():
		return {"ok": false, "message": "Incomplete prospect catalogue."}
	for id in candidate.records:
		if not expected.worlds.has(id) or not candidate.records[id] is Dictionary:
			return {"ok": false, "message": "Unknown prospect record."}
		for method in candidate.records[id]:
			if not CONFIG.observations.has(method) or not candidate.records[id][method] is Dictionary:
				return {"ok": false, "message": "Unknown observation method."}
			var record: Dictionary = candidate.records[id][method]
			for key in ["received_hour", "source_hour"]:
				var value: Variant = record.get(key)
				if not (value is int or value is float) or not is_finite(float(value)) or value != floor(value) or value > now_hour or value < -1000000:
					return {"ok": false, "message": "Invalid observation timestamp."}
			if record.received_hour < 0 or record.source_hour > record.received_hour:
				return {"ok": false, "message": "Observation causality violated."}
			if method == "probe" and record.source_hour != record.received_hour:
				return {"ok": false, "message": "Invalid local probe timestamp."}
	reset(int(seed))
	state.records = candidate.records.duplicate(true)
	for record in state.records.values():
		for observation in record.values():
			observation.received_hour = int(observation.received_hour)
			observation.source_hour = int(observation.source_hour)
	return {"ok": true, "message": "Prospect evidence restored."}
