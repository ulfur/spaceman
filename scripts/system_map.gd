extends Control
signal selected_body(id: String)
signal entered_body(id: String)
var session: RefCounted
var system := "eir"
var selected := "eir_iii"
var universe: Node
var hovered := ""

func prepare_icons() -> void:
	universe = preload("res://scripts/universe.gd").shared(self)
	universe.system_view(system)

func region() -> Rect2:
	return universe.frame

func centre() -> Vector2:
	return universe.project_body(system)

func body_position(id: String) -> Vector2:
	return universe.project_body(id)

func recenter() -> void:
	universe.system_view(system)

func _gui_input(event: InputEvent) -> void:
	if universe == null: return
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT): universe.turn(event.relative)
		hovered = ""
		var closest := 20.0
		# Prefer the primary when a moon has not yet been spatially resolved.
		for definition in session.expedition.scenario.bodies:
			if definition.system != system or not universe.points.has(definition.id): continue
			var delta: float = body_position(definition.id).distance_to(event.position)
			if definition.kind == "moon": delta += 5.0
			if delta < closest: closest = delta; hovered = definition.id
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if hovered != "" else CURSOR_ARROW
	if event is InputEventMagnifyGesture:
		universe.zoom(1.0 / event.factor); accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			universe.zoom(0.75 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.3333); accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and hovered != "":
			selected_body.emit(hovered)
			if event.double_click: entered_body.emit(hovered)
			accept_event()
