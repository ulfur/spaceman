extends SceneTree
const Session = preload("res://scripts/session.gd")
const Atlas = preload("res://scripts/world_atlas.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; printerr("FAIL: " + message)

func _initialize() -> void:
	var session = Session.new()
	var saved := session.save_json()
	check(not session.choose_region("eir_iii", Vector2i(2, 2)), "Unsurveyed surface is gated")
	check(session.save_json() == saved, "Failed selection does not mutate state")
	check(session.command("survey", "eir_iii").ok, "Local survey enables regional reconnaissance")
	check(session.choose_region("eir_iii", Atlas.DEFAULT_REGION), "Select reference region")
	var first = session.surface_for("eir_iii")
	check(session.surface_command("land", 10, 10).ok, "First module lands")
	check(session.expedition.state.ship.modules == 1, "Landing consumes stocked ship module")
	var second_region := Vector2i(51, 9)
	check(session.choose_region("eir_iii", second_region), "Select another latitude and longitude")
	var second = session.surface_for("eir_iii")
	check(second != first and second.state.seed != first.state.seed, "Different regions own distinct deterministic terrain")
	check(not second.state.landed and second.state.structures.is_empty(), "Factories are not copied across regions")
	check(session.surface_command("land", 10, 10).ok and session.expedition.state.ship.modules == 0, "Second landing accounts for the second module")
	check(not session.command("deploy", "eir_iii").ok, "Regional installations exclude overlapping legacy allocation")
	var polar: Dictionary = session.region_context("eir_iii", Vector2i(51, 0))
	check(polar.solar_factor < session.region_context("eir_iii", second_region).solar_factor, "Latitude changes solar screening potential")
	session.advance_hours(13)
	check(first.state.total_hours == 13 and second.state.total_hours == 13, "Every retained site advances on the shared clock")
	var restored = Session.new()
	var outcome: Dictionary = restored.restore_json(session.save_json())
	check(outcome.ok, "Multiple regions round-trip: " + outcome.message)
	check(restored.surface_region == second_region and restored.surface_for("eir_iii").state.seed == second.state.seed, "Selected address survives reload")
	check(restored.sites.eir_iii.state.landed, "Legacy body-only site key stays reachable")
	var preserved := restored.save_json()
	var malformed: Dictionary = JSON.parse_string(preserved)
	malformed.surface_address = "eir_iii@72,0"
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == preserved, "Invalid coordinates reject atomically")
	malformed = JSON.parse_string(preserved)
	malformed.sites["eir_iii@51,9"].seed += 1
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == preserved, "Region seed cannot drift on reload")
	check(session.choose_region("eir_iii", Vector2i(10, 11)), "Reconnaissance remains possible with empty module bay")
	check(not session.surface_command("land", 10, 10).ok, "Exploring fresh regions cannot create free modules")
	check(not session.surface_command("mine", 7, 9).ok, "Sealed module cargo cannot build before landing")
	var original_world: Dictionary = session.prospects.worlds.prospect_4.duplicate(true)
	var before: int = session.elapsed_hours()
	check(session.catalogue_field(Vector2i(2, -1)), "Lazy stellar field is catalogued")
	check(session.prospects.worlds.size() == 12, "Only requested field adds systems")
	check(not session.catalogue_field(Vector2i(2, -1)), "Catalogue revisit does not regenerate")
	check(session.elapsed_hours() == before and session.expedition.state.system == "eir", "Map exploration does not teleport or advance time")
	check(session.prospects.worlds.prospect_4 == original_world, "Expansion preserves original worlds")
	var target := "field_2_-1_0"
	check(session.expedition.has_system(target) and session.expedition.travel_quote(target).valid, "Catalogued star is a real travel destination")
	check(not session.prospects.evidence(target).has("pressure"), "Remote expanded systems do not leak environmental truth")
	check(session.observe(target, "photometry").ok, "Remote instruments work on expanded systems")
	check(restored.restore_json(session.save_json()).ok, "Expanded catalogue and evidence survive save/load")
	check(restored.prospects.worlds[target] == session.prospects.worlds[target], "World addresses regenerate identical truth")
	check(restored.prospects.evidence(target).has("orbit_low"), "Expanded catalogue retains dated observations")
	var reverse = Session.new()
	reverse.catalogue_field(Vector2i(-3, 1)); reverse.catalogue_field(Vector2i(2, -1))
	check(reverse.prospects.worlds[target] == session.prospects.worlds[target], "Generation does not depend on exploration order")
	check(not session.catalogue_field(Vector2i(5000, 5000)), "Galaxy radius bounds catalogue requests")
	check(Atlas.orbit(session.expedition.state.bodies.nacre).parent == "eir_iii", "Authored moon has a planetary parent")
	check(Atlas.orbit(session.expedition.state.bodies[target + "_c"]).parent == target + "_b", "Generated moon has a planetary parent")
	check(Atlas.orbit(session.expedition.state.bodies[target + "_d"]).au > Atlas.orbit(session.expedition.state.bodies[target + "_b"]).au, "Outer planet is a distinct orbit")
	var travel = Session.new()
	travel.catalogue_field(Vector2i(1, 0))
	travel.expedition.state.ship.fuel = 500.0
	travel.expedition.state.ship.propellant = 1500.0
	var arrival := "field_1_0_0"
	var travel_year: int = travel.expedition.state.year
	var travel_duration: int = travel.expedition.travel_quote(arrival).years
	check(travel.command("travel", arrival).ok and travel.expedition.state.year == travel_year + travel_duration, "Generated destination is reachable through the actual travel simulation")
	check(travel.observe(arrival, "probe").ok and travel.site_available(arrival + "_d"), "Local probe opens the generated outer planet")
	check(travel.prospects.body_evidence(arrival + "_d").flux_high < travel.prospects.body_evidence(arrival + "_b").flux_low, "Outer-world evidence uses its own irradiance")
	check(travel.choose_region(arrival + "_d", Vector2i(3, 0)), "Polar site on an outer world is selectable")
	travel.surface_for(travel.surface_body)
	check(restored.restore_json(travel.save_json()).ok, "Dim outer-world regions remain loadable")
	var clipped: Array = preload("res://scripts/prospect_map.gd").clipped_route(Vector2(-1000000, 100), Vector2(400, 100), Rect2(0, 0, 600, 400))
	check(clipped.size() == 2 and clipped[0].distance_to(clipped[1]) < 601, "Galactic routes submit only bounded visible geometry")
	# A genuine v4 schema, before the additional orbital bodies existed.
	var legacy = Session.new()
	var old_orbit = Session.Simulation.new(legacy.prospects.definitions(false))
	old_orbit.command("survey", "eir_iii")
	var old_site = Session.Surface.new()
	old_site.command("land", 10, 10)
	old_orbit.state.ship.modules -= 1
	var old_save := {"version": 4, "prospects": JSON.parse_string(legacy.prospects.save_json()), "expedition": JSON.parse_string(old_orbit.save_json()), "sites": {"eir_iii": JSON.parse_string(old_site.save_json())}, "fractional_hours": 0, "surface_body": "eir_iii"}
	check(restored.restore_json(JSON.stringify(old_save)).ok, "Version-four expedition migrates without relocating its module")
	check(restored.surface_region == Atlas.DEFAULT_REGION and restored.sites.eir_iii.state.structures.size() == 1, "Migration preserves factory state and geographic address")
	print("World atlas: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
