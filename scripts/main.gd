extends Control

const UI = preload("res://scripts/interface.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Session = preload("res://scripts/session.gd")
const SpaceView = preload("res://scripts/space_view.gd")
const Nav = preload("res://scripts/navigation.gd")
const SAVE_PATH := "user://expedition.json"
const INK := Color("d5e1e6")
const MUTED := Color("829ba8")
const TEAL := Color("91d6cc")
const GOLD := Color("e5bd85")

var session = Session.get_shared()
var sim = session.expedition
var selected := "eir_iii"
var status: Label
var year_label: Label
var heading: Label
var subtitle: Label
var telemetry: Label
var resources: Label
var body_list: HBoxContainer
var operations: VBoxContainer
var view: SpaceView
var industry_open := false
var milestone_dialog: AcceptDialog

func _ready() -> void:
	build_theme()
	build_interface()
	# Smoke tests start from a known state without touching a player's save.
	if not session.initialized:
		var loaded: Dictionary = session.load_disk()
		status.text = loaded.message
	selected = session.orbit_body if not sim.local_body(session.orbit_body).is_empty() else session.default_body()
	refresh()
	Nav.arrive(self, view, view.globe.position + view.globe.size * 0.5)


func build_theme() -> void:
	UI.install(self)



func button(text: String, callback: Callable, node_name: String = "") -> Button:
	return UI.button(text, callback, node_name)

func build_interface() -> void:
	add_child(preload("res://scripts/space_backdrop.gd").new())
	view = SpaceView.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 28
	view.offset_top = 132
	view.offset_right = -410
	view.offset_bottom = -132
	var nav := UI.header(self)
	nav.add_child(button("Star chart", open_prospects, "Prospects"))
	nav.add_child(button("System", open_system, "SystemView"))
	nav.add_child(UI.label("/  Orbit", 16, TEAL))
	UI.spacer(nav)
	nav.add_child(UI.label("Spaceship", 14, MUTED))
	UI.menu(self, nav, [["Save expedition", save_game, "Save"], ["Load expedition", load_game, "Load"], ["Ship's journal", show_journal, "Journal"], ["Controls & help", show_help, "Help"]])
	resources = UI.label("", 15, MUTED)
	UI.mount(self, Control.PRESET_TOP_WIDE, Vector4(28, 87, -24, 118)).add_child(resources)
	var scene := UI.column(UI.mount(self, Control.PRESET_FULL_RECT, Vector4(28, 140, -410, -112)), 14)
	body_list = HBoxContainer.new()
	body_list.name = "LocalBodies"
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "OrbitBodiesScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.custom_minimum_size.y = 56
	scene.add_child(body_scroll)
	body_scroll.add_child(body_list)
	heading = UI.label("", 36)
	scene.add_child(heading)
	subtitle = UI.label("", 16, MUTED, true)
	subtitle.custom_minimum_size.x = 222
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scene.add_child(subtitle)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.custom_minimum_size = Vector2(240, 220)
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.add_child(space)
	telemetry = UI.label("", 18, TEAL, true)
	scene.add_child(telemetry)
	var inspector := UI.inspector(self)
	operations = UI.scroll(inspector, "OrbitInspectorScroll")
	var footer := UI.footer(self)
	var time := UI.row(footer)
	year_label = UI.label("", 16, GOLD)
	time.add_child(year_label)
	UI.spacer(time)
	time.add_child(UI.label("Advance time", 14, MUTED))
	for years in [1, 10, 50]:
		time.add_child(button("+%d yr" % years, advance_time.bind(years), "Wait%d" % years))
	status = UI.status(footer)
	milestone_dialog = AcceptDialog.new()
	milestone_dialog.title = "First rain"
	milestone_dialog.dialog_text = "There is rain on Eir III.\n\nI remember the idea of its smell.\n\nYour expedition continues. Pioneer life can now be introduced."
	add_child(milestone_dialog)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func refresh() -> void:
	var state: Dictionary = sim.state
	var ship: Dictionary = state.ship
	year_label.text = "Year %d + %d h · Paused" % [state.year, session.fractional_hours]
	resources.text = "Fuel %.1f    ·    Propellant %.1f    ·    Alloy %.1f    ·    Hull %.0f%%    ·    Modules %d    ·    Archives %d" % [ship.fuel, ship.propellant, ship.alloy, ship.integrity, ship.modules, ship.seeds]
	clear_children(body_list)
	for definition in sim.scenario.bodies:
		if definition.system != state.system:
			continue
		var id: String = definition.id
		var item := button(("•  " if selected == id else "") + definition.name, select_body.bind(id), "Select_" + id)
		UI.selected(item, selected == id)
		body_list.add_child(item)
	var body: Dictionary = sim.known_body(selected)
	heading.text = body.get("name", "Unknown body")
	subtitle.text = body.get("description", "Awaiting observation.") if body.get("surveyed", false) else "Orbital contact · Unsurveyed"
	if body.get("surveyed", false):
		if body.kind == "world" and body.water > 0.15:
			subtitle.text = "An ocean world beneath gathering clouds. " + ("Pioneer life is finding its way." if body.seeded else "Liquid water. An atmosphere. The possibility of life.")
		if body.kind == "world" and body.temperature > 303.0:
			subtitle.text = "A world pushed beyond the seed archive's tolerances. The heat is hostile to pioneer life."
		telemetry.text = "%.1f K   /   %.0f%% SURFACE WATER   /   %.1f%% BIOSPHERE\n%s  ·  %.1f accessible feedstock" % [body.temperature, body.water * 100.0, body.biomass * 100.0, "NO SURFACE INDUSTRY" if body.factory == "" else body.factory.to_upper() + " FACTORY", body.deposit]
		if session.site_available(selected) and session.sites.has(selected) and session.sites[selected].state.landed:
			telemetry.text = "%.1f K   /   SPATIAL INDUSTRY ACTIVE\n%d installations · protected local culture, not planetary terraforming" % [body.temperature, session.sites[selected].state.structures.size()]
	else:
		telemetry.text = "Composition unresolved"
	if body.get("generated", false) and body.kind == "world" and body.surveyed:
		var known: Dictionary = session.prospects.body_evidence(body.id)
		subtitle.text = "LOCAL PROBE  /  Climate and native life unresolved. Globe is a schematic reconstruction."
		telemetry.text = "IRRADIANCE %.2f–%.2f EARTH  /  GRAVITY %.2f g\nPRESSURE %.2f bar  /  MAGNETIC FIELD %.2f Earth · geometry unresolved" % [known.flux_low, known.flux_high, known.gravity, known.pressure, known.field_earth]
		body = body.duplicate(true)
		body.pressure = known.pressure
	view.show_body(body)
	refresh_operations(body)

func select_body(id: String) -> void:
	selected = id
	session.orbit_body = id
	industry_open = false
	refresh()

func action_button(text: String, action: String, disabled: bool = false, hint: String = "") -> void:
	var node := UI.button(text, act.bind(action), "Action_" + action, action in ["survey", "deploy", "collect", "seed"])
	node.disabled = disabled
	node.tooltip_text = hint
	operations.add_child(node)

func refresh_operations(body: Dictionary) -> void:
	clear_children(operations)
	if body.is_empty(): return
	operations.add_child(UI.label("WORLD OPERATIONS", 13, MUTED))
	if not body.surveyed:
		operations.add_child(UI.label("Resolve the unknown", 23))
		operations.add_child(UI.label("Survey this body to identify resources and available operations.", 16, MUTED, true))
		action_button("Survey body →", "survey")
		return
	var has_surface: bool = session.body_has_industry(selected)
	if session.site_available(selected):
		operations.add_child(UI.label("Surface access", 23))
		operations.add_child(UI.label("Your installation is operating here." if has_surface else "A landing region is mapped. Choose a site for a factory module.", 16, MUTED, true))
		operations.add_child(UI.button("Continue surface operations →" if has_surface else "Choose a landing site →", open_surface, "Surface", true))
	if body.get("generated", false) and body.kind == "world":
		operations.add_child(UI.label("Local probe acquired", 15, TEAL))
		operations.add_child(UI.label("Detailed evidence is in the star chart. Environmental trials are managed at the surface.", 15, MUTED, true))
		return
	if body.factory == "" and not has_surface:
		if body.kind != "world":
			operations.add_child(UI.label("Establish supply industry", 23))
			operations.add_child(UI.label("Deploy an autonomous module to manufacture ship supplies from local feedstock.", 16, MUTED, true))
			action_button("Deploy factory module", "deploy", sim.state.ship.modules < 1, "Consumes one onboard factory module.")
		else:
			var expand := button("Orbital industry  " + ("−" if industry_open else "+"), toggle_industry, "OrbitalIndustry")
			operations.add_child(expand)
			if industry_open:
				operations.add_child(UI.label("The original climate programme occupies this region until reclaimed. Choose surface operations for spatial construction.", 15, MUTED, true))
				action_button("Deploy climate factory", "deploy", sim.state.ship.modules < 1)
	elif body.factory != "":
		operations.add_child(UI.label("Climate programme" if body.factory == "warming" else "Supply industry", 23))
		if body.factory == "warming":
			operations.add_child(UI.label("Equilibrium target", 15, MUTED))
			var policy := OptionButton.new()
			policy.name = "Policy"
			policy.custom_minimum_size.y = 42
			for value in ["288 K · Temperate", "300 K · Warm", "325 K · Extreme"]: policy.add_item(value)
			policy.select([288.0, 300.0, 325.0].find(body.target))
			policy.item_selected.connect(func(index: int): act("policy", [288.0, 300.0, 325.0][index]))
			operations.add_child(policy)
			operations.add_child(UI.label("The surface responds gradually. Life needs 273–303 K and liquid water.", 15, MUTED, true))
			if not body.seeded:
				action_button("Introduce pioneer life", "seed", body.temperature < 273 or body.temperature > 303 or body.water < 0.1 or sim.state.ship.seeds < 1, "Requires liquid water, 273–303 K, and one archive packet.")
			else: operations.add_child(UI.label("Pioneer life established", 16, TEAL))
		else:
			operations.add_child(UI.label("Stored for collection\n%.1f fuel · %.1f propellant · %.1f alloy" % [body.stock.fuel, body.stock.propellant, body.stock.alloy], 16, TEAL, true))
			action_button("Collect supplies", "collect", body.stock.fuel + body.stock.propellant + body.stock.alloy <= 0)
			action_button("Build module · 5 yr", "build", sim.state.ship.alloy < 20 or sim.state.ship.fuel < 3, "20 onboard alloy + 3 fuel")
			action_button("Repair ship · 2 yr", "repair", sim.state.ship.alloy < 10 or sim.state.ship.integrity >= 100, "10 alloy restores up to 25 hull integrity")
		operations.add_child(HSeparator.new())
		action_button("Reclaim factory & stores", "reclaim")
	elif has_surface:
		operations.add_child(UI.label("The surface module remains committed. Its work continues while Spaceship is away.", 15, MUTED, true))

	if body.kind == "world" and not body.get("generated", false) and body.factory != "warming" and not body.seeded and body.temperature >= 273 and body.temperature <= 303 and body.water >= 0.1:
		operations.add_child(HSeparator.new())
		action_button("Introduce pioneer life", "seed", sim.state.ship.seeds < 1, "Consumes one archive packet.")

func act(action: String, value: float = 288.0) -> void:
	var was_complete: bool = sim.state.first_rain
	var outcome: Dictionary = session.command(action, "" if action == "travel" else selected, value)
	status.text = outcome.message
	if outcome.ok:
		if action == "travel":
			selected = session.default_body()
		refresh()
		autosave()
		if sim.state.first_rain and not was_complete:
			milestone_dialog.popup_centered(Vector2i(510, 240))

func advance_time(years: int) -> void:
	session.advance_years(years)
	status.text = "%d years elapsed. Local observations updated." % years
	refresh()
	autosave()


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
	if session.surface_body != selected: session.surface_region = Session.Atlas.DEFAULT_REGION
	session.surface_body = selected
	Nav.go(self, "res://scenes/regions.tscn", view.position + view.size * 0.5, true)

func _unhandled_key_input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func open_prospects() -> void:
	session.viewed_system = sim.state.system
	session.chart_center = sim.system_position(sim.state.system)
	Nav.go(self, "res://scenes/prospects.tscn", view.position + view.size * 0.5, false)


func toggle_industry() -> void:
	industry_open = not industry_open
	refresh()

func show_journal() -> void:
	var lines: Array[String] = [sim.objective(), ""]
	for entry in sim.known_log(): lines.append("%d  /  %s" % [entry.year, entry.text])
	UI.text_dialog(self, "Ship's journal", "\n".join(lines))

func show_help() -> void:
	UI.text_dialog(self, "Orbit", "Select a local body, then survey or operate it.\n\nStar chart: observe distant systems and plan travel.\nSurface access: choose and manage a landing region.\nTime controls: advance the whole expedition in years.\n\nChanges autosave. Save, load and the journal are in Menu.\nF11 toggles fullscreen.")

func open_system() -> void:
	session.viewed_system = sim.state.system
	session.orbit_body = selected
	Nav.go(self, "res://scenes/system.tscn", view.position + view.size * 0.5, false)
