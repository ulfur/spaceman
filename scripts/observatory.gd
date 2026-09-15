extends Control
const UI = preload("res://scripts/interface.gd")
const Session = preload("res://scripts/session.gd")
const Prospects = preload("res://scripts/prospects.gd")
const Map = preload("res://scripts/prospect_map.gd")
const INK := Color("dce2d9")
const MUTED := Color("8fa6af")
const CYAN := Color("a1d6ca")
const AMBER := Color("e2bc7e")
var session = Session.get_shared()
var selected := "prospect_0"
var map: Control
var clock: Label
var resources: Label
var dossier: Label
var title: Label
var route: Label
var decision: Label
var status: Label
var provenance: Label
var observe_buttons: Dictionary = {}
var depart: Button
var surface: Button
var overview: VBoxContainer
var evidence_page: VBoxContainer
var details_tab := false
var tabs: Array[Button] = []
var local_orbit: Button
var travel_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var seed_input: SpinBox

func _ready() -> void:
	if not session.initialized:
		session.load_disk()
	if session.prospects.worlds.has(session.expedition.state.system):
		selected = session.expedition.state.system
	build_interface()
	refresh()

func label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


func button(text: String, callback: Callable, node_name: String) -> Button:
	return UI.button(text, callback, node_name)


func stack(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", 12)
	parent.add_child(node)
	return node


func build_interface() -> void:
	UI.install(self)
	map = Map.new()
	map.name = "ProspectMap"
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.selected_system.connect(select_system)
	var nav := UI.header(self)
	nav.add_child(UI.label("Star chart", 16, CYAN))
	UI.spacer(nav)
	local_orbit = button("Local orbit →", open_orbit, "LocalOrbit")
	nav.add_child(local_orbit)
	UI.menu(self, nav, [["Save expedition", save, "SaveChart"], ["New expedition", request_reset, "NewProspects"], ["Map & instruments", show_help, "Help"]])
	resources = UI.label("", 15, MUTED)
	UI.mount(self, Control.PRESET_TOP_WIDE, Vector4(28, 87, -28, 118)).add_child(resources)
	var map_title := UI.column(UI.mount(self, Control.PRESET_TOP_LEFT, Vector4(36, 142, 540, 215)), 5)
	map_title.add_child(UI.label("Choose your next star", 30))
	map_title.add_child(UI.label("Select a system to inspect its evidence and route.", 15, MUTED))
	var right := UI.inspector(self)
	title = UI.label("", 27)
	right.add_child(title)
	var tab_row := UI.row(right)
	for page in ["Overview", "Evidence"]:
		var node := button(page, set_tab.bind(page == "Evidence"), "Chart" + page)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(node)
		tabs.append(node)
	var content := UI.scroll(right, "DossierScroll")
	overview = UI.column(content)
	decision = UI.label("", 16, CYAN, true)
	overview.add_child(decision)
	var instruments := UI.column(overview, 8)
	instruments.name = "ObservationTools"
	for method in ["photometry", "spectrum", "monitor", "probe"]:
		var node := button("", observe.bind(method), "Observe_" + method)
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		instruments.add_child(node)
		observe_buttons[method] = node
	evidence_page = UI.column(content)
	dossier = UI.label("", 16, INK, true)
	evidence_page.add_child(dossier)
	provenance = UI.label("", 14, MUTED, true)
	evidence_page.add_child(provenance)
	right.add_child(HSeparator.new())
	route = UI.label("", 15, AMBER, true)
	right.add_child(route)
	depart = UI.button("Review transit →", request_travel, "ProspectDepart", true)
	right.add_child(depart)
	surface = UI.button("Choose a landing site →", open_surface, "ProspectSurface", true)
	right.add_child(surface)
	var bottom := UI.footer(self)
	var time := UI.row(bottom)
	clock = UI.label("", 16, AMBER)
	time.add_child(clock)
	UI.spacer(time)
	time.add_child(UI.label("Distances in light years · Archived observations", 14, MUTED))
	status = UI.status(bottom)
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.name = "ProspectTransit"
	travel_dialog.title = "Commit to interstellar transit"
	travel_dialog.ok_button_text = "Begin transit"
	travel_dialog.confirmed.connect(travel)
	add_child(travel_dialog)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Begin a different expedition?"
	reset_dialog.ok_button_text = "Begin expedition"
	var reset_content := stack(reset_dialog)
	reset_content.custom_minimum_size.x = 430
	# A wrapping label in an auto-sized Window feeds its initial zero width back
	# into the minimum height. Fixed lines keep the confirmation bounded.
	reset_content.add_child(label("This replaces the current expedition and autosave.\nChanging the seed changes every prospect.", 14))
	reset_content.add_child(label("Neighbourhood seed", 14, CYAN))
	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.step = 1
	seed_input.custom_minimum_size.y = 38
	reset_content.add_child(seed_input)
	reset_dialog.register_text_enter(seed_input.get_line_edit())
	reset_dialog.confirmed.connect(new_expedition)
	add_child(reset_dialog)

func select_system(id: String) -> void:
	selected = id
	refresh()

func refresh() -> void:
	map.show_catalogue(session, selected)
	var ship: Dictionary = session.expedition.state.ship
	clock.text = "Year %d + %d h  ·  Paused" % [session.expedition.state.year, session.fractional_hours]
	local_orbit.text = system_name(session.expedition.state.system) + " orbit →"
	resources.text = "Fuel %.2f    ·    Propellant %.1f    ·    Alloy %.1f    ·    Hull %.0f%%    ·    Modules %d" % [ship.fuel, ship.propellant, ship.alloy, ship.integrity, ship.modules]
	var data: Dictionary = session.prospects.evidence(selected)
	title.text = system_name(selected) if data.is_empty() else data.planet_name
	for method in observe_buttons:
		var allowed: Dictionary = session.prospects.can_observe(selected, method, session.expedition.state.system)
		var cost: Dictionary = Prospects.CONFIG.observations[method]
		observe_buttons[method].disabled = not allowed.ok or ship.fuel < cost.fuel or ship.alloy < cost.alloy
		var acquired: bool = not data.is_empty() and data.records.has(method)
		observe_buttons[method].visible = not data.is_empty() and (method != "probe" or selected == session.expedition.state.system)
		observe_buttons[method].text = ("✓ " + cost.label + " · acquired") if acquired else ("%s   %d h · %.2f fuel%s" % [cost.label, cost.hours, cost.fuel, " · 1 alloy" if cost.alloy > 0 else ""])
		observe_buttons[method].add_theme_font_size_override("font_size", 14)
		observe_buttons[method].tooltip_text = allowed.message if not allowed.ok else "Commits instrument time and supplies immediately."
		observe_buttons[method].disabled = observe_buttons[method].disabled or acquired
	surface.visible = not data.is_empty() and session.site_available(selected + "_b")
	surface.text = "Continue surface operations →" if session.sites.has(selected + "_b") and session.sites[selected + "_b"].state.landed else "Choose a landing site →"
	if data.is_empty():
		dossier.text = "REFERENCE SYSTEM\n\nThe original expedition route remains available. Enter local orbit to survey its bodies, operate orbital factories or collect supplies."
		provenance.text = "Authored First Rain scenario."
		decision.text = "A known route can support a longer expedition. Resources must still be surveyed and collected locally."
	else:
		dossier.text = "%s STAR  /  CATALOGUE\nLuminosity %.3f solar\nAge estimate %.1f–%.1f Gyr\n\n" % [data.type, data.luminosity, data.age_low, data.age_high]
		if data.has("flux_low"):
			dossier.text += "ORBIT FIT\nIrradiance %.2f–%.2f Earth\nOrbit %.3f–%.3f AU\n\n" % [data.flux_low, data.flux_high, data.orbit_low, data.orbit_high]
		else:
			dossier.text += "IRRADIANCE  /  UNKNOWN\nResolve the orbit first.\n\n"
		dossier.text += "ATMOSPHERIC SPECTRUM\n%s\n\n" % data.get("spectrum_hint", "No targeted spectrum acquired.")
		dossier.text += "STELLAR VARIABILITY\n%s\n\n" % (data.activity_band + " in sampled window; rare events unresolved." if data.has("activity_band") else "Unmeasured. Spectral type alone is insufficient.")
		if data.records.has("probe"):
			dossier.text += "ENVIRONMENTAL ESTIMATE\nAmbient %.1f K (grey model)\nCO₂ %.2f%% (molar)\n\n" % [data.ambient_k, data.co2_fraction * 100.0]
			dossier.text += "LOCAL PROBE\nGravity %.2f g\nPressure %.3f bar\nAtmospheric column %.0f kg/m²\nField strength %.2f Earth\nRotation: %s\n\nSolar yield %.2f×\nOre richness %.2f×\nAccessible ice %.2f×\n\n" % [data.gravity, data.pressure, data.atmospheric_column, data.field_earth, "synchronous" if data.locked else "non-synchronous", data.solar_factor, data.ore_factor, data.ice_factor]
			dossier.text += "RADIATION / LIFE\nSurface dose and native life unresolved. A field affects charged particles, not UV photons. A protected refuge is a separate goal."
		else:
			dossier.text += "GROUND TRUTH  /  UNKNOWN\nPressure, gravity, magnetic field, rotation, deposits and surface dose require local investigation."
		decision.text = assessment(data)
		if data.records.has("probe"):
			decision.text = "Region mapped\n%.1f K ambient · %.3f bar\nSolar yield %.2f× · Ice richness %.2f×\n\nReview the full probe in Evidence, or enter the surface." % [data.ambient_k, data.pressure, data.solar_factor, data.ice_factor]
			for node in observe_buttons.values(): node.visible = false
		provenance.text = latest_observation(data)
	var quote: Dictionary = session.expedition.travel_quote(selected)
	if selected == session.expedition.state.system:
		route.text = "In this system · No transit required"
		depart.disabled = true
	else:
		route.text = "%.2f ly · %d years\n%.1f fuel · %.1f propellant · %.1f hull\n" % [quote.distance_ly, quote.years, quote.fuel_cost, quote.propellant_cost, quote.wear]
		var return_ready: bool = ship.fuel >= quote.fuel_cost * 2 and ship.propellant >= quote.propellant_cost * 2 and ship.integrity - quote.wear > maxf(20, quote.wear)
		route.text += "Return reserves available." if return_ready else "Return requires resupply or repairs."
		depart.disabled = not quote.valid or ship.fuel < quote.fuel_cost or ship.propellant < quote.propellant_cost or ship.integrity <= maxf(20, quote.wear)

	depart.visible = selected != session.expedition.state.system
	set_tab(details_tab)
	status.tooltip_text = status.text

func assessment(data: Dictionary) -> String:
	if not data.has("flux_low"):
		return "A star and a candidate. Their separation—and the planet's received energy—remain uncertain."
	var text := "Moderate exposure candidate. Atmosphere and radiation still matter."
	if data.flux_high < 0.6:
		text = "A dim orbit. More arrays are needed to support the same loads."
	elif data.flux_low > 1.3:
		text = "Strong irradiation. Useful energy does not establish exposed-life viability."
	if data.get("activity_band", "") == "HIGH":
		text += "\n\nActive star: investigate particle and photon exposure separately."
	if data.has("ice_factor") and data.ice_factor < 0.4:
		text += "\n\nSparse accessible ice. A refuge's initial water will not last indefinitely."
	return text

func system_name(id: String) -> String:
	return session.expedition.system_name(id)

func latest_observation(data: Dictionary) -> String:
	var latest: Dictionary = {}
	var name := ""
	for method in data.records:
		var record: Dictionary = data.records[method]
		if latest.is_empty() or record.received_hour > latest.received_hour:
			latest = record
			name = Prospects.CONFIG.observations[method].label
	if latest.is_empty():
		return "Catalogue only. Bounds are illustrative uncertainty ranges, not confidence percentages."
	return "%s: received %.2f, source epoch %.2f.\nArchived evidence; source conditions are static in this slice." % [name, 2400.0 + latest.received_hour / 8766.0, 2400.0 + latest.source_hour / 8766.0]

func observe(method: String) -> void:
	var outcome: Dictionary = session.observe(selected, method)
	status.text = outcome.message
	if outcome.ok:
		save()
	refresh()

func request_travel() -> void:
	var quote: Dictionary = session.expedition.travel_quote(selected)
	travel_dialog.dialog_text = "Destination: %s\n%.2f light years; %d years pass everywhere.\nCost: %.1f fuel, %.1f propellant, %.1f integrity.\n\n%s\n\nLocal industry keeps working. Surface modules remain committed. Arrival does not establish habitability." % [system_name(selected), quote.distance_ly, quote.years, quote.fuel_cost, quote.propellant_cost, quote.wear, route.text]
	travel_dialog.popup_centered(Vector2i(580, 400))

func travel() -> void:
	var outcome: Dictionary = session.command("travel", selected)
	status.text = outcome.message
	if outcome.ok:
		save()
	refresh()

func save() -> void:
	var outcome: Dictionary = session.save_disk()
	if not outcome.ok:
		status.text = outcome.message

func open_orbit() -> void:
	save()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func open_surface() -> void:
	if not session.site_available(selected + "_b"):
		return
	session.surface_body = selected + "_b"
	save()
	get_tree().change_scene_to_file("res://scenes/surface.tscn")

func set_tab(show_evidence: bool) -> void:
	details_tab = show_evidence
	overview.visible = not show_evidence
	evidence_page.visible = show_evidence
	UI.selected(tabs[0], not show_evidence)
	UI.selected(tabs[1], show_evidence)

func request_reset() -> void:
	seed_input.value = session.prospects.state.seed + 1
	reset_dialog.popup_centered(Vector2i(470, 220))

func new_expedition() -> void:
	session.reset(int(seed_input.value))
	selected = "prospect_0"
	status.text = "New neighbourhood generated. No observation rerolls a world within an expedition."
	save()
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		open_orbit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func show_help() -> void:
	UI.text_dialog(self, "Star chart", "Select a star to compare its route and evidence.\n\nOrbit fit measures received sunlight.\nSpectrum investigates the atmosphere.\nActivity watch samples stellar variability.\nLocal probe unlocks a landing region after arrival.\n\nObservations consume the displayed time and supplies.\nReview transit shows the full commitment before departure.\nEvidence contains dated readings and model limits.\n\nNew expeditions and neighbourhood seeds are in Menu.")
