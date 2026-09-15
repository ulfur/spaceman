extends RefCounted
## Exercise GUI hit-testing, including layouts that settle after a tab changes.
static func click(tree: SceneTree, game: Control, id: String) -> bool:
	await settle(tree)
	var node: Control = game.find_child(id, true, false)
	if node == null or not node.is_visible_in_tree() or (node is BaseButton and node.disabled):
		printerr("FAIL: Control unavailable: " + id)
		return false
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(node)
		parent = parent.get_parent()
	await tree.process_frame
	await tree.process_frame
	point(node.get_window(), node.get_global_transform_with_canvas() * (node.size / 2.0))
	return true

static func point(window: Window, position: Vector2) -> void:
	if not window.has_meta("driver_pointer_entered"):
		window.notify_mouse_entered()
		window.set_meta("driver_pointer_entered", true)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	window.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		window.push_input(event, true)

static func key(window: Window, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		window.push_input(event, true)

static func settle(tree: SceneTree) -> void:
	while preload("res://scripts/navigation.gd").busy:
		await tree.process_frame
	await tree.process_frame
