extends SceneTree
## Runs the real main scene and its button callbacks, then captures rendered frames.

var game: Control
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func press(node_name: String) -> void:
	var node = game.find_child(node_name, true, false)
	if node == null or node.disabled:
		check(false, "Missing or disabled button: " + node_name)
		return
	node.pressed.emit()

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.save_png("res://build/" + filename) == OK, "Screenshot saved: " + filename)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.sim.state.year == 2400, "Fresh scene starts at year 2400")
	press("Action_survey")
	press("Action_deploy")
	check(game.sim.state.bodies.eir_iii.factory == "warming", "UI deploys a warming factory")
	await capture("01-frozen-world.png")
	check(game.get_global_rect().encloses(game.find_child("Depart", true, false).get_global_rect()), "Departure remains within the visible interface")
	press("Chart")
	await capture("02-interstellar-chart.png")
	press("Depart")
	check(game.travel_dialog.visible, "Transit requires its confirmation dialog")
	game.travel_dialog.hide()
	game.travel_dialog.confirmed.emit()
	check(game.sim.state.system == "vesper", "UI transit arrives at Vesper")
	press("Action_survey")
	press("Action_deploy")
	press("Wait10")
	press("Action_collect")
	check(game.sim.state.ship.propellant > 115.0, "UI collects locally manufactured supplies")
	press("Depart")
	game.travel_dialog.hide()
	game.travel_dialog.confirmed.emit()
	check(game.sim.state.first_rain, "UI expedition reaches first rain")
	game.milestone_dialog.hide()
	press("Action_seed")
	press("Wait50")
	check(game.sim.state.bodies.eir_iii.biomass > 0.5, "UI can seed and grow a biosphere")
	await capture("03-first-rain.png")
	check("ocean world" in game.subtitle.text, "Planet description reflects its changed state")
	root.size = Vector2i(1100, 760)
	await capture("04-compact-window.png")
	print("UI expedition: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
