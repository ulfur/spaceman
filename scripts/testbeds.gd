extends Control
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
var trial_list: VBoxContainer
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

func label(value: String, font_size: int = 14, color: Color = INK, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func skin(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.border_width_bottom = 2
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box

func button(value: String, callback: Callable, id: String) -> Button:
	var node := Button.new()
	node.name = id
	node.text = value
	node.focus_mode = Control.FOCUS_NONE
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 12)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	node.add_theme_stylebox_override("normal", skin(Color("101e28"), Color("34515e")))
	node.add_theme_stylebox_override("hover", skin(Color("213a43"), CYAN))
	node.add_theme_stylebox_override("pressed", skin(Color("25443f"), CYAN))
	node.add_theme_stylebox_override("disabled", skin(Color("0b151d"), Color("1e3039")))
	node.pressed.connect(callback)
	buttons[id] = node
	return node

func area(preset: int, offsets: Vector4) -> MarginContainer:
	var container := MarginContainer.new()
	container.set_anchors_and_offsets_preset(preset)
	container.offset_left = offsets.x
	container.offset_top = offsets.y
	container.offset_right = offsets.z
	container.offset_bottom = offsets.w
	add_child(container)
	return container

func stack(parent: Node) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)
	return container

func scrolled(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	return stack(scroll)

func row(parent: Node) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	parent.add_child(container)
	return container

func build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("080f17")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var header := stack(area(Control.PRESET_TOP_WIDE, Vector4(28, 24, -28, 115)))
	var top := row(header)
	var title := label("SPACEMAN   /   TESTBEDS", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var surface_nav := button("SURFACE  /  ESC", open_surface, "TrialSurface")
	surface_nav.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(surface_nav)
	var orbit_nav := button("LOCAL ORBIT", open_orbit, "TrialOrbit")
	orbit_nav.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(orbit_nav)
	clock = label("", 12, CYAN)
	header.add_child(clock)
	inventory = label("", 13)
	header.add_child(inventory)
	var left := scrolled(area(Control.PRESET_LEFT_WIDE, Vector4(28, 145, 278, -188)))
	left.add_child(label("A SMALL CLIMATE", 12, AMBER))
	left.add_child(label("Build the evidence.\nThen build the world.", 21))
	trial_list = stack(left)
	conditions = label("", 13, MUTED, true)
	left.add_child(conditions)
	left.add_child(label("LIMITING CONDITIONS", 12, AMBER))
	diagnosis = label("", 14, CYAN, true)
	left.add_child(diagnosis)
	diagram = Diagram.new()
	diagram.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	diagram.offset_left = 295
	diagram.offset_top = 145
	diagram.offset_right = -332
	diagram.offset_bottom = -190
	add_child(diagram)
	var controls := scrolled(area(Control.PRESET_RIGHT_WIDE, Vector4(-311, 145, -28, -188)))
	controls.add_child(label("ENGINEERING ORDERS", 12, AMBER))
	controls.add_child(label("THERMAL / up to 4 kW", 12, MUTED))
	var thermal := row(controls)
	for mode in ["passive", "auto", "heat", "cool"]:
		thermal.add_child(button(mode.to_upper(), order.bind("thermal", mode), "Thermal_" + mode))
	var targets := row(controls)
	for target in [278, 288, 303]:
		targets.add_child(button("%d K" % target, order.bind("target_k", float(target)), "Target_%d" % target))
	controls.add_child(button("ATMOSPHERE / SEALED", flip.bind("pressure_control"), "PressureControl"))
	var pressures := row(controls)
	for target in [0.1, 0.3, 0.8]:
		pressures.add_child(button("%.1f bar" % target, order.bind("target_bar", target), "Pressure_%d" % int(target * 10)))
	controls.add_child(button("WATER FEED / OFF", flip.bind("feed_water"), "WaterFeed"))
	controls.add_child(button("GROW LIGHT / OFF", flip.bind("lamp"), "GrowLight"))
	controls.add_child(label("ROOF SHADE", 12, MUTED))
	var shades := row(controls)
	for value in [0, 50, 90]:
		shades.add_child(button("%d%%" % value, order.bind("shade", value / 100.0), "Shade_%d" % value))
	controls.add_child(button("FIT UV FILTER\n4 metal · 1 component · 8 h", order.bind("filter", null), "FitFilter"))
	controls.add_child(button("BUILD REGOLITH CANOPY\n4 ore · 8 metal · 2 components · 16 h", order.bind("canopy", null), "FitCanopy"))
	controls.add_child(button("INOCULATE / 1 ARCHIVE", order.bind("inoculate", null), "Inoculate"))
	progress = label("", 12, CYAN, true)
	controls.add_child(progress)
	var bottom := stack(area(Control.PRESET_BOTTOM_WIDE, Vector4(28, -167, -28, -22)))
	var toolbar := row(bottom)
	toolbar.name = "TrialToolbar"
	for metric in ["temperature", "pressure", "biomass"]:
		toolbar.add_child(button(metric.to_upper(), set_metric.bind(metric), "Graph_" + metric))
	for rate in [0, 1, 10, 50]:
		toolbar.add_child(button("Ⅱ" if rate == 0 else "%d×" % rate, set_speed.bind(rate), "TrialSpeed%d" % rate))
	toolbar.add_child(button("+24 h", advance.bind(24), "TrialDay"))
	toolbar.add_child(button("+7 d", advance.bind(168), "TrialWeek"))
	status = label("Configure the chamber, watch its response, then commit an archive culture.", 14, CYAN, true)
	bottom.add_child(status)
	bottom.add_child(label("16 m² ENCLOSURE  /  MEAN FORCING  /  EXPOSURE INDICES ARE SCREENING PROXIES, NOT A RADIATION DOSE", 11, MUTED))

func refresh() -> void:
	structure = site.testbed_at(session.trial_id)
	if structure.is_empty():
		for candidate in site.state.structures:
			if candidate.kind == "testbed":
				structure = candidate
				session.trial_id = int(candidate.id)
				break
	for child in trial_list.get_children():
		trial_list.remove_child(child)
		child.queue_free()
	for candidate in site.state.structures:
		if candidate.kind == "testbed":
			trial_list.add_child(button("%sTRIAL %02d  ·  %d%% BUILT" % ["• " if candidate.id == session.trial_id else "", candidate.id, candidate.progress * 100], select_trial.bind(int(candidate.id)), "SelectTrial%d" % candidate.id))
	var e: Dictionary = site.environment
	conditions.text = "OUTSIDE / MODEL ESTIMATE\n%.1f K · %.3f bar\nCO₂ %.2f%% · %.2f g\nFlux %.2f Earth\nField %.2f Earth\n\nAmbient temperature is a grey-atmosphere estimate. Chemistry is a synthetic N₂/CO₂ mixture." % [e.ambient_k, e.pressure, e.co2_fraction * 100, e.gravity, e.flux, e.field_earth]
	var goods: Dictionary = site.state.resources
	inventory.text = "ORE %.1f t    /    METAL %.1f t    /    WATER %.1f t    /    COMPONENTS %.1f t    /    ARCHIVE PACKETS %d" % [goods.ore, goods.metal, goods.water, goods.components, session.expedition.state.ship.seeds]
	clock.text = "%s  /  SITE HOUR %d  /  YEAR %d + %d h  /  %s" % [session.expedition.state.bodies[session.surface_body].name.to_upper(), site.state.total_hours, session.expedition.state.year, session.fractional_hours, "PAUSED" if speed == 0 else "%d h/s" % speed]
	var ready: bool = not structure.is_empty() and structure.progress >= 1.0
	for id in buttons:
		if not is_instance_valid(buttons[id]): continue
		if id.begins_with("Thermal_") or id.begins_with("Target_") or id.begins_with("Pressure_") or id.begins_with("Shade_") or id in ["PressureControl", "WaterFeed", "GrowLight", "FitFilter", "FitCanopy", "Inoculate"]:
			buttons[id].disabled = not ready
	if structure.is_empty():
		diagnosis.text = "No chamber yet. Open Surface and build Testbed [9] beside the service network."
		progress.text = "Assembly: 30 metal + 5 components. Sixteen base construction hours."
		diagram.trial = {}
		return
	var network: Dictionary = site.summary()
	var t: Dictionary = structure.trial
	diagram.trial = t
	diagram.environment = e
	diagram.light = site.cell_at(structure.x, structure.z).light
	var reasons: Array[String] = Model.limitations(t, e, diagram.light)
	diagnosis.text = "\n\n".join(reasons) if not reasons.is_empty() else "Trial conditions support the archive culture. This is a local enclosed result."
	if not ready:
		diagnosis.text = "Assembly in progress. Advance time while power and service are available."
	elif not structure.enabled:
		diagnosis.text = "SUSPENDED BY ORDER\nPassive exchange and biology continue.\n\n" + diagnosis.text
	elif not structure.connected:
		diagnosis.text = "SERVICE LINK LOST\nReconnect the installation to restore its actuators.\n\n" + diagnosis.text
	elif not structure.powered:
		diagnosis.text = "POWER DEFICIT\nNetwork reserves %.1f / %.1f kW. Add generation or suspend another load.\n\n" % [network.power_demand, network.power_supply] + diagnosis.text
	elif goods.components < Model.CONFIG.service_components_t_h:
		diagnosis.text = "SERVICE PARTS EXHAUSTED\nNeeds 0.002 t components per operating hour.\n\n" + diagnosis.text
	buttons.PressureControl.text = "ATMOSPHERE / " + ("REGULATING" if t.pressure_control else "SEALED")
	buttons.PressureControl.tooltip_text = "1 kW gas train: metered native intake, venting and CO₂ separation. Valves close when disabled or unpowered."
	buttons.WaterFeed.text = "WATER FEED / " + ("ON · 1 kg/h" if t.feed_water else "OFF")
	buttons.GrowLight.text = "GROW LIGHT / " + ("ON · 0.8 kW" if t.lamp else "OFF")
	for mode in ["passive", "auto", "heat", "cool"]:
		buttons["Thermal_" + mode].add_theme_color_override("font_color", CYAN if t.thermal == mode else INK)
	for target in [278, 288, 303]:
		buttons["Target_%d" % target].add_theme_color_override("font_color", CYAN if t.target_k == target else INK)
	for target in [0.1, 0.3, 0.8]:
		buttons["Pressure_%d" % int(target * 10)].add_theme_color_override("font_color", CYAN if is_equal_approx(t.target_bar, target) else INK)
	for value in [0, 50, 90]:
		buttons["Shade_%d" % value].add_theme_color_override("font_color", CYAN if is_equal_approx(t.shade, value / 100.0) else INK)
	buttons.FitFilter.disabled = not ready or t.filter or t.upgrade != ""
	buttons.FitCanopy.disabled = not ready or t.canopy or t.upgrade != ""
	buttons.Inoculate.disabled = not ready or t.biomass_kg > 0.000000001 or session.expedition.state.ship.seeds < 1
	buttons.FitFilter.text = "UV FILTER FITTED" if t.filter else "FIT UV FILTER\n4 metal · 1 component · 8 h"
	buttons.FitCanopy.text = "REGOLITH CANOPY FITTED" if t.canopy else "BUILD REGOLITH CANOPY\n4 ore · 8 metal · 2 components · 16 h"
	progress.text = "%s\n%.1f g live · %.1f g detritus\n%.0f / 168 stable hours\n%.1f kWh used · %.1f kg CO₂ captured" % ["ENCLOSED TRIAL ESTABLISHED" if t.established else "ARCHIVE TRIAL", t.biomass_kg * 1000, t.detritus_kg * 1000, t.stable_hours, t.energy_kwh, t.captured_co2_kg]
	if t.upgrade != "": progress.text += "\n%s installation %d%%" % [Model.CONFIG.upgrades[t.upgrade].label, t.upgrade_progress * 100]

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

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: open_surface()
		KEY_SPACE: set_speed(1 if speed == 0 else 0)
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
