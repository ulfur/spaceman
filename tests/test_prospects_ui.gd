extends SceneTree
const Session = preload("res://scripts/session.gd")
var game: Control
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func click_position(position_value: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position_value
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position_value
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func click(name: String) -> void:
	var node: Control = game.find_child(name, true, false)
	check(node != null, "Control exists: " + name)
	if node != null:
		click_position(node.get_global_transform_with_canvas() * (node.size / 2.0))

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/" + name) == OK, "Screenshot captured")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var session = Session.get_shared()
	session.reset()
	session.initialized = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	root.notify_mouse_entered()
	click("Prospects")
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Observatory", "Orbital navigation enters observatory")
	await capture("08-prospect-catalogue.png")
	var chosen := "prospect_1"
	click_position(game.map.get_global_transform_with_canvas() * game.map.star_position(chosen))
	check(game.selected == chosen, "Map star can be selected by mouse")
	click("Observe_photometry")
	check(session.prospects.evidence(chosen).has("flux_low"), "Instrument button resolves exposure")
	click("Observe_spectrum")
	click("Observe_monitor")
	check(session.prospects.evidence(chosen).has("activity_band"), "Activity programme updates evidence")
	await capture("09-prospect-evidence.png")
	click("ProspectDepart")
	check(game.travel_dialog.visible, "Transit is reviewed before commitment")
	game.travel_dialog.hide()
	game.travel_dialog.confirmed.emit()
	check(session.expedition.state.system == chosen, "Chosen destination reached")
	click("Observe_probe")
	check(session.site_available(chosen + "_b"), "Local probe opens new surface")
	check("Atmospheric column" in game.dossier.text, "Dossier exposes local shielding context")
	await process_frame
	game.find_child("DossierScroll", true, false).scroll_vertical = 10000
	await capture("10-prospect-local-probe.png")
	root.size = Vector2i(1100, 760)
	await capture("11-prospect-compact.png")
	check(game.get_global_rect().encloses(game.find_child("ObservationTools", true, false).get_global_rect()), "Instrument dock fits compact window")
	click("ProspectSurface")
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Surface", "Prospect opens actual 3D surface")
	check(game.site.state.has("solar_factor"), "Generated planet affects loaded surface state")
	await capture("12-prospect-surface.png")
	click("ReturnOrbit")
	await process_frame
	await process_frame
	game = current_scene
	check(game.sim.state.system == chosen and game.selected == chosen + "_b", "Orbital view stays in generated system")
	click("Prospects")
	await process_frame
	await process_frame
	game = current_scene
	click("NewProspects")
	check(game.reset_dialog.visible, "New seed requires explicit reset confirmation")
	await capture("13-prospect-new-expedition.png")
	game.seed_input.value = 1702
	game.reset_dialog.hide()
	game.reset_dialog.confirmed.emit()
	check(session.prospects.state.seed == 1702 and session.expedition.state.system == "eir", "Confirmed reset changes neighbourhood and resets expedition")
	print("Prospects UI: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
