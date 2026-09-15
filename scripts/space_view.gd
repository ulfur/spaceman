extends Control
## Procedural viewport. Presentation only; never mutates the simulation.

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

func show_body(body: Dictionary) -> void:
	globe.visible = not body.is_empty()
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
	var radius := minf(size.x * 0.49, size.y * 0.49)
	draw_arc(size * 0.5, radius, -0.35, 1.2, 80, Color("263e4a"), 1.0, true)
	draw_arc(size * 0.5, radius, 2.6, 4.1, 80, Color("263e4a"), 1.0, true)
	for i in range(8):
		var y := size.y * (0.2 + i * 0.085)
		draw_line(Vector2(8, y), Vector2(14 if i % 2 else 22, y), Color("35515f"), 1.0)
