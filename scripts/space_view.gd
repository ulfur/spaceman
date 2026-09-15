extends Control
## Pointer input is confined to the rendered map. Empty HUD containers ignore it.
signal contact_selected(id: String)
signal contact_entered(id: String)
var universe: Node
var body_id := ""
var regional := false
var selection_only := false
var dragging := false
var drag_distance := 0.0
var double_click := false

func _ready() -> void:
	universe = preload("res://scripts/universe.gd").shared(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(func(): universe.hovered = "")

func _process(_delta: float) -> void:
	# The hit area and clipping follow the rendered viewport, not an invisible
	# full-screen panel that can consume events over another instrument.
	global_position = universe.frame.position
	size = universe.frame.size

func show_body(body: Dictionary) -> void:
	if body.is_empty(): return
	var changed := body_id != String(body.id)
	body_id = body.id
	if changed: universe.body_view(body_id, regional, not selection_only)
	else: universe.update_ephemeris(); universe.render_frame()
	selection_only = false

func frame_body() -> void:
	universe.tracking = body_id
	universe.fly(universe.positions[body_id], universe.radii[body_id] * 3.3, universe.direction)

func frame_family() -> void:
	universe.family_view(body_id)

func day_side() -> void:
	universe.tracking = body_id
	universe.fly(universe.positions[body_id], universe.radii[body_id] * 3.3, universe.day_direction(body_id))

func clicked(pixel: Vector2, twice: bool) -> void:
	var id: String = universe.pick_contact(pixel)
	if id == "": return
	contact_selected.emit(id)
	if twice: contact_entered.emit(id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging or event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
			drag_distance += event.relative.length()
			universe.turn(event.relative); accept_event()
		universe.hovered = universe.pick_contact(event.position + global_position)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if universe.hovered != "" else CURSOR_CROSS
	elif event is InputEventMagnifyGesture:
		universe.zoom(1.0 / maxf(event.factor, 0.01)); accept_event()
	elif event is InputEventPanGesture:
		universe.zoom(exp(event.delta.y * 0.12)); accept_event()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var amount: float = event.factor if event.factor > 0 else 1.0
			universe.zoom(exp(amount * (-0.22 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.22))); accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true; drag_distance = 0; double_click = event.double_click
			else:
				dragging = false
				if drag_distance < 5: clicked(event.position + global_position, double_click)
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	var menu := get_parent().get_node_or_null("ExpeditionMenu")
	if menu != null and menu.visible: return
	if not event is InputEventKey or not event.pressed or event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return
	if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]: universe.zoom(0.8)
	elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]: universe.zoom(1.25)
	elif event.keycode == KEY_HOME: frame_family()
	elif event.keycode == KEY_F: frame_body()
	else: return
	get_viewport().set_input_as_handled()
