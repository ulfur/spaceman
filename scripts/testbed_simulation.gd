extends RefCounted
## A sealed 16 m² pilot, not a planetary climate solver. SI internally.
## Ideal gas + implicit lumped thermal balance + mass-balanced CH2O production.
## Radiation indices and archive physiology are illustrative screening models.
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/testbeds.json"))
const R := 8.314462618
const SIGMA := 5.670374419e-8
const MOLAR := {"inert": 0.028, "co2": 0.044, "oxygen": 0.032, "vapor": 0.018}
const FUSION_J_KG := 334000.0
const VAPORIZATION_J_KG := 2500000.0

static func create(environment: Dictionary) -> Dictionary:
	var moles: float = environment.pressure * 100000.0 * CONFIG.volume_m3 / (R * environment.ambient_k)
	var gas := {"inert": moles * (1.0 - environment.co2_fraction) * MOLAR.inert,
		"co2": moles * environment.co2_fraction * MOLAR.co2, "oxygen": 0.0, "vapor": 0.0}
	return {"version": 1, "temperature_k": environment.ambient_k, "gas": gas,
		"water_kg": 0.0, "biomass_kg": 0.0, "detritus_kg": 0.0, "nutrients_kg": 0.0, "bound_nutrients_kg": 0.0,
		"captured_co2_kg": 0.0, "gas_in_kg": gas.inert + gas.co2, "gas_out_kg": 0.0,
		"water_in_kg": 0.0, "water_waste_kg": 0.0, "archive_in_kg": 0.0,
		"thermal": "passive", "target_k": 288.0, "pressure_control": false, "target_bar": 0.3,
		"shade": 0.0, "lamp": false, "feed_water": false, "filter": false, "canopy": false,
		"upgrade": "", "upgrade_progress": 0.0, "stable_hours": 0, "established": false,
		"operating": false, "heat_w": 0.0, "energy_kwh": 0.0, "history": []}

static func pressure(state: Dictionary, species: String = "") -> float:
	var moles := 0.0
	for kind in MOLAR:
		if species == "" or species == kind:
			moles += state.gas[kind] / MOLAR[kind]
	return moles * R * state.temperature_k / CONFIG.volume_m3 / 100000.0

static func load_kw(state: Dictionary) -> float:
	return 0.5 + (CONFIG.heater_kw if state.thermal != "passive" else 0.0) + (CONFIG.lamp_kw if state.lamp else 0.0) + (CONFIG.pump_kw if state.pressure_control else 0.0)

static func radiation(state: Dictionary, environment: Dictionary) -> Dictionary:
	var column: float = environment.pressure * 100000.0 / (environment.gravity * 9.81)
	var model: Dictionary = CONFIG.radiation
	# Coarse screening proxies, not a transport calculation or a dose in Sv.
	# Field affects only the charged-particle term; there is a cosmic-ray floor.
	var uv: float = environment.flux * (model.uv_quiet + model.uv_activity * environment.activity) * exp(-column / model.uv_column_scale_kg_m2)
	var particles: float = (model.particle_floor + environment.activity / (1.0 + model.field_factor * environment.field_earth)) * exp(-column / model.particle_column_scale_kg_m2)
	uv *= (CONFIG.upgrades.filter.uv_transmission if state.filter else model.glazing_uv_transmission) * (1.0 - state.shade)
	if state.canopy:
		uv *= CONFIG.upgrades.canopy.uv_transmission
		var shield_column: float = CONFIG.upgrades.canopy.cost.ore * 1000.0 / CONFIG.area_m2
		particles *= exp(-shield_column / model.shield_column_scale_kg_m2)
	return {"uv": uv, "particles": particles, "column_kg_m2": column}

static func sunlight_w(state: Dictionary, environment: Dictionary, light: float) -> float:
	return 1361.0 * environment.flux * 0.25 * CONFIG.area_m2 * light * CONFIG.solar_transmission * (1.0 - state.shade) * (CONFIG.upgrades.filter.light_transmission if state.filter else 1.0) * (CONFIG.upgrades.canopy.light_transmission if state.canopy else 1.0)

static func par_w(state: Dictionary, environment: Dictionary, light: float) -> float:
	return sunlight_w(state, environment, light) * 0.45 + (CONFIG.lamp_kw * 1000.0 * CONFIG.lamp_par_fraction if state.lamp and state.operating else 0.0)

static func saturation_pa(temperature: float) -> float:
	# Constant-latent-heat approximation; sublimation below the freezing range.
	return 611.657 * exp((6140.0 if temperature < 273.16 else 5420.0) * (1.0 / 273.16 - 1.0 / temperature))

static func liquid_fraction(temperature: float) -> float:
	# Smear the freezing transition across one kelvin to keep the solve continuous.
	return clampf(temperature - 273.15, 0.0, 1.0)

static func equilibrium_vapor(temperature: float, water_mass: float) -> float:
	return minf(water_mass, saturation_pa(temperature) * CONFIG.volume_m3 * MOLAR.vapor / (R * temperature))

static func water_enthalpy(temperature: float, water_mass: float) -> float:
	var vapor: float = equilibrium_vapor(temperature, water_mass)
	return (water_mass - vapor) * liquid_fraction(temperature) * FUSION_J_KG + vapor * (FUSION_J_KG + VAPORIZATION_J_KG)

static func limitations(state: Dictionary, environment: Dictionary, light: float) -> Array[String]:
	var reasons: Array[String] = []
	var culture: Dictionary = CONFIG.culture
	if state.temperature_k < culture.minimum_k:
		reasons.append("Too cold for archive culture")
	if state.temperature_k > culture.maximum_k:
		reasons.append("Too hot for archive culture")
	if pressure(state) * 100000.0 < saturation_pa(state.temperature_k):
		reasons.append("Pressure cannot sustain exposed liquid water")
	if state.water_kg < 0.1:
		reasons.append("Water store empty")
	var co2_pa: float = pressure(state, "co2") * 100000.0
	if co2_pa < culture.minimum_co2_pa:
		reasons.append("Carbon dioxide depleted")
	elif co2_pa > culture.maximum_co2_pa:
		reasons.append("Carbon dioxide exceeds trial tolerance")
	if par_w(state, environment, light) / CONFIG.area_m2 < culture.minimum_par_w_m2:
		reasons.append("Insufficient photosynthetic light")
	var exposure := radiation(state, environment)
	if exposure.uv > culture.maximum_uv_index:
		reasons.append("UV screening limit exceeded")
	if exposure.particles > culture.maximum_particle_index:
		reasons.append("Particle screening limit exceeded")
	if state.nutrients_kg < 0.0000001:
		reasons.append("Nutrient packet exhausted")
	return reasons

static func exchange(state: Dictionary, kind: String, delta: float) -> void:
	if absf(delta) < 0.000000001:
		return
	state.gas[kind] += delta
	if delta > 0:
		state.gas_in_kg += delta
	else:
		state.gas_out_kg -= delta

static func step(state: Dictionary, environment: Dictionary, light: float, goods: Dictionary, powered: bool) -> bool:
	var before: Dictionary = state.duplicate(true)
	before.erase("history")
	state.operating = powered and goods.components >= CONFIG.service_components_t_h
	if state.operating:
		goods.components -= CONFIG.service_components_t_h
		if state.feed_water:
			var delivered: float = minf(CONFIG.water_feed_kg_h, minf(goods.water * 1000.0, maxf(0.0, CONFIG.water_capacity_kg - state.water_kg - state.gas.vapor)))
			goods.water -= delivered / 1000.0
			state.water_kg += delivered
			state.water_in_kg += delivered
		var flushed: float = minf(state.water_kg * liquid_fraction(state.temperature_k), CONFIG.service_water_kg_h)
		state.water_kg -= flushed
		state.water_waste_kg += flushed
		if state.upgrade != "":
			state.upgrade_progress = minf(1.0, state.upgrade_progress + 1.0 / CONFIG.upgrades[state.upgrade].hours)
			if state.upgrade_progress >= 1.0:
				state[state.upgrade] = true
				state.upgrade = ""
				state.upgrade_progress = 0.0
	if state.operating and state.pressure_control:
		# The operating gas train has parasitic exchange. Its normally closed
		# isolation valves seal when disabled or unpowered; hull leaks are omitted.
		var ambient_moles: float = environment.pressure * 100000.0 * CONFIG.volume_m3 / (R * state.temperature_k)
		for kind in MOLAR:
			var fraction: float = environment.co2_fraction if kind == "co2" else (1.0 - environment.co2_fraction if kind == "inert" else 0.0)
			var ambient_mass: float = ambient_moles * fraction * MOLAR[kind]
			exchange(state, kind, (ambient_mass - state.gas[kind]) * CONFIG.leak_fraction_h)
		var present_moles: float = pressure(state) * 100000.0 * CONFIG.volume_m3 / (R * state.temperature_k)
		var desired_moles: float = state.target_bar * 100000.0 * CONFIG.volume_m3 / (R * state.temperature_k)
		var pump_limit: float = CONFIG.pump_mol_h * environment.pressure / (environment.pressure + 0.05)
		var change_moles: float = clampf(desired_moles - present_moles, -pump_limit, pump_limit)
		if change_moles > 0.0:
			exchange(state, "co2", change_moles * environment.co2_fraction * MOLAR.co2)
			exchange(state, "inert", change_moles * (1.0 - environment.co2_fraction) * MOLAR.inert)
		elif present_moles > 0.0:
			for kind in MOLAR:
				exchange(state, kind, state.gas[kind] * change_moles / present_moles)
		# Regenerative separator moves carbon into a captured store, not oblivion.
		var co2_limit: float = CONFIG.regulator_co2_pa * CONFIG.volume_m3 / (R * state.temperature_k) * MOLAR.co2
		var concentrated: float = minf(maxf(0.0, co2_limit - state.gas.co2), pump_limit * environment.co2_fraction * MOLAR.co2)
		exchange(state, "co2", concentrated)
		var captured: float = minf(maxf(0.0, state.gas.co2 - co2_limit), CONFIG.capture_co2_kg_h)
		state.gas.co2 -= captured
		state.captured_co2_kg += captured
	var solar: float = sunlight_w(state, environment, light)
	var lamp_heat: float = CONFIG.lamp_kw * 1000.0 if state.operating and state.lamp else 0.0
	state.heat_w = 0.0
	if state.operating:
		match state.thermal:
			"heat": state.heat_w = CONFIG.heater_kw * 1000.0
			"cool": state.heat_w = -CONFIG.heater_kw * 1000.0 * CONFIG.cooling_cop
			"auto":
				var needed: float = thermal_loss(state.target_k, environment) - solar - lamp_heat + CONFIG.heat_capacity_j_k * (state.target_k - state.temperature_k) / 3600.0
				state.heat_w = clampf(needed, -CONFIG.heater_kw * 1000.0 * CONFIG.cooling_cop, CONFIG.heater_kw * 1000.0)
	if state.operating:
		state.energy_kwh += 0.5 + lamp_heat / 1000.0 + absf(state.heat_w) / 1000.0 / (CONFIG.cooling_cop if state.heat_w < 0 else 1.0) + (CONFIG.pump_kw if state.pressure_control else 0.0)
	var chemical_j := 0.0
	var reasons := limitations(state, environment, light)
	if state.biomass_kg > 0.0:
		if reasons.is_empty():
			var c: Dictionary = CONFIG.culture
			var growth: float = minf(state.biomass_kg * c.growth_fraction_h, c.capacity_kg - state.biomass_kg)
			growth = minf(growth, par_w(state, environment, light) * 3600.0 * c.photosynthetic_efficiency / c.chemical_energy_j_kg)
			growth = minf(growth, minf(state.gas.co2 * 30.0 / 44.0, minf(state.water_kg * 30.0 / 18.0, state.nutrients_kg / c.nutrients_per_kg)))
			if growth > 0.000000001:
				chemical_j = growth * c.chemical_energy_j_kg
				state.biomass_kg += growth
				state.gas.co2 -= growth * 44.0 / 30.0
				state.water_kg -= growth * 18.0 / 30.0
				state.gas.oxygen += growth * 32.0 / 30.0
				state.nutrients_kg -= growth * c.nutrients_per_kg
				state.bound_nutrients_kg += growth * c.nutrients_per_kg
			state.stable_hours = mini(int(c.established_hours), int(state.stable_hours) + 1)
			if state.stable_hours >= c.established_hours and state.biomass_kg >= c.established_kg:
				state.established = true
		else:
			var dead: float = state.biomass_kg * CONFIG.culture.decay_fraction_h
			if state.biomass_kg - dead < 0.000000001: dead = state.biomass_kg
			state.biomass_kg -= dead
			state.detritus_kg += dead
			state.stable_hours = 0
	# Backward Euler: bounded nonlinear solve instead of unstable explicit T^4.
	# Energy stored by photosynthesis is removed from the absorbed-light budget.
	var water_mass: float = state.water_kg + state.gas.vapor
	var previous_water_heat: float = state.water_kg * liquid_fraction(state.temperature_k) * FUSION_J_KG + state.gas.vapor * (FUSION_J_KG + VAPORIZATION_J_KG)
	var low := 50.0
	var high := 1000.0
	for iteration in range(34):
		var trial: float = (low + high) * 0.5
		var latent_w: float = (water_enthalpy(trial, water_mass) - previous_water_heat) / 3600.0
		var residual: float = CONFIG.heat_capacity_j_k * (trial - state.temperature_k) / 3600.0 - solar - lamp_heat - state.heat_w + thermal_loss(trial, environment) + chemical_j / 3600.0 + latent_w
		if residual > 0.0: high = trial
		else: low = trial
	var temperature: float = (low + high) * 0.5
	if absf(temperature - state.temperature_k) > 0.0000001:
		state.temperature_k = temperature
	var vapor: float = equilibrium_vapor(state.temperature_k, water_mass)
	if absf(vapor - state.gas.vapor) > 0.000000001:
		state.gas.vapor = vapor
		state.water_kg = water_mass - vapor
	var after: Dictionary = state.duplicate(false)
	after.erase("history")
	return before != after

static func thermal_loss(temperature: float, environment: Dictionary) -> float:
	return CONFIG.conductance_w_k * (temperature - environment.ambient_k) + CONFIG.infrared_emissivity * CONFIG.area_m2 * SIGMA * (pow(temperature, 4) - pow(environment.equilibrium_k, 4))

static func sample(state: Dictionary, hour: int) -> void:
	if hour % int(CONFIG.history_interval_h) != 0:
		return
	state.history.append({"hour": hour, "temperature": state.temperature_k, "pressure": pressure(state), "biomass": state.biomass_kg})
	if state.history.size() > int(CONFIG.history_samples): state.history.pop_front()

static func stationary_samples(state: Dictionary, begin: int, end: int) -> void:
	var interval: int = int(CONFIG.history_interval_h)
	var first: int = maxi(begin + 1, end - interval * int(CONFIG.history_samples) + 1)
	first += (interval - first % interval) % interval
	for hour in range(first, end + 1, interval): sample(state, hour)

static func mass_error(state: Dictionary) -> float:
	var imported: float = state.gas_in_kg - state.gas_out_kg + state.water_in_kg + state.archive_in_kg
	var stored: float = state.water_kg + state.water_waste_kg + state.biomass_kg + state.detritus_kg + state.nutrients_kg + state.bound_nutrients_kg + state.captured_co2_kg
	for amount in state.gas.values(): stored += amount
	return imported - stored

static func valid(state: Variant, now: int) -> bool:
	if not state is Dictionary: return false
	var reference := create({"pressure": 1.0, "ambient_k": 288.0, "co2_fraction": 0.01})
	for key in reference:
		if not state.has(key): return false
		var template: Variant = reference[key]
		if template is float or template is int:
			if not (state[key] is float or state[key] is int) or not is_finite(float(state[key])): return false
		elif typeof(state[key]) != typeof(template): return false
	if state.version != 1 or state.temperature_k < 50.0 or state.temperature_k > 1000.0: return false
	if state.thermal not in ["passive", "heat", "cool", "auto"] or state.target_k < 278 or state.target_k > 310: return false
	if state.target_bar < 0.05 or state.target_bar > 1.0 or state.shade < 0 or state.shade > 0.95: return false
	if state.upgrade not in ["", "filter", "canopy"] or state.upgrade_progress < 0 or state.upgrade_progress >= 1: return false
	if state.upgrade != "" and state[state.upgrade]: return false
	if state.upgrade == "" and state.upgrade_progress != 0: return false
	if state.stable_hours < 0 or state.stable_hours > CONFIG.culture.established_hours or state.stable_hours != floor(state.stable_hours): return false
	for key in ["water_kg", "biomass_kg", "detritus_kg", "nutrients_kg", "bound_nutrients_kg", "captured_co2_kg", "gas_in_kg", "gas_out_kg", "water_in_kg", "water_waste_kg", "archive_in_kg", "energy_kwh"]:
		if state[key] < 0.0 or state[key] > 1000000000.0: return false
	if state.water_kg > CONFIG.water_capacity_kg or state.biomass_kg > CONFIG.culture.capacity_kg + 0.0000001: return false
	if state.gas.size() != MOLAR.size(): return false
	for kind in MOLAR:
		var amount: Variant = state.gas.get(kind)
		if not (amount is float or amount is int) or not is_finite(float(amount)) or amount < 0.0 or amount > 10000.0: return false
	if state.water_kg + state.gas.vapor > CONFIG.water_capacity_kg + 0.0000001: return false
	if absf(mass_error(state)) > 0.00001: return false
	if state.history.size() > int(CONFIG.history_samples): return false
	var previous := -1
	for point in state.history:
		if not point is Dictionary: return false
		for key in ["hour", "temperature", "pressure", "biomass"]:
			var value: Variant = point.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0.0: return false
		if point.hour > now or point.hour <= previous or point.hour != floor(point.hour) or int(point.hour) % int(CONFIG.history_interval_h) != 0: return false
		if point.temperature > 1000 or point.pressure > 100 or point.biomass > CONFIG.culture.capacity_kg + 0.0000001: return false
		previous = int(point.hour)
	return true
