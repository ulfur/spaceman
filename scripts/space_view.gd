extends Control
## Input adapter for the persistent astronomical scene, not another planet image.
var universe: Node
var body_id := ""
var regional := false

func _ready() -> void:
	universe = preload("res://scripts/universe.gd").shared(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_body(body: Dictionary) -> void:
	if body.is_empty(): return
	var changed := body_id != String(body.id)
	body_id = body.id
	if changed: universe.body_view(body_id, regional)
	else: universe.update_ephemeris(); universe.render_frame()

func frame_body() -> void:
	universe.fly(universe.positions[body_id], universe.radii[body_id] * 3.3, universe.direction)

func frame_family() -> void:
	universe.family_view(body_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_LEFT):
		universe.turn(event.relative); accept_event()
	elif event is InputEventMagnifyGesture:
		universe.zoom(1.0 / event.factor); accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		universe.zoom(0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25); accept_event()
