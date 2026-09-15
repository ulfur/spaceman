extends Control
signal selected_body(id: String)
signal entered_body(id: String)
const Atlas = preload("res://scripts/world_atlas.gd")
var session: RefCounted
var system := "eir"
var selected := "eir_iii"
var points: Dictionary = {}
var zoom := 1.0
var pan := Vector2.ZERO
var hovered := ""

func region() -> Rect2:
	return Rect2(32, 202, maxf(320, size.x - 460), maxf(340, size.y - 334))

func centre() -> Vector2:
	return region().get_center() + pan

func orbit_radius(au: float) -> float:
	# Log compression keeps moons and outer planets legible. Never labelled as a ruler.
	return (55.0 + log(1.0 + au) * 88.0) * zoom

func body_position(id: String) -> Vector2:
	var body: Dictionary = session.expedition.state.bodies[id]
	var data: Dictionary = session.prospects.evidence(system)
	var orbit := Atlas.orbit(body, data)
	var angle: float = orbit.phase + fmod(session.elapsed_hours() / 8766.0, orbit.period_years) / orbit.period_years * TAU
	var origin := centre()
	var radius := orbit_radius(orbit.au)
	if orbit.parent != system:
		origin = body_position(orbit.parent)
		radius = 33.0 * zoom
	return origin + Vector2(cos(angle), sin(angle) * 0.62) * radius

func _draw() -> void:
	if session == null: return
	var font := ThemeDB.fallback_font
	var origin := centre()
	var data: Dictionary = session.prospects.evidence(system)
	var resolved: bool = system == session.expedition.state.system or data.is_empty() or data.has("orbit_low")
	var color := Color("edc58e") if data.get("type") != "M V" else Color("e9916a")
	for i in range(24, 0, -1): draw_circle(origin, i * 2.4 * zoom, Color(color, 0.002 * (25 - i)))
	draw_circle(origin, 13.0 * zoom, color)
	draw_string(font, origin + Vector2(-25, 38) * zoom, session.expedition.system_name(system), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	points.clear()
	if not resolved:
		draw_arc(origin, 125, 0, TAU, 96, Color("30444d"), 1.0, true)
		draw_string(font, origin + Vector2(-150, 160), "Acquire an orbit fit to resolve this system", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("93a8b0"))
		return
	for definition in session.expedition.scenario.bodies:
		if definition.system != system: continue
		var orbit := Atlas.orbit(definition, data)
		var parent := origin if orbit.parent == system else body_position(orbit.parent)
		var radius: float = orbit_radius(orbit.au) if orbit.parent == system else 33.0 * zoom
		var path := PackedVector2Array()
		for step in range(129):
			var a := step * TAU / 128.0
			path.append(parent + Vector2(cos(a), sin(a) * 0.62) * radius)
		draw_polyline(path, Color("30434a") if definition.kind == "world" else Color("52635e"), 1.0, true)
		var point := body_position(definition.id)
		points[definition.id] = point
		var tint := Color("95bac8") if definition.kind == "world" else Color("b4a38e")
		var r := 8.0 if definition.kind == "world" else 4.0
		draw_circle(point, r * zoom + 3, Color(tint, 0.12))
		draw_circle(point, r * zoom, tint)
		draw_circle(point + Vector2(2, 1) * zoom, r * zoom * 0.7, tint.darkened(0.45))
		if definition.id == selected or definition.id == hovered:
			draw_arc(point, r * zoom + 11, 0, TAU, 64, Color("c1d9cd"), 1.5, true)
		var offset := Vector2(13, -15) if definition.kind == "world" else Vector2(8, 21)
		draw_string(font, point + offset, definition.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if definition.kind == "world" else 12, Color("d8e0d9"))
	if system == session.expedition.state.system:
		draw_string(font, region().position + Vector2(0, 10), "SPACESHIP IN SYSTEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a1d6ca"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
			pan += event.relative; queue_redraw()
		hovered = ""
		var closest := 25.0
		for id in points:
			var distance: float = points[id].distance_to(event.position)
			if distance < closest: closest = distance; hovered = id
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if hovered != "" else CURSOR_ARROW
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89), 0.6, 2.0); queue_redraw(); accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var nearest := ""
			var distance := 25.0
			for id in points:
				if points[id].distance_to(event.position) < distance: distance = points[id].distance_to(event.position); nearest = id
			if nearest != "":
				selected_body.emit(nearest)
				if event.double_click: entered_body.emit(nearest)
				accept_event()
