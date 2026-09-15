extends RefCounted
## Shared expedition and surface clock. Views never own persistent physical state.
const Simulation = preload("res://scripts/simulation.gd")
const Surface = preload("res://scripts/surface_simulation.gd")
const Prospects = preload("res://scripts/prospects.gd")
const Atlas = preload("res://scripts/world_atlas.gd")
const HOURS_PER_YEAR := 8766
const SAVE_PATH := "user://expedition.json"
static var shared: RefCounted

var prospects = Prospects.new(int(Prospects.CONFIG.default_seed))
var expedition = Simulation.new(prospects.definitions())
var sites: Dictionary = {}
var fractional_hours := 0
var surface_body := "eir_iii"
var surface_region := Atlas.DEFAULT_REGION
var orbit_body := ""
var viewed_system := ""
var chart_center := Vector2.ZERO
var trial_id := -1
var initialized := false

static func get_shared() -> RefCounted:
	if shared == null:
		shared = load("res://scripts/session.gd").new()
	return shared

func reset(seed: int = 1701) -> void:
	prospects = Prospects.new(clampi(seed, 1, 999999))
	var fresh = Simulation.new(prospects.definitions())
	expedition.scenario = fresh.scenario
	expedition.state = fresh.state
	sites.clear()
	fractional_hours = 0
	surface_body = "eir_iii"
	surface_region = Atlas.DEFAULT_REGION
	orbit_body = ""
	viewed_system = ""
	chart_center = Vector2.ZERO
	trial_id = -1

func site_available(id: String) -> bool:
	var body: Dictionary = expedition.local_body(id)
	if body.is_empty() or not body.surveyed or body.factory != "": return false
	return not body.get("generated", false) or body.kind == "moon" or prospects.state.records[body.system].has("probe")

func base_context(id: String, source: RefCounted = null, simulation: RefCounted = null) -> Dictionary:
	var catalogue = prospects if source == null else source
	var sim = expedition if simulation == null else simulation
	var context: Dictionary = catalogue.surface_context(id)
	if not context.is_empty() or id == "eir_iii": return context
	var body: Dictionary = sim.state.bodies[id]
	return {"seed": int(body.seed), "solar_factor": 0.35, "ice_factor": 1.2, "ore_factor": 1.0,
		"environment": {"ambient_k": body.baseline, "equilibrium_k": body.baseline,
		"pressure": 0.0, "gravity": 0.3, "flux": 0.35, "field_earth": 0.0, "activity": 0.2, "co2_fraction": 0.0}}

func region_context(id: String, region: Vector2i) -> Dictionary:
	return Atlas.region_context(base_context(id), id, region)

func current_address() -> String:
	return Atlas.address(surface_body, surface_region)

func choose_region(id: String, region: Vector2i) -> bool:
	if not site_available(id) or Atlas.parse_address(Atlas.address(id, region)).is_empty(): return false
	surface_body = id
	surface_region = region
	return true

func surface_for(id: String, region: Vector2i = Vector2i(-1, -1)) -> RefCounted:
	if not site_available(id): return null
	if region.x < 0: region = surface_region if id == surface_body else Atlas.DEFAULT_REGION
	var key := Atlas.address(id, region)
	if Atlas.parse_address(key).is_empty(): return null
	if not sites.has(key):
		var context := region_context(id, region)
		sites[key] = Surface.new(int(context.get("seed", Surface.CONFIG.seed)), context)
	return sites[key]

func body_has_industry(id: String) -> bool:
	for key in sites:
		if Atlas.parse_address(key).get("body") == id and sites[key].state.landed: return true
	return false

func catalogue_field(cell: Vector2i) -> bool:
	if not prospects.catalogue_cell(cell): return false
	var expanded = Simulation.new(prospects.definitions())
	for id in expedition.state.bodies: expanded.state.bodies[id] = expedition.state.bodies[id]
	expedition.state.bodies = expanded.state.bodies
	expedition.scenario = expanded.scenario
	return true

func default_body() -> String:
	for definition in expedition.scenario.bodies:
		if definition.system == expedition.state.system:
			return definition.id
	return "eir_iii"

func elapsed_hours() -> int:
	return (int(expedition.state.year) - int(expedition.scenario.start_year)) * HOURS_PER_YEAR + fractional_hours

func observe(id: String, method: String) -> Dictionary:
	var allowed: Dictionary = prospects.can_observe(id, method, expedition.state.system)
	if not allowed.ok:
		return allowed
	var cost: Dictionary = Prospects.CONFIG.observations[method]
	var ship: Dictionary = expedition.state.ship
	if ship.fuel < cost.fuel or ship.alloy < cost.alloy:
		return {"ok": false, "message": "Observation needs %.2f reactor fuel and %.1f alloy." % [cost.fuel, cost.alloy]}
	ship.fuel -= cost.fuel
	ship.alloy -= cost.alloy
	var distance: float = expedition.system_position(expedition.state.system).distance_to(expedition.system_position(id))
	advance_hours(int(cost.hours))
	var outcome: Dictionary = prospects.observe(id, method, expedition.state.system, elapsed_hours(), distance)
	if method == "probe":
		for suffix in ["_b", "_c", "_d"]:
			expedition.command("survey", id + suffix)
	expedition.record(outcome.message)
	return outcome

func surface_command(action: String, x: int = -1, z: int = -1) -> Dictionary:
	var site = surface_for(surface_body)
	if site == null:
		return {"ok": false, "message": "Surface command needs a surveyed, local landing region without an orbital factory."}
	if action in ["land", "seed"] and expedition.state.ship.modules < 1:
		return {"ok": false, "message": "No factory modules aboard Spaceship."}
	var outcome: Dictionary = site.command(action, x, z)
	if outcome.ok and action in ["land", "seed"]:
		expedition.state.ship.modules -= 1
		expedition.record("%s: surface seed module landed. Spatial industry commissioned." % expedition.state.bodies[surface_body].name, surface_body)
	return outcome

func command(action: String, id: String = "", value: float = 288.0) -> Dictionary:
	var body: Dictionary = expedition.local_body(id)
	if action == "survey" and not body.is_empty() and body.get("generated", false) and body.kind == "world":
		return observe(body.system, "probe")
	if action == "deploy" and body_has_industry(id):
		return {"ok": false, "message": "This region already has a surface module. Use Surface operations."}
	var before: int = expedition.state.year
	var outcome: Dictionary = expedition.command(action, id, value)
	_advance_sites((int(expedition.state.year) - before) * HOURS_PER_YEAR)
	return outcome

func _advance_sites(hours: int) -> void:
	if hours <= 0:
		return
	for site in sites.values():
		site.advance(hours)

func advance_hours(hours: int) -> void:
	if hours <= 0 or hours > 10000 * HOURS_PER_YEAR:
		return
	_advance_sites(hours)
	fractional_hours += hours
	var years: int = fractional_hours / HOURS_PER_YEAR
	fractional_hours %= HOURS_PER_YEAR
	if years > 0:
		expedition.advance(years)

func advance_years(years: int) -> void:
	if years <= 0 or years > 10000:
		return
	advance_hours(years * HOURS_PER_YEAR)

func save_json() -> String:
	var saved_sites: Dictionary = {}
	for id in sites:
		saved_sites[id] = JSON.parse_string(sites[id].save_json())
	return JSON.stringify({"version": 5, "prospects": JSON.parse_string(prospects.save_json()), "expedition": JSON.parse_string(expedition.save_json()),
		"sites": saved_sites, "fractional_hours": fractional_hours, "surface_body": surface_body, "surface_address": current_address()}, "\t", true, true)

func restore_json(contents: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "Invalid save. Current expedition preserved."}
	var candidate: Dictionary = parser.data
	# JSON parses numbers as floats; Array membership distinguishes 3.0 from 3.
	var raw_version: Variant = candidate.get("version")
	if not (raw_version is float or raw_version is int) or not is_finite(float(raw_version)) or raw_version != floor(raw_version):
		return {"ok": false, "message": "Unsupported save version."}
	var version := int(raw_version)
	if version not in [1, 2, 3, 4, 5]:
		return {"ok": false, "message": "Unsupported save version."}
	var orbital: Variant = candidate if version == 1 else candidate.get("expedition")
	if not orbital is Dictionary:
		return {"ok": false, "message": "Missing expedition state."}
	var remainder: Variant = 0 if version == 1 else candidate.get("fractional_hours")
	if not (remainder is float or remainder is int) or not is_finite(float(remainder)) or remainder != floor(remainder) or remainder < 0 or remainder >= HOURS_PER_YEAR:
		return {"ok": false, "message": "Invalid save clock."}
	var year: Variant = orbital.get("year")
	if not (year is float or year is int) or not is_finite(float(year)) or year != floor(year) or year < 2400 or year > 1000000000:
		return {"ok": false, "message": "Invalid expedition year."}
	var now: int = (int(year) - 2400) * HOURS_PER_YEAR + int(remainder)
	var staged_prospects = Prospects.new(int(Prospects.CONFIG.default_seed))
	if version >= 3:
		if not candidate.get("prospects") is Dictionary:
			return {"ok": false, "message": "Missing prospect evidence."}
		var restored: Dictionary = staged_prospects.restore_json(JSON.stringify(candidate.prospects), now)
		if not restored.ok:
			return restored
	var staged = Simulation.new(staged_prospects.definitions(version >= 5))
	if version >= 3:
		var restored: Dictionary = staged.restore_json(JSON.stringify(orbital))
		if not restored.ok:
			return restored
	else:
		# Validate the original three-body schema before extending old expeditions.
		var legacy = Simulation.new()
		var restored: Dictionary = legacy.restore_json(JSON.stringify(orbital))
		if not restored.ok:
			return restored
		var all_bodies: Dictionary = staged.state.bodies
		all_bodies.merge(legacy.state.bodies, true)
		staged.state = legacy.state
		staged.state.bodies = all_bodies
	if version < 5:
		var expanded = Simulation.new(staged_prospects.definitions())
		for id in staged.state.bodies: expanded.state.bodies[id] = staged.state.bodies[id]
		staged.state.bodies = expanded.state.bodies
		staged.scenario = expanded.scenario
		staged.observe_local()
	var staged_sites: Dictionary = {}
	var selected_body: Variant = "eir_iii" if version == 1 else candidate.get("surface_body")
	if not selected_body is String or not staged.state.bodies.has(selected_body):
		return {"ok": false, "message": "Unknown surface region."}
	var selected_region := Atlas.DEFAULT_REGION
	if version >= 5:
		if not candidate.get("surface_address") is String: return {"ok": false, "message": "Missing surface address."}
		var decoded := Atlas.parse_address(candidate.surface_address)
		if decoded.is_empty() or decoded.body != selected_body: return {"ok": false, "message": "Invalid selected surface address."}
		selected_region = decoded.region
	if version != 1:
		if not candidate.get("sites") is Dictionary:
			return {"ok": false, "message": "Missing surface sites."}
		for key in candidate.sites:
			var decoded := Atlas.parse_address(key)
			if decoded.is_empty(): return {"ok": false, "message": "Invalid surface address."}
			var id: String = decoded.body
			if not staged.state.bodies.has(id) or not candidate.sites[key] is Dictionary:
				return {"ok": false, "message": "Unknown surface site."}
			var body: Dictionary = staged.state.bodies[id]
			if not body.surveyed or (body.get("generated", false) and body.kind == "world" and not staged_prospects.state.records[body.system].has("probe")):
				return {"ok": false, "message": "Surface site lacks local probe evidence."}
			var context: Dictionary = Atlas.region_context(base_context(id, staged_prospects, staged), id, decoded.region)
			var site = Surface.new(int(context.get("seed", Surface.CONFIG.seed)), context)
			var restored: Dictionary = site.restore_json(JSON.stringify(candidate.sites[key]))
			if not restored.ok:
				return restored
			if site.state.total_hours > now or (site.state.landed and body.factory != "") or site.state.seed != int(context.get("seed", Surface.CONFIG.seed)):
				return {"ok": false, "message": "Conflicting site clock, seed or factory allocation."}
			if absf(site.state.get("solar_factor", 1.0) - context.get("solar_factor", 1.0)) > 0.00000001:
				return {"ok": false, "message": "Surface solar context conflicts with its planet."}
			staged_sites[key] = site
	# No live state is replaced until all components validate.
	expedition.scenario = staged.scenario
	expedition.state = staged.state
	prospects = staged_prospects
	sites = staged_sites
	fractional_hours = int(remainder)
	surface_body = selected_body
	surface_region = selected_region
	orbit_body = ""
	viewed_system = ""
	return {"ok": true, "message": "Expedition, prospect evidence and surface installations restored."}

func trial_command(id: int, action: String, value: Variant = null) -> Dictionary:
	var site = surface_for(surface_body)
	if site == null: return {"ok": false, "message": "Direct trial control requires a local probed site."}
	if action != "inoculate": return site.trial_command(id, action, value)
	var structure: Dictionary = site.testbed_at(id)
	if structure.is_empty() or structure.progress < 1.0 or structure.trial.biomass_kg > 0.000000001:
		return {"ok": false, "message": "Select a completed testbed without an existing live culture."}
	if expedition.state.ship.seeds < 1:
		return {"ok": false, "message": "No biological archive packets aboard Spaceship."}
	var c: Dictionary = Surface.Testbed.CONFIG.culture
	expedition.state.ship.seeds -= 1
	structure.trial.biomass_kg += c.seed_kg
	structure.trial.nutrients_kg += c.packet_nutrients_kg
	structure.trial.archive_in_kg += c.seed_kg + c.packet_nutrients_kg
	site._record("Testbed %d inoculated from one ship archive packet. Monitor the limiting conditions." % id)
	return {"ok": true, "message": "Archive culture introduced. Survival now depends on the measured environment."}

func load_disk() -> Dictionary:
	initialized = true
	if "--smoke" in OS.get_cmdline_user_args() or not FileAccess.file_exists(SAVE_PATH):
		return {"ok": true, "message": "Expedition ready."}
	return restore_json(FileAccess.get_file_as_string(SAVE_PATH))

func save_disk() -> Dictionary:
	if "--smoke" in OS.get_cmdline_user_args():
		return {"ok": true, "message": "Smoke mode: player save untouched."}
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Save failed: cannot open storage."}
	file.store_string(save_json())
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) != OK:
		return {"ok": false, "message": "Save failed: previous save retained."}
	return {"ok": true, "message": "Expedition saved."}
