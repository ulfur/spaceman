extends Node
## One native-window controller for all HUDs, including modal menus.
var previous_mode := Window.MODE_WINDOWED
var changing := false

func _ready() -> void:
	get_tree().root.size_changed.connect(refresh_buttons)

func refresh_buttons() -> void:
	for control in get_tree().get_nodes_in_group("FullscreenButtons"):
		control.text = "Windowed" if fullscreen() else "Full screen"

static func shared(owner: Node) -> Node:
	var root := owner.get_tree().root
	var service := root.get_node_or_null("DisplayControls")
	if service == null:
		service = load("res://scripts/display_controls.gd").new()
		service.name = "DisplayControls"
		root.add_child(service)
	return service

static func is_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	return event.keycode == KEY_F11 or (event.keycode == KEY_F and event.ctrl_pressed and event.meta_pressed) or (event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.alt_pressed)

func _input(event: InputEvent) -> void:
	if is_shortcut(event):
		get_viewport().set_input_as_handled()
		toggle()

func fullscreen() -> bool:
	return get_tree().root.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func toggle() -> void:
	if changing: return
	var window := get_tree().root
	# Editor embedding owns the native window. Do not silently fullscreen its host.
	var embedded := window.is_embedded()
	for argument in OS.get_cmdline_args():
		if argument == "--embedded" or argument == "--wid" or argument.begins_with("--wid="): embedded = true
	if embedded:
		explain("The editor owns this game window. Stop the game, turn off Embed Game on Play in Godot's Game workspace, then run again. The standalone game supports full screen here, with Control–Command–F or Option–Return.")
		return
	changing = true
	var entering := not fullscreen()
	if entering:
		previous_mode = window.mode
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = previous_mode if previous_mode == Window.MODE_MAXIMIZED else Window.MODE_WINDOWED
	# Cocoa's transition is asynchronous; read the resulting native mode.
	await get_tree().create_timer(0.8).timeout
	changing = false
	refresh_buttons()
	if fullscreen() != entering and DisplayServer.get_name() != "headless":
		explain("The window manager did not accept full screen. If you are running inside Godot, stop the game and disable Embed Game on Play, then run in its own window. On a Mac you can also use the green window control.")

func explain(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Full screen"
	dialog.dialog_text = message
	dialog.dialog_autowrap = true
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560, 210))

func add_button(row: HBoxContainer) -> void:
	var control := Button.new()
	control.name = "Fullscreen"
	control.text = "Full screen"
	control.add_theme_font_size_override("font_size", 13)
	control.custom_minimum_size.y = 42
	control.tooltip_text = "Full screen / windowed · Control–Command–F · Option/Alt–Return · F11"
	control.pressed.connect(toggle)
	row.add_child(control)
	control.add_to_group("FullscreenButtons")
	control.text = "Windowed" if fullscreen() else "Full screen"
