extends Control
signal selected_system(id: String)
var session: RefCounted
var selected := "prospect_0"
var points: Dictionary = {}
var phase := 0.0
var hover_id := ""
var redraw_elapsed := 0.0

func _ready() -> void:
	var backdrop := preload("res://scripts/space_backdrop.gd").new()
	backdrop.show_behind_parent = true
	add_child(backdrop)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	phase += delta
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func show_catalogue(current: RefCounted, selected_id: String) -> void:
	session = current
	selected = selected_id
	queue_redraw()

func star_position(id: String) -> Vector2:
	var region := chart_region()
	return region.get_center() + session.expedition.system_position(id) * Vector2(chart_scale(), -chart_scale())

func chart_region() -> Rect2:
	# Reserve actual space for the header, side dossiers and instrument dock.
	return Rect2(38, 220, maxf(300, size.x - 476), maxf(320, size.y - 342))

func chart_scale() -> float:
	var extent := chart_region().size
	return minf(extent.x * 0.078, extent.y * 0.085)

func _draw() -> void:
	if session == null:
		return
	var font := ThemeDB.fallback_font
	var origin := star_position("eir")
	var scale_value: float = chart_scale()
	for radius in range(1, 6):
		draw_arc(origin, scale_value * radius, 0, TAU, 128, Color("192b38"), 1, true)
		draw_string(font, origin + Vector2(-6, -scale_value * radius + 15), "%d ly" % radius, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("607581"))
	draw_line(origin + Vector2(-scale_value * 5, 0), origin + Vector2(scale_value * 5, 0), Color("182b35"), 1)
	draw_line(origin + Vector2(0, -scale_value * 5), origin + Vector2(0, scale_value * 5), Color("182b35"), 1)
	var local: String = session.expedition.state.system
	var active := star_position(local)
	if selected != local:
		var target := star_position(selected)
		draw_line(active, target, Color(0.76, 0.63, 0.43, 0.12), 8, true)
		draw_dashed_line(active, target, Color("bb9f70"), 1.5, 8, true)
		# A route-planning pulse, not a travelling ship or elapsed transit.
		var cursor := active.lerp(target, fmod(phase * 0.15, 1.0))
		draw_circle(cursor, 5, Color(0.9, 0.75, 0.5, 0.16))
		draw_circle(cursor, 2, Color("f6d49a"))
		var quote: Dictionary = session.expedition.travel_quote(selected)
		draw_string(font, (active + target) * 0.5 + Vector2(10, -9), "%d yr" % quote.years, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dcc08d"))
	points.clear()
	for definition in session.expedition.scenario.systems:
		var id: String = definition.id
		var point := star_position(id)
		points[id] = point
		var data: Dictionary = session.prospects.evidence(id)
		var color := Color("ead6a7")
		if not data.is_empty():
			color = Color("de9a75") if data.type == "M V" else (Color("edc38b") if data.type == "K V" else Color("d4e5e6"))
		for ring in range(12, 0, -1):
			draw_circle(point, ring * 2.3, Color(color, 0.007 * (13 - ring)))
		draw_line(point - Vector2(15, 0), point + Vector2(15, 0), Color(color, 0.13), 1, true)
		draw_line(point - Vector2(0, 15), point + Vector2(0, 15), Color(color, 0.13), 1, true)
		draw_circle(point, 4.2, color)
		draw_circle(point - Vector2(0.5, 0.6), 2.0, color.lightened(0.6))
		if id == hover_id:
			draw_arc(point, 31, 0, TAU, 64, Color(color, 0.5), 1, true)
		if id == selected:
			draw_arc(point, 27, -0.6 + phase * 0.08, 1.1 + phase * 0.08, 30, Color("e2c58e"), 2, true)
			draw_arc(point, 27, 2.54 + phase * 0.08, 4.24 + phase * 0.08, 30, Color("e2c58e"), 2, true)
		if id == local:
			draw_arc(point, 17, 0, TAU, 64, Color("a0d4c9"), 1.5, true)
			draw_string(font, point + Vector2(-22, -25), "SPACESHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("a0d4c9"))
		var name: String = definition.name
		draw_string(font, point + Vector2(13, 3), name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d8ddd6"))
		var caption: String = "REFERENCE ROUTE" if data.is_empty() else data.type + "  ·  " + ("PROBED" if data.records.has("probe") else "%d PROGRAMMES" % data.records.size())
		draw_string(font, point + Vector2(13, 19), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8aa4ad"))
		if not data.is_empty() and data.records.has("probe"):
			draw_circle(point + Vector2(-11, 11), 2.5, Color("a0d4c9"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_id = ""
		for id in points:
			if event.position.distance_to(points[id]) < 28:
				hover_id = id
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_id != "" else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in points:
			if event.position.distance_to(points[id]) < 28:
				selected_system.emit(id)
				accept_event()
				return
