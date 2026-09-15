extends Control
## Presentation only. Rotation is inspection motion, not elapsed simulation time.
var globe: ColorRect
var globe_material: ShaderMaterial
var phase := 0.0
var observed_seed := -1.0
var reveal := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe = ColorRect.new()
	globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_material = ShaderMaterial.new()
	globe_material.shader = preload("res://shaders/planet.gdshader")
	globe.material = globe_material
	add_child(globe)
	resized.connect(layout_globe)
	layout_globe()

func layout_globe() -> void:
	if not is_instance_valid(globe): return
	var diameter := minf(size.x * 0.94, size.y * 0.98)
	globe.size = Vector2.ONE * diameter
	globe.position = (size - globe.size) * 0.5 + Vector2(size.x * 0.05, 12)
	queue_redraw()

func show_body(body: Dictionary) -> void:
	globe.visible = not body.is_empty()
	if body.is_empty(): return
	if observed_seed != float(body.seed):
		observed_seed = float(body.seed)
		reveal = 0.0
	globe_material.set_shader_parameter("warmth", clampf((body.temperature - 250.0) / 35.0, 0.0, 1.0))
	globe_material.set_shader_parameter("water", body.water)
	globe_material.set_shader_parameter("life", body.biomass)
	globe_material.set_shader_parameter("world_seed", body.seed)
	globe_material.set_shader_parameter("rocky", body.kind != "world")
	globe_material.set_shader_parameter("air", float(body.get("pressure", 0.35)))

func _process(delta: float) -> void:
	phase += delta
	reveal = minf(1.0, reveal + delta * 2.2)
	globe.modulate.a = smoothstep(0.0, 1.0, reveal)
	globe_material.set_shader_parameter("phase", phase)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(globe) or not globe.visible: return
	var center := globe.position + globe.size * 0.5
	var radius := globe.size.x * 0.476
	draw_arc(center, radius, -0.35, 1.15, 96, Color(0.23, 0.39, 0.46, 0.42), 1.0, true)
	draw_arc(center, radius, 2.75, 4.05, 96, Color(0.23, 0.39, 0.46, 0.42), 1.0, true)
	for i in range(60):
		var angle := i * TAU / 60.0
		if i % 5 != 0: continue
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * radius, center + direction * (radius + 5), Color(0.43, 0.62, 0.68, 0.35), 1, true)
