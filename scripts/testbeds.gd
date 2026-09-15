extends Control
const UI = preload("res://scripts/interface.gd")
const Session = preload("res://scripts/session.gd")
const Model = preload("res://scripts/testbed_simulation.gd")
const Diagram = preload("res://scripts/trial_diagram.gd")
const INK := Color("dce7e1")
const MUTED := Color("8ca5af")
const CYAN := Color("91d1c3")
const AMBER := Color("e0b979")
var session = Session.get_shared()
var site: RefCounted
var structure: Dictionary = {}
var diagram: Control
var status: Label
var clock: Label
var inventory: Label
var conditions: Label
var diagnosis: Label
var trial_list: OptionButton
var trial_title: Label
var readings: Array[Label] = []
var pages: Array[VBoxContainer] = []
var control_tabs: Array[Button] = []
var control_tab := 0
var limits: Label
var empty_hint: Label
var control_content: VBoxContainer
var progress: Label
var buttons: Dictionary = {}
var speed := 0
var accumulated := 0.0
var save_elapsed := 0.0

func _ready() -> void:
	site = session.surface_for(session.surface_body)
	if site == null or site.environment.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	build_interface()
	refresh()



func button(value: String, callback: Callable, id: String) -> Button:
	var node := UI.button(value, callback, id)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons[id] = node
	return node





func build_interface() -> void:
	UI.install(self)
	var background := ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var nav := UI.header(self)
	nav.add_child(UI.button("Star chart", open_chart, "TrialChart"))
	nav.add_child(UI.button("Orbit", open_orbit, "TrialOrbit"))
	nav.add_child(UI.button("Surface", open_surface, "TrialSurface"))
	nav.add_child(UI.label("/  Field trial", 16, CYAN))
	UI.spacer(nav)
	nav.add_child(UI.label(session.expedition.state.bodies[session.surface_body].name, 16))
	var menu := UI.menu(self, nav, [["Save expedition", save, "SaveTrial"], ["Trial controls & model", show_help, "Help"]])
	menu.visibility_changed.connect(set_speed.bind(0))
	inventory = UI.label("", 15, MUTED)
	UI.mount(self, Control.PRESET_TOP_WIDE, Vector4(28, 87, -28, 120)).add_child(inventory)
	var scene := UI.column(UI.mount(self, Control.PRESET_FULL_RECT, Vector4(34, 143, -416, -114)), 16)
	var trial_row := UI.row(scene)
	trial_title = UI.label("Environmental testbed", 30)
	trial_row.add_child(trial_title)
	UI.spacer(trial_row)
	trial_list = OptionButton.new()
	trial_list.name = "TrialSelector"
	trial_list.custom_minimum_size.x = 160
	trial_list.item_selected.connect(func(index: int): select_trial(trial_list.get_item_id(index)))
	trial_row.add_child(trial_list)
	var metrics := UI.row(scene, 36)
	for metric in ["TEMPERATURE", "PRESSURE", "LIVE CULTURE"]:
		var cell := UI.column(metrics, 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UI.label(metric, 13, MUTED))
		var value := UI.label("—", 32)
		cell.add_child(value)
		readings.append(value)
	diagram = Diagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.custom_minimum_size = Vector2(300, 260)
	scene.add_child(diagram)
	var graph_tabs := UI.row(scene)
	graph_tabs.add_child(button("Chamber", show_chamber, "ViewChamber"))
	for metric in ["temperature", "pressure", "biomass"]:
		graph_tabs.add_child(button({"temperature":"Temperature", "pressure":"Pressure", "biomass":"Culture"}[metric], set_metric.bind(metric), "Graph_" + metric))
	var diagnosis_row := UI.row(scene)
	diagnosis = UI.label("", 17, AMBER, true)
	diagnosis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagnosis_row.add_child(diagnosis)
	diagnosis_row.add_child(UI.button("Inspect limits", select_controls.bind(2), "InspectLimits"))
	var inspector := UI.inspector(self)
	inspector.add_child(UI.label("Trial controls", 23))
	empty_hint = UI.label("Build a testbed on the surface to begin an experiment.", 17, MUTED, true)
	inspector.add_child(empty_hint)
	control_content = UI.column(inspector)
	control_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tabs := UI.row(control_content, 4)
	for caption in ["Climate", "Shielding", "Culture"]:
		var node := button(caption, select_controls.bind(control_tabs.size()), "Controls" + caption)
		node.add_theme_font_size_override("font_size", 14)
		tabs.add_child(node)
		control_tabs.append(node)
	var content := UI.scroll(control_content, "TrialControlsScroll")
	for index in range(3): pages.append(UI.column(content))
	var climate: VBoxContainer = pages[0]
	climate.add_child(UI.label("Thermal control · up to 4 kW", 15, MUTED))
	var thermal := UI.row(climate, 4)
	for mode in ["passive", "auto", "heat", "cool"]:
		var node := button(mode.capitalize(), order.bind("thermal", mode), "Thermal_" + mode)
		node.add_theme_font_size_override("font_size", 14)
		thermal.add_child(node)
	climate.add_child(UI.label("Target temperature", 14, MUTED))
	var targets := UI.row(climate, 4)
	for target in [278, 288, 303]: targets.add_child(button("%d K" % target, order.bind("target_k", float(target)), "Target_%d" % target))
	climate.add_child(HSeparator.new())
	climate.add_child(button("", flip.bind("pressure_control"), "PressureControl"))
	var pressures := UI.row(climate, 4)
	for target in [0.1, 0.3, 0.8]: pressures.add_child(button("%.1f bar" % target, order.bind("target_bar", target), "Pressure_%d" % int(target * 10)))
	climate.add_child(button("", flip.bind("feed_water"), "WaterFeed"))
	climate.add_child(UI.label("Setpoints change orders. Heat and gas move over time.", 15, MUTED, true))
	var shielding: VBoxContainer = pages[1]
	shielding.add_child(button("", flip.bind("lamp"), "GrowLight"))
	shielding.add_child(UI.label("Roof shade", 14, MUTED))
	var shades := UI.row(shielding, 4)
	for value in [0, 50, 90]: shades.add_child(button("%d%%" % value, order.bind("shade", value / 100.0), "Shade_%d" % value))
	shielding.add_child(button("UV filter · 8 h\n4 t metal · 1 t parts", order.bind("filter", null), "FitFilter"))
	shielding.add_child(button("Regolith canopy · 16 h\n4 t ore · 8 t metal · 2 t parts", order.bind("canopy", null), "FitCanopy"))
	shielding.add_child(UI.label("The canopy blocks most daylight. A sheltered culture may need powered lighting.", 15, MUTED, true))
	var culture: VBoxContainer = pages[2]
	culture.add_child(button("Inoculate · 1 archive", order.bind("inoculate", null), "Inoculate"))
	progress = UI.label("", 16, CYAN, true)
	culture.add_child(progress)
	culture.add_child(HSeparator.new())
	limits = UI.label("", 15, MUTED, true)
	culture.add_child(limits)
	culture.add_child(button("Outside measurements  +", toggle_readings, "OutsideReadings"))
	conditions = UI.label("", 15, MUTED, true)
	conditions.visible = false
	culture.add_child(conditions)
	var bottom := UI.footer(self)
	var toolbar := UI.row(bottom)
	toolbar.name = "TrialToolbar"
	clock = UI.label("", 16, AMBER)
	toolbar.add_child(clock)
	UI.spacer(toolbar)
	for rate in [0, 1, 10, 50]:
		var node := button("Pause" if rate == 0 else "%d×" % rate, set_speed.bind(rate), "TrialSpeed%d" % rate)
		node.size_flags_horizontal = Control.SIZE_SHRINK_END
		node.tooltip_text = "Pause [Space]" if rate == 0 else "%d simulated hours per second" % rate
		toolbar.add_child(node)
	for amount in [24, 168]:
		var node := button("+1 day" if amount == 24 else "+1 week", advance.bind(amount), "TrialDay" if amount == 24 else "TrialWeek")
		node.size_flags_horizontal = Control.SIZE_SHRINK_END
		toolbar.add_child(node)
	status = UI.status(bottom)
	select_controls(0)
	show_chamber()

func refresh() -> void:
	structure = site.testbed_at(session.trial_id)
	var available: Array = []
	for candidate in site.state.structures:
		if candidate.kind == "testbed": available.append(candidate)
	if structure.is_empty() and not available.is_empty():
		structure = available[0]
		session.trial_id = int(structure.id)
	if trial_list.item_count != available.size():
		trial_list.clear()
		for candidate in available: trial_list.add_item("Trial %02d" % candidate.id, int(candidate.id))
	for index in range(available.size()):
		if available[index].id == session.trial_id: trial_list.select(index)
	trial_list.visible = available.size() > 1
	var e: Dictionary = site.environment
	var goods: Dictionary = site.state.resources
	inventory.text = "Ore %.1f t    ·    Metal %.1f t    ·    Water %.1f t    ·    Parts %.1f t    ·    Archives %d" % [goods.ore, goods.metal, goods.water, goods.components, session.expedition.state.ship.seeds]
	clock.text = "Year %d + %d h · %s" % [session.expedition.state.year, session.fractional_hours, "Paused" if speed == 0 else "%d h/s" % speed]
	clock.tooltip_text = "Site hour %d. Time advances every installation." % site.state.total_hours
	for rate in [0, 1, 10, 50]: UI.selected(buttons["TrialSpeed%d" % rate], speed == rate)
	empty_hint.visible = structure.is_empty()
	control_content.visible = not structure.is_empty()
	if structure.is_empty():
		diagnosis.text = "Return to the surface and build a testbed [9]."
		diagram.trial = {}
		for value in readings: value.text = "—"
		return
	var ready: bool = structure.progress >= 1
	var t: Dictionary = structure.trial
	var network: Dictionary = site.summary()
	trial_title.text = "Field trial %02d" % structure.id
	diagram.trial = t
	diagram.running = speed > 0
	diagram.environment = e
	diagram.light = site.cell_at(structure.x, structure.z).light
	readings[0].text = "%.1f K" % t.temperature_k
	readings[1].text = "%.3f bar" % Model.pressure(t)
	readings[2].text = "%.1f g" % (t.biomass_kg * 1000)
	var reasons: Array[String] = Model.limitations(t, e, diagram.light)
	if not ready: reasons.push_front("Assembly %d%% · needs power and service" % int(structure.progress * 100))
	elif not structure.enabled: reasons.push_front("Operation suspended")
	elif not structure.connected: reasons.push_front("Service link lost · reconnect the installation")
	elif not structure.powered: reasons.push_front("Power deficit · %.1f / %.1f kW available" % [network.power_supply, network.power_demand])
	elif goods.components < Model.CONFIG.service_components_t_h: reasons.push_front("Service parts exhausted")
	diagnosis.text = reasons[0] + ("  (+%d more)" % (reasons.size() - 1) if reasons.size() > 1 else "") if not reasons.is_empty() else ("Conditions support the culture." if t.biomass_kg > 0 else "Conditions ready for an archive culture.")
	diagnosis.add_theme_color_override("font_color", AMBER if not reasons.is_empty() else CYAN)
	limits.text = "LIMITING CONDITIONS\n" + ("\n\n".join(reasons) if not reasons.is_empty() else "All archive screening limits satisfied.")
	conditions.text = "OUTSIDE · MODEL ESTIMATE\n%.1f K · %.3f bar\nCO₂ %.2f%% · Gravity %.2f g\nFlux %.2f Earth · Field %.2f Earth\n\nMean climate estimate; exposure indices are not measured radiation doses." % [e.ambient_k, e.pressure, e.co2_fraction * 100, e.gravity, e.flux, e.field_earth]
	for id in buttons:
		if id.begins_with("Thermal_") or id.begins_with("Target_") or id.begins_with("Pressure_") or id.begins_with("Shade_") or id in ["PressureControl", "WaterFeed", "GrowLight", "FitFilter", "FitCanopy", "Inoculate"]: buttons[id].disabled = not ready
	buttons.PressureControl.text = "Gas regulator · " + ("On" if t.pressure_control else "Sealed")
	buttons.PressureControl.tooltip_text = "1 kW. Intake, venting and CO₂ separation. Valves close when off or unpowered."
	buttons.WaterFeed.text = "Water feed · " + ("On · 1 kg/h" if t.feed_water else "Off")
	buttons.GrowLight.text = "Grow light · " + ("On · 0.8 kW" if t.lamp else "Off")
	for mode in ["passive", "auto", "heat", "cool"]: UI.selected(buttons["Thermal_" + mode], t.thermal == mode)
	for target in [278, 288, 303]:
		UI.selected(buttons["Target_%d" % target], t.target_k == target)
		buttons["Target_%d" % target].disabled = not ready or t.thermal != "auto"
		buttons["Target_%d" % target].tooltip_text = "Choose Auto to use a temperature setpoint."
	for target in [0.1, 0.3, 0.8]:
		UI.selected(buttons["Pressure_%d" % int(target * 10)], is_equal_approx(t.target_bar, target))
		buttons["Pressure_%d" % int(target * 10)].disabled = not ready or not t.pressure_control
	for value in [0, 50, 90]: UI.selected(buttons["Shade_%d" % value], is_equal_approx(t.shade, value / 100.0))
	for id in ["PressureControl", "WaterFeed", "GrowLight"]: UI.selected(buttons[id], t[{"PressureControl":"pressure_control", "WaterFeed":"feed_water", "GrowLight":"lamp"}[id]])
	for upgrade in ["filter", "canopy"]:
		var node: Button = buttons.FitFilter if upgrade == "filter" else buttons.FitCanopy
		node.disabled = not ready or t[upgrade] or t.upgrade != ""
		for resource in Model.CONFIG.upgrades[upgrade].cost:
			if goods[resource] < Model.CONFIG.upgrades[upgrade].cost[resource]: node.disabled = true
	buttons.FitFilter.text = "✓ UV filter installed" if t.filter else "UV filter · 8 h\n4 t metal · 1 t parts"
	buttons.FitCanopy.text = "✓ Regolith canopy installed" if t.canopy else "Regolith canopy · 16 h\n4 t ore · 8 t metal · 2 t parts"
	if t.upgrade != "":
		var pending: Button = buttons.FitFilter if t.upgrade == "filter" else buttons.FitCanopy
		pending.text = "Installing " + Model.CONFIG.upgrades[t.upgrade].label + "\n%d%% · needs operating time" % int(t.upgrade_progress * 100)
	buttons.Inoculate.disabled = not ready or t.biomass_kg > 0.000000001 or session.expedition.state.ship.seeds < 1
	var record: String = "Established culture" if t.established else "Archive trial"
	if t.established and t.biomass_kg < 0.000001: record = "Culture lost · Record retained"
	progress.text = "%s\n%.1f g detritus\n%.0f / 168 stable hours\n\nEnergy %.1f kWh\nCO₂ captured %.1f kg" % [record, t.detritus_kg * 1000, t.stable_hours, t.energy_kwh, t.captured_co2_kg]
	if t.upgrade != "": progress.text += "\n%s installation %d%%" % [Model.CONFIG.upgrades[t.upgrade].label, t.upgrade_progress * 100]
	status.tooltip_text = status.text
	diagram.queue_redraw()

func select_trial(id: int) -> void:
	session.trial_id = id
	refresh()

func order(action: String, value: Variant) -> void:
	var result: Dictionary = session.trial_command(session.trial_id, action, value)
	status.text = result.message
	if result.ok: save()
	refresh()

func flip(action: String) -> void:
	if not structure.is_empty(): order(action, not structure.trial[action])

func set_metric(metric: String) -> void:
	diagram.metric = metric
	diagram.view_mode = "history"
	UI.selected(buttons.ViewChamber, false)
	for name in ["temperature", "pressure", "biomass"]: UI.selected(buttons["Graph_" + name], name == metric)
	diagram.queue_redraw()

func set_speed(rate: int) -> void:
	speed = rate
	refresh()

func advance(hours: int) -> void:
	session.advance_hours(hours)
	refresh()
	save()

func save() -> bool:
	var result: Dictionary = session.save_disk()
	if not result.ok: status.text = result.message
	return result.ok

func open_surface() -> void:
	if save(): get_tree().change_scene_to_file("res://scenes/surface.tscn")

func open_orbit() -> void:
	if save(): get_tree().change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> void:
	if site == null or speed == 0: return
	accumulated += delta * speed
	if accumulated >= 1:
		var hours: int = int(accumulated)
		accumulated -= hours
		session.advance_hours(hours)
		refresh()
	save_elapsed += delta
	if save_elapsed >= 15:
		save_elapsed = 0
		save()

func _input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode not in [KEY_ESCAPE, KEY_SPACE]: return
	match event.keycode:
		KEY_ESCAPE: open_surface()
		KEY_SPACE: set_speed(1 if speed == 0 else 0)
	get_viewport().set_input_as_handled()

func select_controls(index: int) -> void:
	control_tab = index
	for page in range(pages.size()):
		pages[page].visible = page == index
		UI.selected(control_tabs[page], page == index)

func toggle_readings() -> void:
	conditions.visible = not conditions.visible
	buttons.OutsideReadings.text = "Outside measurements  " + ("−" if conditions.visible else "+")

func show_chamber() -> void:
	diagram.view_mode = "chamber"
	UI.selected(buttons.ViewChamber, true)
	for name in ["temperature", "pressure", "biomass"]: UI.selected(buttons["Graph_" + name], false)
	diagram.queue_redraw()

func open_chart() -> void:
	if save(): get_tree().change_scene_to_file("res://scenes/prospects.tscn")

func show_help() -> void:
	UI.text_dialog(self, "Field trials", "Climate: regulate temperature, gas pressure and water.\nShielding: control light, UV filtering and the regolith canopy.\nCulture: introduce an archive and inspect every limiting condition.\n\nReadings at the top are the actual chamber state.\nSelect Temperature, Pressure or Culture to plot its history.\nEach 1× is one simulated hour per second. Space pauses.\n\nThe chamber is 16 m² / 32 m³. Exposure values are screening indices; outside climate is a model estimate. A successful enclosed trial is not a planetary habitability verdict.")
