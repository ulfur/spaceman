extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func warming_world():
	var sim = Simulation.new()
	sim.command("survey", "eir_iii")
	sim.command("deploy", "eir_iii")
	return sim

func _initialize() -> void:
	var sim = Simulation.new()
	check(sim.state.ship.modules == 2, "Start with two factory modules")
	var unchanged: String = sim.save_json()
	check(not sim.command("deploy", "eir_iii").ok, "Survey gates deployment")
	check(sim.save_json() == unchanged, "Rejected command has no side effects")
	check(not sim.command("survey", "vesper_b").ok, "Cannot survey a remote system")
	check(not sim.command("seed", "eir_iii").ok, "Cannot seed a frozen world")
	check(sim.travel_quote().years == 68, "Travel includes cruise and maneuvers")

	sim = warming_world()
	check(sim.state.ship.modules == 1, "Landing consumes an onboard module")
	check(not sim.command("deploy", "eir_iii").ok, "Cannot deploy twice at the same site")
	check(not sim.command("policy", "eir_iii", 999.0).ok, "Reject unsupported targets")
	check(sim.command("travel").ok, "First departure is affordable")
	check(sim.state.year == 2468 and sim.state.system == "vesper", "Travel advances the universe")
	check(sim.state.bodies.eir_iii.temperature > 280.0, "Factory works while commander is away")
	check(sim.known_body("eir_iii").temperature == 244.0, "Remote telemetry remains stale")
	var hidden := true
	for entry in sim.known_log():
		if entry.body == "eir_iii" and entry.year > 2400:
			hidden = false
	check(hidden, "Remote event log does not reveal unseen outcomes")
	check(sim.command("travel").ok, "Initial reserves support a return without mining")
	check(sim.state.first_rain, "Returning to the changed planet achieves first rain")
	check(sim.state.ship.propellant == 50.0 and sim.state.ship.fuel == 44.0, "Travel debits distinct resources")
	check(sim.known_body("eir_iii").temperature > 280.0, "Arrival refreshes local observations")
	check(sim.command("seed", "eir_iii").ok, "Habitable world accepts pioneer life")
	sim.advance(60)
	check(sim.state.bodies.eir_iii.biomass > 0.75, "Life grows under suitable conditions")
	var healthy: float = sim.state.bodies.eir_iii.biomass
	sim.command("policy", "eir_iii", 325.0)
	sim.advance(100)
	check(sim.state.bodies.eir_iii.biomass < healthy * 0.1, "Bad policy has ecological consequences")

	var late = Simulation.new()
	late.command("travel")
	late.command("travel")
	late.command("survey", "eir_iii")
	late.command("deploy", "eir_iii")
	late.state.ship.propellant = 200.0
	late.command("travel")
	check(not late.state.first_rain, "An earlier return cannot award unseen rain while arriving at Vesper")
	late.command("travel")
	check(late.state.first_rain, "Late intervention is discovered on the next actual return to Eir")

	var jump = warming_world()
	var ticks = warming_world()
	jump.command("survey", "nacre")
	jump.command("deploy", "nacre")
	ticks.command("survey", "nacre")
	ticks.command("deploy", "nacre")
	jump.advance(200)
	for year in range(200):
		ticks.advance(1)
	check(jump.save_json() == ticks.save_json(), "Time partitioning preserves state and history exactly")
	var moon: Dictionary = jump.state.bodies.nacre
	var output: float = moon.stock.fuel + moon.stock.propellant + moon.stock.alloy
	check(absf(output + moon.deposit - 520.0) < 0.000001, "Extraction conserves abstract feedstock mass")
	check(moon.deposit == 0.0 and moon.exhausted, "Factories stop at deposit exhaustion")
	var stock_before: Dictionary = moon.stock.duplicate(true)
	jump.advance(100)
	check(moon.stock == stock_before, "Exhausted factories cannot create resources")
	check(jump.state.bodies.eir_iii.temperature <= 288.0, "Safe policy never overshoots equilibrium target")
	jump.command("collect", "nacre")
	check(moon.stock.fuel == 0.0 and moon.stock.alloy == 0.0, "Collection empties surface stores")
	var aboard: Dictionary = jump.state.ship.duplicate(true)
	check(not jump.command("collect", "nacre").ok, "Cannot collect the same stores twice")
	check(jump.state.ship == aboard, "Duplicate collection cannot mint supplies")
	var modules_before: int = jump.state.ship.modules
	check(jump.command("reclaim", "eir_iii").ok, "Factory can be recovered")
	check(jump.state.ship.modules == modules_before + 1 and jump.state.bodies.eir_iii.factory == "", "Recovery transfers exactly one module")
	var forcing: float = jump.state.bodies.eir_iii.greenhouse
	jump.advance(50)
	check(jump.state.bodies.eir_iii.greenhouse < forcing, "Abandoned atmosphere slowly loses forcing")

	var industry = Simulation.new()
	industry.command("survey", "nacre")
	industry.command("deploy", "nacre")
	check(industry.command("build", "nacre").ok, "Industry builds replacement modules")
	check(industry.state.ship.modules == 2 and industry.state.ship.alloy == 4.0 and industry.state.year == 2405, "Manufacturing debits materials and advances time")
	industry.state.ship.integrity = 60.0
	check(not industry.command("repair", "nacre").ok, "Repairs cannot overdraft alloy")
	industry.advance(10)
	industry.command("collect", "nacre")
	check(industry.command("repair", "nacre").ok and industry.state.ship.integrity == 85.0, "Repairs restore integrity with industrial support")
	industry.state.ship.propellant = 0.0
	var stranded: String = industry.save_json()
	check(not industry.command("travel").ok and industry.save_json() == stranded, "Insufficient propellant blocks transit atomically")

	var original = warming_world()
	original.advance(37)
	var saved: String = original.save_json()
	var restored = Simulation.new()
	check(restored.restore_json(saved).ok, "Versioned JSON save loads")
	original.advance(100)
	restored.advance(100)
	if original.save_json() != restored.save_json():
		var expected: String = original.save_json()
		var actual: String = restored.save_json()
		for index in range(mini(expected.length(), actual.length())):
			if expected[index] != actual[index]:
				print("Save continuity difference: expected=", expected.substr(maxi(0, index - 60), 160), " actual=", actual.substr(maxi(0, index - 60), 160))
				break
	check(original.save_json() == restored.save_json(), "Save/load preserves future evolution")
	restored.command("travel")
	check(restored.restore_json(saved).ok, "Earlier save loads after visiting another system")
	var protected_state: String = restored.save_json()
	for contents in ["not json", "{}", "[]", '{"version": 99}']:
		check(not restored.restore_json(contents).ok and restored.save_json() == protected_state, "Malformed save is rejected without destroying current game")
	var invalid: Dictionary = JSON.parse_string(saved)
	invalid.ship.fuel = -1
	check(not restored.restore_json(JSON.stringify(invalid)).ok, "Negative inventories rejected")
	invalid = JSON.parse_string(saved)
	invalid.observations.eir_iii.body = {}
	check(not restored.restore_json(JSON.stringify(invalid)).ok, "Malformed observations rejected")
	invalid = JSON.parse_string(saved)
	invalid.observations = {}
	check(not restored.restore_json(JSON.stringify(invalid)).ok, "Missing navigation observations rejected")
	invalid = JSON.parse_string(saved)
	invalid.ship.modules = 1.5
	check(not restored.restore_json(JSON.stringify(invalid)).ok, "Fractional factory modules rejected")
	var before_wait: String = restored.save_json()
	restored.advance(-5)
	check(restored.save_json() == before_wait, "Negative time cannot rewind production")
	print("Simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
