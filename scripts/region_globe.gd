extends "res://scripts/space_view.gd"
signal region_selected(region: Vector2i)
signal region_entered(region: Vector2i)
const Atlas = preload("res://scripts/world_atlas.gd")
var selected_region := Atlas.DEFAULT_REGION
var established: Array[Vector2i] = []
var screening := "solar"
var survey_texture: ImageTexture

func _ready() -> void:
	regional = true
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()

func show_body(body: Dictionary) -> void:
	super.show_body(body)
	var data := Image.create(72, 36, false, Image.FORMAT_RGBF)
	for y in range(36):
		for x in range(72):
			var context: Dictionary = universe.session.region_context(body_id, Vector2i(x, y))
			data.set_pixel(x, y, Color(context.get("solar_factor", 1.0), context.get("ore_factor", 1.0), context.get("ice_factor", 1.0)))
	survey_texture = ImageTexture.create_from_image(data)
	universe.materials[body_id].set_shader_parameter("survey_data", survey_texture)
	set_screening(screening)

func set_screening(layer: String) -> void:
	screening = layer
	universe.materials[body_id].set_shader_parameter("survey_mode", ["natural", "solar", "ore", "ice"].find(layer))
	queue_redraw()

func project(region: Vector2i) -> Vector3:
	var p: Vector3 = universe.project_region(body_id, region)
	return Vector3(p.x - global_position.x, p.y - global_position.y, p.z)

func pick_region(point: Vector2) -> Vector2i:
	return universe.pick_region(body_id, point + global_position)

func focus_region(region: Vector2i) -> void:
	selected_region = region
	universe.focus_region(body_id, region)
	queue_redraw()

func _draw() -> void:
	if body_id == "": return
	var legend := Vector2(24, size.y - 76)
	if screening != "natural":
		for step in range(100):
			var color := Color("073447").lerp(Color("29b8bc"), minf(step / 60.0, 1.0)).lerp(Color("edc078"), maxf(0.0, (step - 60) / 40.0))
			draw_line(legend + Vector2(step * 1.4, 0), legend + Vector2(step * 1.4, 5), color, 2)
		draw_string(ThemeDB.fallback_font, legend - Vector2(0, 8), screening.to_upper() + " PRIOR · 0 — 2.5×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aad4d4"))
	for latitude in range(3, 36, 6):
		var previous := Vector3.ZERO
		for longitude in range(72):
			var current := project(Vector2i(longitude, latitude))
			if longitude > 0 and current.z > 0.05 and previous.z > 0.05:
				draw_line(Vector2(previous.x, previous.y), Vector2(current.x, current.y), Color(0.55, 0.75, 0.78, 0.16), 1, true)
			previous = current
	for longitude in range(4, 72, 8):
		var previous := Vector3.ZERO
		for latitude in range(36):
			var current := project(Vector2i(longitude, latitude))
			if latitude > 0 and current.z > 0.05 and previous.z > 0.05:
				draw_line(Vector2(previous.x, previous.y), Vector2(current.x, current.y), Color(0.55, 0.75, 0.78, 0.16), 1, true)
			previous = current
	for region in established:
		var marker := project(region)
		if marker.z > 0: draw_rect(Rect2(Vector2(marker.x, marker.y) - Vector2(4, 4), Vector2(8, 8)), Color("a1d6ca"))
	var selection := project(selected_region)
	if selection.z > 0:
		var point := Vector2(selection.x, selection.y)
		var geo := Atlas.coordinates(selected_region)
		var corners := PackedVector2Array()
		for offset in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(2.5, 2.5), Vector2(-2.5, 2.5), Vector2(-2.5, -2.5)]:
			var lon := deg_to_rad(geo.x + offset.x)
			var lat := deg_to_rad(geo.y + offset.y)
			var corner: Vector3 = universe.project_normal(body_id, Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat)))
			if corner.z > 0: corners.append(Vector2(corner.x, corner.y) - global_position)
		if corners.size() == 5: draw_polyline(corners, Color("f1c786"), 2, true)
		draw_circle(point, 4, Color("f1c786"))
		draw_arc(point, 15, 0, TAU, 48, Color("f1c786"), 1.5, true)
		draw_line(point + Vector2(18, 0), point + Vector2(62, -35), Color("f1c786"), 1, true)
		draw_string(ThemeDB.fallback_font, point + Vector2(66, -35), Atlas.region_label(selected_region), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eddfc4"))

func clicked(pixel: Vector2, twice: bool) -> void:
	var id: String = universe.pick_contact(pixel, body_id)
	if id != "":
		contact_selected.emit(id)
		if twice: contact_entered.emit(id)
		return
	var region: Vector2i = universe.pick_region(body_id, pixel)
	if region.x >= 0:
		selected_region = region; region_selected.emit(region)
		if twice: region_entered.emit(region)
