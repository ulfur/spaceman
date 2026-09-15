extends SceneTree
## Runs the real main scene and its button callbacks, then captures rendered frames.

const Driver = preload("res://tests/ui_driver.gd")
var game: Control
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func press(id: String) -> void:
	check(await Driver.click(self, game, id), "Click " + id)

func change_view(id: String) -> void:
	await press(id)
	await process_frame
	await process_frame
	game = current_scene

func transit_to(id: String) -> void:
	await change_view("Prospects")
	Driver.point(root, game.map.get_global_transform_with_canvas() * game.map.star_position(id))
	await capture("02-interstellar-chart.png")
	await press("ProspectDepart")
	check(game.travel_dialog.visible, "Transit is reviewed before departure")
	game.travel_dialog.hide()
	game.travel_dialog.confirmed.emit()
	await change_view("LocalOrbit")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.save_png("res://build/" + filename) == OK, "Screenshot saved: " + filename)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	check(game.sim.state.year == 2400, "Fresh scene starts in year 2400")
	await capture("19-orbit-entry.png")
	await press("Action_survey")
	check(game.find_child("Surface", true, false) != null, "Survey reveals the primary surface action")
	check(game.find_child("Action_deploy", true, false) == null, "Orbital climate programme is disclosed on demand")
	await press("OrbitalIndustry")
	await press("Action_deploy")
	check(game.sim.state.bodies.eir_iii.factory == "warming", "Climate programme remains playable")
	await capture("01-frozen-world.png")
	await transit_to("vesper")
	check(game.sim.state.system == "vesper", "Chart transit reaches Vesper")
	await press("Action_survey")
	await press("Action_deploy")
	await press("Wait10")
	await press("Action_collect")
	check(game.sim.state.ship.propellant > 115.0, "Collects locally manufactured supplies")
	await transit_to("eir")
	check(game.sim.state.first_rain, "Expedition still reaches first rain")
	await press("Action_seed")
	await press("Wait50")
	check(game.sim.state.bodies.eir_iii.biomass > 0.5, "Pioneer culture still grows")
	await capture("03-first-rain.png")
	check("ocean world" in game.subtitle.text, "Description reflects the changed world")
	root.size = Vector2i(1100, 760)
	await capture("04-compact-window.png")
	check(game.get_global_rect().encloses(game.find_child("Navigation", true, false).get_global_rect()), "Shared navigation fits compact window")
	await press("Menu")
	check(game.find_child("ExpeditionMenu", true, false).visible, "Secondary commands open in Menu")
	print("UI expedition: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
