extends SceneTree
const Surface = preload("res://scripts/surface_simulation.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	elif a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not equivalent(a[index], b[index]):
				return false
		return true
	elif (a is float or a is int) and (b is float or b is int):
		# Godot JSON's decimal parser may move a double by one ULP. This bound
		# is far tighter than the model's resolution; integer clocks remain exact.
		return a == b if a is int else absf(a - b) < 0.00000001
	return a == b

func place(site: RefCounted, kind: String) -> Vector2i:
	# Choose the nearest legal cell, not a hardcoded solution map.
	var candidate := Vector2i(-1, -1)
	var best := 1000.0
	for cell in site.state.cells:
		if site.can_place(kind, cell.x, cell.z).ok:
			var distance: float = Vector2(cell.x - 10, cell.z - 10).length()
			if distance < best:
				best = distance
				candidate = Vector2i(cell.x, cell.z)
	check(candidate.x >= 0, "Legal placement available for " + kind)
	if candidate.x >= 0:
		check(site.command(kind, candidate.x, candidate.y).ok, "Place " + kind)
	return candidate

func _initialize() -> void:
	var site = Surface.new()
	check(site.state.cells.size() == 400, "Bounded terrain")
	check(site.save_json() == Surface.new().save_json(), "Identical seeds produce identical state")
	check(site.save_json() != Surface.new(1702).save_json(), "Different seed changes terrain")
	var before: String = site.save_json()
	check(not site.command("mine", 10, 10).ok, "Construction requires module")
	check(site.save_json() == before, "Rejected order conserves state")
	check(site.command("land", 10, 10).ok, "Land on surveyed centre")
	check(not site.command("land", 11, 10).ok, "One landed module per site")
	check(not site.command("solar", 0, 0).ok, "Unsurveyed and disconnected placement denied")
	check(site.command("survey", 0, 0).ok, "Survey is available")
	check(site.cell_at(0, 0).scanned, "Survey updates ground knowledge")
	check(not site.can_place("solar", 0, 0).ok, "Survey does not create a service connection")
	var constrained = Surface.new()
	constrained.command("land", 10, 10)
	var blocked_refinery: Vector2i = place(constrained, "refinery")
	constrained.advance(20)
	var blocked_fabricator: Vector2i = place(constrained, "fabricator")
	constrained.advance(20)
	constrained.state.resources.ore = 20.0
	constrained.summary()
	check(not constrained.structure_at(blocked_fabricator.x, blocked_fabricator.y).powered, "Insufficient power sheds later loads")
	var components_before: float = constrained.state.resources.components
	constrained.advance(30)
	check(constrained.state.resources.components == components_before, "Unpowered fabricator cannot create goods")
	check(constrained.command("toggle", blocked_refinery.x, blocked_refinery.y).ok, "Suspend an operating load")
	constrained.advance(20)
	check(constrained.state.resources.components > components_before, "Freed power enables fabrication")
	for kind in ["solar", "solar", "solar", "mine", "ice_well", "refinery", "fabricator", "refuge"]:
		place(site, kind)
		site.advance(22)
	check(site.summary().power_supply >= site.summary().power_demand, "Built network can support its loads")
	site.advance(120)
	check(site.state.milestone, "Production supports an enclosed pioneer refuge")
	check(site.state.resources.biomass > 0.5, "Culture has actually grown")
	var extractors := 0
	for structure in site.state.structures:
		if structure.kind in ["mine", "ice_well"]:
			extractors += 1
			var cell: Dictionary = site.cell_at(structure.x, structure.z)
			check(absf(cell.initial - cell.remaining - structure.produced) < 0.00001, "Extraction conserves finite deposit " + structure.kind)
		if structure.kind in ["refinery", "fabricator"]:
			check(structure.produced > 0, "Real batches completed: " + structure.kind)
	check(extractors == 2, "Both extraction processes tested")
	var save: String = site.save_json()
	var restored = Surface.new()
	check(restored.restore_json(save).ok, "Valid surface save restored")
	check(equivalent(site.state, restored.state), "Surface save roundtrip within 1e-8 numeric tolerance")
	var restored_save: String = restored.save_json()
	var malformed: Dictionary = JSON.parse_string(save)
	malformed.resources.metal = -1
	check(not restored.restore_json(JSON.stringify(malformed)).ok, "Negative inventory rejected")
	check(restored.save_json() == restored_save, "Invalid load preserves previous state exactly")
	malformed = JSON.parse_string(save)
	malformed.structures[1].x = malformed.structures[0].x
	malformed.structures[1].z = malformed.structures[0].z
	check(not restored.restore_json(JSON.stringify(malformed)).ok, "Overlapping structures rejected")
	var bulk = Surface.new()
	bulk.restore_json(save)
	bulk.advance(1000)
	site.advance(1000)
	for hour in range(1000):
		restored.advance(1)
	for resource in site.state.resources:
		check(absf(bulk.state.resources[resource] - restored.state.resources[resource]) < 0.000001, "Chunk-independent " + resource)
		check(absf(site.state.resources[resource] - restored.state.resources[resource]) < 0.000001, "Save/load preserves future " + resource)
	check(bulk.state.total_hours == restored.state.total_hours, "Chunk-independent site clock")
	bulk.advance(68 * 8766)
	check(bulk.state.total_hours == site.state.total_hours + 68 * 8766, "Interstellar interval is not silently capped")
	check(bulk.state.resources.biomass == 0, "Finite life-support stores cannot sustain culture forever")
	var session = Session.new()
	check(session.surface_for("eir_iii") == null, "Surface requires local orbital survey")
	check(session.command("survey", "eir_iii").ok, "Session survey")
	var local = session.surface_for("eir_iii")
	var modules: int = session.expedition.state.ship.modules
	check(session.surface_command("land", 10, 10).ok, "Integrated module landing")
	check(session.expedition.state.ship.modules == modules - 1, "Exactly one ship module consumed")
	check(not session.surface_command("land", 11, 10).ok, "Duplicate landing rejected")
	check(session.expedition.state.ship.modules == modules - 1, "Rejected landing consumes no module")
	check(not session.command("deploy", "eir_iii").ok, "Legacy factory cannot duplicate a spatial module")
	session.advance_hours(8765)
	check(session.expedition.state.year == 2400 and session.fractional_hours == 8765, "Subannual clock preserved")
	session.advance_hours(1)
	check(session.expedition.state.year == 2401 and session.fractional_hours == 0, "Exactly one orbital year elapsed")
	var before_hours: int = local.state.total_hours
	check(session.command("travel").ok, "Integrated interstellar departure")
	check(local.state.total_hours == before_hours + 68 * 8766, "Surface site evolves during travel")
	check(session.surface_for("eir_iii") == null, "Remote site inaccessible to direct control")
	check(not session.surface_command("survey", 0, 0).ok, "Remote command rejected")
	var full_save: String = session.save_json()
	var session_copy = Session.new()
	check(session_copy.restore_json(full_save).ok, "Complete expedition plus site restored")
	check(equivalent(JSON.parse_string(session_copy.save_json()), JSON.parse_string(full_save)), "Complete save roundtrip")
	var before_bad_load: String = session_copy.save_json()
	check(not session_copy.restore_json("{bad json").ok, "Malformed save rejected without engine error")
	check(session_copy.save_json() == before_bad_load, "Malformed save is exactly atomic")
	check(session_copy.restore_json(session.expedition.save_json()).ok and session_copy.sites.is_empty(), "Old version-one expedition saves migrate")
	check(session.command("travel").ok and session.surface_for("eir_iii") != null, "Return reacquires the same site")
	check(session.surface_for("eir_iii").state.landed, "Module persists on return")
	print("Surface and session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
