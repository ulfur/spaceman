extends Node3D
## Presentation only. Terrain, machinery and service lines reflect model state.
## Small rover motion illustrates a working service network; it is not pathfinding.
const Surface = preload("res://scripts/surface_simulation.gd")
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
var distance := 83.0
var focus := Vector3(0, 1, 0)
var structures: Dictionary = {}
var rovers: Array[Node3D] = []
var animation_time := 0.0
var motion_rate := 0.0
var surveyed_count := -1

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

func setup(surface_state: Dictionary) -> void:
	snapshot = surface_state
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("171d23")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5c6d4")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.light_color = Color("ffd4a3")
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
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
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = preload("res://shaders/surface_terrain.gdshader")
	var terrain := mesh_node(self, st.commit(), Vector3.ZERO, terrain_mat)
	terrain.name = "Terrain"
	# Geological apron and distant ridges make the sector a place, not a floating board.
	var apron := PlaneMesh.new()
	apron.size = Vector2(340, 340)
	mesh_node(self, apron, Vector3(0, -0.12, 0), terrain_mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(snapshot.seed) + 81
	var rock_mat := material(Color("333e42"))
	for i in range(155):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(48.0, 110.0)
		var rock := SphereMesh.new()
		rock.radial_segments = 5
		rock.rings = 3
		var node := mesh_node(self, rock, Vector3(cos(angle) * radius, 0, sin(angle) * radius), rock_mat)
		node.scale = Vector3(rng.randf_range(4, 15), rng.randf_range(5, 19), rng.randf_range(5, 14))
		node.rotation.y = angle
	for cell in snapshot.cells:
		if not cell.buildable or rng.randf() < 0.1:
			var rock := SphereMesh.new()
			rock.radial_segments = 5
			rock.rings = 3
			var node := mesh_node(self, rock, cell_position(cell.x, cell.z) + Vector3(1, 0.15, 1), rock_mat)
			node.scale = Vector3(1.6, 0.65, 1.2) if cell.buildable else Vector3(2.6, 2.2, 2.1)
			node.rotation.y = rng.randf() * TAU
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
		var ore_mat := material(Color("d8aa61"), 0.45)
		var ice_mat := material(Color("92c4c9"), 0.15)
		for cell in snapshot.cells:
			if not cell.scanned or cell.resource == "":
				continue
			var pos := cell_position(cell.x, cell.z)
			var mat: Material = ore_mat if cell.resource == "metal" else ice_mat
			for offset in [Vector3(-0.8, 0.04, -0.7), Vector3(0.6, 0.03, 0.2), Vector3(-0.2, 0.04, 0.9)]:
				var shard := cylinder(deposits, pos + offset, 0.44, 0.13, mat, 0.24)
				shard.rotation_degrees.y = cell.x * 17 + cell.z * 31
	for structure in snapshot.structures:
		var id: int = structure.id
		if not structures.has(id):
			var node := make_structure(structure.kind)
			installations.add_child(node)
			structures[id] = node
		var node: Node3D = structures[id]
		node.position = cell_position(structure.x, structure.z)
		node.scale.y = maxf(0.12, structure.progress)
		var beacon: MeshInstance3D = node.get_node_or_null("Beacon")
		if beacon != null:
			beacon.material_override = material(Color("a8deca") if structure.powered and structure.enabled else Color("e18f53"), 0.0, true)
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
			var rover := Node3D.new()
			block(rover, Vector3(0, 0.45, 0), Vector3(0.7, 0.5, 1.2), material(Color("c4c5b5"), 0.4))
			for side in [-1, 1]:
				block(rover, Vector3(side * 0.48, 0.22, 0), Vector3(0.24, 0.36, 1.25), material(Color("242d30")))
			block(rover, Vector3(0, 0.5, -0.61), Vector3(0.42, 0.12, 0.04), material(Color("b3dbcb"), 0, true))
			add_child(rover)
			rovers.append(rover)

func make_structure(kind: String, ghost: bool = false) -> Node3D:
	var root := Node3D.new()
	var ivory := material(Color(0.79, 0.8, 0.73, 0.42) if ghost else Color("c9caba"), 0.35)
	var dark := material(Color(0.16, 0.22, 0.24, 0.4) if ghost else Color("293a40"), 0.45)
	var copper := material(Color(0.72, 0.39, 0.19, 0.4) if ghost else Color("b97743"), 0.5)
	block(root, Vector3(0, 0.12, 0), Vector3(3.25, 0.24, 3.25), dark)
	match kind:
		"seed":
			cylinder(root, Vector3(0, 1.7, 0), 1.25, 2.8, ivory, 0.88)
			cylinder(root, Vector3(0, 3.2, 0), 0.83, 0.35, copper)
			for side in [-1, 1]:
				block(root, Vector3(side * 1.4, 0.7, 0), Vector3(0.35, 1.4, 2.0), dark)
				block(root, Vector3(side * 1.85, 1.7, 0), Vector3(1.4, 0.12, 2.2), dark)
			cylinder(root, Vector3(0, 4.1, 0), 0.055, 1.9, copper)
		"solar":
			cylinder(root, Vector3(0, 0.85, 0), 0.13, 1.4, ivory)
			var panel := block(root, Vector3(0, 1.55, 0), Vector3(3.5, 0.12, 2.7), dark)
			panel.rotation_degrees.x = -23
			for x in [-1.1, 0.0, 1.1]:
				var line := block(root, Vector3(x, 1.62, 0), Vector3(0.035, 0.025, 2.7), copper)
				line.rotation_degrees.x = -23
		"mine":
			for side in [-1, 1]:
				block(root, Vector3(side, 1.9, 0), Vector3(0.23, 3.4, 0.35), copper)
			block(root, Vector3(0, 3.5, 0), Vector3(2.45, 0.35, 0.8), ivory)
			cylinder(root, Vector3(0, 1.7, 0), 0.27, 2.8, dark, 0.16)
			block(root, Vector3(0, 0.5, 1), Vector3(2.4, 0.65, 0.9), ivory)
		"ice_well":
			cylinder(root, Vector3(-0.6, 1.1, 0), 0.75, 1.8, ivory)
			cylinder(root, Vector3(0.8, 0.95, 0.5), 0.44, 1.45, dark)
			block(root, Vector3(0, 1.65, 0), Vector3(2.5, 0.2, 0.22), copper)
		"refinery":
			block(root, Vector3(-0.5, 1.0, 0), Vector3(1.5, 1.6, 2.55), ivory)
			cylinder(root, Vector3(0.9, 1.7, -0.6), 0.48, 2.95, copper)
			cylinder(root, Vector3(0.9, 1.2, 0.7), 0.48, 2.0, dark)
			for z in [-0.8, 0.0, 0.8]:
				block(root, Vector3(-0.5, 1.9, z), Vector3(1.1, 0.16, 0.13), dark)
		"fabricator":
			block(root, Vector3(0, 1.0, 0), Vector3(2.8, 1.6, 2.55), ivory)
			block(root, Vector3(0, 1.0, 1.3), Vector3(1.6, 1.15, 0.06), dark)
			block(root, Vector3(0, 1.87, 0), Vector3(2.4, 0.18, 1.2), copper)
		"refuge":
			cylinder(root, Vector3(0, 0.6, 0), 1.4, 0.65, ivory)
			var dome := SphereMesh.new()
			dome.radius = 1.28
			dome.height = 2.56
			var glass := mesh_node(root, dome, Vector3(0, 1.25, 0), material(Color(0.3, 0.61, 0.58, 0.65), 0.1))
			glass.scale.y = 0.75
			for side in [-1, 1]:
				block(root, Vector3(side * 1.32, 0.9, 0), Vector3(0.35, 1.1, 1.8), dark)
	var beacon := block(root, Vector3(1.4, 0.65, 1.4), Vector3(0.12, 0.65, 0.12), copper)
	beacon.name = "Beacon"
	return root

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
			var height: float = 4.8 if structure.kind == "seed" else (3.8 if structure.kind == "mine" else 2.7)
			height *= maxf(0.12, structure.progress)
			var bounds := AABB(cell_position(structure.x, structure.z) - Vector3(1.7, 0, 1.7), Vector3(3.4, height, 3.4))
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
	if snapshot.is_empty() or snapshot.structures.is_empty():
		return
	var hub: Dictionary = snapshot.structures[0]
	var targets: Array = []
	for structure in snapshot.structures:
		if structure.kind != "seed" and structure.connected and structure.powered and structure.enabled:
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
