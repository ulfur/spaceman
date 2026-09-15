extends Control
## Instrument marks describe the same physical scene; they never inflate bodies.
const Mechanics = preload("res://scripts/celestial_mechanics.gd")
const INK := Color("bbd5d8")
const CYAN := Color("76cecf")
const GOLD := Color("efc582")
var universe: Node

func line_label(at: Vector2, text: String, color: Color = INK, height: int = 12) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)

func brackets(point: Vector2, radius: float, color: Color) -> void:
	var r := maxf(12.0, radius + 9)
	for side in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = point + side * r
		if not universe.frame.has_point(at): continue
		draw_line(at, at - Vector2(side.x * 10, 0), color, 1.5, true)
		draw_line(at, at - Vector2(0, side.y * 10), color, 1.5, true)

func _draw() -> void:
	if universe == null or not universe.active or universe.mode == "chart": return
	var frame: Rect2 = universe.frame
	var center := frame.get_center()
	# Quiet instrument boundary and angular ticks establish a navigation display.
	draw_rect(frame, Color(0.24, 0.53, 0.58, 0.22), false, 1)
	for x in range(60, int(frame.size.x), 60):
		draw_line(frame.position + Vector2(x, 0), frame.position + Vector2(x, 4), Color(CYAN, 0.35), 1)
	for y in range(60, int(frame.size.y), 60):
		draw_line(frame.position + Vector2(0, y), frame.position + Vector2(4, y), Color(CYAN, 0.35), 1)
	line_label(frame.position + Vector2(14, 19), "LOCAL FRAME  /  " + universe.title(universe.reference).to_upper(), Color(CYAN, 0.8), 11)
	line_label(Vector2(frame.end.x - 210, frame.position.y + 19), "RANGE  " + Mechanics.distance_text(universe.distance), CYAN, 11)
	if universe.show_guides and universe.mode != "regions": draw_orbits()
	var occupied: Array[Rect2] = []
	for id in universe.contact_hits:
		# Survey targets geographic cells. Keep body-level brackets and callouts
		# for other contacts, rather than duplicating the selected site marker.
		if universe.mode == "regions" and id == universe.tracking: continue
		var hit: Dictionary = universe.contact_hits[id]
		var point: Vector2 = hit.point
		var selected: bool = id == universe.selected
		var grouped_moons := 0
		for body in universe.session.expedition.scenario.bodies:
			if body.kind != "moon" or body.system != universe.reference or not universe.positions.has(body.id): continue
			if Mechanics.orbit(universe.session, body.id).parent == id and universe.project_body(body.id).distance_to(point) < 20:
				grouped_moons += 1
				if body.id == universe.selected: selected = true
		var hover: bool = id == universe.hovered
		var stellar: bool = not universe.session.expedition.state.bodies.has(id)
		var color := GOLD if selected else (Color("ffd5a1") if stellar else CYAN)
		if hit.edge:
			var outward := (point - center).normalized()
			var tangent := Vector2(-outward.y, outward.x)
			draw_colored_polygon(PackedVector2Array([point + outward * 7, point - outward * 5 + tangent * 4, point - outward * 5 - tangent * 4]), Color(color, 1.0 if hover else 0.7))
			line_label(hit.label_at, universe.title(id), Color(color, 0.85))
			if hover: brackets(point, 0, color)
			continue
		if hit.radius < 4:
			for ring in range(4, 0, -1): draw_circle(point, ring * 3, Color(color, 0.018 * (5 - ring)))
			draw_circle(point, 2.5, color)
		if selected or hover: brackets(point, hit.radius, color)
		if hit.radius > 70 and not hover: continue
		var caption: String = universe.title(id).to_upper()
		if grouped_moons > 0: caption += " + %d MOON%s" % [grouped_moons, "S" if grouped_moons > 1 else ""]
		var below: String = "TARGET" if selected else universe.contact_distance(id) + " from target"
		var text_size := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var at := point + Vector2(maxf(22, hit.radius + 18), -20)
		if at.x + text_size.x > frame.end.x - 18: at.x = point.x - text_size.x - maxf(22, hit.radius + 18)
		for attempt in range(5):
			var overlap := false
			for rect in occupied:
				if rect.intersects(Rect2(at - Vector2(4, 15), Vector2(maxf(text_size.x, 130), 35))): overlap = true
			if not overlap: break
			at.y += 38
		at.y = clampf(at.y, frame.position.y + 50, frame.end.y - 50)
		occupied.append(Rect2(at - Vector2(4, 15), Vector2(maxf(text_size.x, 130), 35)))
		draw_line(point + Vector2(8, -4), at - Vector2(5, 5), Color(color, 0.4), 1, true)
		line_label(at, caption, color, 13)
		line_label(at + Vector2(0, 17), below, Color(INK, 0.7), 10)
	var ruler := frame.position + Vector2(16, frame.size.y - 28)
	var width_au: float = universe.distance * 2.0 * tan(deg_to_rad(universe.camera.fov * 0.5)) * 100.0 / frame.size.y
	draw_line(ruler, ruler + Vector2(100, 0), CYAN, 1, true)
	for x in [0.0, 50.0, 100.0]: draw_line(ruler + Vector2(x, -3), ruler + Vector2(x, 3), CYAN, 1, true)
	line_label(ruler + Vector2(0, 17), Mechanics.distance_text(width_au) + " at focus", Color(INK, 0.8), 11)
	var mode_label := "GEOGRAPHIC SURVEY" if universe.mode == "regions" else "EPHEMERIS / PHYSICAL SCALE"
	line_label(frame.end - Vector2(216, 12), mode_label, Color(CYAN, 0.6), 11)

func draw_orbits() -> void:
	var frame: Rect2 = universe.frame
	for body in universe.session.expedition.scenario.bodies:
		if body.system != universe.reference or not universe.positions.has(body.id): continue
		var fit := Mechanics.orbit(universe.session, body.id)
		var apparent: float = fit.au / universe.distance * frame.size.y
		if apparent < 10 or apparent > frame.size.x * 3: continue
		var origin: Array = universe.positions[fit.parent]
		var previous := Vector3(-100000, -100000, -1)
		var color := Color(CYAN, 0.45 if body.id == universe.selected or fit.parent == universe.selected else 0.17)
		for step in range(193):
			var angle := step * TAU / 192.0
			var current: Vector3 = universe.project_position(Mechanics.add(origin, [cos(angle) * fit.au, 0.0, sin(angle) * fit.au]))
			var a := Vector2(previous.x, previous.y)
			var b := Vector2(current.x, current.y)
			if step > 0 and previous.z > 0 and current.z > 0 and frame.has_point(a) and frame.has_point(b): draw_line(a, b, color, 1, true)
			previous = current
