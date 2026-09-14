extends Control

const Simulation = preload("res://scripts/simulation.gd")
const Session = preload("res://scripts/session.gd")
const SpaceView = preload("res://scripts/space_view.gd")
const SAVE_PATH := "user://expedition.json"
const INK := Color("d5e1e6")
const MUTED := Color("829ba8")
const TEAL := Color("91d6cc")
const GOLD := Color("e5bd85")

var session = Session.get_shared()
var sim = session.expedition
var selected := "eir_iii"
var chart := false
var status: Label
var year_label: Label
var objective_label: Label
var heading: Label
var subtitle: Label
var telemetry: Label
var resources: Label
var journal: RichTextLabel
var body_list: VBoxContainer
var operations: VBoxContainer
var transit: VBoxContainer
var view: SpaceView
var travel_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var milestone_dialog: AcceptDialog

func _ready() -> void:
	build_theme()
	build_interface()
	# Smoke tests start from a known state without touching a player's save.
	if not session.initialized:
		var loaded: Dictionary = session.load_disk()
		status.text = loaded.message
	selected = session.default_body()
	refresh()

func box(color: Color, border: Color = Color("293f4b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func build_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("536c79"))
	theme.set_stylebox("normal", "Button", box(Color("101e29")))
	theme.set_stylebox("hover", "Button", box(Color("1d3441"), TEAL))
	theme.set_stylebox("pressed", "Button", box(Color("294650"), TEAL))
	theme.set_stylebox("disabled", "Button", box(Color("0a141e"), Color("192b35")))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD))
	theme.set_stylebox("panel", "PanelContainer", box(Color("0b1620")))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 16)

func label_node(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func wrapped(text: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var node := label_node(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func button(text: String, callback: Callable, node_name: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if node_name != "":
		node.name = node_name
	node.pressed.connect(callback)
	return node

func build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := label_node("COMMANDER SPACEMAN", 25, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(label_node("SPACESHIP  /  BRAINCAST 01", 13, TEAL))
	year_label = label_node("", 18, GOLD)
	header.add_child(year_label)
	root.add_child(label_node("F I R S T   R A I N     /     E X P E D I T I O N   P R O T O T Y P E", 12, MUTED))
	root.add_child(HSeparator.new())
	resources = label_node("", 15, INK)
	root.add_child(resources)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 205
	columns.add_child(left)
	left.add_child(label_node("NAVIGATION", 12, MUTED))
	left.add_child(button("Orbital observation", func(): chart = false; refresh(), "Orbit"))
	left.add_child(button("Prospects / observatory →", open_prospects, "Prospects"))
	left.add_child(button("First Rain route", show_legacy_chart, "Chart"))
	left.add_child(HSeparator.new())
	left.add_child(label_node("LOCAL BODIES", 12, MUTED))
	body_list = VBoxContainer.new()
	left.add_child(body_list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(wrapped("You are the ship.\nThe factories are your hands.\nTime is what you leave behind.", 14))
	left.add_child(button("Save expedition", save_game, "Save"))
	left.add_child(button("Load expedition", load_game, "Load"))
	left.add_child(button("New expedition", func(): reset_dialog.popup_centered(), "New"))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	heading = label_node("", 38, INK)
	center.add_child(heading)
	subtitle = wrapped("", 14)
	subtitle.custom_minimum_size.y = 42
	center.add_child(subtitle)
	view = SpaceView.new()
	view.custom_minimum_size = Vector2(200, 220)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(view)
	telemetry = wrapped("", 16, TEAL)
	telemetry.custom_minimum_size.y = 65
	center.add_child(telemetry)
	var time_controls := HBoxContainer.new()
	center.add_child(time_controls)
	for years in [1, 10, 50]:
		var time_button := button("+%d yr" % years, advance_time.bind(years), "Wait%d" % years)
		time_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_controls.add_child(time_button)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 326
	columns.add_child(right_panel)
	var scroll := ScrollContainer.new()
	var right_stack := VBoxContainer.new()
	right_panel.add_child(right_stack)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_stack.add_child(scroll)
	operations = VBoxContainer.new()
	operations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(operations)
	transit = VBoxContainer.new()
	right_stack.add_child(transit)
	var objective_panel := PanelContainer.new()
	root.add_child(objective_panel)
	objective_label = wrapped("", 15, GOLD)
	objective_panel.add_child(objective_label)
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	bottom.add_child(label_node("SHIP'S MEMORY", 12, MUTED))
	status = label_node("Simulation paused. Advance years when you are ready.", 12, TEAL)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(status)
	journal = RichTextLabel.new()
	journal.custom_minimum_size.y = 95
	journal.add_theme_font_size_override("normal_font_size", 14)
	journal.scroll_following = true
	root.add_child(journal)
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.title = "Commit to interstellar transit"
	travel_dialog.ok_button_text = "Begin transit"
	travel_dialog.confirmed.connect(func(): act("travel"))
	add_child(travel_dialog)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Start another expedition?"
	reset_dialog.dialog_text = "This replaces your current expedition and its autosave."
	reset_dialog.confirmed.connect(func(): session.reset(); selected = "eir_iii"; chart = false; refresh(); autosave())
	add_child(reset_dialog)
	milestone_dialog = AcceptDialog.new()
	milestone_dialog.title = "FIRST RAIN"
	milestone_dialog.dialog_text = "There is rain on Eir III.\n\nI remember the idea of its smell.\n\nYour expedition continues. You can now seed the world with pioneer life."
	add_child(milestone_dialog)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func refresh() -> void:
	var state: Dictionary = sim.state
	var ship: Dictionary = state.ship
	year_label.text = "YEAR %d" % state.year
	resources.text = "FUEL  %.1f     /     PROPELLANT  %.1f     /     ALLOY  %.1f     /     INTEGRITY  %.0f%%     /     FACTORIES ABOARD  %d     /     SEEDS  %d" % [ship.fuel, ship.propellant, ship.alloy, ship.integrity, ship.modules, ship.seeds]
	objective_label.text = sim.objective()
	if session.sites.has("eir_iii") and session.sites.eir_iii.state.landed:
		objective_label.text = "FIRST FOOTHOLD  /  Your Eir III installation persists. Manage its production locally, or leave and return to the consequences."
	if session.prospects.worlds.has(state.system):
		objective_label.text = "PROSPECTS  /  Probe the candidate world, establish surface industry or harvest ship supplies from its companion. Return to the observatory when you are ready to choose another destination."
	clear_children(body_list)
	for definition in sim.scenario.bodies:
		if definition.system != state.system:
			continue
		var id: String = definition.id
		var item := button(("•  " if selected == id and not chart else "") + definition.name, select_body.bind(id), "Select_" + id)
		body_list.add_child(item)
	var body: Dictionary = sim.known_body(selected)
	if chart:
		heading.text = "The long way home"
		subtitle.text = "EIR  /  VESPER     ·     Two stars. One continuous mind."
		var known: Dictionary = sim.known_body("eir_iii")
		telemetry.text = "CRUISE  0.07 c   /   TRANSIT  %d years\nEir III: last observation, year %d. %s" % [sim.travel_quote().years, sim.state.observations.eir_iii.year, "Surface telemetry requires a survey." if not known.surveyed else "%.1f K · %.0f%% surface water" % [known.temperature, known.water * 100.0]]
	else:
		heading.text = body.get("name", "Unknown body")
		subtitle.text = body.get("description", "Awaiting observation.") if body.get("surveyed", false) else "ORBITAL CONTACT  /  Detailed survey pending."
		if body.get("surveyed", false):
			if body.kind == "world" and body.water > 0.15:
				subtitle.text = "An ocean world beneath gathering clouds. " + ("Pioneer life is finding its way." if body.seeded else "Liquid water. An atmosphere. The possibility of life.")
			if body.kind == "world" and body.temperature > 303.0:
				subtitle.text = "A world pushed beyond the seed archive's tolerances. The heat is hostile to pioneer life."
			telemetry.text = "%.1f K   /   %.0f%% SURFACE WATER   /   %.1f%% BIOSPHERE\n%s  ·  %.1f accessible feedstock" % [body.temperature, body.water * 100.0, body.biomass * 100.0, "NO SURFACE INDUSTRY" if body.factory == "" else body.factory.to_upper() + " FACTORY", body.deposit]
			if session.site_available(selected) and session.sites.has(selected) and session.sites[selected].state.landed:
				telemetry.text = "%.1f K   /   SPATIAL INDUSTRY ACTIVE\n%d installations · protected local culture, not planetary terraforming" % [body.temperature, session.sites[selected].state.structures.size()]
		else:
			telemetry.text = "Unresolved composition.\nDeploy a survey probe before making plans."
	if body.get("generated", false) and body.kind == "world" and body.surveyed:
		var known: Dictionary = session.prospects.evidence(body.system)
		subtitle.text = "LOCAL PROBE  /  Climate and native life unresolved. Globe is a schematic reconstruction."
		telemetry.text = "IRRADIANCE %.2f–%.2f EARTH  /  GRAVITY %.2f g\nPRESSURE %.2f bar  /  MAGNETIC FIELD %.2f Earth · geometry unresolved" % [known.flux_low, known.flux_high, known.gravity, known.pressure, known.field_earth]
	view.show_body(body, chart, state.system)
	refresh_operations(body)
	journal.clear()
	var entries: Array = sim.known_log()
	for entry in entries.slice(maxi(0, entries.size() - 30)):
		journal.append_text("%d   /   %s\n" % [entry.year, entry.text])

func select_body(id: String) -> void:
	selected = id
	chart = false
	refresh()

func action_button(text: String, action: String, disabled: bool = false, hint: String = "") -> void:
	var node := button(text, act.bind(action), "Action_" + action)
	node.disabled = disabled
	node.tooltip_text = hint
	operations.add_child(node)

func refresh_operations(body: Dictionary) -> void:
	clear_children(operations)
	operations.add_child(label_node("COMMAND AUTHORITY", 12, TEAL))
	if not chart and not body.is_empty():
		operations.add_child(label_node(body.name, 23))
		if session.site_available(selected):
			operations.add_child(button("Surface operations  /  3D →", open_surface, "Surface"))
			operations.add_child(wrapped("FIRST FOOTHOLD: survey, build and maintain a real surface installation.", 13, TEAL))
		if not body.surveyed:
			operations.add_child(wrapped("Characterise resources, climate, and the possibility of a living future."))
			action_button("Survey body", "survey")
		elif body.get("generated", false) and body.kind == "world":
			operations.add_child(wrapped("The local probe has mapped a candidate landing region. Use the prospect dossier to assess illumination, radiation evidence and resources. Global interventions are a later milestone.", 14))
		elif body.factory == "":
			var has_surface: bool = session.sites.has(selected) and session.sites[selected].state.landed
			if has_surface:
				operations.add_child(wrapped("A module is committed to the surface sector. Its work continues during orbital time advances and travel. Surface recovery and freight are not yet implemented.", 14))
			else:
				operations.add_child(wrapped("Factory modules carry their own power and automation. Legacy orbital factories remain here until reclaimed."))
				action_button("Land orbital-policy factory", "deploy", sim.state.ship.modules < 1, "Legacy climate/mining abstraction. Use Surface operations for spatial industry.")
		else:
			operations.add_child(wrapped("Autonomous industry active. Work continues until local feedstock runs out."))
			if body.factory == "warming":
				operations.add_child(label_node("EQUILIBRIUM TARGET", 12, MUTED))
				var policy := OptionButton.new()
				policy.name = "Policy"
				policy.custom_minimum_size.y = 40
				policy.add_item("288 K  /  Temperate")
				policy.add_item("300 K  /  Warm")
				policy.add_item("325 K  /  Extreme")
				policy.select([288.0, 300.0, 325.0].find(body.target))
				policy.item_selected.connect(func(index: int): act("policy", [288.0, 300.0, 325.0][index]))
				operations.add_child(policy)
				operations.add_child(wrapped("Emissions stop at the target, then replace atmospheric losses. The surface warms gradually.", 14))
				if body.target > 303.0:
					operations.add_child(wrapped("Extreme heat is hostile to the seed archive's organisms.", 14, GOLD))
			else:
				operations.add_child(wrapped("STORES\n%.1f fuel · %.1f propellant\n%.1f alloy" % [body.stock.fuel, body.stock.propellant, body.stock.alloy], 15, TEAL))
				action_button("Collect manufactured supplies", "collect", body.stock.fuel + body.stock.propellant + body.stock.alloy <= 0.0)
				action_button("Build factory  /  5 yr", "build", sim.state.ship.alloy < 20.0 or sim.state.ship.fuel < 3.0, "Costs 20 onboard alloy and 3 reactor fuel.")
				action_button("Repair ship  /  2 yr", "repair", sim.state.ship.alloy < 10.0 or sim.state.ship.integrity >= 100.0, "Costs 10 alloy; restores up to 25 integrity.")
				operations.add_child(wrapped("Build: 20 alloy + 3 fuel\nRepair: 10 alloy → +25 integrity", 13))
			action_button("Reclaim factory & stores", "reclaim")
		if body.surveyed and body.kind == "world" and not body.get("generated", false):
			operations.add_child(HSeparator.new())
			if body.seeded:
				operations.add_child(wrapped("Pioneer life introduced. Advance time to observe its growth—or decline.", 14, TEAL))
			else:
				action_button("Release pioneer life", "seed", body.temperature < 273.0 or body.temperature > 303.0 or body.water < 0.1 or sim.state.ship.seeds < 1, "Requires 273–303 K, liquid water, and one seed archive.")
				operations.add_child(wrapped("Life requires 273–303 K and liquid water.", 13))
	else:
		operations.add_child(label_node("Departure window", 23))
		operations.add_child(wrapped("Travel advances every factory and every world. Your memory of a remote world stays at its last local observation."))
	clear_children(transit)
	transit.add_child(HSeparator.new())
	var destination: String = "Vesper" if sim.state.system == "eir" else "Eir"
	var quote: Dictionary = sim.travel_quote()
	transit.add_child(wrapped("TRANSIT TO %s\n%d years · %.1f fuel · %.1f propellant\n%.1f integrity consumed" % [destination.to_upper(), quote.years, quote.fuel_cost, quote.propellant_cost, quote.wear], 14, GOLD))
	var travel := button("Depart for " + destination + " →", request_travel, "Depart")
	travel.disabled = sim.state.ship.fuel < quote.fuel_cost or sim.state.ship.propellant < quote.propellant_cost or sim.state.ship.integrity <= maxf(20.0, quote.wear)
	transit.add_child(travel)
	if travel.disabled:
		transit.add_child(wrapped("Insufficient transit reserves. Collect supplies or repair at a local factory.", 13, GOLD))

func act(action: String, value: float = 288.0) -> void:
	var was_complete: bool = sim.state.first_rain
	var outcome: Dictionary = session.command(action, "" if action == "travel" else selected, value)
	status.text = outcome.message
	if outcome.ok:
		if action == "travel":
			selected = session.default_body()
			chart = false
		refresh()
		autosave()
		if sim.state.first_rain and not was_complete:
			milestone_dialog.popup_centered(Vector2i(510, 240))

func advance_time(years: int) -> void:
	session.advance_years(years)
	status.text = "%d years elapsed. Local observations updated." % years
	refresh()
	autosave()

func request_travel() -> void:
	var abandoned: Array[String] = []
	for body in sim.state.bodies.values():
		if body.system == sim.state.system and body.factory != "":
			abandoned.append(body.name + " (" + body.factory + ")")
		if body.system == sim.state.system and session.sites.has(body.id) and session.sites[body.id].state.landed:
			abandoned.append(body.name + " (surface installation; finite stores)")
	var quote: Dictionary = sim.travel_quote()
	travel_dialog.dialog_text = "%d years will pass.\nCost: %.1f reactor fuel, %.1f propellant, %.1f integrity.\n\nFactories left working: %s\n\nReturn travel has the same cost. Supplies are collected locally." % [quote.years, quote.fuel_cost, quote.propellant_cost, quote.wear, ", ".join(abandoned) if not abandoned.is_empty() else "none"]
	travel_dialog.popup_centered(Vector2i(590, 250))

func autosave() -> void:
	if not "--smoke" in OS.get_cmdline_user_args():
		write_save(false)

func save_game() -> void:
	write_save(true)

func write_save(announce: bool) -> void:
	var outcome: Dictionary = session.save_disk()
	if announce or not outcome.ok:
		status.text = outcome.message

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		status.text = "No saved expedition yet."
		return
	var outcome: Dictionary = session.restore_json(FileAccess.get_file_as_string(SAVE_PATH))
	status.text = outcome.message
	if outcome.ok:
		selected = session.default_body()
		refresh()

func open_surface() -> void:
	if not session.site_available(selected):
		return
	session.surface_body = selected
	get_tree().change_scene_to_file("res://scenes/surface.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func open_prospects() -> void:
	get_tree().change_scene_to_file("res://scenes/prospects.tscn")

func show_legacy_chart() -> void:
	if sim.state.system not in ["eir", "vesper"]:
		open_prospects()
		return
	chart = true
	refresh()
