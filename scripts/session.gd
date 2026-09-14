extends RefCounted
## Shared expedition and surface clock. Views never own persistent physical state.
const Simulation = preload("res://scripts/simulation.gd")
const Surface = preload("res://scripts/surface_simulation.gd")
const HOURS_PER_YEAR := 8766
const SAVE_PATH := "user://expedition.json"
static var shared: RefCounted

var expedition = Simulation.new()
var sites: Dictionary = {}
var fractional_hours := 0
var surface_body := "eir_iii"
var initialized := false

static func get_shared() -> RefCounted:
	if shared == null:
		shared = load("res://scripts/session.gd").new()
	return shared

func reset() -> void:
	expedition.reset()
	sites.clear()
	fractional_hours = 0
	surface_body = "eir_iii"

func site_available(id: String) -> bool:
	# One authored landing region in this slice, not generic terrain for every body.
	var body: Dictionary = expedition.local_body(id)
	return id == "eir_iii" and not body.is_empty() and body.surveyed and body.factory == ""

func surface_for(id: String) -> RefCounted:
	if not site_available(id):
		return null
	if not sites.has(id):
		sites[id] = Surface.new(1701)
	return sites[id]

func surface_command(action: String, x: int = -1, z: int = -1) -> Dictionary:
	var site = surface_for(surface_body)
	if site == null:
		return {"ok": false, "message": "Surface command needs a surveyed, local landing region without an orbital factory."}
	if action in ["land", "seed"] and expedition.state.ship.modules < 1:
		return {"ok": false, "message": "No factory modules aboard Spaceship."}
	var outcome: Dictionary = site.command(action, x, z)
	if outcome.ok and action in ["land", "seed"]:
		expedition.state.ship.modules -= 1
		expedition.record("Eir III: surface seed module landed. Spatial industry commissioned.", surface_body)
	return outcome

func command(action: String, id: String = "", value: float = 288.0) -> Dictionary:
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
	return JSON.stringify({"version": 2, "expedition": JSON.parse_string(expedition.save_json()),
		"sites": saved_sites, "fractional_hours": fractional_hours, "surface_body": surface_body}, "\t", true, true)

func restore_json(contents: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "Invalid save. Current expedition preserved."}
	var candidate: Dictionary = parser.data
	var staged = Simulation.new()
	var staged_sites: Dictionary = {}
	var hours := 0
	if candidate.get("version") == 1:
		var legacy: Dictionary = staged.restore_json(contents)
		if not legacy.ok:
			return legacy
	elif candidate.get("version") == 2:
		if not candidate.get("expedition") is Dictionary or not candidate.get("sites") is Dictionary:
			return {"ok": false, "message": "Incomplete save. Current expedition preserved."}
		var remainder: Variant = candidate.get("fractional_hours")
		if not (remainder is float or remainder is int) or not is_finite(float(remainder)) or remainder != floor(remainder) or remainder < 0 or remainder >= HOURS_PER_YEAR:
			return {"ok": false, "message": "Invalid save clock. Current expedition preserved."}
		if candidate.get("surface_body") != "eir_iii":
			return {"ok": false, "message": "Unknown surface region. Current expedition preserved."}
		hours = int(remainder)
		var orbital: Dictionary = staged.restore_json(JSON.stringify(candidate.expedition))
		if not orbital.ok:
			return orbital
		for id in candidate.sites:
			if id != "eir_iii" or not candidate.sites[id] is Dictionary:
				return {"ok": false, "message": "Unknown surface site. Current expedition preserved."}
			var site = Surface.new()
			var restored: Dictionary = site.restore_json(JSON.stringify(candidate.sites[id]))
			if not restored.ok:
				return restored
			if not staged.state.bodies[id].surveyed or (site.state.landed and staged.state.bodies[id].factory != ""):
				return {"ok": false, "message": "Conflicting factory allocation. Current expedition preserved."}
			staged_sites[id] = site
	else:
		return {"ok": false, "message": "Unsupported save version. Current expedition preserved."}
	# Commit only after every component validates; preserve the UI's simulation reference.
	expedition.state = staged.state
	sites = staged_sites
	fractional_hours = hours
	surface_body = "eir_iii"
	return {"ok": true, "message": "Expedition and surface installations restored."}

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
