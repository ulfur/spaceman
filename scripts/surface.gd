extends Control
const UI = preload("res://scripts/interface.gd")
const Session = preload("res://scripts/session.gd")
const Surface = preload("res://scripts/surface_simulation.gd")
const World = preload("res://scripts/surface_world.gd")
const INK := Color("e1e1cf")
const MUTED := Color("b1b7ac")
const CYAN := Color("a1d6ca")
const AMBER := Color("e2bc7e")
const TOOLS := ["inspect", "survey", "land", "solar", "mine", "ice_well", "refinery", "fabricator", "refuge", "testbed"]
const LABELS := ["INSPECT", "SURVEY", "MODULE", "SOLAR", "EXTRACTOR", "ICE WELL", "REFINERY", "FABRICATOR", "REFUGE", "TESTBED"]
var session = Session.get_shared()
var site: RefCounted
var world: Node3D
var viewport: SubViewport
var viewport_container: SubViewportContainer
var selected := Vector2i(-1, -1)
var hovered := Vector2i(-1, -1)
var tool := "land"
var speed := 0
var accumulated := 0.0
var autosave_elapsed := 0.0
var notice_until_msec := 0
var inventory: Label
var time_label: Label
var detail: Label
var selection_title: Label
var status: Label
var build_hint: Label
var power: Label
var tool_buttons: Dictionary = {}
var inspector_panel: Control
var detail_scroll: ScrollContainer
var selection_page: VBoxContainer
var build_page: VBoxContainer
var build_open := false
var build_tabs: Array[Button] = []
var categories: Array[VBoxContainer] = []
var speed_buttons: Array[Button] = []
var toggle_button: Button
var trial_button: Button

func _ready() -> void:
	if not session.initialized:
		session.load_disk()
	site = session.surface_for(session.surface_body)
	if site == null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	tool = "inspect" if site.state.landed else "land"
	build_interface()
	refresh()
	set_tool(tool)



func button(text: String, callback: Callable, node_name: String) -> Button:
	return UI.button(text, callback, node_name)


func build_interface() -> void:
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "TerrainInput"
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	add_child(viewport_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	world = World.new()
	viewport.add_child(world)
	world.setup(site.state)
	viewport_container.gui_input.connect(terrain_input)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://shaders/surface_hud.gdshader")
	shade.material = shade_material
	add_child(shade)
	UI.install(self)
	var nav := UI.header(self)
	nav.add_child(button("Star chart", open_chart, "SurfaceChart"))
	nav.add_child(button("Orbit", return_to_orbit, "ReturnOrbit"))
	nav.add_child(UI.label("/  Surface", 16, CYAN))
	UI.spacer(nav)
	nav.add_child(UI.label(session.expedition.state.bodies[session.surface_body].name + " · Sector 01", 16))
	var menu := UI.menu(self, nav, [["Save expedition", save_game, "SaveSurface"], ["Surface controls", show_help, "Help"]])
	menu.visibility_changed.connect(set_speed.bind(0))
	var supplies := UI.row(UI.mount(self, Control.PRESET_TOP_WIDE, Vector4(28, 86, -28, 121)))
	inventory = UI.label("", 16)
	supplies.add_child(inventory)
	UI.spacer(supplies)
	power = UI.label("", 16, CYAN)
	supplies.add_child(power)
	var inspector := UI.inspector(self, 149, -111)
	inspector_panel = inspector.get_parent()
	inspector_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var title_row := UI.row(inspector)
	selection_title = UI.label("", 22)
	selection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(selection_title)
	title_row.add_child(button("×", dismiss_inspector, "CloseInspector"))
	var content := UI.scroll(inspector, "SurfaceDetailsScroll")
	detail_scroll = content.get_parent()
	content.resized.connect(fit_inspector)
	selection_page = UI.column(content)
	detail = UI.label("", 16, INK, true)
	selection_page.add_child(detail)
	trial_button = UI.button("Open field trial →", open_selected_trial, "OpenTrial", true)
	selection_page.add_child(trial_button)
	toggle_button = button("Suspend operation", toggle_selected, "ToggleStructure")
	selection_page.add_child(toggle_button)
	build_page = UI.column(content)
	var tab_row := UI.row(build_page)
	for category in ["Industry", "Life support"]:
		var node := button(category, set_category.bind(build_tabs.size()), "Build" + category.replace(" ", ""))
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(node)
		build_tabs.append(node)
	for index in range(2): categories.append(UI.column(build_page, 9))
	for index in range(2, TOOLS.size()):
		var kind: String = TOOLS[index]
		var recipe: Dictionary = Surface.RECIPES["seed" if kind == "land" else kind]
		var node := button("%s   [%d]" % [recipe.label, index], set_tool.bind(kind), "Tool_" + kind)
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node.tooltip_text = recipe.label + ": " + recipe_description(kind)
		categories[1 if kind in ["refuge", "testbed"] else 0].add_child(node)
		tool_buttons[kind] = node
	build_hint = UI.label("Choose equipment, then place it on the ground.\n\nOre → metal → parts\nIce → water", 15, MUTED, true)
	build_page.add_child(build_hint)
	set_category(0)
	var bottom := UI.footer(self)
	var controls := UI.row(bottom)
	controls.name = "Toolbelt"
	for kind in ["inspect", "survey"]:
		var node := button("Inspect [0]" if kind == "inspect" else "Survey [1]", set_tool.bind(kind), "Tool_" + kind)
		controls.add_child(node)
		tool_buttons[kind] = node
	controls.add_child(UI.button("Build [B]", toggle_build, "BuildPalette", true))
	UI.spacer(controls)
	time_label = UI.label("", 15, AMBER)
	controls.add_child(time_label)
	for rate in [0, 1, 10, 50]:
		var node := button("Pause" if rate == 0 else "%d×" % rate, set_speed.bind(rate), "Speed%d" % rate)
		node.tooltip_text = "Pause [Space]" if rate == 0 else "%d simulated hours per second" % rate
		controls.add_child(node)
		node.toggle_mode = true
		speed_buttons.append(node)
	status = UI.status(bottom)
	set_speed(0)

func set_speed(rate: int) -> void:
	speed = rate
	for index in range(speed_buttons.size()):
		speed_buttons[index].set_pressed_no_signal([0, 1, 10, 50][index] == rate)
	if world != null:
		world.motion_rate = 0.0 if rate == 0 else minf(5, rate)
	update_clock()

func set_tool(kind: String) -> void:
	if kind == "testbed" and site.environment.is_empty():
		status.text = "Testbeds require the environmental probe from a generated world."
		return
	tool = kind
	build_open = false
	for id in tool_buttons: UI.selected(tool_buttons[id], id == kind)
	update_detail()
	update_preview()

func terrain_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			world.pan_camera(event.relative)
		var cell: Vector2i = world.pick_cell(event.position, tool == "inspect")
		if cell != hovered:
			hovered = cell
			update_preview()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				world.zoom_camera(-5)
			MOUSE_BUTTON_WHEEL_DOWN:
				world.zoom_camera(5)
			MOUSE_BUTTON_RIGHT:
				set_tool("inspect")
			MOUSE_BUTTON_LEFT:
				select_or_build(world.pick_cell(event.position, tool == "inspect"))

func select_or_build(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0:
		return
	selected = cell
	world.set_selected(selected)
	if tool != "inspect":
		var outcome: Dictionary = session.surface_command(tool, cell.x, cell.y)
		status.text = outcome.message
		notice_until_msec = Time.get_ticks_msec() + 2500
		if outcome.ok:
			if tool != "survey" and not Input.is_physical_key_pressed(KEY_SHIFT):
				set_tool("inspect")
			autosave()
	refresh()

func update_preview() -> void:
	if world == null:
		return
	var valid := true
	if tool not in ["inspect", "survey"]:
		valid = site.can_place(tool, hovered.x, hovered.y).ok
	world.set_preview("" if tool == "inspect" else tool, hovered, valid)
	if hovered.x >= 0 and tool not in ["inspect", "survey"] and Time.get_ticks_msec() >= notice_until_msec:
		var allowed: Dictionary = site.can_place(tool, hovered.x, hovered.y)
		status.text = allowed.message if not allowed.ok else ""
		update_detail()

func refresh() -> void:
	var state: Dictionary = site.state
	var report: Dictionary = site.summary()
	world.refresh(state)
	var goods: Dictionary = state.resources
	inventory.text = "Ore %.1f t    ·    Metal %.1f t    ·    Water %.1f t    ·    Parts %.1f t" % [goods.ore, goods.metal, goods.water, goods.components]
	power.text = "Power %.1f / %.1f kW" % [report.power_demand, report.power_supply]
	power.tooltip_text = "%d linked installations · demand / supply" % report.connected_count
	power.add_theme_color_override("font_color", AMBER if report.power_demand > report.power_supply else CYAN)
	tool_buttons.land.visible = not state.landed
	for kind in tool_buttons:
		if kind not in ["inspect", "survey", "land"]: tool_buttons[kind].disabled = not state.landed or (kind == "testbed" and site.environment.is_empty())
	update_clock()
	update_detail()
	update_preview()
	status.tooltip_text = status.text

func update_clock() -> void:
	if time_label != null and site != null:
		time_label.text = "Year %d + %d h · %s" % [session.expedition.state.year, session.fractional_hours, "Paused" if speed == 0 else "%d h/s" % speed]
		time_label.tooltip_text = "Site hour %d. Time advances the entire expedition." % site.state.total_hours

func update_detail() -> void:
	fit_inspector.call_deferred()
	toggle_button.visible = false
	trial_button.visible = false
	selection_page.visible = not build_open
	build_page.visible = build_open
	inspector_panel.visible = build_open or selected.x >= 0 or tool != "inspect"
	if build_open:
		selection_title.text = "Build installation"
		return
	var inspecting: Vector2i = hovered if tool not in ["inspect", "survey"] else selected
	var cell: Dictionary = site.cell_at(inspecting.x, inspecting.y)
	if tool not in ["inspect", "survey"]:
		selection_title.text = "Land module" if tool == "land" else "Place " + LABELS[TOOLS.find(tool)].to_lower()
		detail.text = recipe_description(tool) + "\n\nClick suitable ground to place. Esc cancels."
		if tool == "land": detail.text += "\n\nChoose a site near ore and ice. The module connects nearby machinery."
		if not cell.is_empty():
			detail.text += "\n\nGround %02d:%02d · Sunlight %.0f%%\n" % [inspecting.x, inspecting.y, cell.light * 100]
			detail.text += site.can_place(tool, inspecting.x, inspecting.y).message
		return
	if cell.is_empty():
		selection_title.text = "Survey terrain"
		detail.text = "Click ground to resolve resources and foundations.\n\nAmber outcrops: ore\nCyan outcrops: ice"
		return
	var structure: Dictionary = site.structure_at(selected.x, selected.y)
	selection_title.text = "Ground %02d:%02d" % [selected.x, selected.y]
	if not cell.scanned:
		detail.text = "Unsurveyed ground.\nUse Survey [1] to identify deposits and check the foundation."
		return
	if structure.is_empty():
		detail.text = "%s\nSunlight %.0f%%\n" % ["Stable foundation" if cell.buildable else "Unstable ground", cell.light * 100]
		detail.text += ("%s · %.1f t remaining" % ["Ore" if cell.resource == "metal" else "Ice", cell.remaining]) if cell.resource != "" else "No mapped deposit"
		return
	selection_title.text = Surface.RECIPES[structure.kind].label
	detail.text = structure.status + "\n"
	if structure.progress < 1: detail.text += "Construction %d%%\n" % int(structure.progress * 100)
	detail.text += "Service efficiency %d%%" % int(structure.efficiency * 100)
	if structure.queue.size() > 0: detail.text += "\nProduces " + ", ".join(structure.queue).replace("components", "parts")
	if cell.resource != "": detail.text += "\nDeposit %.1f t remaining" % cell.remaining
	if structure.kind == "solar": detail.text += "\nSunlight %.0f%%" % (cell.light * 100)
	if structure.kind == "seed": detail.text += "\n\nBuild power, then extract ore and ice. Refine metal and fabricate parts to maintain the installation."
	if structure.kind == "refuge": detail.text += "\n\nLife support uses water and parts."
	if structure.kind == "testbed":
		trial_button.visible = structure.progress >= 1
		detail.text += "\n\n%.1f K · %.3f bar\nCulture %.1f g live" % [structure.trial.temperature_k, Surface.Testbed.pressure(structure.trial), structure.trial.biomass_kg * 1000]
	toggle_button.visible = structure.kind != "seed"
	toggle_button.text = "Suspend operation" if structure.enabled else "Resume operation"

func toggle_selected() -> void:
	var outcome: Dictionary = session.surface_command("toggle", selected.x, selected.y)
	status.text = outcome.message
	refresh()
	if outcome.ok:
		autosave()

func autosave() -> bool:
	var outcome: Dictionary = session.save_disk()
	if not outcome.ok:
		status.text = outcome.message
	return outcome.ok

func save_game() -> void:
	status.text = session.save_disk().message

func return_to_orbit() -> void:
	set_speed(0)
	if not autosave():
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func open_selected_trial() -> void:
	var structure: Dictionary = site.structure_at(selected.x, selected.y)
	if structure.get("kind") != "testbed": return
	session.trial_id = int(structure.id)
	open_trials()

func open_trials() -> void:
	set_speed(0)
	if autosave(): get_tree().change_scene_to_file("res://scenes/testbeds.tscn")

func _process(delta: float) -> void:
	if site == null or speed == 0:
		return
	accumulated += delta * speed
	if accumulated >= 1:
		var hours: int = int(accumulated)
		accumulated -= hours
		session.advance_hours(hours)
		refresh()
	autosave_elapsed += delta
	if autosave_elapsed >= 15:
		autosave_elapsed = 0
		autosave()

func _input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode not in [KEY_B, KEY_SPACE, KEY_Q, KEY_E, KEY_ESCAPE, KEY_F11] and not (event.keycode >= KEY_0 and event.keycode <= KEY_9): return
	if event.keycode >= KEY_0 and event.keycode <= KEY_9:
		set_tool(TOOLS[event.keycode - KEY_0])
	else:
		match event.keycode:
			KEY_SPACE:
				set_speed(1 if speed == 0 else 0)
			KEY_Q:
				world.orbit_camera(-0.15)
			KEY_E:
				world.orbit_camera(0.15)
			KEY_ESCAPE:
				if build_open or tool != "inspect" or selected.x >= 0: dismiss_inspector()
				else: return_to_orbit()
			KEY_B:
				toggle_build()
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()

func recipe_description(kind: String) -> String:
	var recipe: Dictionary = Surface.RECIPES["seed" if kind == "land" else kind]
	if kind == "land": return "1 onboard module · %d available" % session.expedition.state.ship.modules
	var costs: Array[String] = []
	for resource in recipe.cost: costs.append("%.0f t %s" % [recipe.cost[resource], "parts" if resource == "components" else resource])
	return "%s\n%.0f base hours · %.1f kW load" % [" · ".join(costs), recipe.hours, recipe.power]

func toggle_build() -> void:
	build_open = not build_open
	tool = "inspect"
	for id in tool_buttons: UI.selected(tool_buttons[id], id == "inspect")
	update_detail()
	update_preview()

func set_category(index: int) -> void:
	for page in range(categories.size()):
		categories[page].visible = page == index
		UI.selected(build_tabs[page], page == index)

func dismiss_inspector() -> void:
	selected = Vector2i(-1, -1)
	world.set_selected(selected)
	set_tool("inspect")

func open_chart() -> void:
	set_speed(0)
	if autosave(): get_tree().change_scene_to_file("res://scenes/prospects.tscn")

func show_help() -> void:
	UI.text_dialog(self, "Surface controls", "Click terrain or machinery to inspect it.\nB opens the build palette. Choose equipment, then place it.\nHold Shift to place multiple installations.\nRight-click or Esc cancels placement.\n\n1 surveys ground; 0 returns to inspection.\n2–9 select equipment directly.\nMiddle-drag pans · Wheel zooms · Q / E rotate.\nSpace pauses. Each 1× is one simulated hour per second.\nEsc dismisses the inspector before returning to orbit.\n\nSelect a finished testbed to open its field trial.")

func fit_inspector() -> void:
	if not inspector_panel.visible: return
	var page: VBoxContainer = build_page if build_open else selection_page
	detail_scroll.custom_minimum_size.y = clampf(page.get_combined_minimum_size().y, 60, maxf(60, size.y - 456))
