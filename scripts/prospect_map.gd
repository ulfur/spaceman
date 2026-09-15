extends Control
signal selected_system(id: String)
signal entered_system(id: String)
signal field_requested(cell: Vector2i)
const Atlas = preload("res://scripts/world_atlas.gd")
var zoom_power := 0.0
var galaxy_points: PackedVector2Array = []
var camera_tween: Tween
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 8211
	for i in range(1600):
		var radius := pow(rng.randf(), 0.7) * Atlas.GALAXY_RADIUS_LY
		var angle := (i % 4) * TAU / 4.0 + radius / 6200.0 + rng.randfn(0, 0.24)
		galaxy_points.append(Vector2(cos(angle), sin(angle)) * radius)


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
	return region.get_center() + (session.expedition.system_position(id) - session.chart_center) * Vector2(chart_scale(), -chart_scale())

func chart_region() -> Rect2:
	# Reserve actual space for the header, side dossiers and instrument dock.
	return Rect2(38, 220, maxf(300, size.x - 476), maxf(320, size.y - 342))

func chart_scale() -> float:
	var extent := chart_region().size
	return minf(extent.x * 0.078, extent.y * 0.085) * pow(2.0, zoom_power)

func _draw() -> void:
	if session == null:
		return
	var font := ThemeDB.fallback_font
	if zoom_power < -3.0:
		var density_alpha := clampf((-zoom_power - 3.0) / 5.0, 0.0, 1.0)
		for coordinate in galaxy_points:
			var point: Vector2 = chart_region().get_center() + (coordinate - session.chart_center) * Vector2(chart_scale(), -chart_scale())
			if chart_region().has_point(point): draw_circle(point, 1.5, Color(0.5, 0.68, 0.77, density_alpha * 0.32))
		var home := star_position(session.expedition.state.system)
		draw_arc(home, 9, 0, TAU, 32, Color("a1d6ca"), 1.5, true)
		draw_string(font, home + Vector2(14, 5), "SPACESHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a1d6ca"))
		draw_string(font, chart_region().position + Vector2(0, 20), "GALACTIC DENSITY · SYNTHETIC DISC · CLICK TO RESOLVE A STELLAR FIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("93a7af"))
		points.clear()
		return
	var origin := star_position("eir")
	var scale_value: float = chart_scale()
	for radius in range(1, 6):
		draw_arc(origin, scale_value * radius, 0, TAU, 128, Color("192b38"), 1, true)
		draw_string(font, origin + Vector2(-6, -scale_value * radius + 15), "%d ly" % radius, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("607581"))
	draw_line(origin + Vector2(-scale_value * 5, 0), origin + Vector2(scale_value * 5, 0), Color("182b35"), 1)
	draw_line(origin + Vector2(0, -scale_value * 5), origin + Vector2(0, scale_value * 5), Color("182b35"), 1)
	var ruler := chart_region().position + Vector2(14, chart_region().size.y - 24)
	draw_line(ruler, ruler + Vector2(scale_value, 0), Color("8fa6af"), 1.5, true)
	for x in [0.0, scale_value]: draw_line(ruler + Vector2(x, -4), ruler + Vector2(x, 4), Color("8fa6af"), 1.0, true)
	draw_string(font, ruler + Vector2(0, 20), "1 ly · Field centre %.0f, %.0f ly" % [session.chart_center.x, session.chart_center.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8fa6af"))
	var local: String = session.expedition.state.system
	var active := star_position(local)
	if selected != local:
		var clipped := clipped_route(active, star_position(selected), chart_region())
		if not clipped.is_empty():
			var start: Vector2 = clipped[0]
			var target: Vector2 = clipped[1]
			draw_line(start, target, Color(0.76, 0.63, 0.43, 0.12), 8, true)
			draw_dashed_line(start, target, Color("bb9f70"), 1.5, 8, true)
			var cursor := start.lerp(target, fmod(phase * 0.15, 1.0))
			draw_circle(cursor, 5, Color(0.9, 0.75, 0.5, 0.16))
			draw_circle(cursor, 2, Color("f6d49a"))
			var quote: Dictionary = session.expedition.travel_quote(selected)
			draw_string(font, (start + target) * 0.5 + Vector2(10, -9), "%d yr" % quote.years, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dcc08d"))
	points.clear()
	for definition in session.expedition.scenario.systems:
		var id: String = definition.id
		var point := star_position(id)
		if not chart_region().grow(20).has_point(point): continue
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

func frame_field(center: Vector2, power: float) -> void:
	if camera_tween != null and camera_tween.is_running(): camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(session, "chart_center", center, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(self, "zoom_power", power, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func wide_view() -> void:
	frame_field(Vector2.ZERO, -13.0)

func local_view() -> void:
	frame_field(session.expedition.system_position(session.expedition.state.system), 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
			session.chart_center -= event.relative / Vector2(chart_scale(), -chart_scale())
			session.chart_center = session.chart_center.limit_length(Atlas.GALAXY_RADIUS_LY)
		hover_id = ""
		for id in points:
			if event.position.distance_to(points[id]) < 28: hover_id = id
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_id != "" or zoom_power < -3 else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and zoom_power >= 1.6 and hover_id != "":
				entered_system.emit(hover_id); accept_event(); return
			var before: Vector2 = (event.position - chart_region().get_center()) / Vector2(chart_scale(), -chart_scale())
			zoom_power = clampf(zoom_power + (0.35 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.35), -13.0, 2.2)
			var after: Vector2 = (event.position - chart_region().get_center()) / Vector2(chart_scale(), -chart_scale())
			session.chart_center += before - after
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and chart_region().has_point(event.position):
			if zoom_power < -3:
				var coordinate: Vector2 = session.chart_center + (event.position - chart_region().get_center()) / Vector2(chart_scale(), -chart_scale())
				var cell := Vector2i(roundi(coordinate.x / Atlas.CELL_LY), roundi(coordinate.y / Atlas.CELL_LY))
				if Vector2(cell).length() * Atlas.CELL_LY <= Atlas.GALAXY_RADIUS_LY:
					field_requested.emit(cell)
					frame_field(Vector2(cell) * Atlas.CELL_LY, 0.0)
			else:
				for id in points:
					if event.position.distance_to(points[id]) < 28:
						selected_system.emit(id)
						if event.double_click: entered_system.emit(id)
						break
			accept_event()

static func clipped_route(a: Vector2, b: Vector2, rect: Rect2) -> Array[Vector2]:
	# Bound dashed geometry before submission: a galactic route can be millions of pixels long.
	var delta := b - a
	var low := 0.0
	var high := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: return []
		else:
			var first := (rect.position[axis] - a[axis]) / delta[axis]
			var last := (rect.end[axis] - a[axis]) / delta[axis]
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if low > high: return []
	return [a + delta * low, a + delta * high]
