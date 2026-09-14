extends Control
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

func skin(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_bottom = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func button(text: String, callback: Callable, node_name: String) -> Button:
	var node := Button.new()
	node.name = node_name
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_disabled_color", Color("526974"))
	node.add_theme_stylebox_override("normal", skin(Color("101e27"), Color("39515d")))
	node.add_theme_stylebox_override("hover", skin(Color("1c333c"), CYAN))
	node.add_theme_stylebox_override("pressed", skin(Color("233c43"), AMBER))
	node.add_theme_stylebox_override("disabled", skin(Color("0c151e"), Color("23313b")))
	node.pressed.connect(callback)
	return node

func area(preset: int, offsets: Vector4) -> MarginContainer:
	var node := MarginContainer.new()
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func stack(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", 12)
	parent.add_child(node)
	return node

func wrapped(text: String, font_size: int = 14, color: Color = INK) -> Label:
	var node := label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func build_interface() -> void:
	map = Map.new()
	map.name = "ProspectMap"
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.selected_system.connect(select_system)
	var top := stack(area(Control.PRESET_TOP_WIDE, Vector4(28, 24, -28, 110)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var brand := label("SPACEMAN   /   PROSPECTS", 26)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	row.add_child(button("LOCAL ORBIT  /  ESC", open_orbit, "LocalOrbit"))
	row.add_child(button("NEW EXPEDITION", request_reset, "NewProspects"))
	clock = label("", 12, CYAN)
	top.add_child(clock)
	resources = label("", 14)
	top.add_child(resources)
	var left_scroll := ScrollContainer.new()
	left_scroll.name = "AssessmentScroll"
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area(Control.PRESET_LEFT_WIDE, Vector4(28, 150, 267, -220)).add_child(left_scroll)
	var left := stack(left_scroll)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(label("THE LONG VIEW", 12, AMBER))
	left.add_child(wrapped("Observe first.\nCommit years later.", 21))
	left.add_child(wrapped("Select a star. Spend instrument time to investigate its possibilities.", 14, MUTED))
	left.add_child(label("TRANSIT ESTIMATE", 12, AMBER))
	route = wrapped("", 15)
	left.add_child(route)
	left.add_child(label("ASSESSMENT", 12, AMBER))
	decision = wrapped("", 14, CYAN)
	left.add_child(decision)
	var right := stack(area(Control.PRESET_RIGHT_WIDE, Vector4(-317, 150, -28, -220)))
	title = label("", 28)
	right.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "DossierScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	dossier = wrapped("", 14)
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dossier)
	provenance = wrapped("", 11, MUTED)
	right.add_child(provenance)
	surface = button("SURFACE OPERATIONS  /  3D →", open_surface, "ProspectSurface")
	right.add_child(surface)
	var bottom := stack(area(Control.PRESET_BOTTOM_WIDE, Vector4(28, -200, -28, -22)))
	bottom.add_child(label("OBSERVING PROGRAMMES     /     SHIP TIME AND REACTOR FUEL ARE COMMITTED IMMEDIATELY", 11, MUTED))
	var tools_row := HBoxContainer.new()
	tools_row.name = "ObservationTools"
	tools_row.add_theme_constant_override("separation", 5)
	bottom.add_child(tools_row)
	for method in ["photometry", "spectrum", "monitor", "probe"]:
		var data: Dictionary = Prospects.CONFIG.observations[method]
		var node := button("%s\n%d h · %.2f fuel%s" % [data.label.to_upper(), data.hours, data.fuel, " · 1 alloy" if data.alloy > 0 else ""], observe.bind(method), "Observe_" + method)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.custom_minimum_size.y = 62
		tools_row.add_child(node)
		observe_buttons[method] = node
	depart = button("COMMIT TRANSIT →", request_travel, "ProspectDepart")
	depart.custom_minimum_size.x = 185
	tools_row.add_child(depart)
	status = wrapped("A catalogue is not a habitability verdict. Surface resources require a local probe.", 14, CYAN)
	bottom.add_child(status)
	bottom.add_child(label("PLANAR NEIGHBOURHOOD · DISTANCES IN LIGHT YEARS    /    PHOTONS CARRY OLD NEWS    /    STARS AND WORLDS ARE SYNTHETIC", 10, MUTED))
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
	clock.text = "BRAINCAST 01   /   YEAR %d + %d h   /   NEIGHBOURHOOD %d   /   CURRENT SYSTEM: %s" % [session.expedition.state.year, session.fractional_hours, session.prospects.state.seed, system_name(session.expedition.state.system)]
	resources.text = "REACTOR FUEL  %.2f     /     PROPELLANT  %.1f     /     ALLOY  %.1f     /     INTEGRITY  %.1f%%     /     MODULES ABOARD  %d" % [ship.fuel, ship.propellant, ship.alloy, ship.integrity, ship.modules]
	var data: Dictionary = session.prospects.evidence(selected)
	title.text = selected.to_upper() if data.is_empty() else data.planet_name.to_upper()
	for method in observe_buttons:
		var allowed: Dictionary = session.prospects.can_observe(selected, method, session.expedition.state.system)
		var cost: Dictionary = Prospects.CONFIG.observations[method]
		observe_buttons[method].disabled = not allowed.ok or ship.fuel < cost.fuel or ship.alloy < cost.alloy
		observe_buttons[method].tooltip_text = allowed.message
	surface.visible = not data.is_empty() and session.site_available(selected + "_b")
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
			dossier.text += "LOCAL PROBE\nGravity %.2f g\nPressure %.3f bar\nAtmospheric column %.0f kg/m²\nField strength %.2f Earth\nRotation: %s\n\nSolar yield %.2f×\nOre richness %.2f×\nAccessible ice %.2f×\n\n" % [data.gravity, data.pressure, data.atmospheric_column, data.field_earth, "synchronous" if data.locked else "non-synchronous", data.solar_factor, data.ore_factor, data.ice_factor]
			dossier.text += "RADIATION / LIFE\nSurface dose and native life unresolved. A field affects charged particles, not UV photons. A protected refuge is a separate goal."
		else:
			dossier.text += "GROUND TRUTH  /  UNKNOWN\nPressure, gravity, magnetic field, rotation, deposits and surface dose require local investigation."
		decision.text = assessment(data)
		provenance.text = latest_observation(data)
	var quote: Dictionary = session.expedition.travel_quote(selected)
	if selected == session.expedition.state.system:
		route.text = "LOCAL CONTACT\nNo interstellar transfer required.\nLaunch a probe or enter local orbit."
		depart.disabled = true
	else:
		route.text = "%.2f ly  /  %d years\n%.1f fuel  ·  %.1f propellant\n%.1f integrity\n\n" % [quote.distance_ly, quote.years, quote.fuel_cost, quote.propellant_cost, quote.wear]
		var return_ready: bool = ship.fuel >= quote.fuel_cost * 2 and ship.propellant >= quote.propellant_cost * 2 and ship.integrity - quote.wear > maxf(20, quote.wear)
		route.text += "Same-route return reserves available." if return_ready else "Return needs resupply or repairs. Plan local industry before committing modules."
		depart.disabled = not quote.valid or ship.fuel < quote.fuel_cost or ship.propellant < quote.propellant_cost or ship.integrity <= maxf(20, quote.wear)

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
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		open_orbit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
