extends "res://scripts/space_view.gd"
signal region_selected(region: Vector2i)
signal region_entered(region: Vector2i)
const Atlas = preload("res://scripts/world_atlas.gd")
var selected_region := Atlas.DEFAULT_REGION
var established: Array[Vector2i] = []
var dragging := false
var drag_distance := 0.0

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	# Fixed geographical coordinates during selection; drag turns the globe.
	reveal = 1.0
	globe.modulate.a = 1.0
	globe_material.set_shader_parameter("phase", phase)
	queue_redraw()

func project(region: Vector2i) -> Vector3:
	var geo := Atlas.coordinates(region)
	var latitude := deg_to_rad(geo.y)
	var longitude := deg_to_rad(geo.x) - (phase * 0.012 + 0.4)
	var normal := Vector3(sin(longitude) * cos(latitude), -sin(latitude), cos(longitude) * cos(latitude))
	var center := globe.position + globe.size * 0.5
	var point := center + Vector2(normal.x, normal.y) * globe.size.x / 2.19
	return Vector3(point.x, point.y, normal.z)

func pick_region(point: Vector2) -> Vector2i:
	var p := (point - globe.position - globe.size * 0.5) * 2.19 / globe.size.x
	if p.length_squared() > 1.0: return Vector2i(-1, -1)
	var latitude := asin(-p.y)
	var longitude := atan2(p.x, sqrt(1.0 - p.length_squared())) + phase * 0.012 + 0.4
	var x := posmod(int(floor((rad_to_deg(longitude) + 180.0) / 5.0)), 72)
	var y := clampi(int(floor((90.0 - rad_to_deg(latitude)) / 5.0)), 0, 35)
	return Vector2i(x, y)

func focus_region(region: Vector2i) -> void:
	selected_region = region
	phase = (deg_to_rad(Atlas.coordinates(region).x) - 0.4) / 0.012
	queue_redraw()

func _draw() -> void:
	super._draw()
	if globe == null: return
	# Sparse geodetic grid, attached to the same projection as the shader.
	for latitude in range(3, 36, 6):
		var previous := Vector3.ZERO
		for longitude in range(72):
			var current := project(Vector2i(longitude, latitude))
			if longitude > 0 and current.z > 0.05 and previous.z > 0.05:
				draw_line(Vector2(previous.x, previous.y), Vector2(current.x, current.y), Color(0.55, 0.75, 0.78, 0.14), 1, true)
			previous = current
	for longitude in range(4, 72, 8):
		var previous := Vector3.ZERO
		for latitude in range(36):
			var current := project(Vector2i(longitude, latitude))
			if latitude > 0 and current.z > 0.05 and previous.z > 0.05:
				draw_line(Vector2(previous.x, previous.y), Vector2(current.x, current.y), Color(0.55, 0.75, 0.78, 0.14), 1, true)
			previous = current
	for region in established:
		var marker := project(region)
		if marker.z > 0:
			var point := Vector2(marker.x, marker.y)
			draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color("a1d6ca"))
	var selection := project(selected_region)
	if selection.z > 0:
		var point := Vector2(selection.x, selection.y)
		draw_circle(point, 4, Color("f1c786"))
		draw_arc(point, 15, 0, TAU, 48, Color("f1c786"), 1.5, true)
		draw_line(point + Vector2(18, 0), point + Vector2(72, -35), Color("f1c786"), 1, true)
		draw_string(ThemeDB.fallback_font, point + Vector2(76, -35), Atlas.region_label(selected_region), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eddfc4"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging:
		drag_distance += event.relative.length()
		phase -= event.relative.x * 0.32
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: dragging = true; drag_distance = 0.0
			else:
				dragging = false
				if drag_distance < 5:
					var region := pick_region(event.position)
					if region.x >= 0:
						selected_region = region; region_selected.emit(region)
						if event.double_click: region_entered.emit(region)
			accept_event()
