extends SceneTree
const Model = preload("res://scripts/testbed_simulation.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0
var environment := {"pressure": 0.3, "gravity": 1.0, "flux": 0.5, "field_earth": 1.0, "activity": 0.3, "co2_fraction": 0.01, "ambient_k": 230.0, "equilibrium_k": 220.0}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func inoculate(trial: Dictionary) -> void:
	trial.biomass_kg += Model.CONFIG.culture.seed_kg
	trial.nutrients_kg += Model.CONFIG.culture.packet_nutrients_kg
	trial.archive_in_kg += Model.CONFIG.culture.seed_kg + Model.CONFIG.culture.packet_nutrients_kg

func step(trial: Dictionary, goods: Dictionary, hours: int, powered: bool = true) -> void:
	for hour in range(hours): Model.step(trial, environment, 0.7, goods, powered)

func place(site: RefCounted, kind: String) -> Dictionary:
	for cell in site.state.cells:
		if cell.x >= 8 and cell.x <= 12 and cell.z >= 8 and cell.z <= 12 and site.can_place(kind, cell.x, cell.z).ok:
			check(site.command(kind, cell.x, cell.z).ok, "Place " + kind)
			return site.structure_at(cell.x, cell.z)
	check(false, "Legal site for " + kind)
	return {}

func _initialize() -> void:
	var trial: Dictionary = Model.create(environment)
	check(absf(Model.pressure(trial) - environment.pressure) < 0.00000001, "Initial gas mass produces ambient pressure")
	check(absf(Model.mass_error(trial)) < 0.00000001, "Initial sealed inventory is accounted for")
	var water_only: Dictionary = Model.create(environment)
	for kind in water_only.gas: water_only.gas[kind] = 0.0
	water_only.gas_in_kg = 0.0
	water_only.temperature_k = 288.0
	water_only.water_kg = 20.0
	water_only.water_in_kg = 20.0
	Model.step(water_only, environment, 0.7, {"components": 0.0, "water": 0.0}, false)
	check(water_only.gas.vapor > 0.1 and water_only.water_kg > 19, "A sealed water pool supplies vapor while retaining condensed water")
	check(Model.pressure(water_only) * 100000.0 >= Model.saturation_pa(water_only.temperature_k) - 0.001, "Vapor contributes to chamber pressure")
	check(absf(Model.mass_error(water_only)) < 0.00000001, "Phase changes transfer mass without creating water")
	check(water_only.gas_in_kg == 0.0 and water_only.gas_out_kg == 0.0, "Unpowered isolation valves preserve the sealed gas inventory")
	check(Model.water_enthalpy(275, 20) - Model.water_enthalpy(272, 20) > 6000000, "Freezing/melting includes the latent energy budget")
	var doubled: Dictionary = trial.duplicate(true)
	doubled.temperature_k *= 2
	check(absf(Model.pressure(doubled) - 2 * Model.pressure(trial)) < 0.00000001, "Ideal gas pressure follows absolute temperature")
	var field: Dictionary = environment.duplicate(true)
	field.field_earth = 10.0
	var normal: Dictionary = Model.radiation(trial, environment)
	var magnetic: Dictionary = Model.radiation(trial, field)
	check(normal.uv == magnetic.uv and magnetic.particles < normal.particles, "Magnetic field changes only the charged-particle channel")
	var shaded: Dictionary = trial.duplicate(true)
	shaded.shade = 0.9
	check(absf(Model.sunlight_w(shaded, environment, 0.7) * 10 - Model.sunlight_w(trial, environment, 0.7)) < 0.000001, "Shade changes the actual absorbed energy budget")
	check(Model.radiation(shaded, environment).particles == normal.particles, "An optical shade is not a particle shield")
	shaded.filter = true
	check(Model.radiation(shaded, environment).uv < normal.uv * 0.01, "Filter and shade attenuate UV")
	shaded.canopy = true
	check(Model.radiation(shaded, environment).particles < normal.particles * 0.1, "Mass shielding also reduces the particle screening proxy")
	var goods := {"water": 20.0, "components": 20.0}
	trial.thermal = "auto"
	trial.pressure_control = true
	trial.feed_water = true
	trial.lamp = true
	trial.filter = true
	Model.step(trial, environment, 0.7, goods, true)
	check(trial.temperature_k > environment.ambient_k and trial.temperature_k < 235, "Heating advances through thermal inertia, not an instant target jump")
	check(goods.water < 20 and goods.components < 20, "Trial draws real water and service parts")
	step(trial, goods, 160)
	check(absf(trial.temperature_k - 288.0) < 0.1, "Sufficient actuator capacity holds the target")
	check(absf(Model.pressure(trial) - 0.3) < 0.01, "Pressure regulation approaches the selected inventory")
	check(trial.water_kg > 19, "Metered feed fills the trial reservoir")
	inoculate(trial)
	var seeded: float = trial.biomass_kg
	step(trial, goods, 280)
	check(trial.biomass_kg > seeded * 20 and trial.established, "Compatible conditions establish a culture over a measured week")
	check(trial.gas.oxygen > 0 and trial.nutrients_kg < Model.CONFIG.culture.packet_nutrients_kg, "Photosynthesis produces oxygen and consumes nutrients")
	check(absf(Model.mass_error(trial)) < 0.000001, "Water, gases, biomass and captured/waste streams conserve mass")
	check(Model.valid(trial, 1000), "Physical trial state validates")
	var cold: Dictionary = trial.duplicate(true)
	var unpowered_goods: Dictionary = goods.duplicate(true)
	step(cold, unpowered_goods, 500, false)
	check(cold.temperature_k < 270 and cold.biomass_kg < 0.000001 and cold.detritus_kg > 0, "Power loss changes the environment and kills an unsupported culture")
	check(unpowered_goods == goods, "Inactive actuators consume no site inventory")
	check(absf(Model.mass_error(cold)) < 0.000001, "Dead culture remains accounted detritus")
	var dark: Dictionary = trial.duplicate(true)
	dark.canopy = true
	dark.lamp = false
	check("Insufficient photosynthetic light" in Model.limitations(dark, environment, 0.7), "Opaque shelter has a lighting tradeoff")
	dark.lamp = true
	check(not "Insufficient photosynthetic light" in Model.limitations(dark, environment, 0.7), "Powered grow light restores sheltered illumination")
	var thin: Dictionary = trial.duplicate(true)
	for kind in thin.gas: thin.gas[kind] *= 0.001
	check("Pressure cannot sustain exposed liquid water" in Model.limitations(thin, environment, 0.7), "Temperature alone does not establish liquid-water conditions")
	var session = Session.new()
	check(not session.surface_for("eir_iii") is RefCounted, "Old unsurveyed surface remains gated")
	check(session.command("travel", "prospect_0").ok and session.observe("prospect_0", "probe").ok, "Arrive and resolve a test environment")
	session.surface_body = "prospect_0_b"
	var site = session.surface_for(session.surface_body)
	check(not site.environment.is_empty(), "Probed physical context reaches the surface model")
	check(session.surface_command("land", 10, 10).ok, "Allocate the industrial module")
	var metal: float = site.state.resources.metal
	var lab: Dictionary = place(site, "testbed")
	check(site.state.resources.metal == metal - 30.0, "Testbed construction charges quoted metal")
	var before: String = session.save_json()
	check(not session.trial_command(lab.id, "inoculate").ok and session.save_json() == before, "Incomplete chamber cannot consume an archive")
	session.advance_hours(40)
	check(lab.progress == 1.0, "Testbed builds on actual surface power and service")
	check(session.trial_command(lab.id, "thermal", "auto").ok and session.trial_command(lab.id, "pressure_control", true).ok and session.trial_command(lab.id, "feed_water", true).ok, "Trial controls issue authoritative orders")
	before = session.save_json()
	check(not session.trial_command(lab.id, "target_k", -30).ok and session.save_json() == before, "Invalid setpoint is atomic")
	check(session.trial_command(lab.id, "filter").ok, "Filter construction commits actual goods")
	before = session.save_json()
	check(not session.trial_command(lab.id, "filter").ok and session.save_json() == before, "Duplicate upgrade cannot charge twice")
	session.advance_hours(24)
	check(lab.trial.filter and lab.trial.history.size() > 0, "Upgrade takes time and measurements accumulate")
	var archives: int = session.expedition.state.ship.seeds
	check(session.trial_command(lab.id, "inoculate").ok and session.expedition.state.ship.seeds == archives - 1, "Inoculation allocates exactly one archive")
	var saved: String = session.save_json()
	var restored = Session.new()
	var result: Dictionary = restored.restore_json(saved)
	check(result.ok, "Version-four testbed save restores: " + result.message)
	if not result.ok:
		print("Testbeds: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var copy = restored.surface_for(restored.surface_body)
	var copy_lab: Dictionary = copy.testbed_at(lab.id)
	check(absf(copy_lab.trial.temperature_k - lab.trial.temperature_k) < 0.0000001, "Measured thermal state persists")
	var malformed: Dictionary = JSON.parse_string(saved)
	malformed.sites[session.surface_body].structures[-1].trial.water_kg += 0.1
	before = restored.save_json()
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == before, "Unaccounted trial mass is rejected atomically")
	malformed = JSON.parse_string(saved)
	malformed.sites[session.surface_body].structures[-1].trial.history[-1].hour += 1000000
	check(not restored.restore_json(JSON.stringify(malformed)).ok and restored.save_json() == before, "A future trial observation cannot load")
	session.advance_hours(500)
	for hour in range(500): restored.advance_hours(1)
	for key in ["temperature_k", "water_kg", "biomass_kg", "detritus_kg", "energy_kwh"]:
		check(absf(lab.trial[key] - copy_lab.trial[key]) < 0.0000001, "Save/load and chunk size preserve " + key)
	var same_history: bool = lab.trial.history.size() == copy_lab.trial.history.size()
	for index in range(mini(lab.trial.history.size(), copy_lab.trial.history.size())):
		for key in ["hour", "temperature", "pressure", "biomass"]:
			same_history = same_history and absf(lab.trial.history[index][key] - copy_lab.trial.history[index][key]) < 0.0000001
	check(same_history, "History samples follow logical time, not frame rate")
	var departure_hour: int = site.state.total_hours
	var years: int = session.expedition.travel_quote("eir").years
	check(session.command("travel", "eir").ok, "Departure with an unattended experiment")
	check(site.state.total_hours == departure_hour + years * 8766, "The full transit advances the trial and industry")
	check(absf(Model.mass_error(lab.trial)) < 0.00001, "Long unattended intervals conserve trial mass")
	check(not session.trial_command(lab.id, "thermal", "heat").ok, "Remote experiments cannot receive instant direct commands")
	check(session.command("travel", "prospect_0").ok and session.surface_for(session.surface_body) == site, "Return reacquires the same physical experiment")
	var old = Session.new()
	var v3: Dictionary = JSON.parse_string(old.save_json())
	v3.version = 3
	v3.expedition = JSON.parse_string(Session.Simulation.new(old.prospects.definitions(false)).save_json())
	check(restored.restore_json(JSON.stringify(v3)).ok and restored.sites.is_empty(), "Prospects version-three expeditions migrate")
	print("Testbeds: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
