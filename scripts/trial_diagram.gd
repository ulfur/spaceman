extends Control
## Live engineering schematic and measured history; drawing never advances state.
const Model = preload("res://scripts/testbed_simulation.gd")
var trial: Dictionary = {}
var environment: Dictionary = {}
var light := 0.7
var metric := "temperature"
var view_mode := "chamber"
var running := false
var phase := 0.0
const INK := Color("dce7e1")
const MUTED := Color("7d9da9")
const CYAN := Color("81c9c0")
const AMBER := Color("dfb77a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if running and view_mode == "chamber":
		phase += delta
		queue_redraw()

func text_at(point: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
	draw_string(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func line_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	draw_dashed_line(start, end, Color(color, 0.55), 1.5, 7, true)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([end, end - direction * 9 + normal * 4, end - direction * 9 - normal * 4]), color)
	if running and trial.get("operating", false):
		draw_circle(start.lerp(end, fmod(phase * 0.3, 1.0)), 3, color)

func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	if trial.is_empty():
		text_at(Vector2(24, height * 0.48), "No field chamber on this site", 25)
		text_at(Vector2(24, height * 0.48 + 34), "Build a testbed from Surface → Build → Life support.", 17, MUTED)
		return
	if view_mode == "history":
		draw_history(Rect2(58, 36, width - 80, height - 82))
		return
	var center := Vector2(width * 0.5, height * 0.56)
	var scale_value: float = minf(width / 790.0, height / 345.0)
	for index in range(3):
		draw_arc(center, (125.0 + index * 35) * scale_value, 0, TAU, 90, Color(0.11, 0.2, 0.24, 0.3), 1, true)
	var temperature: float = trial.temperature_k
	var heat_color := Color("62adc2").lerp(Color("df9e67"), clampf((temperature - 245.0) / 90.0, 0.0, 1.0))
	var a := center + Vector2(-155, 20) * scale_value
	var b := center + Vector2(55, 85) * scale_value
	var c := center + Vector2(168, 14) * scale_value
	var d := center + Vector2(-43, -51) * scale_value
	var roof := Vector2(0, -122) * scale_value
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("243f40"))
	var green: float = clampf(trial.biomass_kg / Model.CONFIG.culture.capacity_kg, 0.0, 1.0)
	for i in range(8):
		for j in range(6):
			var point := a + (b - a) * ((i + 0.5) / 8.0) + (d - a) * ((j + 0.5) / 6.0)
			draw_circle(point, (2.0 + green * 2.5) * scale_value, Color("554e3a").lerp(Color("85c58e"), green))
	draw_colored_polygon(PackedVector2Array([a, b, b + roof, a + roof]), Color(heat_color, 0.1))
	draw_colored_polygon(PackedVector2Array([b, c, c + roof, b + roof]), Color(heat_color, 0.16))
	draw_colored_polygon(PackedVector2Array([a + roof, b + roof, c + roof, d + roof]), Color("635e50") if trial.canopy else Color(heat_color, 0.14))
	for segment in [[a, b], [b, c], [c, d], [d, a], [a, a + roof], [b, b + roof], [c, c + roof], [d, d + roof], [a + roof, b + roof], [b + roof, c + roof], [c + roof, d + roof], [d + roof, a + roof]]:
		draw_line(segment[0], segment[1], Color(heat_color, 0.7), 1.8, true)
	if trial.filter: draw_line(a + roof + Vector2(0, -6), b + roof + Vector2(0, -6), CYAN, 3, true)
	var solar: float = Model.sunlight_w(trial, environment, light)
	line_arrow(Vector2(132, 55), a + roof + Vector2(45, 5), AMBER)
	text_at(Vector2(12, 24), "SUNLIGHT", 13, MUTED)
	text_at(Vector2(12, 48), "%.0f W absorbed" % solar, 18, AMBER)
	var exposure: Dictionary = Model.radiation(trial, environment)
	text_at(Vector2(width - 220, 24), "EXPOSURE INDICES", 13, MUTED)
	text_at(Vector2(width - 220, 48), "%.2f UV · %.2f particles" % [exposure.uv, exposure.particles], 17, INK)
	if trial.heat_w >= 0: line_arrow(Vector2(118, height - 92), a + Vector2(0, -20), heat_color)
	else: line_arrow(a + Vector2(0, -20), Vector2(118, height - 92), heat_color)
	text_at(Vector2(12, height - 61), "THERMAL CONTROL", 13, MUTED)
	text_at(Vector2(12, height - 37), "%+.0f W" % trial.heat_w, 18, heat_color)
	var phase_name: String = "LIQUID" if temperature >= 274.15 else ("ICE" if temperature < 273.15 else "ICE + LIQUID")
	text_at(Vector2(width - 220, height - 61), phase_name + " / VAPOUR", 13, MUTED)
	text_at(Vector2(width - 220, height - 37), "%.1f / %.2f kg" % [trial.water_kg, trial.gas.vapor], 18, CYAN)
	var cover: String = "Regolith canopy" if trial.canopy else ("UV-filtered glazing" if trial.filter else "Standard glazing")
	text_at(Vector2(12, height - 4), "16 m² enclosure · " + cover, 14, MUTED)

func draw_history(rect: Rect2) -> void:
	var points: Array = trial.history
	var labels := {"temperature": "TEMPERATURE / K", "pressure": "PRESSURE / bar", "biomass": "LIVE CULTURE / g"}
	text_at(rect.position + Vector2(0, -12), labels[metric], 14, MUTED)
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
		text_at(Vector2(0, y + 4), "%.1f" % lerpf(high, low, index / 3.0), 13, MUTED)
	if metric == "temperature":
		var upper: float = rect.position.y + rect.size.y * (high - 310) / (high - low)
		var lower: float = rect.position.y + rect.size.y * (high - 278) / (high - low)
		draw_rect(Rect2(rect.position.x, upper, rect.size.x, lower - upper), Color(0.23, 0.55, 0.45, 0.12))
	if points.size() < 2:
		text_at(rect.position + Vector2(18, rect.size.y * 0.6), "Measurements accumulate every six simulated hours.", 16, MUTED)
		return
	var plotted := PackedVector2Array()
	for point in points:
		var ratio: float = float(point.hour - points[0].hour) / maxf(1.0, points[-1].hour - points[0].hour)
		var value: float = point[metric] * (1000.0 if metric == "biomass" else 1.0)
		plotted.append(Vector2(rect.position.x + ratio * rect.size.x, rect.position.y + (high - value) / (high - low) * rect.size.y))
	draw_polyline(plotted, CYAN, 2, true)
	text_at(rect.position + Vector2(0, rect.size.y + 18), "SITE HOUR %d → %d" % [points[0].hour, points[-1].hour], 14, MUTED)
