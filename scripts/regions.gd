extends Control
const UI = preload("res://scripts/interface.gd")
const Session = preload("res://scripts/session.gd")
const Atlas = preload("res://scripts/world_atlas.gd")
const Nav = preload("res://scripts/navigation.gd")
var session = Session.get_shared()
var globe: Control
var selected := Atlas.DEFAULT_REGION
var detail: Label
var title: Label
var approach: Button
var status: Label

func _ready() -> void:
	UI.install(self)
	add_child(preload("res://scripts/space_backdrop.gd").new())
	globe = preload("res://scripts/region_globe.gd").new()
	globe.name = "RegionGlobe"
	add_child(globe)
	globe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe.offset_top = 178; globe.offset_left = 20; globe.offset_right = -400; globe.offset_bottom = -112
	globe.region_selected.connect(select_region)
	globe.region_entered.connect(func(_region): approach_region())
	var body: Dictionary = session.expedition.known_body(session.surface_body).duplicate(true)
	if body.is_empty(): Nav.go(self, "res://scenes/main.tscn", size * 0.5, false); return
	var context: Dictionary = session.base_context(session.surface_body)
	body.pressure = context.get("environment", {}).get("pressure", 0.35)
	globe.show_body(body)
	selected = session.surface_region
	globe.focus_region(selected)
	var nav := UI.header(self)
	nav.add_child(UI.button("Orbit", open_orbit, "RegionsOrbit"))
	nav.add_child(UI.label("/  " + body.name + "  /  Surface regions", 16, UI.ACCENT))
	UI.spacer(nav)
	UI.menu(self, nav, [["Save expedition", session.save_disk, "SaveRegions"]])
	var heading := UI.column(UI.mount(self, Control.PRESET_TOP_LEFT, Vector4(32, 112, 760, 182)), 5)
	heading.add_child(UI.label("Choose your foothold", 32))
	heading.add_child(UI.label("Click a location · Drag to turn the planet · Each site keeps its own industry", 15, UI.MUTED))
	var right := UI.inspector(self)
	title = UI.label("", 25); right.add_child(title)
	detail = UI.label("", 16, UI.INK, true); right.add_child(detail)
	var sites := UI.scroll(right, "EstablishedSites")
	for key in session.sites:
		var address := Atlas.parse_address(key)
		if address.body != session.surface_body or not session.sites[key].state.landed: continue
		globe.established.append(address.region)
		sites.add_child(UI.button("▣  " + Atlas.region_label(address.region), revisit.bind(address.region), "Region_" + key.replace("@", "_").replace(",", "_")))
	approach = UI.button("Reconnoitre this site →", approach_region, "ApproachRegion", true)
	right.add_child(approach)
	var footer := UI.footer(self)
	footer.add_child(UI.label("Regional survey candidates · 80 m working sites · Globe reconstruction and resource estimates are schematic", 13, UI.MUTED))
	status = UI.status(footer)
	select_region(selected)
	Nav.arrive(self, globe)

func select_region(region: Vector2i) -> void:
	selected = region
	globe.selected_region = region
	globe.queue_redraw()
	var context: Dictionary = session.region_context(session.surface_body, region)
	var key := Atlas.address(session.surface_body, region)
	var established: bool = session.sites.has(key) and session.sites[key].state.landed
	title.text = Atlas.region_label(region)
	detail.text = "ORBITAL SCREENING\n\nSolar potential %.2f×\nOre prior %.2f×\nAccessible ice prior %.2f×\n\n" % [context.get("solar_factor", 1.0), context.get("ore_factor", 1.0), context.get("ice_factor", 1.0)]
	detail.text += "Surface surveys resolve individual deposits and construction sites. Latitude modifies the solar screening estimate; it does not resolve weather.\n\n"
	detail.text += "%d installations retained at this site." % session.sites[key].state.structures.size() if established else "Reconnaissance commits no hardware. Choose the exact module position on the ground; landing consumes one stocked factory module."
	approach.text = "Resume this site →" if established else "Reconnoitre this site →"
	approach.disabled = not session.site_available(session.surface_body)
	status.text = "%d modules aboard · Industry at other sites continues when time advances" % session.expedition.state.ship.modules

func revisit(region: Vector2i) -> void:
	globe.focus_region(region)
	select_region(region)

func approach_region() -> void:
	if not session.choose_region(session.surface_body, selected): return
	session.save_disk()
	var point: Vector3 = globe.project(selected)
	Nav.go(self, "res://scenes/surface.tscn", globe.position + Vector2(point.x, point.y), true)

func open_orbit() -> void:
	session.orbit_body = session.surface_body
	Nav.go(self, "res://scenes/main.tscn", globe.position + globe.size * 0.5, false)

func _unhandled_key_input(event: InputEvent) -> void:
	if UI.menu_key(self, event): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: open_orbit()
