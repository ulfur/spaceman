extends SceneTree
const Session = preload("res://scripts/session.gd")
const Prospects = preload("res://scripts/prospects.gd")
const Surface = preload("res://scripts/surface_simulation.gd")
const Simulation = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var session = Session.new()
	var catalogue = session.prospects
	check(catalogue.worlds.size() == 6, "Six generated prospects")
	check(session.expedition.scenario.systems.size() == 8, "Generated and reference systems coexist")
	check(catalogue.worlds == Prospects.new(1701).worlds, "Seed reproduces true worlds")
	check(catalogue.worlds != Prospects.new(1702).worlds, "Different seed changes opportunities")
	for id in catalogue.worlds:
		var truth: Dictionary = catalogue.worlds[id]
		check(absf(truth.flux - truth.luminosity / pow(truth.orbit_au, 2)) < 0.000001, "Inverse-square irradiation " + id)
		check(absf(truth.gravity - truth.mass / pow(truth.radius, 2)) < 0.000001, "Mass-radius-gravity consistency " + id)
		var evidence: Dictionary = catalogue.evidence(id)
		check(not evidence.has("flux_low") and not evidence.has("pressure") and not evidence.has("ice_factor") and not evidence.has("field_earth") and not evidence.has("co2_fraction") and not evidence.has("ambient_k"), "Catalogue cannot leak unmeasured planet " + id)
		check(not session.expedition.state.observations.has(id + "_b"), "No distant ground truth in orbital observations " + id)
	var target := "prospect_0"
	var truth_before: Dictionary = catalogue.worlds.duplicate(true)
	var before: String = session.save_json()
	check(not session.observe(target, "probe").ok, "Cannot probe remotely")
	check(not session.observe(target, "spectrum").ok, "Spectrum requires an orbit fit")
	check(session.save_json() == before, "Rejected observations are atomic")
	session.command("survey", "eir_iii")
	session.surface_for("eir_iii")
	session.surface_command("land", 10, 10)
	var fuel: float = session.expedition.state.ship.fuel
	check(session.observe(target, "photometry").ok, "Distant photometry succeeds")
	check(is_equal_approx(session.expedition.state.ship.fuel, fuel - 0.25), "Observation consumes its quoted fuel")
	check(session.fractional_hours == 36 and session.sites.eir_iii.state.total_hours == 36, "Instrument time advances existing industry")
	var known: Dictionary = catalogue.evidence(target)
	check(known.has("flux_low") and not known.has("ice_factor"), "Orbit fit reveals exposure but not deposits")
	check(known.flux_low <= catalogue.worlds[target].flux and known.flux_high >= catalogue.worlds[target].flux, "Stated illumination bounds contain model truth")
	check(known.records.photometry.source_hour < known.records.photometry.received_hour, "Distant observation has a light-travel lookback")
	before = session.save_json()
	check(not session.observe(target, "photometry").ok and session.save_json() == before, "Repeated programme neither rerolls nor charges again")
	check(session.observe(target, "spectrum").ok and session.observe(target, "monitor").ok, "Complementary programmes succeed")
	known = catalogue.evidence(target)
	check(known.has("spectrum_hint") and known.has("activity_band") and not known.has("field_earth"), "Stellar monitoring is not a remote magnetometer")
	check(catalogue.worlds == truth_before, "Observation never rerolls physical truth")
	var quote: Dictionary = session.expedition.travel_quote(target)
	var expected_year: int = session.expedition.state.year + quote.years
	var hour_before: int = session.sites.eir_iii.state.total_hours
	fuel = session.expedition.state.ship.fuel
	check(session.command("travel", target).ok, "Travel to a chosen generated system")
	check(session.expedition.state.system == target and session.expedition.state.year == expected_year, "Arrival and clock match quote")
	check(absf(session.expedition.state.ship.fuel - (fuel - quote.fuel_cost)) < 0.000001, "Route charge matches quote")
	check(session.sites.eir_iii.state.total_hours == hour_before + quote.years * 8766, "Home industry evolves through new routes")
	check(not session.site_available(target + "_b"), "Arrival alone cannot open unsurveyed terrain")
	check(session.observe(target, "probe").ok, "Local probe resolves the region")
	known = catalogue.evidence(target)
	check(known.has("pressure") and known.has("field_earth") and known.has("ice_factor"), "Probe reveals local physical evidence")
	check(known.flux_high - known.flux_low < truth_before[target].flux * 0.1, "Local probe narrows distant exposure bounds")
	check(session.site_available(target + "_b"), "Probed generated region is playable")
	session.surface_body = target + "_b"
	var region = session.surface_for(session.surface_body)
	check(absf(region.state.solar_factor - minf(1.8, catalogue.worlds[target].flux)) < 0.000001, "Planet controls actual solar output")
	check(session.surface_command("land", 10, 10).ok, "Land second scarce module on prospect")
	check(session.expedition.state.ship.modules == 0, "Modules cannot be duplicated across worlds")
	check(not session.command("deploy", target + "_b").ok and not session.command("seed", target + "_b").ok, "Legacy climate shortcut cannot establish prospect habitability")
	var saved: String = session.save_json()
	var restored = Session.new()
	var restore_result: Dictionary = restored.restore_json(saved)
	check(restore_result.ok, "Version-three expedition restores in a generated system: " + restore_result.message)
	check(restored.prospects.state == catalogue.state, "Evidence and epochs survive save/load")
	check(restored.prospects.worlds == catalogue.worlds, "Saved seed reconstructs identical worlds")
	check(restored.sites.size() == 2 and restored.sites[target + "_b"].state.landed, "Both industrial sites persist")
	before = restored.save_json()
	var malformed: Dictionary = JSON.parse_string(saved)
	malformed.prospects.records[target].probe.source_hour = malformed.prospects.records[target].probe.received_hour + 1
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == before, "Future evidence rejected atomically")
	malformed = JSON.parse_string(saved)
	malformed.sites[target + "_b"].solar_factor = 1.799
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == before, "Solar context cannot detach from its world")
	var archived: Dictionary = catalogue.state.records[target].duplicate(true)
	check(session.command("travel", "eir").ok, "Return from generated system using actual distance")
	check(session.prospects.state.records[target] == archived, "Remote evidence remains dated, not live")
	check(not session.site_available(target + "_b"), "Remote installations are not directly controllable")
	var legacy = Simulation.new()
	legacy.command("survey", "eir_iii")
	legacy.command("deploy", "eir_iii")
	legacy.advance(12)
	var old_v2 := {"version": 2, "expedition": JSON.parse_string(legacy.save_json()), "sites": {}, "fractional_hours": 12, "surface_body": "eir_iii"}
	var migration: Dictionary = restored.restore_json(JSON.stringify(old_v2))
	check(migration.ok, "First Foothold version-two save migrates: " + migration.message)
	check(restored.expedition.state.year == 2412 and restored.fractional_hours == 12 and restored.expedition.state.bodies.eir_iii.factory == "warming", "Migration preserves established progress")
	check(restored.expedition.state.bodies.size() == 15, "Migration adds unobserved prospects without removing old bodies")
	check(restored.restore_json(legacy.save_json()).ok, "Original version-one save migrates")
	var old_orbit = Simulation.new()
	old_orbit.command("survey", "eir_iii")
	old_orbit.state.ship.modules -= 1
	var old_site = Surface.new()
	old_site.command("land", 10, 10)
	old_site.command("solar", 11, 10)
	old_site.advance(25)
	old_v2 = {"version": 2, "expedition": JSON.parse_string(old_orbit.save_json()), "sites": {"eir_iii": JSON.parse_string(old_site.save_json())}, "fractional_hours": 25, "surface_body": "eir_iii"}
	migration = restored.restore_json(JSON.stringify(old_v2))
	check(migration.ok, "Version-two settlement migrates: " + migration.message)
	check(restored.sites.has("eir_iii") and restored.sites.eir_iii.state.total_hours == 25 and restored.sites.eir_iii.state.structures.size() == 2 and restored.expedition.state.ship.modules == 1, "Migration preserves settlement, clock and allocated module")
	before = restored.save_json()
	malformed = JSON.parse_string(before)
	malformed.version = 3.5
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == before, "Fractional save version is rejected without changing the expedition")
	var dark = Surface.new(555, {"solar_factor": 0.25})
	var bright = Surface.new(555, {"solar_factor": 1.0})
	for site in [dark, bright]:
		site.command("land", 10, 10)
		site.command("solar", 11, 10)
		site.advance(10)
	check(absf((dark.summary().power_supply - 8.0) * 4 - (bright.summary().power_supply - 8.0)) < 0.000001, "Surface power scales with received light under identical placement")
	var poor = Surface.new(555, {"ice_factor": 0.25})
	var rich = Surface.new(555, {"ice_factor": 1.0})
	var poor_ice := 0.0
	var rich_ice := 0.0
	for cell in poor.state.cells:
		if cell.resource == "ice":
			poor_ice += cell.remaining
	for cell in rich.state.cells:
		if cell.resource == "ice":
			rich_ice += cell.remaining
	check(absf(poor_ice * 4 - rich_ice) < 0.00001, "Observed ice richness controls actual finite deposits")
	print("Prospects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
