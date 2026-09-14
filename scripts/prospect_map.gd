extends Control
signal selected_system(id: String)
var session: RefCounted
var selected := "prospect_0"
var points: Dictionary = {}
var background: Array[Vector3] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 913
	for index in range(280):
		background.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	resized.connect(queue_redraw)

func show_catalogue(current: RefCounted, selected_id: String) -> void:
	session = current
	selected = selected_id
	queue_redraw()

func star_position(id: String) -> Vector2:
	var region := chart_region()
	return region.get_center() + session.expedition.system_position(id) * Vector2(chart_scale(), -chart_scale())

func chart_region() -> Rect2:
	# Reserve actual space for the header, side dossiers and instrument dock.
	return Rect2(286, 145, maxf(200, size.x - 606), maxf(200, size.y - 375))

func chart_scale() -> float:
	var extent := chart_region().size
	return minf(extent.x * 0.085, extent.y * 0.094)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080f17"))
	for star in background:
		draw_circle(Vector2(star.x, star.y) * size, 0.4 + star.z, Color(0.65, 0.79, 0.9, 0.1 + star.z * 0.23))
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
		draw_dashed_line(active, target, Color("bb9f70"), 1.5, 8, true)
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
		for ring in range(5, 0, -1):
			draw_circle(point, ring * 4.0, Color(color, 0.013 * (6 - ring)))
		draw_circle(point, 4.5, color)
		if id == selected:
			draw_arc(point, 27, -0.6, 1.1, 30, Color("e2c58e"), 2, true)
			draw_arc(point, 27, 2.54, 4.24, 30, Color("e2c58e"), 2, true)
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in points:
			if event.position.distance_to(points[id]) < 28:
				selected_system.emit(id)
				accept_event()
				return
