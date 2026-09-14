extends RefCounted
## Shared expedition and surface clock. Views never own persistent physical state.
const Simulation = preload("res://scripts/simulation.gd")
const Surface = preload("res://scripts/surface_simulation.gd")
const Prospects = preload("res://scripts/prospects.gd")
const HOURS_PER_YEAR := 8766
const SAVE_PATH := "user://expedition.json"
static var shared: RefCounted

var prospects = Prospects.new(int(Prospects.CONFIG.default_seed))
var expedition = Simulation.new(prospects.definitions())
var sites: Dictionary = {}
var fractional_hours := 0
var surface_body := "eir_iii"
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

func site_available(id: String) -> bool:
	var body: Dictionary = expedition.local_body(id)
	if body.is_empty() or not body.surveyed or body.factory != "":
		return false
	return id == "eir_iii" or (body.get("generated", false) and body.kind == "world" and prospects.state.records[body.system].has("probe"))

func surface_for(id: String) -> RefCounted:
	if not site_available(id):
		return null
	if not sites.has(id):
		var context: Dictionary = prospects.surface_context(id)
		sites[id] = Surface.new(int(context.get("seed", Surface.CONFIG.seed)), context)
	return sites[id]

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
		expedition.command("survey", id + "_b")
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
	if action == "deploy" and sites.has(id) and sites[id].state.landed:
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
	return JSON.stringify({"version": 3, "prospects": JSON.parse_string(prospects.save_json()), "expedition": JSON.parse_string(expedition.save_json()),
		"sites": saved_sites, "fractional_hours": fractional_hours, "surface_body": surface_body}, "\t", true, true)

func restore_json(contents: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "Invalid save. Current expedition preserved."}
	var candidate: Dictionary = parser.data
	var version: Variant = candidate.get("version")
	if version not in [1, 2, 3]:
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
	if version == 3:
		if not candidate.get("prospects") is Dictionary:
			return {"ok": false, "message": "Missing prospect evidence."}
		var restored: Dictionary = staged_prospects.restore_json(JSON.stringify(candidate.prospects), now)
		if not restored.ok:
			return restored
	var staged = Simulation.new(staged_prospects.definitions())
	if version == 3:
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
	var staged_sites: Dictionary = {}
	var selected_body: Variant = "eir_iii" if version == 1 else candidate.get("surface_body")
	if not selected_body is String or not staged.state.bodies.has(selected_body):
		return {"ok": false, "message": "Unknown surface region."}
	if version != 1:
		if not candidate.get("sites") is Dictionary:
			return {"ok": false, "message": "Missing surface sites."}
		for id in candidate.sites:
			if not staged.state.bodies.has(id) or not candidate.sites[id] is Dictionary:
				return {"ok": false, "message": "Unknown surface site."}
			var body: Dictionary = staged.state.bodies[id]
			if body.kind != "world" or not body.surveyed or (id != "eir_iii" and not staged_prospects.state.records[body.system].has("probe")):
				return {"ok": false, "message": "Surface site lacks local probe evidence."}
			var context: Dictionary = staged_prospects.surface_context(id)
			var site = Surface.new(int(context.get("seed", Surface.CONFIG.seed)), context)
			var restored: Dictionary = site.restore_json(JSON.stringify(candidate.sites[id]))
			if not restored.ok:
				return restored
			if site.state.total_hours > now or (site.state.landed and body.factory != "") or site.state.seed != int(context.get("seed", Surface.CONFIG.seed)):
				return {"ok": false, "message": "Conflicting site clock, seed or factory allocation."}
			if absf(site.state.get("solar_factor", 1.0) - context.get("solar_factor", 1.0)) > 0.00000001:
				return {"ok": false, "message": "Surface solar context conflicts with its planet."}
			staged_sites[id] = site
	# No live state is replaced until all components validate.
	expedition.scenario = staged.scenario
	expedition.state = staged.state
	prospects = staged_prospects
	sites = staged_sites
	fractional_hours = int(remainder)
	surface_body = selected_body
	return {"ok": true, "message": "Expedition, prospect evidence and surface installations restored."}

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
