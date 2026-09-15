extends SceneTree
const Driver = preload("res://tests/ui_driver.gd")
const Session = preload("res://scripts/session.gd")
const Atlas = preload("res://scripts/world_atlas.gd")
const Nav = preload("res://scripts/navigation.gd")
var game: Control
var failures := 0
var session = Session.get_shared()
var movie_frame := 0

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; printerr("FAIL: " + message)
func click(id: String) -> void:
	check(await Driver.click(self, game, id), "Click " + id)
func arrived() -> void:
	await process_frame
	await process_frame
	game = current_scene
	await Driver.settle(self)
func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/" + filename) == OK, "Capture " + filename)
func transition() -> void:
	check(Nav.busy, "Navigation begins a HUD handoff")
	var frames := 0
	while Nav.busy or frames < 5:
		await capture("zoom-%02d.png" % movie_frame)
		movie_frame += 1
		frames += 1
		if frames > 100: break
	await arrived()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	session.reset(); session.initialized = true
	game = load("res://scenes/prospects.tscn").instantiate()
	root.add_child(game); current_scene = game
	await process_frame
	Driver.point(root, game.map.get_global_transform_with_canvas() * game.map.star_position("eir"))
	check(game.selected == "eir", "A star is selected spatially")
	var unchanged: String = session.save_json()
	await click("ResolveSystem")
	await transition()
	check(game.name == "System", "Chart resolves a system map")
	check(session.save_json() == unchanged, "Camera approach does not change physical expedition")
	var universe := root.get_node("Universe")
	var body_instance: int = universe.meshes.eir_iii.get_instance_id()
	var planet: Vector2 = game.map.body_position("eir_iii")
	var moon: Vector2 = game.map.body_position("nacre")
	check(planet.distance_to(moon) < 2 and planet.distance_to(game.map.centre()) > 60, "At physical system scale the moon is unresolved beside its parent")
	Driver.point(root, game.map.get_global_transform_with_canvas() * planet)
	check(game.selected == "eir_iii", "Planet can be selected on its orbit")
	await capture("24-system-map.png")
	await click("ApproachBody")
	await transition()
	check(game.name == "Spaceman" and game.selected == "eir_iii", "Approach retains the selected planet")
	check(universe.meshes.eir_iii.get_instance_id() == body_instance, "Approach uses the same physical world mesh")
	await click("FrameMoons")
	while universe.moving(): await process_frame
	check(universe.project_body("eir_iii").distance_to(universe.project_body("nacre")) > 30, "Approaching the family resolves the real lunar separation")
	await capture("31-planet-and-moon.png")
	await click("FramePlanet")
	while universe.moving(): await process_frame
	await click("Select_nacre")
	while universe.moving(): await process_frame
	await click("FrameMoons")
	while universe.moving(): await process_frame
	await click("FramePlanet")
	while universe.moving(): await process_frame
	check(universe.project_body("nacre").distance_to(universe.frame.get_center()) < 1.0, "Returning from a lunar family tracks the selected moon, not its parent")
	await click("Select_eir_iii")
	while universe.moving(): await process_frame
	await click("Action_survey")
	var pose: Basis = universe.meshes.eir_iii.basis.orthonormalized()
	var camera_pose: Vector3 = universe.direction
	await click("Surface")
	await transition()
	check(game.name == "Regions", "Planet approach exposes geographic selection")
	check(universe.meshes.eir_iii.get_instance_id() == body_instance and universe.meshes.eir_iii.basis.orthonormalized().is_equal_approx(pose), "Survey approach retains the physical planet and its orientation")
	check(not universe.direction.is_equal_approx(camera_pose) and universe.distance < universe.radii.eir_iii * 3, "Survey approaches the selected geography at a closer range")
	await click("LocateRegion")
	while universe.moving(): await process_frame
	var region := Vector2i(48, 15)
	var projected: Vector3 = game.globe.project(region)
	Driver.point(root, game.globe.get_global_transform_with_canvas() * Vector2(projected.x, projected.y))
	check(game.selected == region, "Globe click resolves actual latitude and longitude")
	check(session.sites.is_empty(), "Selecting a candidate does not instantiate industry")
	await capture("25-geographic-selection.png")
	await click("ApproachRegion")
	await transition()
	check(game.name == "Surface" and session.surface_region == region, "Surface uses the chosen geographic address")
	var first_address: String = session.current_address()
	var first = game.site
	var expected_sun := preload("res://scripts/celestial_mechanics.gd").surface_sun(session, session.surface_body, region, session.elapsed_hours())
	check(game.world.sun.basis.z.is_equal_approx(expected_sun), "Ground lighting agrees with the selected planetary coordinates")
	var screen: Vector2 = game.world.camera.unproject_position(game.world.cell_position(10, 10))
	Driver.point(root, game.viewport_container.get_global_transform_with_canvas() * screen)
	check(first.state.landed and session.expedition.state.ship.modules == 1, "Chosen site receives the actual stocked ship module")
	var focus_before: Vector3 = game.world.focus
	var pan_event := InputEventMouseMotion.new()
	pan_event.position = Vector2(root.size) * Vector2(0.4, 0.5)
	pan_event.relative = Vector2(80, 25)
	pan_event.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(pan_event, true)
	check(game.world.focus != focus_before and game.speed == 0, "Middle drag pans the terrain while paused")
	var distance_before: float = game.world.distance
	await click("CameraOut")
	check(game.world.distance > distance_before, "Visible zoom control moves camera")
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(root.size) * Vector2(0.4, 0.5)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true
	root.push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	root.push_input(wheel, true)
	check(game.world.distance < distance_before + 10.0, "Wheel zoom reaches terrain input")
	await click("CameraHome")
	check(game.world.focus == Vector3(4, 1, 2) and game.world.distance == 64, "Home recovers a useful camera")
	var before_keys: Vector3 = game.world.focus
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D; key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.15).timeout
	key = InputEventKey.new(); key.physical_keycode = KEY_D; key.pressed = false
	Input.parse_input_event(key)
	check(game.world.focus != before_keys and game.speed == 0, "WASD navigation works independently of simulation pause")
	await capture("26-regional-industry.png")
	await click("SurfacePlanet"); await arrived()
	if game.name != "Regions":
		printerr("FAIL: Planet navigation did not leave Surface"); quit(1); return
	check(game.globe.established.size() == 1, "Planet map marks the established site")
	region = Vector2i(45, 18)
	projected = game.globe.project(region)
	Driver.point(root, game.globe.get_global_transform_with_canvas() * Vector2(projected.x, projected.y))
	check(game.selected == region, "Another region can be chosen on the same planet")
	await click("ApproachRegion"); await arrived()
	check(game.site != first and not game.site.state.landed, "A new site does not overwrite the first")
	screen = game.world.camera.unproject_position(game.world.cell_position(10, 10))
	Driver.point(root, game.viewport_container.get_global_transform_with_canvas() * screen)
	check(game.site.state.landed and session.expedition.state.ship.modules == 0, "Second geographic foothold uses the remaining module")
	await click("SurfacePlanet"); await arrived()
	check(game.globe.established.size() == 2, "Both persistent sites are visible from orbit")
	await capture("27-two-footholds.png")
	await click("Region_" + first_address.replace("@", "_").replace(",", "_"))
	await click("ApproachRegion"); await arrived()
	check(game.site == first and game.site.state.landed, "Selecting a marker returns to the original factory")
	await click("SurfaceChart"); await arrived()
	await click("GalaxyView")
	await create_timer(0.95).timeout
	await capture("28-galactic-field.png")
	var before_system: String = session.expedition.state.system
	var point: Vector2 = game.map.chart_region().get_center() + Vector2(90, -40)
	Driver.point(root, game.map.get_global_transform_with_canvas() * point)
	await create_timer(0.95).timeout
	check(session.prospects.worlds.size() == 12 and session.expedition.state.system == before_system, "Resolving a distant galactic field expands the world without travelling")
	check(game.selected.begins_with("field_"), "Resolved field selects an addressable star")
	await capture("29-distant-field.png")
	root.size = Vector2i(1100, 760)
	await capture("30-navigation-compact.png")
	check(game.get_global_rect().encloses(game.find_child("Navigation", true, false).get_global_rect()), "Expanded navigation fits compact window")
	print("Spatial navigation UI: %d failures" % failures)
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
