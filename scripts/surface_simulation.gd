extends RefCounted
## Surface industry V1. Authoritative logical hours; no scene-tree dependencies.
## Cell distance is 4 m. Inventories are deliberately abstract tonnes, electrical
## loads are kW, and construction hours represent accelerated robotic assembly.
## Solar uses site mean exposure, not instantaneous weather/day-night simulation.
## Logistics is a shared transport service: delivered throughput falls with the
## shortest connected route. No free transport across disconnected installations.
## Long advances execute the same hourly rules, then skip provably stationary
## intervals / linear refuge-only maintenance to the next physical threshold.

const SIZE := 20
const CELL_SIZE := 4.0
const Testbed = preload("res://scripts/testbed_simulation.gd")
const SAVE_VERSION := 1
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface.json"))
static var LINK_RANGE: float = CONFIG.link_range_cells
static var STORAGE: Dictionary = CONFIG.storage
static var RECIPES: Dictionary = CONFIG.recipes

var state: Dictionary
var environment: Dictionary = {}
var _network_dirty := true

func _init(seed: int = 1701, context: Dictionary = {}) -> void:
	reset(seed, context)

func reset(seed: int = 1701, context: Dictionary = {}) -> void:
	environment = context.get("environment", {}).duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	state = {"version": SAVE_VERSION, "seed": seed, "total_hours": 0,
		"landed": false, "next_id": 1,
		"resources": CONFIG.starting_resources.duplicate(true),
		"cells": [], "structures": [], "events": [], "milestone": false}
	if not context.is_empty():
		state.solar_factor = float(context.get("solar_factor", 1.0))
	var phase: float = rng.randf_range(-3.0, 3.0)
	var ore_center := Vector2(rng.randi_range(5, 8), rng.randi_range(7, 11))
	var ice_center := Vector2(rng.randi_range(12, 15), rng.randi_range(8, 12))
	for z in range(SIZE):
		for x in range(SIZE):
			var p := Vector2(x, z)
			var elevation: float = 1.3 + sin(x * 0.38 + phase) * 0.6 + cos(z * 0.43 - phase) * 0.5 + rng.randf_range(-0.25, 0.25)
			var resource := ""
			if p.distance_to(ore_center) < 2.2 or rng.randf() < 0.035:
				resource = "metal"
			if p.distance_to(ice_center) < 2.2 or rng.randf() < 0.035:
				resource = "ice"
			var remaining: float = rng.randf_range(100.0, 280.0) if resource != "" else 0.0
			if resource != "":
				remaining *= context.get("ore_factor" if resource == "metal" else "ice_factor", 1.0)
			state.cells.append({"x": x, "z": z, "height": elevation,
				"resource": resource, "remaining": remaining, "initial": remaining,
				"scanned": p.distance_to(Vector2(10, 10)) <= 4.5,
				"buildable": p.distance_to(Vector2(10, 10)) < 7.0 or rng.randf() > 0.18,
				"light": clampf(0.78 + 0.12 * sin(x * 0.25 + phase) - elevation * 0.04, 0.4, 1.0)})
	_network_dirty = true
	_record("Orbital landing survey available. Choose a seed-module site; local surveys cost no material.")

func cell_at(x: int, z: int) -> Dictionary:
	if x < 0 or z < 0 or x >= SIZE or z >= SIZE:
		return {}
	return state.cells[z * SIZE + x]

func structure_at(x: int, z: int) -> Dictionary:
	for structure in state.structures:
		if structure.x == x and structure.z == z:
			return structure
	return {}

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func _record(message: String) -> void:
	state.events.append({"hour": state.total_hours, "text": message})
	if state.events.size() > 120:
		state.events.pop_front()

func can_place(kind: String, x: int, z: int) -> Dictionary:
	var cell := cell_at(x, z)
	if kind == "land":
		kind = "seed"
	if not RECIPES.has(kind):
		return _result(false, "Unknown construction plan.")
	if kind == "testbed" and environment.is_empty():
		return _result(false, "Testbeds require a local environmental probe on a generated prospect.")
	if cell.is_empty():
		return _result(false, "Select a cell in the landing sector.")
	if not cell.scanned:
		return _result(false, "Survey this ground before construction.")
	if not cell.buildable:
		return _result(false, "Terrain is too unstable for this foundation.")
	if not structure_at(x, z).is_empty():
		return _result(false, "This cell already contains an installation.")
	if kind == "seed":
		return _result(not state.landed, "Landing site ready." if not state.landed else "One seed module is already deployed in this sector.")
	if not state.landed:
		return _result(false, "Land the seed module first.")
	if kind == "mine" and (cell.resource != "metal" or cell.remaining <= 0.0):
		return _result(false, "An ore extractor needs a surveyed, unexhausted metal deposit.")
	if kind == "ice_well" and (cell.resource != "ice" or cell.remaining <= 0.0):
		return _result(false, "An ice well needs a surveyed, unexhausted ice deposit.")
	_refresh_network()
	var near_network := false
	for structure in state.structures:
		if structure.connected and structure.enabled and structure.progress >= 1.0 and _distance(structure, cell) <= LINK_RANGE:
			near_network = true
			break
	if not near_network:
		return _result(false, "Beyond the %.0f m service link. Expand from a completed, connected installation." % (LINK_RANGE * CELL_SIZE))
	var cost: Dictionary = RECIPES[kind].cost
	for resource in cost:
		if state.resources[resource] + 0.0000001 < cost[resource]:
			return _result(false, "Requires %.0f %s; %.1f available." % [cost[resource], resource, state.resources[resource]])
	return _result(true, "Site ready. Construction consumes materials immediately.")

func command(action: String, x: int = -1, z: int = -1) -> Dictionary:
	if action == "survey":
		if cell_at(x, z).is_empty():
			return _result(false, "Select a location to survey.")
		var revealed := 0
		for cell in state.cells:
			if Vector2(cell.x - x, cell.z - z).length() <= 4.5 and not cell.scanned:
				cell.scanned = true
				revealed += 1
		_record("Survey at %d:%d mapped %d new terrain cells." % [x, z, revealed])
		return _result(true, "Survey complete: %d new cells." % revealed)
	if action == "toggle":
		var existing := structure_at(x, z)
		if existing.is_empty() or existing.kind == "seed":
			return _result(false, "Select an installation. The seed service hub stays online.")
		existing.enabled = not existing.enabled
		_network_dirty = true
		_refresh_network()
		_record("%s %s." % [RECIPES[existing.kind].label, "enabled" if existing.enabled else "disabled"])
		return _result(true, "Operating policy updated.")
	var kind: String = "seed" if action == "land" else action
	var allowed := can_place(kind, x, z)
	if not allowed.ok:
		return allowed
	for resource in RECIPES[kind].cost:
		state.resources[resource] -= RECIPES[kind].cost[resource]
	var queue: Array = []
	if kind == "refinery":
		queue = ["4 ore → 2 metal"]
	elif kind == "fabricator":
		queue = ["3 metal → 1 component"]
	state.structures.append({"id": state.next_id, "kind": kind, "x": x, "z": z,
		"progress": 1.0 if kind == "seed" else 0.0, "enabled": true,
		"status": "Service hub" if kind == "seed" else "Constructing",
		"connected": false, "powered": false, "efficiency": 0.0, "path_distance": 0.0,
		"cycle": 0.0, "job_active": false, "queue": queue, "culture": 0.0,
		"produced": 0.0})
	if kind == "testbed":
		state.structures[-1].trial = Testbed.create(environment)
	state.next_id += 1
	if kind == "seed":
		state.landed = true
		for cell in state.cells:
			if Vector2(cell.x - x, cell.z - z).length() <= 5.5:
				cell.scanned = true
	_network_dirty = true
	_refresh_network()
	_record("%s %s at %d:%d." % [RECIPES[kind].label, "landed" if kind == "seed" else "commissioned", x, z])
	return _result(true, "Seed module landed." if kind == "seed" else "Construction queued: " + RECIPES[kind].label)

func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _refresh_network() -> void:
	if not _network_dirty:
		return
	_network_dirty = false
	for structure in state.structures:
		structure.connected = structure.kind == "seed"
		structure.path_distance = 0.0 if structure.connected else 1000000.0
		structure.efficiency = 1.0 if structure.connected else 0.0
	# Shortest routes through completed, enabled relays; power and hauling share
	# this graph. A pending foundation may receive service but cannot relay it.
	for _iteration in range(state.structures.size()):
		var changed := false
		for source in state.structures:
			if not source.connected or not source.enabled or source.progress < 1.0:
				continue
			for destination in state.structures:
				var distance: float = _distance(source, destination)
				var route: float = source.path_distance + distance
				if distance <= LINK_RANGE and route + 0.000001 < destination.path_distance:
					destination.connected = true
					destination.path_distance = route
					destination.efficiency = 1.0 / (1.0 + route / 12.0)
					changed = true
		if not changed:
			break
	_allocate_power()

func _allocate_power() -> Dictionary:
	var supply := 0.0
	var demand := 0.0
	for structure in state.structures:
		if not structure.enabled or not structure.connected or structure.progress < 1.0:
			continue
		if structure.kind == "seed":
			supply += RECIPES.seed.supply
		elif structure.kind == "solar":
			supply += RECIPES.solar.supply * cell_at(structure.x, structure.z).light * state.get("solar_factor", 1.0)
	var available: float = supply
	for structure in state.structures:
		structure.powered = false
		if not structure.enabled:
			structure.status = "Disabled"
			continue
		if not structure.connected:
			structure.status = "No service link"
			continue
		var load: float = 0.75 if structure.progress < 1.0 else RECIPES[structure.kind].power
		if structure.kind == "testbed" and structure.progress >= 1.0:
			load = Testbed.load_kw(structure.trial)
		demand += load
		if load <= available + 0.000001:
			structure.powered = true
			available -= load
		else:
			structure.status = "Power deficit"
	return {"power_supply": supply, "power_demand": demand}

func advance(hours: int) -> void:
	if hours <= 0:
		return
	var remaining: int = hours
	while remaining > 0:
		_refresh_network()
		_allocate_power()
		var jump: int = _maintenance_jump(remaining)
		if jump > 1:
			remaining -= jump
			continue
		state.total_hours += 1
		var changed: bool = _step_hour()
		remaining -= 1
		if not changed and not _network_dirty:
			# No clocks/weather/random events advance independently in this model;
			# an unchanged hour proves the entire remaining interval is stationary.
			for structure in state.structures:
				if structure.kind == "testbed" and structure.progress >= 1.0:
					Testbed.stationary_samples(structure.trial, state.total_hours, state.total_hours + remaining)
			state.total_hours += remaining
			break

func _step_hour() -> bool:
	var changed := false
	var biomass := 0.0
	for structure in state.structures:
		# Heat exchange, phase changes and biology continue without power.
		if structure.kind == "testbed" and structure.progress >= 1.0:
			var established: bool = structure.trial.established
			if Testbed.step(structure.trial, environment, cell_at(structure.x, structure.z).light, state.resources, structure.powered):
				changed = true
			Testbed.sample(structure.trial, state.total_hours)
			structure.status = "Trial running" if structure.trial.operating else "Passive trial · power or service parts unavailable"
			if not established and structure.trial.established:
				_record("FIELD TRIAL: archive culture sustained for seven days. This is evidence for an enclosed pilot, not an exposed biosphere.")
			continue
		if not structure.powered:
			if structure.culture > 0.0:
				structure.culture = maxf(0.0, structure.culture - 1.0 / 48.0)
				changed = true
			biomass += structure.culture
			continue
		if structure.progress < 1.0:
			structure.progress = minf(1.0, structure.progress + structure.efficiency / RECIPES[structure.kind].hours)
			structure.status = "Constructing"
			changed = true
			if structure.progress >= 1.0:
				_network_dirty = true
				_record("%s construction complete." % RECIPES[structure.kind].label)
			continue
		match structure.kind:
			"seed":
				structure.status = "Service hub · %.1f kW" % RECIPES.seed.supply
			"solar":
				structure.status = "Generating %.1f kW" % (RECIPES.solar.supply * cell_at(structure.x, structure.z).light * state.get("solar_factor", 1.0))
			"mine", "ice_well":
				var cell := cell_at(structure.x, structure.z)
				var output: String = "ore" if structure.kind == "mine" else "water"
				var extracted: float = minf(minf(4.0 * structure.efficiency, cell.remaining), maxf(0.0, STORAGE[output] - state.resources[output]))
				if extracted > 0.0000001:
					cell.remaining = maxf(0.0, cell.remaining - extracted)
					state.resources[output] += extracted
					structure.produced += extracted
					structure.status = "Extracting %.1f t/h" % extracted
					changed = true
					if cell.remaining <= 0.0000001:
						_record("%s at %d:%d exhausted its accessible deposit." % [RECIPES[structure.kind].label, structure.x, structure.z])
				else:
					structure.status = "Deposit exhausted" if cell.remaining <= 0.0000001 else "Storage full"
			"refinery", "fabricator":
				if _step_batch(structure):
					changed = true
			"refuge":
				if state.resources.water >= 0.02 and state.resources.components >= 0.002:
					state.resources.water -= 0.02
					state.resources.components -= 0.002
					structure.culture = minf(1.0, structure.culture + 1.0 / 96.0)
					structure.status = "Pioneer culture stable" if structure.culture >= 1.0 else "Establishing pioneer culture"
					changed = true
					if structure.culture >= 1.0 and not state.milestone:
						state.milestone = true
						_record("Pioneer refuge established. Life is viable inside this maintained enclosure; the planet remains hostile.")
				else:
					structure.status = "Life support starved"
					if structure.culture > 0.0:
						structure.culture = maxf(0.0, structure.culture - 1.0 / 48.0)
						changed = true
		biomass += structure.culture
	state.resources.biomass = biomass
	return changed

func _step_batch(structure: Dictionary) -> bool:
	var refining: bool = structure.kind == "refinery"
	var input: String = "ore" if refining else "metal"
	var output: String = "metal" if refining else "components"
	var required: float = 4.0 if refining else 3.0
	var quantity: float = 2.0 if refining else 1.0
	var duration: float = 2.0 if refining else 3.0
	if not structure.job_active:
		if state.resources[output] > STORAGE[output] - quantity:
			structure.status = "Output storage full"
			return false
		if state.resources[input] + 0.0000001 < required:
			structure.status = "Waiting for " + input
			return false
		state.resources[input] = maxf(0.0, state.resources[input] - required)
		structure.job_active = true
		structure.cycle = 0.0
	structure.cycle = minf(1.0, structure.cycle + structure.efficiency / duration)
	structure.status = "%s batch · %d%%" % ["Refining" if refining else "Fabricating", int(structure.cycle * 100.0)]
	if structure.cycle >= 1.0:
		# Output may exceed its soft target by other concurrently completed batches;
		# these remain real stored goods, never lost or manufactured twice.
		state.resources[output] += quantity
		structure.produced += quantity
		structure.job_active = false
		structure.cycle = 0.0
	return true

func _maintenance_jump(limit: int) -> int:
	# Exact affine event step, with floating-point roundoff bounded by ~1e-8 t
	# for century intervals. Only applicable after all industry has stopped; a
	# pending/buffered production job or mine that could wake up forbids skipping.
	if limit < 2:
		return 0
	var consumers: Array = []
	for structure in state.structures:
		if structure.kind == "testbed":
			return 0
		if structure.culture > 0.0 and (not structure.powered or structure.culture < 1.0):
			return 0
		if not structure.powered:
			continue
		if structure.progress < 1.0:
			return 0
		if structure.kind in ["mine", "ice_well"] and cell_at(structure.x, structure.z).remaining > 0.0000001:
			return 0
		if structure.kind in ["refinery", "fabricator"]:
			var input: String = "ore" if structure.kind == "refinery" else "metal"
			var required: float = 4.0 if structure.kind == "refinery" else 3.0
			if structure.job_active or state.resources[input] >= required:
				return 0
		if structure.kind == "refuge":
			if structure.culture < 1.0:
				return 0
			consumers.append(structure)
	if consumers.is_empty():
		return 0
	var count: int = consumers.size()
	# Stop one hour before a resource boundary, leaving arbitration to hourly rules.
	var count_hours: int = mini(limit, mini(int(floor(state.resources.water / (0.02 * count))), int(floor(state.resources.components / (0.002 * count)))) - 1)
	if count_hours < 2:
		return 0
	state.resources.water -= count_hours * count * 0.02
	state.resources.components -= count_hours * count * 0.002
	state.total_hours += count_hours
	for structure in consumers:
		structure.status = "Pioneer culture stable"
	return count_hours

func summary() -> Dictionary:
	_refresh_network()
	var output := _allocate_power()
	var connected := 0
	var refuge_progress := 0.0
	var trials := 0
	var established_trials := 0
	var trial_biomass_g := 0.0
	for structure in state.structures:
		if structure.connected:
			connected += 1
		refuge_progress = maxf(refuge_progress, structure.culture)
		if structure.kind == "testbed":
			trials += 1
			established_trials += 1 if structure.trial.established else 0
			trial_biomass_g += structure.trial.biomass_kg * 1000.0
	output.merge({"connected_count": connected, "refuge_progress": refuge_progress,
		"trials": trials, "established_trials": established_trials, "trial_biomass_g": trial_biomass_g,
		"landed": state.landed, "total_hours": state.total_hours,
		"completed": state.milestone, "link_range_m": LINK_RANGE * CELL_SIZE})
	return output

func save_json() -> String:
	_refresh_network()
	return JSON.stringify(state, "\t", true, true)

func restore_json(contents: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary or not _valid_save(parser.data):
		return _result(false, "Invalid or incompatible surface save. Current site preserved.")
	state = parser.data.duplicate(true)
	state.version = int(state.version)
	state.seed = int(state.seed)
	state.total_hours = int(state.total_hours)
	state.next_id = int(state.next_id)
	for cell in state.cells:
		cell.x = int(cell.x)
		cell.z = int(cell.z)
	for structure in state.structures:
		structure.id = int(structure.id)
		structure.x = int(structure.x)
		structure.z = int(structure.z)
	for event in state.events:
		event.hour = int(event.hour)
	_network_dirty = true
	_refresh_network()
	return _result(true, "Surface installation restored.")

func _number(value: Variant, low: float, high: float = 1000000000.0) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

func _integer(value: Variant, low: int, high: int = 1000000000) -> bool:
	return _number(value, low, high) and value == floor(value)

func _valid_save(candidate: Dictionary) -> bool:
	if candidate.has("solar_factor") and not _number(candidate.solar_factor, 0.0, 1.8):
		return false
	for key in ["version", "seed", "total_hours", "next_id", "landed", "resources", "cells", "structures", "events", "milestone"]:
		if not candidate.has(key):
			return false
	if candidate.version != SAVE_VERSION or not _integer(candidate.seed, -1000000000) or not _integer(candidate.total_hours, 0) or not _integer(candidate.next_id, 1):
		return false
	if not candidate.landed is bool or not candidate.milestone is bool or not candidate.resources is Dictionary or not candidate.cells is Array or not candidate.structures is Array or not candidate.events is Array:
		return false
	if candidate.cells.size() != SIZE * SIZE or candidate.structures.size() > SIZE * SIZE or candidate.events.size() > 120:
		return false
	for resource in ["ore", "metal", "water", "components", "biomass"]:
		if not candidate.resources.has(resource) or not _number(candidate.resources[resource], 0.0):
			return false
	for index in range(SIZE * SIZE):
		var cell: Variant = candidate.cells[index]
		if not cell is Dictionary:
			return false
		for key in ["x", "z", "height", "resource", "remaining", "initial", "scanned", "buildable", "light"]:
			if not cell.has(key):
				return false
		if cell.x != index % SIZE or cell.z != index / SIZE or not _number(cell.height, -100.0, 100.0) or cell.resource not in ["", "metal", "ice"]:
			return false
		if not _number(cell.initial, 0.0) or not _number(cell.remaining, 0.0, cell.initial) or not cell.scanned is bool or not cell.buildable is bool or not _number(cell.light, 0.0, 1.0):
			return false
		if cell.resource == "" and cell.remaining != 0.0:
			return false
	var occupied: Dictionary = {}
	var ids: Dictionary = {}
	var seeds := 0
	var biomass := 0.0
	for structure in candidate.structures:
		if not structure is Dictionary:
			return false
		for key in ["id", "kind", "x", "z", "progress", "enabled", "status", "connected", "powered", "efficiency", "path_distance", "cycle", "job_active", "queue", "culture", "produced"]:
			if not structure.has(key):
				return false
		if not _integer(structure.id, 1, int(candidate.next_id) - 1) or ids.has(structure.id) or not _integer(structure.x, 0, SIZE - 1) or not _integer(structure.z, 0, SIZE - 1):
			return false
		var index: int = int(structure.z) * SIZE + int(structure.x)
		if occupied.has(index) or not structure.kind is String or not RECIPES.has(structure.kind) or not candidate.cells[index].buildable or not candidate.cells[index].scanned:
			return false
		if not structure.enabled is bool or not structure.connected is bool or not structure.powered is bool or not structure.status is String or not structure.job_active is bool or not structure.queue is Array:
			return false
		for key in ["progress", "efficiency", "cycle", "culture"]:
			if not _number(structure[key], 0.0, 1.0):
				return false
		if not _number(structure.path_distance, 0.0) or not _number(structure.produced, 0.0):
			return false
		if structure.kind == "seed":
			seeds += 1
			if structure.progress != 1.0 or not structure.enabled:
				return false
		if structure.kind == "mine" and candidate.cells[index].resource != "metal":
			return false
		if structure.kind == "ice_well" and candidate.cells[index].resource != "ice":
			return false
		if structure.kind == "testbed" and (environment.is_empty() or not Testbed.valid(structure.get("trial"), int(candidate.total_hours))):
			return false
		if structure.kind != "refuge" and structure.culture != 0.0:
			return false
		if structure.kind not in ["refinery", "fabricator"] and (structure.job_active or structure.cycle != 0.0):
			return false
		ids[structure.id] = true
		occupied[index] = true
		biomass += structure.culture
	if seeds != (1 if candidate.landed else 0) or (not candidate.landed and not candidate.structures.is_empty()) or absf(biomass - candidate.resources.biomass) > 0.000001:
		return false
	for event in candidate.events:
		if not event is Dictionary or not event.has("hour") or not event.has("text") or not _integer(event.hour, 0, int(candidate.total_hours)) or not event.text is String:
			return false
	return true

func testbed_at(id: int) -> Dictionary:
	for structure in state.structures:
		if structure.kind == "testbed" and structure.id == id:
			return structure
	return {}

func trial_command(id: int, action: String, value: Variant = null) -> Dictionary:
	var structure := testbed_at(id)
	if structure.is_empty() or structure.progress < 1.0:
		return _result(false, "Complete a testbed on the service network first.")
	var trial: Dictionary = structure.trial
	match action:
		"thermal":
			if not value is String or value not in ["passive", "heat", "cool", "auto"]: return _result(false, "Unsupported thermal mode.")
			trial.thermal = value
		"target_k", "target_bar", "shade":
			var bounds: Array = {"target_k": [278.0, 310.0], "target_bar": [0.05, 1.0], "shade": [0.0, 0.95]}[action]
			if not _number(value, bounds[0], bounds[1]): return _result(false, "Control value outside equipment limits.")
			trial[action] = float(value)
		"pressure_control", "feed_water", "lamp":
			if not value is bool: return _result(false, "Control needs an on/off value.")
			trial[action] = value
		"filter", "canopy":
			if trial[action] or trial.upgrade != "": return _result(false, "Upgrade already fitted or another installation is underway.")
			var cost: Dictionary = Testbed.CONFIG.upgrades[action].cost
			for resource in cost:
				if state.resources[resource] < cost[resource]: return _result(false, "Upgrade needs %.1f %s." % [cost[resource], resource])
			for resource in cost: state.resources[resource] -= cost[resource]
			trial.upgrade = action
			trial.upgrade_progress = 0.0
		"inoculate":
			return _result(false, "Inoculation must allocate a ship archive through the expedition.")
		_:
			return _result(false, "Unknown testbed command.")
	_allocate_power()
	_record("Testbed %d: %s revised." % [id, action.replace("_", " ")])
	return _result(true, "Trial order accepted. Physical conditions respond over time.")
