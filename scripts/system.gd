extends Control
const UI = preload("res://scripts/interface.gd")
const Session = preload("res://scripts/session.gd")
const Atlas = preload("res://scripts/world_atlas.gd")
const Mechanics = preload("res://scripts/celestial_mechanics.gd")
const Nav = preload("res://scripts/navigation.gd")
var session = Session.get_shared()
var map: Control
var selected := ""
var title: Label
var detail: Label
var enter: Button
var status: Label

func _ready() -> void:
	if not session.initialized: session.load_disk()
	if session.viewed_system == "": session.viewed_system = session.expedition.state.system
	UI.install(self)
	add_child(preload("res://scripts/space_backdrop.gd").new())
	map = preload("res://scripts/system_map.gd").new()
	map.name = "SystemMap"
	add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.session = session
	map.system = session.viewed_system
	map.prepare_icons()
	map.selected_body.connect(select_body)
	map.entered_body.connect(open_body)
	var nav := UI.header(self)
	nav.add_child(UI.button("Star chart", open_chart, "SystemChart"))
	nav.add_child(UI.label("/  " + session.expedition.system_name(map.system), 16, UI.ACCENT))
	UI.spacer(nav)
	nav.add_child(UI.button("Recenter", map.recenter, "SystemRecenter"))
	UI.menu(self, nav, [["Save expedition", session.save_disk, "SaveSystem"]])
	var heading := UI.column(UI.mount(self, Control.PRESET_TOP_LEFT, Vector4(32, 128, 690, 195)), 4)
	heading.add_child(UI.label("A system of worlds", 32))
	heading.add_child(UI.label("Select a body · Double-click to approach · Scroll / pinch to zoom · Drag to orbit", 14, UI.MUTED))
	var right := UI.inspector(self, 140)
	title = UI.label("", 28); right.add_child(title)
	detail = UI.label("", 16, UI.INK, true); right.add_child(detail)
	UI.spacer(right)
	enter = UI.button("Approach orbit →", func(): open_body(selected), "ApproachBody", true); right.add_child(enter)
	var footer := UI.footer(self)
	footer.add_child(UI.label("Physical scale · Points mark unresolved bodies · Circular orbit fits · Camera inspection is free", 13, UI.MUTED))
	status = UI.status(footer)
	selected = session.orbit_body
	if not session.expedition.state.bodies.has(selected) or session.expedition.state.bodies[selected].system != map.system:
		for body in session.expedition.scenario.bodies:
			if body.system == map.system: selected = body.id; break
	select_body(selected)
	Nav.arrive(self, map, map.centre())

func select_body(id: String) -> void:
	selected = id
	map.selected = id
	map.universe.selected = id
	map.queue_redraw()
	var body: Dictionary = session.expedition.state.bodies[id]
	var evidence: Dictionary = session.prospects.evidence(map.system)
	var orbit := Mechanics.orbit(session, id)
	var resolved: bool = map.system == session.expedition.state.system or evidence.is_empty() or evidence.has("orbit_low")
	title.text = body.name if resolved else "Unresolved candidate"
	detail.text = "Acquire an orbit fit in the star chart. Remote surface conditions remain unknown."
	if resolved:
		var parent: String = session.expedition.system_name(orbit.parent) if orbit.parent == map.system else session.expedition.state.bodies[orbit.parent].name
		detail.text = "%s · orbits %s\n\n%.4f AU from parent\n%.2f years per orbit\n\n" % ["Moon" if body.kind == "moon" else "Planet", parent, orbit.au, orbit.period_years]
		if map.system == session.expedition.state.system:
			detail.text += "Local control available. Approach to survey this world and choose a surface region."
		else:
			detail.text += "Remote orbit reconstruction. Review observations and commit to transit in the star chart to investigate locally."
		var physical := Mechanics.properties(session, id)
		detail.text += "\n\nRadius %.0f km%s" % [physical.radius_km, " · assumed until probed" if physical.get("estimated", false) else ""]
	enter.disabled = map.system != session.expedition.state.system
	status.text = "Spaceship remains at %s · Year %d" % [session.expedition.system_name(session.expedition.state.system), session.expedition.state.year]

func open_body(id: String) -> void:
	if map.system != session.expedition.state.system: return
	session.orbit_body = id
	Nav.go(self, "res://scenes/main.tscn", map.body_position(id), true)

func open_chart() -> void:
	session.chart_center = session.expedition.system_position(map.system)
	Nav.go(self, "res://scenes/prospects.tscn", map.centre(), false)

func _unhandled_key_input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: open_chart()
