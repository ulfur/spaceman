extends SceneTree
const Driver = preload("res://tests/ui_driver.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	var session = Session.get_shared()
	session.reset(); session.initialized = true
	session.command("survey", "eir_iii")
	for view in ["main", "system", "regions", "surface", "prospects", "testbeds"]:
		print("Display check begins: ", view)
		if view == "testbeds":
			session.command("travel", "prospect_0")
			session.observe("prospect_0", "probe")
			session.surface_body = "prospect_0_b"
		var game: Control = load("res://scenes/" + view + ".tscn").instantiate()
		root.add_child(game); current_scene = game
		# Hosted Macs expose Apple's CPU renderer. This gate tests native window
		# state and HUD hit-testing; Linux walkthroughs render the full 3D frames.
		if OS.get_name() == "macOS":
			for control in root.find_children("*", "SubViewportContainer", true, false): control.stretch_shrink = 8
		await process_frame
		check(await Driver.click(self, game, "Fullscreen"), "Visible fullscreen control on " + view)
		await create_timer(1.6).timeout
		check(root.mode == Window.MODE_FULLSCREEN, "Native fullscreen accepted on " + view + " (" + OS.get_name() + ")")
		# Keep a menu open to prove the global shortcut is not eaten by HUD focus.
		check(await Driver.click(self, game, "Menu"), "Menu available in fullscreen")
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_F; key.ctrl_pressed = true; key.meta_pressed = true; key.pressed = pressed
			root.push_input(key, true)
		await create_timer(1.6).timeout
		check(root.mode == Window.MODE_WINDOWED, "Control–Command–F restores window with menu focused on " + view)
		game.queue_free(); await process_frame
	print("Native display controls on %s: %d failures" % [OS.get_name(), failures])
	quit(1 if failures else 0)
