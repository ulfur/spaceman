extends Control
## Navigation marks are separate from physical sphere silhouettes.
const Mechanics = preload("res://scripts/celestial_mechanics.gd")
var universe: Node

func _draw() -> void:
	if universe == null or not universe.active: return
	var frame: Rect2 = universe.frame
	var font := ThemeDB.fallback_font
	var labels: Array[Rect2] = []
	if universe.mode == "chart": return
	if universe.show_guides:
		for body in universe.session.expedition.scenario.bodies:
			if body.system != universe.reference or not universe.positions.has(body.id): continue
			var fit := Mechanics.orbit(universe.session, body.id)
			var apparent: float = fit.au / universe.distance * frame.size.y
			if apparent < 10 or apparent > frame.size.x * 3: continue
			var origin: Array = universe.positions[fit.parent]
			var previous := Vector3(-100000, -100000, -1)
			for step in range(193):
				var angle := step * TAU / 192.0
				var current: Vector3 = universe.project_position(Mechanics.add(origin, [cos(angle) * fit.au, 0.0, sin(angle) * fit.au]))
				var a := Vector2(previous.x, previous.y)
				var b := Vector2(current.x, current.y)
				if step > 0 and previous.z > 0 and current.z > 0 and frame.grow(10).has_point(a) and frame.grow(10).has_point(b): draw_line(a, b, Color(0.39, 0.54, 0.57, 0.25), 1, true)
				previous = current
	for id in universe.points:
		var point: Vector2 = universe.points[id].point
		if not frame.has_point(point): continue
		var stellar: bool = not universe.session.expedition.state.bodies.has(id)
		var title: String = universe.session.expedition.system_name(id) if stellar else universe.session.expedition.state.bodies[id].name
		var color := Color("ffdfaa") if stellar else Color("b2ccc9")
		if not stellar:
			var body: Dictionary = universe.session.expedition.state.bodies[id]
			if body.system != universe.reference: continue
			var fit := Mechanics.orbit(universe.session, id)
			if body.kind == "moon" and universe.points.has(fit.parent) and point.distance_to(universe.points[fit.parent].point) < 20: continue
			if body.kind != "moon" and universe.points.has(body.system) and point.distance_to(universe.points[body.system].point) < 18: continue
			for child in universe.session.expedition.scenario.bodies:
				if child.kind == "moon" and child.system == body.system and Mechanics.orbit(universe.session, child.id).parent == id and universe.points.has(child.id) and point.distance_to(universe.points[child.id].point) < 20: title += "  · moon"
		var radius: float = universe.points[id].radius
		if radius < 3:
			for ring in range(4, 0, -1): draw_circle(point, ring * 3, Color(color, 0.018 * (5 - ring)))
			draw_circle(point, 2.0, color)
		if not universe.show_guides: continue
		if stellar and id != universe.reference: continue
		if radius < 30:
			var offset := Vector2(14, -12)
			var extent := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			if point.x > frame.end.x - 120: offset.x = -extent.x - 14
			for attempt in range(4):
				var label_rect := Rect2(point + offset - Vector2(0, 14), Vector2(extent.x + 8, 20))
				var overlaps := false
				for occupied in labels:
					if occupied.intersects(label_rect): overlaps = true
				if not overlaps: labels.append(label_rect); break
				offset.y += 22
			draw_string(font, point + offset, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
			if id == universe.selected: draw_arc(point, maxf(radius + 8.0, 10.0), 0, TAU, 48, Color("eaca92"), 1, true)
	var ruler := frame.position + Vector2(14, frame.size.y - 26)
	if universe.mode == "orbit": ruler = frame.position + Vector2(frame.size.x - 180, 14)
	var width_au: float = universe.distance * 2.0 * tan(deg_to_rad(universe.camera.fov * 0.5)) * 100.0 / frame.size.y
	draw_line(ruler, ruler + Vector2(100, 0), Color("8ca4ab"), 1, true)
	for x in [0.0, 100.0]: draw_line(ruler + Vector2(x, -3), ruler + Vector2(x, 3), Color("8ca4ab"), 1, true)
	draw_string(font, ruler + Vector2(0, 18), Mechanics.distance_text(width_au) + " at focus", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8ca4ab"))
	var range_text := "CAMERA RANGE  " + Mechanics.distance_text(universe.distance)
	var w := font.get_string_size(range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var range_at := frame.end - Vector2(w + 12, 8)
	if universe.mode == "orbit": range_at = Vector2(frame.end.x - w - 12, frame.position.y + 48)
	draw_string(font, range_at, range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8ca4ab"))
