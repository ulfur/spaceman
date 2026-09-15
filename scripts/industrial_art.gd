extends RefCounted
## Shared, metre-scale industrial asset kit. Geometry and animation are presentation only.
## Static pieces are merged by material; named moving parts remain independently addressable.
static var materials: Dictionary = {}
static var bevels: Dictionary = {}

static func finish(color: String, metal: float = 0.0, rough: float = 0.55) -> StandardMaterial3D:
	var key := color + str(metal) + str(rough)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.metallic = metal
	mat.roughness = rough
	materials[key] = mat
	return mat

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, mat)

static func tube(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	shape.radial_segments = 20
	return mesh(parent, shape, at, mat)

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var node := box(parent, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat)
	node.basis = Basis.looking_at((b - a).normalized(), Vector3.FORWARD if absf((b-a).normalized().y) > 0.99 else Vector3.UP)
	return node

static func face(st: SurfaceTool, points: Array[Vector3]) -> void:
	var normal := (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	for i in range(1, points.size() - 1):
		for j in [0, i, i + 1]:
			st.set_normal(normal)
			st.set_uv(Vector2(points[j].x, points[j].z))
			st.add_vertex(points[j])

static func shell(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var key := str(size)
	if not bevels.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var b: float = minf(0.13, minf(size.y, minf(size.x, size.z)) * 0.18)
		var rings: Array = []
		for tier in range(4):
			var inset: float = b if tier == 0 or tier == 3 else 0.0
			var x: float = size.x * 0.5 - inset
			var z: float = size.z * 0.5 - inset
			var y: float = [-size.y * 0.5, -size.y * 0.5 + b, size.y * 0.5 - b, size.y * 0.5][tier]
			var ring: Array[Vector3] = []
			for p in [Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]:
				ring.append(Vector3(p.x, y, p.y))
			rings.append(ring)
		for tier in range(3):
			for i in range(8):
				var j: int = (i + 1) % 8
				face(st, [rings[tier][i], rings[tier][j], rings[tier + 1][j], rings[tier + 1][i]])
		face(st, rings[3])
		var bottom: Array[Vector3] = rings[0].duplicate()
		bottom.reverse()
		face(st, bottom)
		bevels[key] = st.commit()
	return mesh(parent, bevels[key], at, mat)

static func moving(parent: Node3D, id: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = id
	node.position = at
	parent.add_child(node)
	return node

static func keep(node: Node, id: String) -> void:
	node.name = id
	node.set_meta("keep", true)

static func bake(root: Node3D) -> void:
	var groups: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and not child.has_meta("keep"):
			var mat: Material = child.material_override
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				groups[mat] = st
			groups[mat].append_from(child.mesh, 0, child.transform)
			root.remove_child(child)
			child.free()
	for mat in groups:
		mesh(root, groups[mat].commit(), Vector3.ZERO, mat)

static func radiator(root: Node3D, at: Vector3, size: Vector3) -> void:
	box(root, at, size, finish("182b33", 0.4))
	for i in range(9):
		box(root, at + Vector3(0, size.y * 0.5 + 0.012, (i - 4) * size.z / 10), Vector3(size.x * 0.88, 0.045, 0.035), finish("53686c", 0.55))

static func build(kind: String, ghost: bool = false) -> Node3D:
	var root := Node3D.new()
	var ivory := finish("aebdb9", 0.25, 0.48)
	var white := finish("d1d7c9", 0.16, 0.48)
	var dark := finish("172b34", 0.6, 0.42)
	var steel := finish("677c80", 0.72, 0.32)
	var copper := finish("b87742", 0.58, 0.42)
	var rubber := finish("131e23", 0.08, 0.88)
	var amber := finish("c79249", 0.22)
	var panel := ShaderMaterial.new()
	panel.shader = preload("res://shaders/solar_cells.gdshader")
	shell(root, Vector3(0, 0.16, 0), Vector3(3.6, 0.3, 3.6), dark)
	for x in [-1.48, 1.48]:
		for z in [-1.48, 1.48]:
			shell(root, Vector3(x, 0.12, z), Vector3(0.55, 0.22, 0.55), steel)
			box(root, Vector3(x, 0.325, z), Vector3(0.34, 0.025, 0.13), amber)
	match kind:
		"seed":
			tube(root, Vector3(0, 1.65, 0), 1.14, 2.6, ivory, 0.98)
			tube(root, Vector3(0, 0.53, 0), 1.22, 0.25, dark)
			tube(root, Vector3(0, 2.92, 0), 1.0, 0.25, dark, 0.86)
			tube(root, Vector3(0, 3.1, 0), 0.85, 0.23, white, 0.64)
			for i in range(8):
				var angle: float = i * TAU / 8
				var normal := Vector3(sin(angle), 0, cos(angle))
				var plate := shell(root, normal * 1.04 + Vector3(0, 1.78, 0), Vector3(0.56, 1.82, 0.11), white)
				plate.rotation.y = angle
				beam(root, normal * 0.95 + Vector3(0, 1.1, 0), normal * 1.63 + Vector3(0, 0.25, 0), 0.12, steel)
			for side in [-1, 1]:
				var wing := box(root, Vector3(side * 1.4, 1.75, 0), Vector3(0.68, 0.08, 2.55), panel)
				wing.rotation.z = side * 0.12
				shell(root, Vector3(side * 1.2, 0.69, 0.9), Vector3(0.65, 0.62, 0.75), copper)
			tube(root, Vector3(0, 3.77, 0), 0.047, 1.2, steel)
			var dish := moving(root, "Rotor", Vector3(0, 3.98, 0))
			var bowl := tube(dish, Vector3.ZERO, 0.21, 0.27, white, 0.49)
			bowl.rotation.z = -0.65
			beam(dish, Vector3.ZERO, Vector3(0.22, 0.4, 0), 0.04, copper)
		"solar":
			tube(root, Vector3(0, 0.9, 0), 0.18, 1.45, steel)
			var wing := moving(root, "SolarWing", Vector3(0, 1.52, 0))
			wing.rotation.x = -0.34
			shell(wing, Vector3.ZERO, Vector3(3.42, 0.11, 2.85), ivory)
			for side in [-1, 1]:
				box(wing, Vector3(side * 0.84, 0.069, 0), Vector3(1.55, 0.018, 2.65), panel)
			beam(root, Vector3(0, 0.5, 0.7), Vector3(0, 1.35, -0.8), 0.07, copper)
			shell(root, Vector3(0, 0.52, 1.08), Vector3(0.9, 0.4, 0.53), white)
			bake(wing)
		"mine":
			for side in [-1, 1]:
				beam(root, Vector3(side * 1.28, 0.35, -0.6), Vector3(side * 0.94, 3.45, -0.32), 0.22, copper)
				beam(root, Vector3(side * 1.28, 0.35, 0.7), Vector3(side * 0.94, 3.45, -0.32), 0.12, steel)
			shell(root, Vector3(0, 3.42, -0.32), Vector3(2.48, 0.42, 0.83), white)
			tube(root, Vector3(0, 2.86, -0.32), 0.43, 0.62, dark)
			var drill := moving(root, "Rotor", Vector3(0, 1.72, -0.32))
			tube(drill, Vector3.ZERO, 0.15, 2.25, steel)
			for i in range(12):
				var tooth := box(drill, Vector3(0, i * 0.15 - 1.0, 0), Vector3(0.45, 0.065, 0.16), dark)
				tooth.rotation.y = i * 0.9
			shell(root, Vector3(0, 0.75, 1.1), Vector3(2.32, 0.77, 0.9), ivory)
			radiator(root, Vector3(0, 1.17, 1.1), Vector3(1.82, 0.04, 0.58))
			bake(drill)
		"ice_well":
			for x in [-0.72, 0.72]:
				tube(root, Vector3(x, 1.23, -0.3), 0.56, 1.65, white)
				for y in [0.51, 1.14, 1.97]: tube(root, Vector3(x, y, -0.3), 0.585, 0.1, steel)
				tube(root, Vector3(x, 2.13, -0.3), 0.56, 0.23, ivory, 0.33)
			beam(root, Vector3(-0.72, 2.24, -0.3), Vector3(0.72, 2.24, -0.3), 0.13, copper)
			shell(root, Vector3(0, 0.73, 1.08), Vector3(1.5, 0.66, 0.65), dark)
			var pump := moving(root, "Rotor", Vector3(0, 1.14, 1.08))
			tube(pump, Vector3.ZERO, 0.34, 0.09, steel)
			box(pump, Vector3(0, 0.09, 0), Vector3(0.64, 0.09, 0.11), copper)
		"refinery":
			shell(root, Vector3(-0.65, 1.05, 0), Vector3(1.35, 1.54, 2.68), ivory)
			radiator(root, Vector3(-0.65, 1.85, 0), Vector3(1.05, 0.12, 2.22))
			for z in [-0.72, 0.67]:
				tube(root, Vector3(0.78, 1.55, z), 0.48, 2.5, steel)
				for y in [0.52, 1.05, 1.6, 2.45]: tube(root, Vector3(0.78, y, z), 0.52, 0.075, copper)
				tube(root, Vector3(0.78, 2.9, z), 0.48, 0.24, ivory, 0.27)
				beam(root, Vector3(-0.4, 2.05, z), Vector3(0.78, 2.05, z), 0.1, copper)
			var rotor := moving(root, "Rotor", Vector3(-0.65, 1.97, 0))
			for i in range(3):
				var blade := box(rotor, Vector3.ZERO, Vector3(0.91, 0.025, 0.12), steel)
				blade.rotation.y = i * PI / 3
		"fabricator":
			shell(root, Vector3(0, 1.07, -0.05), Vector3(2.85, 1.55, 2.54), ivory)
			box(root, Vector3(0, 1.05, 1.24), Vector3(2.27, 1.1, 0.08), dark)
			for side in [-1, 1]:
				beam(root, Vector3(side * 1.13, 0.65, 1.32), Vector3(side * 1.13, 1.53, 1.32), 0.07, copper)
			var carriage := moving(root, "Carriage", Vector3(0, 1.16, 1.37))
			shell(carriage, Vector3.ZERO, Vector3(0.38, 0.38, 0.25), copper)
			beam(root, Vector3(-1.2, 1.47, 1.37), Vector3(1.2, 1.47, 1.37), 0.06, steel)
			radiator(root, Vector3(0, 1.9, -0.5), Vector3(2.4, 0.15, 0.94))
			for x in [-0.7, 0.0, 0.7]: shell(root, Vector3(x, 0.48, 1.48), Vector3(0.42, 0.2, 0.3), steel)
		"refuge", "testbed":
			shell(root, Vector3(0, 0.48, 0), Vector3(3.26, 0.32, 3.26), ivory)
			var culture_mat := ShaderMaterial.new()
			culture_mat.shader = preload("res://shaders/culture.gdshader")
			keep(box(root, Vector3(0, 0.67, 0), Vector3(2.9, 0.08, 2.9), culture_mat), "Culture")
			for x in [-1.52, 1.52]:
				for z in [-1.52, 1.52]:
					beam(root, Vector3(x, 0.6, z), Vector3(x, 2.77, z), 0.105, white)
				beam(root, Vector3(x, 2.77, -1.52), Vector3(x, 2.77, 1.52), 0.12, ivory)
				beam(root, Vector3(-1.52, 2.77, x), Vector3(1.52, 2.77, x), 0.12, ivory)
			for x in [-0.93, 0.0, 0.93]:
				box(root, Vector3(x, 0.74, 0), Vector3(0.045, 0.06, 2.88), steel)
				beam(root, Vector3(x, 2.74, -1.48), Vector3(x, 2.74, 1.48), 0.045, steel)
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.22, 0.54, 0.57, 0.12)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.14
			glass.metallic = 0.2
			keep(box(root, Vector3(0, 1.72, 0), Vector3(3.03, 2.05, 3.03), glass), "Glazing")
			var canopy := shell(root, Vector3(0, 2.99, 0), Vector3(3.48, 0.32, 3.48), finish("665950", 0.0, 0.98))
			keep(canopy, "Canopy")
			canopy.visible = false
			for x in [-1, 1]:
				shell(root, Vector3(x * 1.33, 0.93, 1.54), Vector3(0.48, 0.85, 0.43), ivory)
				tube(root, Vector3(x * 1.32, 1.05, -1.54), 0.19, 1.02, copper)
			var light_mat := finish("74c7b2").duplicate() as StandardMaterial3D
			light_mat.emission_enabled = true
			light_mat.emission = Color("74c7b2")
			keep(box(root, Vector3(0, 2.64, -1.43), Vector3(2.74, 0.045, 0.06), light_mat), "GrowLight")
	# Equipment identity accents and a separate operating beacon.
	for x in [-1, 1]: box(root, Vector3(x * 1.71, 0.36, 0), Vector3(0.08, 0.035, 1.12), copper)
	var beacon_mat := finish("77d6bc").duplicate() as StandardMaterial3D
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color("77d6bc")
	beacon_mat.emission_energy_multiplier = 1.8
	keep(box(root, Vector3(1.48, 0.55, 1.48), Vector3(0.1, 0.25, 0.1), beacon_mat), "Beacon")
	bake(root)
	if ghost: ghost_material(root)
	return root

static func ghost_material(root: Node) -> void:
	if root is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.34, 0.79, 0.72, 0.21)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		root.material_override = mat
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children(): ghost_material(child)

static func rover() -> Node3D:
	var root := Node3D.new()
	var steel := finish("4a6065", 0.6)
	shell(root, Vector3(0, 0.49, 0), Vector3(0.76, 0.39, 1.27), finish("c2cbbd", 0.2))
	box(root, Vector3(0, 0.7, -0.23), Vector3(0.49, 0.06, 0.35), finish("1b3942", 0.45))
	for side in [-1, 1]:
		for z in [-0.4, 0.0, 0.4]:
			var wheel := tube(root, Vector3(side * 0.45, 0.24, z), 0.23, 0.16, finish("172026", 0.0, 0.9))
			wheel.rotation.z = PI * 0.5
	beam(root, Vector3(0.2, 0.68, 0.3), Vector3(0.2, 1.15, 0.3), 0.035, steel)
	box(root, Vector3(0.2, 1.15, 0.25), Vector3(0.18, 0.12, 0.18), steel)
	bake(root)
	return root
