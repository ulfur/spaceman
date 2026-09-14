extends Control
## Procedural viewport. Presentation only; never mutates the simulation.

var chart := false
var current_system := "eir"
var stars: Array[Vector3] = []
var globe: ColorRect
var globe_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 17012400
	for i in range(240):
		stars.append(Vector3(random.randf(), random.randf(), random.randf()))
	globe = ColorRect.new()
	globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_material = ShaderMaterial.new()
	globe_material.shader = preload("res://shaders/planet.gdshader")
	globe.material = globe_material
	add_child(globe)
	resized.connect(layout_globe)
	layout_globe()

func layout_globe() -> void:
	if not is_instance_valid(globe):
		return
	var diameter := minf(size.x * 0.94, size.y * 0.97)
	globe.size = Vector2.ONE * diameter
	globe.position = (size - globe.size) * 0.5
	queue_redraw()

func show_body(body: Dictionary, is_chart: bool, system_id: String) -> void:
	chart = is_chart
	current_system = system_id
	globe.visible = not chart and not body.is_empty()
	if not body.is_empty():
		globe_material.set_shader_parameter("warmth", clampf((body.temperature - 250.0) / 35.0, 0.0, 1.0))
		globe_material.set_shader_parameter("water", body.water)
		globe_material.set_shader_parameter("life", body.biomass)
		globe_material.set_shader_parameter("world_seed", body.seed)
		globe_material.set_shader_parameter("rocky", body.kind != "world")
	queue_redraw()

func _draw() -> void:
	for star in stars:
		draw_circle(Vector2(star.x, star.y) * size, 0.5 + star.z * 0.7, Color(0.68, 0.8, 0.9, 0.12 + star.z * 0.42))
	var font := ThemeDB.fallback_font
	if chart:
		var a := size * Vector2(0.22, 0.63)
		var b := size * Vector2(0.78, 0.35)
		draw_dashed_line(a, b, Color("42616e"), 1.0, 8.0)
		for point in [a, b]:
			draw_arc(point, 43.0, 0, TAU, 80, Color("283d48"), 1.0, true)
			draw_arc(point, 65.0, 0, TAU, 80, Color("172c37"), 1.0, true)
			draw_circle(point, 5.0, Color("e5c088"))
		var active := a if current_system == "eir" else b
		draw_arc(active, 20, 0, TAU, 64, Color("91d6cc"), 2.0, true)
		draw_string(font, a + Vector2(-13, 93), "EIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d2e1e5"))
		draw_string(font, b + Vector2(-35, 93), "VESPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d2e1e5"))
		draw_string(font, (a + b) * 0.5 + Vector2(-65, -25), "4.2 LIGHT YEARS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("91aab6"))
	else:
		var radius := minf(size.x * 0.49, size.y * 0.49)
		draw_arc(size * 0.5, radius, -0.35, 1.2, 80, Color("263e4a"), 1.0, true)
		draw_arc(size * 0.5, radius, 2.6, 4.1, 80, Color("263e4a"), 1.0, true)
		for i in range(8):
			var y := size.y * (0.2 + i * 0.085)
			draw_line(Vector2(8, y), Vector2(14 if i % 2 else 22, y), Color("35515f"), 1.0)
