extends "res://scripts/space_view.gd"
signal selected_body(id: String)
signal entered_body(id: String)
var session: RefCounted
var system := "eir"
var selected := "eir_iii"
var hovered := ""

func prepare_icons() -> void:
	universe = preload("res://scripts/universe.gd").shared(self)
	universe.system_view(system)

func region() -> Rect2:
	return universe.frame

func centre() -> Vector2:
	return universe.project_body(system) - global_position

func body_position(id: String) -> Vector2:
	return universe.project_body(id) - global_position

func recenter() -> void:
	universe.system_view(system)

func clicked(pixel: Vector2, twice: bool) -> void:
	var id: String = universe.pick_contact(pixel)
	if not session.expedition.state.bodies.has(id): return
	selected_body.emit(id)
	if twice: entered_body.emit(id)

func frame_body() -> void:
	if not universe.positions.has(selected): return
	universe.tracking = selected
	universe.fly(universe.positions[selected], universe.radii[selected] * 3.3, universe.day_direction(selected))

func frame_family() -> void:
	recenter()
