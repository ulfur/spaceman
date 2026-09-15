extends Control
## Physical cutaway and measured history. Rendering never advances trial state.
const Art = preload("res://scripts/industrial_art.gd")
const Model = preload("res://scripts/testbed_simulation.gd")
var trial: Dictionary = {}
var environment: Dictionary = {}
var light := 0.7
var metric := "temperature"
var view_mode := "chamber"
var running := false
var phase := 0.0
var viewport: SubViewport
var scene_container: SubViewportContainer
var chamber: Node3D
var camera: Camera3D
var lamp: OmniLight3D
const INK := Color("dce7e1")
const MUTED := Color("7d9da9")
const CYAN := Color("81c9c0")
const AMBER := Color("dfb77a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	build_chamber()

func build_chamber() -> void:
	scene_container = SubViewportContainer.new()
	scene_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_container.show_behind_parent = true
	scene_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_container.stretch = true
	add_child(scene_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 340)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	scene_container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = Color("96b8bf")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.glow_intensity = 0.22
	env_node.environment = env
	world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("efe1c2")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	world.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 140, 0)
	rim.light_color = Color("72bcc9")
	rim.light_energy = 0.45
	world.add_child(rim)
	chamber = Art.build("testbed")
	world.add_child(chamber)
	# Front glazing is omitted in the inspection cutaway. The experiment stays sealed.
	chamber.get_node("Glazing").visible = false
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.20, 0.47, 0.54, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.15
	glass.metallic = 0.2
	Art.box(chamber, Vector3(0, 1.72, -1.53), Vector3(3.04, 2.04, 0.018), glass)
	Art.box(chamber, Vector3(-1.53, 1.72, 0), Vector3(0.018, 2.04, 3.04), glass)
	var film := Art.box(chamber, Vector3(0, 2.73, 0), Vector3(2.96, 0.01, 2.96), glass)
	film.name = "FilterFilm"
	Art.shell(world, Vector3(0, -0.05, 0), Vector3(4.45, 0.16, 4.45), Art.finish("13242c", 0.4))
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 2.3, 0)
	lamp.omni_range = 3.3
	lamp.light_color = Color("a7edca")
	lamp.light_energy = 0.65
	world.add_child(lamp)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(6.2, 5.3, 7.8)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.45, 0))
	camera.current = true

func _process(delta: float) -> void:
	var showing: bool = view_mode == "chamber" and not trial.is_empty()
	scene_container.visible = showing
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if not showing: return
	if running: phase += delta
	var culture: MeshInstance3D = chamber.get_node("Culture")
	culture.material_override.set_shader_parameter("density", clampf(trial.biomass_kg / Model.CONFIG.culture.capacity_kg, 0.0, 1.0))
	culture.material_override.set_shader_parameter("liquid", 1.0 if trial.temperature_k > 273.15 and trial.water_kg > 0.1 else 0.0)
	culture.material_override.set_shader_parameter("phase", phase if trial.operating else 0.0)
	chamber.get_node("Canopy").visible = trial.canopy
	chamber.get_node("FilterFilm").visible = trial.filter and not trial.canopy
	chamber.get_node("Canopy").position = Vector3(0, 3.1, -0.65)
	lamp.visible = trial.lamp and trial.operating
	chamber.get_node("LampStrip").visible = lamp.visible
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
	var temperature: float = trial.temperature_k
	var heat_color := Color("62adc2").lerp(Color("df9e67"), clampf((temperature - 245.0) / 90.0, 0.0, 1.0))
	var a := center + Vector2(-128, 32) * scale_value
	var roof := Vector2(0, -105) * scale_value
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
	text_at(Vector2(12, height - 4), "CUTAWAY  /  16 m² sealed enclosure · " + cover, 14, MUTED)

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
	var area := plotted.duplicate()
	area.append(Vector2(rect.end.x, rect.end.y))
	area.append(Vector2(rect.position.x, rect.end.y))
	draw_colored_polygon(area, Color(CYAN, 0.055))
	draw_polyline(plotted, Color(CYAN, 0.09), 7, true)
	draw_polyline(plotted, CYAN, 2, true)
	draw_circle(plotted[-1], 3.5, CYAN)
	text_at(rect.position + Vector2(0, rect.size.y + 18), "SITE HOUR %d → %d" % [points[0].hour, points[-1].hour], 14, MUTED)
