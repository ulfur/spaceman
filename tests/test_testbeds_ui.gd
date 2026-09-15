extends SceneTree
const Driver = preload("res://tests/ui_driver.gd")
const Session = preload("res://scripts/session.gd")
var game: Control
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/" + filename) == OK, "Capture " + filename)

func click_position(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func click(id: String) -> void:
	check(await Driver.click(self, game, id), "Click " + id)

func click_cell(cell: Vector2i) -> void:
	var point: Vector2 = game.world.camera.unproject_position(game.world.cell_position(cell.x, cell.y))
	check(game.world.pick_cell(point) == cell, "Terrain picking resolves testbed location")
	click_position(game.viewport_container.get_global_transform_with_canvas() * point)

func build(kind: String) -> void:
	await click("BuildPalette")
	await click("BuildLifesupport" if kind in ["refuge", "testbed"] else "BuildIndustry")
	await click("Tool_" + kind)
	var chosen := Vector2i(-1, -1)
	var best := 1000.0
	for cell in game.site.state.cells:
		if game.site.can_place(kind, cell.x, cell.z).ok:
			var distance: float = Vector2(cell.x - 10, cell.z - 10).length()
			if distance < best:
				best = distance
				chosen = Vector2i(cell.x, cell.z)
	check(chosen.x >= 0, "Legal placement: " + kind)
	if chosen.x >= 0: click_cell(chosen)
	game.session.advance_hours(28)
	game.refresh()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var session = Session.get_shared()
	session.reset()
	session.initialized = true
	# Choose a temperate candidate for this walkthrough; the UI receives only
	# the local probe evidence, and the model suite covers hostile conditions.
	var target := "prospect_0"
	var difference := 1000.0
	for id in session.prospects.worlds:
		var distance: float = absf(session.prospects.worlds[id].ambient_k - 288)
		if distance < difference:
			difference = distance
			target = id
	session.command("travel", target)
	session.observe(target, "probe")
	session.surface_body = target + "_b"
	game = load("res://scenes/surface.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	root.notify_mouse_entered()
	click_cell(Vector2i(10, 10))
	check(game.site.state.landed, "Mouse lands a module on the generated region")
	for kind in ["solar", "solar", "mine", "testbed"]:
		await build(kind)
	var selected: Dictionary = game.site.structure_at(game.selected.x, game.selected.y)
	check(selected.kind == "testbed" and selected.progress == 1, "Real 3D testbed is built")
	await capture("14-testbed-surface.png")
	await click("OpenTrial")
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Testbeds", "Selected surface structure opens its engineering controls")
	await capture("15-testbed-uncontrolled.png")
	await click("Thermal_auto")
	await click("PressureControl")
	await click("WaterFeed")
	await click("ControlsShielding")
	await click("GrowLight")
	await click("FitFilter")
	check("Installing" in game.buttons.FitFilter.text, "Shielding controls acknowledge the pending installation")
	await capture("22-trial-shielding-controls.png")
	await click("TrialDay")
	check(game.structure.trial.filter, "Filter button builds a real upgrade over time")
	await click("FitCanopy")
	await click("TrialWeek")
	check(game.structure.trial.canopy, "Canopy consumes mined material and finishes")
	var archives: int = session.expedition.state.ship.seeds
	await click("ControlsCulture")
	await click("Inoculate")
	check(session.expedition.state.ship.seeds == archives - 1, "UI inoculation allocates an archive")
	await click("TrialWeek")
	await click("TrialWeek")
	check(game.structure.trial.established and game.structure.trial.biomass_kg > 0.02, "Configured UI experiment establishes a culture")
	var recorded: String = session.save_json()
	await click("Graph_biomass")
	check(game.diagram.view_mode == "history", "Measurement tab opens the full graph")
	await capture("20-testbed-history.png")
	await click("ViewChamber")
	check(session.save_json() == recorded, "Changing views does not alter the experiment")
	await capture("16-testbed-established.png")
	await click("TrialSpeed10")
	var hour: int = game.site.state.total_hours
	game._process(0.4)
	check(game.site.state.total_hours >= hour + 4, "Continuous time advances the trial")
	await click("TrialSpeed0")
	hour = game.site.state.total_hours
	game._process(2.0)
	check(game.site.state.total_hours == hour, "Pause stops trial and site time")
	root.size = Vector2i(1100, 760)
	await capture("17-testbed-compact.png")
	check(game.get_global_rect().encloses(game.find_child("TrialToolbar", true, false).get_global_rect()), "Trial controls fit the compact viewport")
	await click("ControlsShielding")
	await click("GrowLight")
	await click("TrialWeek")
	check(game.structure.trial.biomass_kg < 0.001, "Losing light under an opaque canopy kills the culture")
	await click("ControlsCulture")
	await click("Graph_biomass")
	await capture("18-testbed-failed-light.png")
	await click("TrialSurface")
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Surface" and game.site.testbed_at(session.trial_id).trial.detritus_kg > 0.01, "Surface reacquires the actual trial outcome")
	print("Testbeds UI: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
