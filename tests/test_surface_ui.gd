extends SceneTree
const Session = preload("res://scripts/session.gd")
var game: Control
var failures := 0
var mouse_initialized := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/" + filename) == OK, "Rendered screenshot " + filename)

func click_position(position_value: Vector2) -> void:
	# Go through GUI hit-testing, not just a manually emitted callback signal.
	if not mouse_initialized:
		root.notify_mouse_entered()
		mouse_initialized = true
	var motion := InputEventMouseMotion.new()
	motion.position = position_value
	motion.global_position = position_value
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position_value
		event.global_position = position_value
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func click_control(node: Control) -> void:
	click_position(node.get_global_transform_with_canvas() * (node.size / 2.0))

func click_cell(cell: Vector2i) -> void:
	var position_value: Vector3 = game.world.cell_position(cell.x, cell.y)
	var screen: Vector2 = game.world.camera.unproject_position(position_value)
	check(game.world.pick_cell(screen) == cell, "Camera picking agrees with rendered ground " + str(cell))
	click_position(game.viewport_container.get_global_transform_with_canvas() * screen)

func build(kind: String) -> void:
	var button: Button = game.find_child("Tool_" + kind, true, false)
	check(button != null, "Tool visible: " + kind)
	click_control(button)
	check(game.tool == kind, "Hit-tested tool selection " + kind)
	var chosen := Vector2i(-1, -1)
	var best := 1000.0
	for cell in game.site.state.cells:
		if game.site.can_place(kind, cell.x, cell.z).ok:
			var distance: float = Vector2(cell.x - 10, cell.z - 10).length()
			if distance < best:
				best = distance
				chosen = Vector2i(cell.x, cell.z)
	check(chosen.x >= 0, "Legal UI placement for " + kind)
	if chosen.x >= 0:
		click_cell(chosen)
	game.session.advance_hours(22)
	game.refresh()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var session = Session.get_shared()
	session.reset()
	session.initialized = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	click_control(game.find_child("Action_survey", true, false))
	await process_frame
	check(game.find_child("Surface", true, false) != null, "Orbital survey exposes surface entry")
	click_control(game.find_child("Surface", true, false))
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Surface", "Orbital button loads real surface scene")
	await process_frame
	var terrain: MeshInstance3D = game.world.get_node("Terrain")
	var arrays: Array = terrain.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_NORMAL][0].y > 0.5, "Terrain faces upward rather than being back-face culled")
	check(game.speed == 0, "Surface starts paused")
	await capture("05-surface-survey.png")
	click_cell(Vector2i(10, 10))
	check(game.site.state.landed, "Terrain click lands actual ship module")
	var roof: Vector2 = game.world.camera.unproject_position(game.world.cell_position(10, 10) + Vector3(0, 3.0, 0))
	check(game.world.pick_cell(roof, true) == Vector2i(10, 10), "Inspecting a roof selects its machine, not ground behind it")
	for kind in ["solar", "solar", "solar", "mine", "ice_well", "refinery", "fabricator", "refuge"]:
		build(kind)
	click_control(game.find_child("Speed10", true, false))
	game._process(0.4)
	check(game.speed == 10, "Speed control drives simulation")
	click_control(game.find_child("Speed0", true, false))
	var hour: int = game.site.state.total_hours
	game._process(2.0)
	check(game.site.state.total_hours == hour, "Pause stops the authoritative clock")
	game.session.advance_hours(110)
	game.set_tool("inspect")
	game.refresh()
	check(game.site.state.milestone, "Rendered production chain establishes refuge")
	game.world.zoom_camera(-20)
	await capture("06-surface-industry.png")
	check(game.get_global_rect().encloses(game.find_child("Toolbelt", true, false).get_global_rect()), "Toolbelt fits normal window")
	click_control(game.find_child("ToggleStructure", true, false))
	check(not game.site.structure_at(game.selected.x, game.selected.y).enabled, "Selected installation can be suspended")
	root.size = Vector2i(1100, 760)
	await capture("07-surface-compact.png")
	check(game.get_global_rect().encloses(game.find_child("Toolbelt", true, false).get_global_rect()), "Toolbelt fits compact window")
	var hours_before_return: int = game.site.state.total_hours
	click_control(game.find_child("ReturnOrbit", true, false))
	await process_frame
	await process_frame
	game = current_scene
	check(game.name == "Spaceman", "Return button restores orbital scene")
	click_control(game.find_child("Surface", true, false))
	await process_frame
	await process_frame
	game = current_scene
	check(game.site.state.total_hours == hours_before_return and game.site.state.landed, "Re-entering surface preserves clock and module")
	print("Surface UI: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
