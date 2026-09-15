extends CanvasLayer
## Persistent camera and meshes. HUD scenes do not own or replace the world.
## Rebase the stellar origin, subtract doubles, then normalize all lengths together.
const Mechanics = preload("res://scripts/celestial_mechanics.gd")
const Session = preload("res://scripts/session.gd")
var session = Session.get_shared()
var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var overlay: Control
var meshes: Dictionary = {}
var materials: Dictionary = {}
var positions: Dictionary = {}
var points: Dictionary = {}
var radii: Dictionary = {}
var reference := "eir"
var mode := ""
var selected := ""
var focus: Array = [0.0, 0.0, 0.0]
var distance := 1.0
var direction := Vector3(0, 0.72, 1).normalized()
var camera_tween: Tween
var active := false
var initialized := false
var tracking := ""
var last_hours := -1.0
var last_catalogue := -1
var last_seed := -1
var show_guides := true
var frame := Rect2()
var frame_target := Rect2()

static func shared(owner: Node) -> Node:
	var service := owner.get_tree().root.get_node_or_null("Universe")
	if service == null:
		service = load("res://scripts/universe.gd").new()
		service.name = "Universe"
		owner.get_tree().root.add_child(service)
	return service

func _ready() -> void:
	layer = -1
	container = SubViewportContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	world = Node3D.new(); viewport.add_child(world)
	camera = Camera3D.new(); camera.fov = 45; camera.near = 0.01; camera.far = 10000000.0
	world.add_child(camera); camera.current = true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/celestial_sky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky; env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env; world.add_child(environment)
	overlay = preload("res://scripts/celestial_overlay.gd").new()
	overlay.universe = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	get_tree().root.size_changed.connect(layout)
	layout()

func layout() -> void:
	var extent := get_tree().root.get_visible_rect().size
	frame_target = Rect2(28, 202, maxf(300, extent.x - 444), maxf(320, extent.y - 326))
	frame = frame_target
	container.position = frame.position; container.size = frame.size
	overlay.size = extent
	if camera != null: render_frame()

func suspend() -> void:
	active = false; hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func prepare(system: String) -> void:
	active = true; show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if reference != system:
		focus = Mechanics.subtract(focus, star_offset(system))
		reference = system
		last_hours = -1.0
	if last_catalogue != session.expedition.state.bodies.size() or last_seed != int(session.prospects.state.seed):
		if last_seed != int(session.prospects.state.seed):
			for node in meshes.values(): node.queue_free()
			meshes.clear(); materials.clear()
		last_catalogue = session.expedition.state.bodies.size(); last_seed = int(session.prospects.state.seed)
		last_hours = -1.0
	if last_hours != session.elapsed_hours(): update_ephemeris()

func star_offset(id: String) -> Array:
	var point: Vector2 = session.expedition.system_position(id)
	var origin: Vector2 = session.expedition.system_position(reference)
	return [(float(point.x) - origin.x) * Mechanics.LY_AU, 0.0, -(float(point.y) - origin.y) * Mechanics.LY_AU]

func update_ephemeris() -> void:
	var hours: float = session.elapsed_hours()
	positions.clear(); radii.clear()
	for system in session.expedition.scenario.systems:
		positions[system.id] = star_offset(system.id)
		radii[system.id] = Mechanics.star(session, system.id).radius_km / Mechanics.AU_KM
		ensure_mesh(system.id, true)
	for body in session.expedition.scenario.bodies:
		var evidence: Dictionary = session.prospects.evidence(body.system)
		if body.system != session.expedition.state.system and not evidence.is_empty() and not evidence.has("orbit_low"): continue
		positions[body.id] = Mechanics.add(star_offset(body.system), Mechanics.body_position(session, body.id, hours))
		radii[body.id] = Mechanics.properties(session, body.id).radius_km / Mechanics.AU_KM
		ensure_mesh(body.id, false)
		var node: MeshInstance3D = meshes[body.id]
		node.basis = Mechanics.orientation(session, body.id, hours)
		var material: ShaderMaterial = materials[body.id]
		var known: Dictionary = session.expedition.known_body(body.id)
		var local_data: Dictionary = session.prospects.body_evidence(body.id)
		material.set_shader_parameter("world_seed", float(body.seed))
		material.set_shader_parameter("warmth", clampf((known.get("temperature", 240.0) - 250.0) / 35.0, 0.0, 1.0))
		material.set_shader_parameter("water", float(known.get("water", 0.0)))
		material.set_shader_parameter("life", float(known.get("biomass", 0.0)))
		material.set_shader_parameter("air", float(local_data.get("pressure", 0.25 if body.kind == "world" and not body.get("generated", false) else 0.0)))
		material.set_shader_parameter("rocky", body.kind == "moon")
		material.set_shader_parameter("cloud_phase", fmod(hours, 10000.0) * 0.001)
		material.set_shader_parameter("sun_direction", Mechanics.sun_direction(session, body.id, hours))
	last_hours = hours

func ensure_mesh(id: String, stellar: bool) -> void:
	if meshes.has(id): return
	var sphere := SphereMesh.new()
	sphere.radius = 1.0; sphere.height = 2.0
	sphere.radial_segments = 128; sphere.rings = 64
	var node := MeshInstance3D.new(); node.mesh = sphere
	if stellar:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(Mechanics.star(session, id).color)
		node.material_override = material
	else:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/celestial_surface.gdshader")
		node.material_override = material; materials[id] = material
	world.add_child(node); meshes[id] = node

func system_view(id: String) -> void:
	prepare(id); mode = "system"; tracking = ""
	var radius := 1.0
	for body in session.expedition.scenario.bodies:
		if body.system == id and positions.has(body.id): radius = maxf(radius, Mechanics.orbit(session, body.id).au)
	fly([0.0, 0.0, 0.0], radius * 3.05, Vector3(0, 0.95, 1).normalized())

func body_view(id: String, regional: bool = false) -> void:
	var system: String = session.expedition.state.bodies[id].system
	prepare(system)
	var retain := selected == id and mode in ["orbit", "regions"]
	selected = id; mode = "regions" if regional else "orbit"; tracking = id
	if retain:
		render_frame()
		return
	var sun := Mechanics.sun_direction(session, id, session.elapsed_hours())
	var inspection := (sun + Vector3(0, 0.30, 0)).normalized().rotated(Vector3.UP, 0.48)
	fly(positions[id], radii[id] * 3.3, inspection)

func chart_view(center: Vector2, pixels_per_ly: float, first: bool = false) -> void:
	prepare(session.viewed_system if session.viewed_system != "" else session.expedition.state.system)
	mode = "chart"; tracking = ""
	var origin: Vector2 = session.expedition.system_position(reference)
	var at := [(float(center.x) - origin.x) * Mechanics.LY_AU, 0.0, -(float(center.y) - origin.y) * Mechanics.LY_AU]
	var radius := frame.size.y * Mechanics.LY_AU / (2.0 * tan(deg_to_rad(camera.fov * 0.5)) * pixels_per_ly)
	if first: fly(at, radius, Vector3(0, 1, 0.00001).normalized())
	elif not moving():
		focus = at; distance = radius; direction = Vector3(0, 1, 0.00001).normalized(); render_frame()

func family_view(id: String) -> void:
	var fit := Mechanics.orbit(session, id)
	var parent: String = fit.parent if session.expedition.state.bodies.has(fit.parent) else id
	var radius: float = radii[parent] * 3.3
	for body in session.expedition.scenario.bodies:
		if body.system == reference and Mechanics.orbit(session, body.id).parent == parent: radius = maxf(radius, Mechanics.orbit(session, body.id).au * 3.1)
	tracking = parent
	fly(positions[parent], radius, Vector3(0.2, 0.65, 1).normalized())

func fly(at: Array, radius: float, toward: Vector3) -> void:
	if camera_tween != null: camera_tween.kill()
	if not initialized or DisplayServer.get_name() == "headless":
		focus = at.duplicate(); distance = radius; direction = toward; initialized = true; render_frame(); return
	var start := focus.duplicate()
	var start_radius := distance
	var start_direction := direction
	var duration := clampf(absf(log(radius / distance)) * 0.17 + 0.45, 0.55, 2.4)
	camera_tween = create_tween()
	camera_tween.tween_method(func(progress: float):
		var eased := smoothstep(0.0, 1.0, progress)
		# Finish lateral motion before the final approach; no crossfade or raster zoom.
		focus = Mechanics.mix_position(start, at, 1.0 - pow(1.0 - eased, 4.0))
		distance = exp(lerpf(log(start_radius), log(radius), eased))
		direction = start_direction.slerp(toward, eased).normalized()
		render_frame()
	, 0.0, 1.0, duration)

func moving() -> bool:
	return camera_tween != null and camera_tween.is_running()

func _process(_delta: float) -> void:
	if not active: return
	if last_hours != session.elapsed_hours():
		update_ephemeris()
		if tracking != "" and not moving() and positions.has(tracking): focus = positions[tracking].duplicate()
	render_frame()

func normalized_position(at: Array) -> Vector3:
	return Mechanics.vector(Mechanics.subtract(at, focus), distance) * 1000.0

func project_position(at: Array) -> Vector3:
	var relative := normalized_position(at)
	if camera.is_position_behind(relative): return Vector3(-100000, -100000, -1)
	var point := camera.unproject_position(relative) + frame.position
	return Vector3(point.x, point.y, relative.distance_to(camera.position))

func project_body(id: String) -> Vector2:
	if not positions.has(id): return Vector2(-100000, -100000)
	var point := project_position(positions[id])
	return Vector2(point.x, point.y)

func render_frame() -> void:
	if camera == null or not initialized: return
	camera.position = direction * 1000.0
	camera.look_at(Vector3.ZERO, Vector3.FORWARD if direction.y > 0.999 else Vector3.UP)
	points.clear()
	for id in meshes:
		var node: MeshInstance3D = meshes[id]
		if not positions.has(id): node.hide(); continue
		node.position = normalized_position(positions[id])
		var r: float = radii[id] / distance * 1000.0
		node.scale = Vector3.ONE * maxf(r, 0.000001)
		var projected := project_position(positions[id])
		var point := Vector2(projected.x, projected.y)
		var angular_pixels: float = r / maxf(0.01, projected.z) * frame.size.y / (2.0 * tan(deg_to_rad(camera.fov * 0.5)))
		node.visible = projected.z > 0 and angular_pixels > 0.45 and angular_pixels < frame.size.y * 5.0
		if projected.z > 0 and frame.grow(40).has_point(point): points[id] = {"point": point, "radius": angular_pixels}
	overlay.queue_redraw()

func turn(delta: Vector2) -> void:
	if moving(): camera_tween.kill()
	direction = direction.rotated(Vector3.UP, -delta.x * 0.006)
	var right := Vector3.UP.cross(direction).normalized()
	var next := direction.rotated(right, -delta.y * 0.006).normalized()
	if absf(next.y) < 0.985: direction = next
	render_frame()

func zoom(factor: float) -> void:
	var minimum: float = radii.get(tracking, 0.00001) * 1.15
	fly(focus, clampf(distance * factor, minimum, 1000000.0 * Mechanics.LY_AU), direction)

func focus_region(id: String, region: Vector2i) -> void:
	fly(positions[id], radii[id] * 3.3, Mechanics.orientation(session, id, session.elapsed_hours()) * Mechanics.normal(region))

func project_region(id: String, region: Vector2i) -> Vector3:
	var n := Mechanics.orientation(session, id, session.elapsed_hours()) * Mechanics.normal(region)
	var center := normalized_position(positions[id])
	var r: float = radii[id] / distance * 1000.0
	var point := camera.unproject_position(center + n * r) + frame.position
	return Vector3(point.x, point.y, n.dot((camera.position - center - n * r).normalized()))

func pick_region(id: String, pixel: Vector2) -> Vector2i:
	var ray := camera.project_ray_normal(pixel - frame.position)
	var origin := camera.position - normalized_position(positions[id])
	var r: float = radii[id] / distance * 1000.0
	var b := origin.dot(ray)
	var discriminant := b * b - (origin.length_squared() - r * r)
	if discriminant < 0: return Vector2i(-1, -1)
	var t := -b - sqrt(discriminant)
	if t < 0: return Vector2i(-1, -1)
	var normal_value := (origin + ray * t).normalized()
	return Mechanics.region_at(Mechanics.orientation(session, id, session.elapsed_hours()).inverse() * normal_value)
