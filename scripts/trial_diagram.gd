extends Control
## Live engineering schematic and measured history; drawing never advances state.
const Model = preload("res://scripts/testbed_simulation.gd")
var trial: Dictionary = {}
var environment: Dictionary = {}
var light := 0.7
var metric := "temperature"
var phase := 0.0
const INK := Color("dce7e1")
const MUTED := Color("7d9da9")
const CYAN := Color("81c9c0")
const AMBER := Color("dfb77a")

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func text_at(point: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
	draw_string(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func line_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	draw_dashed_line(start, end, Color(color, 0.55), 1.5, 7, true)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([end, end - direction * 9 + normal * 4, end - direction * 9 - normal * 4]), color)
	if trial.get("operating", false):
		draw_circle(start.lerp(end, fmod(phase * 0.3, 1.0)), 3, color)

func _draw() -> void:
	var width: float = size.x
	var diagram_height: float = size.y * 0.64
	var center := Vector2(width * 0.5, diagram_height * 0.54)
	for index in range(6):
		draw_arc(center, 80.0 + index * 36, 0, TAU, 90, Color(0.11, 0.2, 0.24, 0.28), 1, true)
	if trial.is_empty():
		text_at(Vector2(30, diagram_height * 0.45), "A world is too large for a first experiment.", 23)
		text_at(Vector2(30, diagram_height * 0.45 + 36), "Start with sixteen square metres.", 20, CYAN)
		text_at(Vector2(30, diagram_height * 0.45 + 75), "Land a module. Build a testbed [9] on its service network.", 14, MUTED)
		return
	var temperature: float = trial.temperature_k
	var heat_color := Color("62adc2").lerp(Color("df9e67"), clampf((temperature - 245.0) / 90.0, 0.0, 1.0))
	var a := center + Vector2(-155, 20)
	var b := center + Vector2(55, 85)
	var c := center + Vector2(168, 14)
	var d := center + Vector2(-43, -51)
	var roof := Vector2(0, -122)
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("243f40"))
	var green: float = clampf(trial.biomass_kg / Model.CONFIG.culture.capacity_kg, 0.0, 1.0)
	for i in range(8):
		for j in range(6):
			var point := a + (b - a) * ((i + 0.5) / 8.0) + (d - a) * ((j + 0.5) / 6.0)
			draw_circle(point, 2.0 + green * 2.5, Color("554e3a").lerp(Color("85c58e"), green))
	draw_colored_polygon(PackedVector2Array([a, b, b + roof, a + roof]), Color(heat_color, 0.1))
	draw_colored_polygon(PackedVector2Array([b, c, c + roof, b + roof]), Color(heat_color, 0.16))
	draw_colored_polygon(PackedVector2Array([a + roof, b + roof, c + roof, d + roof]), Color("635e50") if trial.canopy else Color(heat_color, 0.14))
	for segment in [[a, b], [b, c], [c, d], [d, a], [a, a + roof], [b, b + roof], [c, c + roof], [d, d + roof], [a + roof, b + roof], [b + roof, c + roof], [c + roof, d + roof], [d + roof, a + roof]]:
		draw_line(segment[0], segment[1], Color(heat_color, 0.65), 1.5, true)
	if trial.filter:
		draw_line(a + roof + Vector2(0, -6), b + roof + Vector2(0, -6), CYAN, 3, true)
	text_at(Vector2(28, 32), "CLOSED FIELD TRIAL  /  16 m² · 32 m³", 13, MUTED)
	text_at(center + Vector2(-126, -10), "%.1f K" % temperature, 36, INK)
	text_at(center + Vector2(-124, 17), "%.3f bar    /    %.1f g live" % [Model.pressure(trial), trial.biomass_kg * 1000], 14, CYAN)
	var solar: float = Model.sunlight_w(trial, environment, light)
	line_arrow(Vector2(width * 0.18, 70), a + roof + Vector2(50, 6), AMBER)
	text_at(Vector2(25, 62), "ABSORBED LIGHT", 11, AMBER)
	text_at(Vector2(25, 84), "%.0f W" % solar, 17, AMBER)
	line_arrow(Vector2(width - 30, 100), c + roof, Color("c0a6d8"))
	text_at(Vector2(width - 175, 65), "UV / PARTICLES", 11, Color("c0a6d8"))
	var exposure: Dictionary = Model.radiation(trial, environment)
	text_at(Vector2(width - 175, 85), "%.2f / %.2f index" % [exposure.uv, exposure.particles], 15, Color("c0a6d8"))
	line_arrow(Vector2(28, diagram_height - 90), a + Vector2(0, -25), heat_color)
	text_at(Vector2(28, diagram_height - 63), "THERMAL CONTROL", 11, heat_color)
	text_at(Vector2(28, diagram_height - 40), "%+.0f W" % trial.heat_w, 18, heat_color)
	line_arrow(c + Vector2(0, -15), Vector2(width - 25, diagram_height - 90), CYAN)
	text_at(Vector2(width - 193, diagram_height - 63), "WATER / GAS STORES", 11, CYAN)
	var mass := 0.0
	for amount in trial.gas.values(): mass += amount
	text_at(Vector2(width - 193, diagram_height - 40), "%.1f / %.1f kg" % [trial.water_kg, mass], 18, CYAN)
	text_at(center + Vector2(-127, 120), "CANOPY FITTED" if trial.canopy else ("UV FILTER FITTED" if trial.filter else "STANDARD GLAZING"), 12, MUTED)
	draw_history(Rect2(40, diagram_height + 20, width - 58, size.y - diagram_height - 48))

func draw_history(rect: Rect2) -> void:
	var points: Array = trial.history
	var labels := {"temperature": "TEMPERATURE / K", "pressure": "PRESSURE / bar", "biomass": "LIVE CULTURE / g"}
	text_at(rect.position + Vector2(0, -12), labels[metric], 11, MUTED)
	var low := 0.0
	var high := 1.0
	if metric == "temperature":
		low = minf(260.0, trial.temperature_k - 8)
		high = maxf(320.0, trial.temperature_k + 8)
	elif metric == "pressure": high = maxf(1.0, Model.pressure(trial) * 1.1)
	else: high = 100.0
	for point in points:
		var value: float = point[metric] * (1000.0 if metric == "biomass" else 1.0)
		low = minf(low, value - (5 if metric == "temperature" else 0))
		high = maxf(high, value + (5 if metric == "temperature" else 0))
	for index in range(4):
		var y: float = rect.position.y + rect.size.y * index / 3.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("213741"), 1)
		text_at(Vector2(0, y + 4), "%.1f" % lerpf(high, low, index / 3.0), 10, MUTED)
	if metric == "temperature":
		var upper: float = rect.position.y + rect.size.y * (high - 310) / (high - low)
		var lower: float = rect.position.y + rect.size.y * (high - 278) / (high - low)
		draw_rect(Rect2(rect.position.x, upper, rect.size.x, lower - upper), Color(0.23, 0.55, 0.45, 0.12))
	if points.size() < 2:
		text_at(rect.position + Vector2(18, rect.size.y * 0.6), "Measurements accumulate every six simulated hours.", 13, MUTED)
		return
	var plotted := PackedVector2Array()
	for point in points:
		var ratio: float = float(point.hour - points[0].hour) / maxf(1.0, points[-1].hour - points[0].hour)
		var value: float = point[metric] * (1000.0 if metric == "biomass" else 1.0)
		plotted.append(Vector2(rect.position.x + ratio * rect.size.x, rect.position.y + (high - value) / (high - low) * rect.size.y))
	draw_polyline(plotted, CYAN, 2, true)
	text_at(rect.position + Vector2(0, rect.size.y + 18), "SITE HOUR %d → %d" % [points[0].hour, points[-1].hour], 11, MUTED)
