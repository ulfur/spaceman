extends Node3D
## Presentation only. Terrain, machinery and service lines reflect model state.
## Small rover motion illustrates a working service network; it is not pathfinding.
const Surface = preload("res://scripts/surface_simulation.gd")
const Art = preload("res://scripts/industrial_art.gd")
const Geology = preload("res://scripts/terrain_art.gd")
const SIZE := 20
const CELL := 4.0
var camera: Camera3D
var snapshot: Dictionary
var installations: Node3D
var deposits: Node3D
var links: Node3D
var marker: Node3D
var preview: Node3D
var yaw := 0.62
var distance := 64.0
var focus := Vector3(4, 1, 2)
var structures: Dictionary = {}
var rovers: Array[Node3D] = []
var animation_time := 0.0
var motion_rate := 0.0
var surveyed_count := -1
var terrain_material: ShaderMaterial
var visual_context: Dictionary = {}
var deposit_nodes: Dictionary = {}
var survey_wave: MeshInstance3D
var survey_age := 9.0
var structure_times: Dictionary = {}

func material(color: Color, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.metallic = metallic
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, position_value: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = position_value
	parent.add_child(node)
	return node

func block(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh_node(parent, mesh, at, mat)

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return mesh_node(parent, mesh, at, mat)

func setup(surface_state: Dictionary, context: Dictionary = {}) -> void:
	snapshot = surface_state
	visual_context = context
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var air: float = clampf(float(context.get("pressure", 0.25)), 0.0, 1.0)
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("182c3d").lerp(Color("010307"), 1.0 - air)
	sky_mat.sky_horizon_color = Color("ac9180").lerp(Color("192833"), 1.0 - air)
	sky_mat.ground_bottom_color = Color("262b30")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = Color("a8bfca")
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = air > 0.025
	env.fog_light_color = Color("82979e")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0012 * air
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_hdr_threshold = 1.8
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-29, -48, 0)
	sun.light_color = Color("f4dbb6")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.035
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 48
	camera.near = 0.1
	camera.far = 450
	add_child(camera)
	camera.current = true
	_update_camera()
	_build_terrain()
	deposits = Node3D.new()
	add_child(deposits)
	links = Node3D.new()
	add_child(links)
	installations = Node3D.new()
	add_child(installations)
	marker = Node3D.new()
	add_child(marker)
	preview = Node3D.new()
	add_child(preview)
	var wave_mat := ShaderMaterial.new()
	wave_mat.shader = preload("res://shaders/survey_wave.gdshader")
	var wave_mesh := PlaneMesh.new()
	wave_mesh.size = Vector2(40, 40)
	survey_wave = mesh_node(self, wave_mesh, Vector3.ZERO, wave_mat)
	survey_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	survey_wave.visible = false
	refresh(surface_state)

func ground(x: float, z: float) -> float:
	var ix: int = clampi(int(floor(x / CELL + 10.0)), 0, SIZE - 1)
	var iz: int = clampi(int(floor(z / CELL + 10.0)), 0, SIZE - 1)
	return float(snapshot.cells[iz * SIZE + ix].height)

func cell_position(x: int, z: int) -> Vector3:
	return Vector3((x - 9.5) * CELL, float(snapshot.cells[z * SIZE + x].height), (z - 9.5) * CELL)

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four flat triangles around each foundation cell, with shared edge heights.
	for z in range(SIZE):
		for x in range(SIZE):
			var center := cell_position(x, z)
			var corners: Array[Vector3] = []
			for offset in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
				var vx: float = center.x + offset.x
				var vz: float = center.z + offset.y
				var h: float = (ground(vx - 0.1, vz - 0.1) + ground(vx + 0.1, vz - 0.1) + ground(vx - 0.1, vz + 0.1) + ground(vx + 0.1, vz + 0.1)) / 4.0
				corners.append(Vector3(vx, h, vz))
			var tint: float = clampf((center.y - 0.2) / 3.0, 0.0, 1.0)
			var base := Color("695a49").lerp(Color("b09a77"), tint)
			for index in range(4):
				st.set_color(base.lightened(0.025 * (index % 2)))
				st.add_vertex(center)
				st.add_vertex(corners[index])
				st.add_vertex(corners[(index + 1) % 4])
	st.generate_normals()
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://shaders/surface_terrain.gdshader")
	var cold: float = clampf((270.0 - float(visual_context.get("ambient_k", 244))) / 100.0, 0.0, 0.65)
	terrain_material.set_shader_parameter("frost", cold)
	var variation: float = fmod(float(snapshot.seed) * 0.618, 1.0)
	terrain_material.set_shader_parameter("sand_color", Color("8b6749").lerp(Color("756451"), variation))
	terrain_material.set_shader_parameter("stone_color", Color("485358").lerp(Color("625c58"), variation))
	var terrain := mesh_node(self, st.commit(), Vector3.ZERO, terrain_material)
	terrain.name = "Terrain"
	Geology.dress(self, int(snapshot.seed), terrain_material)
	# Sparse perimeter survey stakes; no permanent full-screen grid.
	for index in range(0, SIZE + 1, 2):
		for side in [-1, 1]:
			for pos in [Vector3(index * CELL - 40, 0, side * 40), Vector3(side * 40, 0, index * CELL - 40)]:
				pos.y = ground(pos.x, pos.z) + 0.4
				block(self, pos, Vector3(0.08, 0.8, 0.08), material(Color("cfb780")))

func _clear(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh(surface_state: Dictionary) -> void:
	snapshot = surface_state
	var count := 0
	for cell in snapshot.cells:
		if cell.scanned:
			count += 1
	if count != surveyed_count:
		surveyed_count = count
		_clear(deposits)
		deposit_nodes.clear()
		var ore_mat := material(Color("8c6043"), 0.35)
		var ice_mat := material(Color("6d9da5"), 0.2)
		for cell in snapshot.cells:
			if not cell.scanned or cell.resource == "": continue
			var cluster := Node3D.new()
			deposits.add_child(cluster)
			cluster.position = cell_position(cell.x, cell.z)
			deposit_nodes[int(cell.z) * SIZE + int(cell.x)] = cluster
			var mat: Material = ore_mat if cell.resource == "metal" else ice_mat
			for i in range(4):
				var node := Art.mesh(cluster, Geology.rock(int(cell.x) * 31 + int(cell.z) * 19 + i), Vector3(sin(i * 2.4) * 0.9, 0.01, cos(i * 2.4) * 0.8), mat)
				node.scale = Vector3(0.52, 0.15 + i * 0.05, 0.37)
				node.rotation.y = cell.x * 0.17 + i
			Art.bake(cluster)
	# Outcrops recede with extraction; no unsurveyed resource is drawn.
	for index in deposit_nodes:
		var cell: Dictionary = snapshot.cells[index]
		var amount: float = clampf(cell.remaining / maxf(1.0, cell.initial), 0.0, 1.0)
		deposit_nodes[index].visible = amount > 0.001
		deposit_nodes[index].scale = Vector3.ONE * (0.3 + amount * 0.7)
	for structure in snapshot.structures:
		var id: int = structure.id
		if not structures.has(id):
			var node := make_structure(structure.kind)
			installations.add_child(node)
			structures[id] = node
			structure_times[id] = float(id) * 0.47
		var node: Node3D = structures[id]
		node.position = cell_position(structure.x, structure.z)
		node.scale.y = maxf(0.12, structure.progress)
		var beacon: MeshInstance3D = node.get_node_or_null("Beacon")
		var active: bool = is_operating(structure)
		if beacon != null:
			var mat: StandardMaterial3D = beacon.material_override
			var tint := Color("7ad8b8") if active else Color("ce9856")
			mat.albedo_color = tint
			mat.emission = tint
		if structure.kind in ["testbed", "refuge"]:
			var culture: MeshInstance3D = node.get_node("Culture")
			var density: float = structure.trial.biomass_kg / 0.1 if structure.kind == "testbed" else structure.culture
			culture.material_override.set_shader_parameter("density", clampf(density, 0.0, 1.0))
			node.get_node("LampStrip").visible = active and (structure.kind == "refuge" or structure.trial.get("lamp", false))
			if structure.kind == "testbed":
				node.get_node("Canopy").visible = structure.trial.canopy
				culture.material_override.set_shader_parameter("liquid", 1.0 if structure.trial.temperature_k > 273.15 and structure.trial.water_kg > 0.1 else 0.0)
	_clear(links)
	for destination in snapshot.structures:
		if destination.kind == "seed" or not destination.connected:
			continue
		var best: Dictionary = {}
		var nearest := 1000.0
		for source in snapshot.structures:
			if source.id == destination.id or not source.connected or not source.enabled or source.progress < 1.0 or source.path_distance >= destination.path_distance:
				continue
			var length: float = Vector2(source.x - destination.x, source.z - destination.z).length()
			if length <= Surface.LINK_RANGE and length < nearest:
				nearest = length
				best = source
		if not best.is_empty():
			var start := cell_position(best.x, best.z) + Vector3(0, 0.18, 0)
			var end := cell_position(destination.x, destination.z) + Vector3(0, 0.18, 0)
			var cable := block(links, (start + end) / 2.0, Vector3(0.1, 0.08, start.distance_to(end)), material(Color("25383c")))
			cable.look_at(end)
	if snapshot.landed and rovers.is_empty():
		for i in range(3):
			var rover := Art.rover()
			add_child(rover)
			rovers.append(rover)

func make_structure(kind: String, ghost: bool = false) -> Node3D:
	return Art.build(kind, ghost)

func is_operating(structure: Dictionary) -> bool:
	if not structure.enabled or not structure.connected or not structure.powered or structure.progress < 1.0: return false
	match structure.kind:
		"mine", "ice_well": return structure.status.begins_with("Extracting")
		"refinery", "fabricator": return structure.status.begins_with("Refining") or structure.status.begins_with("Fabricating")
		"testbed": return structure.trial.operating
		"refuge": return structure.status != "Life support starved"
	return true

func pulse_survey(cell: Vector2i) -> void:
	survey_age = 0.0
	survey_wave.position = cell_position(cell.x, cell.y) + Vector3(0, 1.9, 0)
	survey_wave.visible = true

func outline(parent: Node3D, color: Color) -> void:
	var mat := material(color, 0, true)
	for side in [-1, 1]:
		block(parent, Vector3(side * 1.9, 0.12, 0), Vector3(0.075, 0.06, 3.8), mat)
		block(parent, Vector3(0, 0.12, side * 1.9), Vector3(3.8, 0.06, 0.075), mat)

func set_selected(cell: Vector2i) -> void:
	_clear(marker)
	if cell.x < 0 or cell.y < 0:
		return
	marker.position = cell_position(cell.x, cell.y)
	outline(marker, Color("e5ce9c"))

func set_preview(kind: String, cell: Vector2i, valid: bool) -> void:
	_clear(preview)
	if cell.x < 0 or cell.y < 0 or kind == "":
		return
	preview.position = cell_position(cell.x, cell.y)
	outline(preview, Color("9cddd3") if valid else Color("e7936e"))
	if kind not in ["survey", "inspect"]:
		preview.add_child(make_structure("seed" if kind == "land" else kind, true))

func pick_cell(screen_position: Vector2, include_structures: bool = false) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if direction.y >= -0.01:
		return Vector2i(-1, -1)
	var t: float = (1.2 - origin.y) / direction.y
	var position_value: Vector3 = origin + direction * t
	for iteration in range(3):
		t = (ground(position_value.x, position_value.z) - origin.y) / direction.y
		position_value = origin + direction * t
	var cell := Vector2i(int(floor(position_value.x / CELL + 10)), int(floor(position_value.z / CELL + 10)))
	if include_structures:
		# Inspect machinery by its volume, not the ground projected behind its roof.
		var closest: float = origin.distance_to(position_value)
		for structure in snapshot.structures:
			var height: float = 4.8 if structure.kind == "seed" else (3.8 if structure.kind == "mine" else 3.3)
			height *= maxf(0.12, structure.progress)
			var bounds := AABB(cell_position(structure.x, structure.z) - Vector3(1.83, 0, 1.83), Vector3(3.66, height, 3.66))
			var hit: Variant = bounds.intersects_ray(origin, direction)
			if hit is Vector3 and origin.distance_to(hit) < closest:
				closest = origin.distance_to(hit)
				cell = Vector2i(structure.x, structure.z)
	return cell if cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE else Vector2i(-1, -1)

func _update_camera() -> void:
	camera.position = focus + Vector3(sin(yaw) * distance * 0.69, distance * 0.72, cos(yaw) * distance * 0.69)
	camera.look_at(focus)

func orbit_camera(delta: float) -> void:
	yaw += delta
	_update_camera()

func zoom_camera(delta: float) -> void:
	distance = clampf(distance + delta, 24, 128)
	_update_camera()

func pan_camera(delta: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	focus += (right * -delta.x + forward * -delta.y) * distance * 0.0015
	focus.x = clampf(focus.x, -35, 35)
	focus.z = clampf(focus.z, -35, 35)
	_update_camera()

func _process(delta: float) -> void:
	animation_time += delta * motion_rate
	if survey_wave != null and survey_age < 2.0:
		survey_age += delta
		survey_wave.material_override.set_shader_parameter("age", survey_age)
		survey_wave.visible = survey_age < 2.0
	for structure in snapshot.get("structures", []):
		if not structures.has(structure.id) or not is_operating(structure): continue
		structure_times[structure.id] += delta * motion_rate
		var t: float = structure_times[structure.id]
		var node: Node3D = structures[structure.id]
		var rotor: Node3D = node.get_node_or_null("Rotor")
		if rotor != null: rotor.rotation.y = t * (0.3 if structure.kind == "seed" else 2.2)
		var carriage: Node3D = node.get_node_or_null("Carriage")
		if carriage != null: carriage.position.x = sin(t * 1.9) * 0.86
		var culture: MeshInstance3D = node.get_node_or_null("Culture")
		if culture != null: culture.material_override.set_shader_parameter("phase", t)
	if snapshot.is_empty() or snapshot.structures.is_empty():
		return
	var hub: Dictionary = snapshot.structures[0]
	var targets: Array = []
	for structure in snapshot.structures:
		if structure.kind != "seed" and is_operating(structure):
			targets.append(structure)
	for index in range(rovers.size()):
		var rover: Node3D = rovers[index]
		rover.visible = not targets.is_empty()
		if targets.is_empty():
			continue
		var target: Dictionary = targets[index % targets.size()]
		var begin := cell_position(hub.x, hub.z)
		var end := cell_position(target.x, target.z)
		var fraction: float = (sin(animation_time * 0.25 + index * 2.1) + 1.0) * 0.5
		rover.position = begin.lerp(end, fraction) + Vector3(0.65, 0.05, 0.65)
		rover.position.y = ground(rover.position.x, rover.position.z) + 0.13
		var aim := end if cos(animation_time * 0.25 + index * 2.1) > 0 else begin
		aim.y = rover.position.y
		if rover.position.distance_to(aim) > 0.1:
			rover.look_at(aim)
