extends RefCounted
## Change the HUD; the astronomical camera and world survive under it.
static var busy := false
static var pending := false

static func go(owner: Control, scene: String, _anchor: Vector2, _inward: bool = true) -> void:
	if busy: return
	busy = true; pending = true
	var tree := owner.get_tree()
	var universe := tree.root.get_node_or_null("Universe")
	if universe != null and scene in ["res://scenes/surface.tscn", "res://scenes/testbeds.tscn"]: universe.suspend()
	tree.change_scene_to_file(scene)
	await tree.process_frame
	await tree.process_frame
	while is_instance_valid(universe) and universe.active and universe.moving(): await tree.process_frame
	busy = false; pending = false

static func arrive(_owner: Control, _visual: Control, _focus: Vector2 = Vector2(-1, -1)) -> void:
	# No screenshot capture, scaling of controls, or replacement sphere.
	pass
