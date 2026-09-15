extends Control
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
var objective: Label
var detail: Label
var selection_title: Label
var status: Label
var build_hint: Label
var power: Label
var event_label: Label
var tool_buttons: Array[Button] = []
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

func label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func skin(background: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.border_width_bottom = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func button(text: String, callback: Callable, node_name: String) -> Button:
	var node := Button.new()
	node.name = node_name
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", AMBER)
	node.add_theme_stylebox_override("normal", skin(Color(0.035, 0.06, 0.065, 0.87), Color("46514c")))
	node.add_theme_stylebox_override("hover", skin(Color(0.12, 0.18, 0.18, 0.97), CYAN))
	node.add_theme_stylebox_override("pressed", skin(Color(0.14, 0.19, 0.18, 0.97), AMBER))
	node.add_theme_stylebox_override("disabled", skin(Color(0.05, 0.07, 0.07, 0.8), Color("343d38")))
	node.pressed.connect(callback)
	return node

func margin_box(preset: int, offsets: Vector4) -> MarginContainer:
	var node := MarginContainer.new()
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

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
	var top := margin_box(Control.PRESET_TOP_WIDE, Vector4(28, 22, -28, 112))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 9)
	top.add_child(stack)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	var title := label("SPACEMAN   /   FIRST FOOTHOLD", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if not site.environment.is_empty():
		header.add_child(button("FIELD TRIALS →", open_trials, "FieldTrials"))
	header.add_child(button("↑  ORBIT  ·  ESC", return_to_orbit, "ReturnOrbit"))
	header.add_child(button("SAVE", save_game, "SaveSurface"))
	stack.add_child(label(session.expedition.state.bodies[session.surface_body].name.to_upper() + "     /     LANDING SECTOR 01     /     SYNTHETIC PRESENCE", 12, CYAN))
	inventory = label("", 15)
	stack.add_child(inventory)
	var left := margin_box(Control.PRESET_TOP_LEFT, Vector4(28, 148, 281, 310))
	var left_stack := VBoxContainer.new()
	left_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_stack.add_theme_constant_override("separation", 12)
	left.add_child(left_stack)
	left_stack.add_child(label("AN INDUSTRIAL SEED", 12, AMBER))
	objective = label("", 19)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_stack.add_child(objective)
	power = label("", 14, CYAN)
	left_stack.add_child(power)
	event_label = label("", 13, MUTED)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_stack.add_child(event_label)
	var right := margin_box(Control.PRESET_TOP_RIGHT, Vector4(-273, 148, -28, 370))
	var right_stack := VBoxContainer.new()
	right_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_stack.add_theme_constant_override("separation", 10)
	right.add_child(right_stack)
	selection_title = label("GROUND TELEMETRY", 12, AMBER)
	right_stack.add_child(selection_title)
	detail = label("", 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_stack.add_child(detail)
	toggle_button = button("TOGGLE OPERATION", toggle_selected, "ToggleStructure")
	right_stack.add_child(toggle_button)
	trial_button = button("OPEN FIELD TRIAL →", open_selected_trial, "OpenTrial")
	right_stack.add_child(trial_button)
	var bottom := margin_box(Control.PRESET_BOTTOM_WIDE, Vector4(28, -203, -28, -20))
	var bottom_stack := VBoxContainer.new()
	bottom_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_stack.add_theme_constant_override("separation", 8)
	bottom.add_child(bottom_stack)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 5)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_stack.add_child(time_row)
	time_label = label("", 13, AMBER)
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(time_label)
	for rate in [0, 1, 10, 50]:
		var node := button("Ⅱ" if rate == 0 else "%d×" % rate, set_speed.bind(rate), "Speed%d" % rate)
		node.toggle_mode = true
		node.custom_minimum_size.x = 52
		time_row.add_child(node)
		speed_buttons.append(node)
	build_hint = label("", 13, INK)
	bottom_stack.add_child(build_hint)
	var belt := HBoxContainer.new()
	belt.name = "Toolbelt"
	belt.add_theme_constant_override("separation", 4)
	bottom_stack.add_child(belt)
	for index in range(TOOLS.size()):
		var node := button("%d   %s" % [index, LABELS[index]], set_tool.bind(TOOLS[index]), "Tool_" + TOOLS[index])
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.custom_minimum_size.y = 53
		node.add_theme_font_size_override("font_size", 11)
		node.toggle_mode = true
		if TOOLS[index] == "testbed" and site.environment.is_empty():
			node.disabled = true
			node.tooltip_text = "Probe a generated prospect to obtain environmental measurements."
		belt.add_child(node)
		tool_buttons.append(node)
	status = label("Choose surveyed ground near both ore and ice. Right-click cancels placement.", 13, CYAN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_stack.add_child(status)
	bottom_stack.add_child(label("LMB select / place    ·    MMB drag to pan    ·    WHEEL zoom    ·    Q / E rotate    ·    SPACE pause    ·    0–9 tools", 11, MUTED))
	set_speed(0)

func set_speed(rate: int) -> void:
	speed = rate
	for index in range(speed_buttons.size()):
		speed_buttons[index].set_pressed_no_signal([0, 1, 10, 50][index] == rate)
	if world != null:
		world.motion_rate = 0.0 if rate == 0 else minf(5, rate)
	update_clock()

func set_tool(kind: String) -> void:
	tool = kind
	for index in range(tool_buttons.size()):
		tool_buttons[index].set_pressed_no_signal(TOOLS[index] == kind)
	if kind in ["inspect", "survey"]:
		build_hint.text = "INSPECT · select ground or machinery" if kind == "inspect" else "SURVEY · reveal nearby deposits and foundation conditions"
	else:
		var recipe: Dictionary = Surface.RECIPES["seed" if kind == "land" else kind]
		var costs: Array[String] = []
		for resource in recipe.cost:
			costs.append("%.0f %s" % [recipe.cost[resource], resource])
		build_hint.text = "%s · %s · %.0f base hours · %.1f kW load" % [recipe.label.to_upper(), "1 ship module" if kind == "land" else " / ".join(costs), recipe.hours, recipe.power]
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
			if tool == "land":
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
		status.text = allowed.message

func refresh() -> void:
	var state: Dictionary = site.state
	var report: Dictionary = site.summary()
	world.refresh(state)
	var goods: Dictionary = state.resources
	inventory.text = "ORE  %.1f     /     METAL  %.1f     /     WATER  %.1f     /     COMPONENTS  %.1f     /     MODULES ABOARD  %d" % [goods.ore, goods.metal, goods.water, goods.components, session.expedition.state.ship.modules]
	power.text = "POWER  %.1f / %.1f kW\n%d installations linked" % [report.power_demand, report.power_supply, report.connected_count]
	if state.has("solar_factor"):
		power.text += "\nSolar yield factor  %.2f×" % state.solar_factor
	power.add_theme_color_override("font_color", AMBER if report.power_demand > report.power_supply else CYAN)
	if not state.landed:
		objective.text = "Find your foothold."
	elif state.structures.size() < 4:
		objective.text = "Power. Water.\nSomething to build with."
	elif report.refuge_progress < 1.0:
		objective.text = "Give life a room\nof its own."
	else:
		objective.text = "A small beginning."
	event_label.text = "Enclosed pioneer culture: %d%%\n\nEnclosed life is not a planetary biosphere.\n\nOre → metal → components\nIce → water\nPower + supplies → refuge" % int(report.refuge_progress * 100)
	if report.trials > 0:
		event_label.text = "FIELD TRIALS\n%d chambers · %d established\nLive trial culture: %.1f g\n\nHeat, pressure, water and exposure determine the outcome. Open a testbed to inspect its measurements." % [report.trials, report.established_trials, report.trial_biomass_g]
		objective.text = "A climate, in miniature." if report.established_trials > 0 else "Test the conditions."
	if state.events.size() > 0:
		event_label.text += "\n\n" + state.events[-1].text
	update_clock()
	update_detail()
	update_preview()

func update_clock() -> void:
	if time_label != null and site != null:
		time_label.text = "YEAR %d  + %dh    /    SITE HOUR %d    /    %s" % [session.expedition.state.year, session.fractional_hours, site.state.total_hours, "PAUSED" if speed == 0 else "%d h/s" % speed]

func update_detail() -> void:
	toggle_button.visible = false
	trial_button.visible = false
	var cell: Dictionary = site.cell_at(selected.x, selected.y)
	if cell.is_empty():
		selection_title.text = "GROUND TELEMETRY"
		detail.text = "Click the ground to inspect it.\n\nAmber outcrops: metal ore\nCyan outcrops: ice\n\nUndiscovered deposits stay hidden until surveyed."
		return
	selection_title.text = "SECTOR  %02d : %02d" % [selected.x, selected.y]
	if not cell.scanned:
		detail.text = "UNSURVEYED\n\nSelect Survey [1] and click here to resolve local resources and foundations."
		return
	detail.text = "%s\nMean solar exposure  %.0f%%\n" % ["Stable foundation" if cell.buildable else "Unstable ground", cell.light * 100]
	if cell.resource != "":
		detail.text += "%s  %.1f / %.1f t\n" % ["Metal-bearing ore" if cell.resource == "metal" else "Accessible ice", cell.remaining, cell.initial]
	else:
		detail.text += "No mapped deposit\n"
	var structure: Dictionary = site.structure_at(selected.x, selected.y)
	if not structure.is_empty():
		detail.text += "\n%s\n%s\nConstruction  %d%%\nService efficiency  %d%%" % [Surface.RECIPES[structure.kind].label.to_upper(), structure.status, int(structure.progress * 100), int(structure.efficiency * 100)]
		if structure.queue.size() > 0:
			detail.text += "\nRepeating: " + ", ".join(structure.queue)
		if structure.kind == "refuge":
			detail.text += "\nConsumes 0.02 water + 0.002 components / h."
		if structure.kind == "testbed":
			trial_button.visible = structure.progress >= 1.0
			detail.text += "\nTrial: %.1f K · %.3f bar\nLive culture %.1f g" % [structure.trial.temperature_k, Surface.Testbed.pressure(structure.trial), structure.trial.biomass_kg * 1000.0]
		toggle_button.visible = structure.kind != "seed"
		toggle_button.text = "SUSPEND OPERATION" if structure.enabled else "RESUME OPERATION"

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

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
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
				return_to_orbit()
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
