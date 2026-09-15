extends SceneTree
## Regressions for the reported startup, inert zoom and unpickable contacts.
const Driver = preload("res://tests/ui_driver.gd")
const Session = preload("res://scripts/session.gd")
var game: Control
var universe: Node
var failures := 0
var session = Session.get_shared()

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; printerr("FAIL: " + message)
func click(id: String) -> void:
	check(await Driver.click(self, game, id), "Click " + id)
func settle() -> void:
	await Driver.settle(self)
	while universe.moving() or universe.zoom_target > 0: await process_frame
func point(at: Vector2) -> void:
	Driver.point(root, game.get_global_transform_with_canvas() * at)
func gesture(event: InputEventGesture) -> void:
	event.position = game.get_global_transform_with_canvas() * universe.frame.get_center()
	root.push_input(event, true)
func capture(name: String) -> void:
	if OS.get_name() == "macOS" or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/" + name + ".png") == OK, "Capture " + name)

func run() -> void:
	session.reset(); session.initialized = true
	session.command("travel", "prospect_3"); session.observe("prospect_3", "probe")
	session.choose_region("prospect_3_b", Vector2i(48, 15))
	var saved: String = session.save_json()
	session.reset()
	check(session.restore_json(saved).ok, "Restore a generated system before normal scene initialization")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame; await process_frame
	game = current_scene; universe = root.get_node("Universe")
	if OS.get_name() == "macOS": universe.container.stretch_shrink = 8
	await settle()
	check(root.get_node("DisplayControls").is_node_ready() and universe.is_node_ready(), "Both presentation services are ready before the HUD")
	check(universe.positions.has("prospect_3_b") and universe.meshes.has("prospect_3_b"), "Restored generated planet resolves into the physical scene")
	await click("FrameMoons"); await settle()
	var physical_state: String = session.save_json()
	var original: float = universe.distance
	await click("NavZoomIn")
	check(universe.distance < original, "Visible zoom responds immediately")
	await settle()
	var before_wheel: float = universe.distance
	point(universe.frame.get_center())
	for step in range(8):
		var event := InputEventMouseButton.new()
		event.position = game.get_global_transform_with_canvas() * (universe.frame.get_center() + Vector2(85, 25))
		event.button_index = MOUSE_BUTTON_WHEEL_UP; event.pressed = true
		root.push_input(event, true)
		event = event.duplicate(); event.pressed = false; root.push_input(event, true)
	await settle()
	check(universe.distance < before_wheel * 0.25, "Rapid wheel events accumulate instead of restarting an inert tween")
	var before_pan: float = universe.distance
	var pan := InputEventPanGesture.new(); pan.delta = Vector2(0, 2)
	gesture(pan); await settle()
	check(universe.distance > before_pan * 1.15, "Mac two-finger scrolling reaches map zoom")
	var before_pinch: float = universe.distance
	var pinch := InputEventMagnifyGesture.new(); pinch.factor = 1.4
	gesture(pinch); await settle()
	check(universe.distance < before_pinch * 0.8, "Trackpad pinch reaches map zoom")
	await click("FrameMoons"); await settle()
	var parent: Vector2 = universe.project_body("prospect_3_b")
	var moon: Vector2 = universe.project_body("prospect_3_c")
	var range_before: float = universe.distance
	point(moon)
	check(game.selected == "prospect_3_c", "A moon is selectable in orbit by its projected position")
	check(is_equal_approx(universe.distance, range_before), "Single-click targets without moving the camera")
	await click("FramePlanet"); await settle()
	check(universe.project_body("prospect_3_c").distance_to(universe.frame.get_center()) < 1, "Focus approaches the selected contact")
	check(universe.contact_hits.has("prospect_3_b"), "The parent remains accessible as an off-screen bearing")
	point(universe.contact_hits.prospect_3_b.label_rect.get_center())
	check(game.selected == "prospect_3_b", "Off-screen parent bearing selects the actual parent")
	await click("FrameMoons"); await settle()
	await capture("32-command-orbit")
	await click("Surface")
	await process_frame; await process_frame
	game = current_scene
	await settle()
	check(game.name == "Regions" and universe.mode == "regions", "Surface enters geographic survey")
	check(universe.distance < universe.radii.prospect_3_b * 3, "Survey approaches the chosen geographic hemisphere")
	# Rendering resolution and instrument coordinates must remain independent.
	var previous_shrink: int = universe.container.stretch_shrink
	universe.container.stretch_shrink = 3
	await process_frame; await process_frame
	check(universe.project_body("prospect_3_b").distance_to(universe.frame.get_center()) < 1, "Changing rendering resolution preserves the instrument frame")
	var center_region: Vector2i = universe.pick_region("prospect_3_b", universe.frame.get_center())
	check(center_region == Vector2i(48, 15), "Raycasting respects scaled SubViewport coordinates")
	universe.container.stretch_shrink = previous_shrink
	await process_frame; await process_frame
	await click("Layer_ore")
	check(game.globe.screening == "ore", "Screening layer is controlled from the visible rail")
	var region := Vector2i(47, 15)
	var projection: Vector3 = universe.project_region("prospect_3_b", region)
	point(Vector2(projection.x, projection.y))
	check(game.selected == region, "Region selection still uses physical globe raycasting")
	var samples: Image = game.globe.survey_texture.get_image()
	var context: Dictionary = session.region_context("prospect_3_b", region)
	check(absf(samples.get_pixel(region.x, region.y).g - context.ore_factor) < 0.00001, "Map colours use the exact inspector's ore prior")
	var before_survey_zoom: float = universe.distance
	await click("NavZoomOut"); await settle()
	check(universe.distance > before_survey_zoom, "Survey zoom control works independently of layer selection")
	await click("LocateRegion"); await settle()
	await capture("33-command-survey")
	for id in universe.contact_hits.keys():
		var hit: Dictionary = universe.contact_hits[id]
		if not hit.edge: continue
		point(hit.label_rect.get_center())
		check(game.contact == id, "Every off-screen label selects its own contact: " + id)
	check(universe.contact_hits.has("prospect_3_c"), "Survey retains a bearing to the moon")
	point(universe.contact_hits.prospect_3_c.point)
	check(game.contact == "prospect_3_c", "Nearby objects are selectable while surveying the surface")
	await click("ApproachRegion")
	await process_frame; await process_frame
	game = current_scene; await settle()
	check(game.name == "Spaceman" and game.selected == "prospect_3_c", "Targeting from survey returns to that object's orbit")
	check(session.save_json() == physical_state, "All navigation preserves physical state and creates no factories")
	await click("SystemView")
	await process_frame; await process_frame
	game = current_scene; await settle()
	var before_system_zoom: float = universe.distance
	var system_pan := InputEventPanGesture.new(); system_pan.delta = Vector2(0, -2)
	gesture(system_pan); await settle()
	check(universe.distance < before_system_zoom, "System map shares the working trackpad controls")
	await capture("34-command-system")
	root.size = Vector2i(1100, 760)
	await process_frame; await process_frame
	await capture("35-command-compact")
	var plus: Control = game.find_child("NavZoomIn", true, false)
	check(game.get_global_rect().encloses(plus.get_global_rect()), "Zoom rail fits the compact window")
	print("Command navigation on %s: %d failures" % [OS.get_name(), failures])
	quit(1 if failures else 0)
