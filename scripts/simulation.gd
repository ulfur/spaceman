extends RefCounted
## Authoritative, deterministic simulation. No scene-tree or rendering dependencies.
## V0 integrates in whole calendar years, including during interstellar travel.

const SCENARIO_PATH := "res://data/expedition.json"
const SAVE_VERSION := 1
var scenario: Dictionary
var state: Dictionary

func _init(additional: Dictionary = {}) -> void:
	scenario = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_PATH))
	for key in ["systems", "bodies"]:
		if additional.has(key):
			scenario[key].append_array(additional[key].duplicate(true))
	reset()

func reset() -> void:
	state = {
		"version": SAVE_VERSION, "year": int(scenario.start_year), "system": "eir",
		"ship": scenario.ship.duplicate(true), "bodies": {}, "observations": {},
		"visited_vesper": false, "returned": false, "first_rain": false, "log": []
	}
	for definition in scenario.bodies:
		var body: Dictionary = definition.duplicate(true)
		body.merge({"surveyed": false, "factory": "", "target": 288.0,
			"greenhouse": 0.0, "water": 0.0, "biomass": 0.0, "seeded": false,
			"rain_recorded": false, "threshold_recorded": false, "exhausted": false,
			"stock": {"fuel": 0.0, "propellant": 0.0, "alloy": 0.0}})
		state.bodies[body.id] = body
	record("Braincast online. Commander Spaceman commands Spaceship.")
	record("Eir III holds ice. I would like to see what it does with rain.")
	observe_local()

func record(message: String, body_id: String = "") -> void:
	state.log.append({"year": state.year, "text": message, "body": body_id})
	if state.log.size() > 500:
		state.log.pop_front()

func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func local_body(id: String) -> Dictionary:
	var body: Dictionary = state.bodies.get(id, {})
	if body.is_empty() or body.system != state.system:
		return {}
	return body

func command(action: String, id: String = "", value: float = 288.0) -> Dictionary:
	var body := local_body(id)
	var ship: Dictionary = state.ship
	match action:
		"survey":
			if body.is_empty() or body.surveyed:
				return result(false, "Select an unsurveyed body in this system.")
			body.surveyed = true
			record("Survey complete: %s. %s" % [body.name, body.description], id)
		"deploy":
			if body.is_empty() or not body.surveyed:
				return result(false, "Survey the site before committing a factory.")
			if body.factory != "" or ship.modules < 1:
				return result(false, "This site needs an empty berth and one onboard factory.")
			if body.get("generated", false) and body.kind == "world":
				return result(false, "Use spatial industry on this prospect. Global interventions are not modelled here yet.")
			ship.modules -= 1
			body.factory = "warming" if body.kind == "world" else "mining"
			record("Factory landed on %s. %s policy active." % [body.name, body.factory], id)
		"policy":
			if body.is_empty() or body.factory != "warming" or value not in [288.0, 300.0, 325.0]:
				return result(false, "Select a warming factory and a supported target.")
			body.target = value
			body.threshold_recorded = false
			record("%s: equilibrium target set to %.0f K." % [body.name, value], id)
		"collect":
			if body.is_empty() or body.factory != "mining":
				return result(false, "A local extraction factory is required.")
			if body.stock.fuel + body.stock.propellant + body.stock.alloy <= 0.0:
				return result(false, "No manufactured supplies yet. Advance time first.")
			for resource in ["fuel", "propellant", "alloy"]:
				ship[resource] += body.stock[resource]
				body.stock[resource] = 0.0
			record("%s: manufactured supplies transferred to Spaceship." % body.name, id)
		"reclaim":
			if body.is_empty() or body.factory == "":
				return result(false, "There is no local factory to reclaim.")
			for resource in ["fuel", "propellant", "alloy"]:
				ship[resource] += body.stock[resource]
				body.stock[resource] = 0.0
			body.factory = ""
			ship.modules += 1
			record("%s: factory and stores reclaimed. Autonomous work has stopped." % body.name, id)
		"seed":
			if body.is_empty() or not body.surveyed or body.kind != "world" or body.seeded:
				return result(false, "Select a surveyed, unseeded terrestrial world.")
			if body.get("generated", false):
				return result(false, "Exposed-life viability is unresolved. A protected surface refuge is available.")
			if ship.seeds < 1 or body.temperature < 273.0 or body.temperature > 303.0 or body.water < 0.1:
				return result(false, "Life needs liquid water and 273–303 K. One seed archive required.")
			ship.seeds -= 1
			body.seeded = true
			body.biomass = 0.025
			record("%s: pioneer organisms released. A small beginning." % body.name, id)
		"build":
			if body.is_empty() or body.factory != "mining" or ship.alloy < 20.0 or ship.fuel < 3.0:
				return result(false, "Requires a local extraction factory, 20 alloy, and 3 fuel.")
			ship.alloy -= 20.0
			ship.fuel -= 3.0
			advance(5)
			ship.modules += 1
			record("A new factory module is secured aboard Spaceship. Five years well spent.")
		"repair":
			if body.is_empty() or body.factory != "mining" or ship.alloy < 10.0 or ship.integrity >= 100.0:
				return result(false, "Repairs require local industry, 10 alloy, and a damaged ship.")
			ship.alloy -= 10.0
			ship.integrity = minf(100.0, ship.integrity + 25.0)
			advance(2)
			record("Spaceship repaired. I feel rather more structurally sound.")
		"travel":
			var quote := travel_quote(id)
			if not quote.valid:
				return result(false, "Choose another known system.")
			if ship.fuel < quote.fuel_cost or ship.propellant < quote.propellant_cost or ship.integrity <= 20.0:
				return result(false, "Transit needs %.1f fuel, %.1f propellant and integrity above 20%%." % [quote.fuel_cost, quote.propellant_cost])
			if ship.integrity - quote.wear <= 0.0:
				return result(false, "Transit wear exceeds hull integrity.")
			ship.fuel -= quote.fuel_cost
			ship.propellant -= quote.propellant_cost
			ship.integrity -= quote.wear
			var destination: String = quote.destination
			record("Departure. %d years to %s. The factories have their instructions." % [quote.years, system_name(destination)])
			# In transit: do not update remote observations or leak surface events.
			state.system = "transit"
			advance(quote.years)
			state.system = destination
			if destination == "vesper":
				state.visited_vesper = true
			elif destination == "eir" and state.visited_vesper:
				state.returned = true
			record("Arrival in %s. Local telemetry acquired." % system_name(destination))
			if destination == "eir" and state.returned and state.bodies.eir_iii.water > 0.15 and not state.first_rain:
				state.first_rain = true
				record("There is rain on Eir III. I remember the idea of its smell.")
		_:
			return result(false, "Unknown command.")
	observe_local()
	return result(true, "Command complete.")

func has_system(id: String) -> bool:
	for definition in scenario.systems:
		if definition.id == id:
			return true
	return false

func system_name(id: String) -> String:
	for definition in scenario.systems:
		if definition.id == id:
			return definition.name.to_upper()
	return id.to_upper()

func system_position(id: String) -> Vector2:
	if id == "eir":
		return Vector2.ZERO
	if id == "vesper":
		return Vector2(4.2, 0)
	for definition in scenario.systems:
		if definition.id == id:
			return Vector2(definition.get("x_ly", 0), definition.get("y_ly", 0))
	return Vector2.ZERO

func travel_quote(destination: String = "") -> Dictionary:
	var route: Dictionary = scenario.route.duplicate(true)
	if destination == "":
		destination = "vesper" if state.system == "eir" else "eir"
	route.destination = destination
	route.valid = has_system(destination) and destination != state.system
	if route.valid and not (state.system in ["eir", "vesper"] and destination in ["eir", "vesper"]):
		route.distance_ly = system_position(state.system).distance_to(system_position(destination))
		var ratio: float = route.distance_ly / scenario.route.distance_ly
		route.fuel_cost *= ratio
		route.propellant_cost *= ratio
		route.wear *= sqrt(ratio)
	route.years = int(ceil(route.distance_ly / route.cruise_fraction_c)) + int(route.maneuver_years)
	return route

func advance(years: int) -> void:
	# Fixed annual steps make one 100-year jump identical to 100 one-year steps.
	if years <= 0:
		return
	for _year in range(clampi(years, 0, 10000)):
		state.year += 1
		for id in state.bodies:
			step_body(state.bodies[id])
	observe_local()

func step_body(body: Dictionary) -> void:
	# Generated prospects have no exposed-climate solver yet. Do not silently
	# award liquid water or habitability from the legacy temperature fixture.
	if body.get("generated", false) and body.kind == "world":
		return
	if body.factory == "mining" and body.deposit > 0.0:
		var amount := minf(3.0, body.deposit)
		body.deposit -= amount
		body.stock.propellant += amount * (2.0 / 3.0)
		body.stock.alloy += amount * (0.8 / 3.0)
		body.stock.fuel += amount * (0.2 / 3.0)
	if body.kind == "world":
		# Greenhouse forcing persists after recovery but slowly escapes the atmosphere.
		body.greenhouse = maxf(0.0, body.greenhouse - 0.02)
		if body.factory == "warming" and body.deposit > 0.0:
			var desired := maxf(0.0, body.target - body.baseline - body.greenhouse)
			var feedstock := minf(minf(1.5, desired / 0.65), body.deposit)
			body.deposit -= feedstock
			body.greenhouse += feedstock * 0.65
			if desired < 0.05 and not body.threshold_recorded:
				body.threshold_recorded = true
				record("%s: target reached; factory now replaces atmospheric losses only." % body.name, body.id)
		body.temperature += (body.baseline + body.greenhouse - body.temperature) * 0.18
		body.water = clampf((body.temperature - 268.0) / 28.0, 0.0, 0.72)
		if body.temperature > 310.0:
			body.water *= clampf((340.0 - body.temperature) / 30.0, 0.0, 1.0)
		if body.water > 0.15 and not body.rain_recorded:
			body.rain_recorded = true
			record("%s: first sustained liquid-water cycle detected." % body.name, body.id)
		if body.seeded:
			if body.temperature >= 273.0 and body.temperature <= 303.0 and body.water > 0.1:
				body.biomass = minf(1.0, body.biomass + 0.09 * body.biomass * (1.0 - body.biomass))
			else:
				body.biomass *= 0.85
	if body.factory != "" and body.deposit <= 0.000001 and not body.exhausted:
		body.exhausted = true
		record("%s: accessible feedstock exhausted. Factory idle." % body.name, body.id)

func observe_local() -> void:
	for id in state.bodies:
		var body: Dictionary = state.bodies[id]
		if body.system == state.system:
			state.observations[id] = {"year": state.year, "body": body.duplicate(true)}

func known_body(id: String) -> Dictionary:
	return state.observations.get(id, {}).get("body", {})

func known_log() -> Array:
	var visible: Array = []
	for entry in state.log:
		if entry.body == "" or (state.observations.has(entry.body) and entry.year <= state.observations[entry.body].year):
			visible.append(entry)
	return visible

func objective() -> String:
	if state.first_rain:
		if not state.bodies.eir_iii.seeded:
			return "FIRST RAIN / Achieved. Return to Eir III and introduce pioneer life."
		return "LIFESEEDED / Keep exploring. Your world will go on without you."
	if not state.bodies.eir_iii.surveyed:
		return "01 / Survey Eir III. Find out what this world could become."
	if state.bodies.eir_iii.factory == "" and not state.visited_vesper:
		return "02 / Land a factory on Eir III. Give the ice a reason to melt."
	if not state.visited_vesper:
		return "03 / Leave for Vesper. Your factory keeps working in your absence."
	if state.system == "vesper":
		return "04 / Establish reserves on Vesper B, then return to Eir."
	return "05 / Eir needs more warmth. Adjust the project, then make another round trip."

func save_json() -> String:
	return JSON.stringify(state, "\t", true, true)

func restore_json(contents: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK:
		return result(false, "Invalid save JSON. Current expedition preserved.")
	var parsed = parser.data
	if not parsed is Dictionary or not valid_save(parsed):
		return result(false, "Invalid or incompatible save. Current expedition preserved.")
	state = parsed.duplicate(true)
	state.version = int(state.version)
	state.year = int(state.year)
	for observation in state.observations.values():
		observation.year = int(observation.year)
	for entry in state.log:
		entry.year = int(entry.year)
	return result(true, "Expedition restored.")

func matches_shape(candidate: Variant, template: Variant) -> bool:
	if template is Dictionary:
		if not candidate is Dictionary:
			return false
		for key in template:
			if not candidate.has(key) or not matches_shape(candidate[key], template[key]):
				return false
		return true
	if template is float or template is int:
		return (candidate is float or candidate is int) and is_finite(float(candidate))
	return typeof(candidate) == typeof(template)

func valid_save(candidate: Dictionary) -> bool:
	var template := state.duplicate(false)
	template.observations = {}
	if not matches_shape(candidate, template) or candidate.version != SAVE_VERSION:
		return false
	if not has_system(candidate.system) or candidate.year < scenario.start_year or candidate.year != floor(candidate.year):
		return false
	for resource in candidate.ship:
		if not resource in scenario.ship or candidate.ship[resource] < 0.0 or candidate.ship[resource] > 1000000000.0:
			return false
	if candidate.ship.integrity > 100.0:
		return false
	for resource in ["modules", "seeds"]:
		if candidate.ship[resource] != floor(candidate.ship[resource]):
			return false
	if candidate.bodies.size() != scenario.bodies.size():
		return false
	for required_id in ["eir_iii", "nacre"]:
		if not candidate.observations.has(required_id):
			return false
	for definition in scenario.bodies:
		if not candidate.bodies.has(definition.id):
			return false
		if definition.system == candidate.system and not candidate.observations.has(definition.id):
			return false
		var body: Dictionary = candidate.bodies[definition.id]
		if body.id != definition.id or body.system != definition.system or body.kind != definition.kind:
			return false
		if body.factory not in ["", "warming", "mining"] or body.target not in [288.0, 300.0, 325.0]:
			return false
		if body.temperature < 0.0 or body.temperature > 1000.0 or body.greenhouse < 0.0 or body.deposit < 0.0:
			return false
		if body.water < 0.0 or body.water > 1.0 or body.biomass < 0.0 or body.biomass > 1.0:
			return false
		for amount in body.stock.values():
			if not (amount is float or amount is int) or not is_finite(float(amount)) or amount < 0.0:
				return false
	for id in candidate.observations:
		if not candidate.bodies.has(id):
			return false
		var observation = candidate.observations[id]
		if not matches_shape(observation, {"year": 0, "body": candidate.bodies[id]}) or observation.year > candidate.year:
			return false
	if candidate.log.size() > 500:
		return false
	for entry in candidate.log:
		if not matches_shape(entry, {"year": 0, "text": "", "body": ""}):
			return false
		if entry.body != "" and not candidate.bodies.has(entry.body):
			return false
	return true
