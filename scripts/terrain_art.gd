extends RefCounted
## Seeded scenery around the surveyed 80 m sector; never resource or traversability data.
const Art = preload("res://scripts/industrial_art.gd")

static func rock(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array = []
	for tier in range(5):
		var ring: Array[Vector3] = []
		var radius: float = [0.84, 1.0, 0.92, 0.65, 0.28][tier]
		for j in range(9):
			var angle: float = j * TAU / 9 + tier * 0.055
			var r: float = radius * rng.randf_range(0.8, 1.15)
			ring.append(Vector3(cos(angle) * r, tier * 0.23 + rng.randf_range(-0.05, 0.05), sin(angle) * r))
		levels.append(ring)
	for tier in range(4):
		for j in range(9):
			var k: int = (j + 1) % 9
			Art.face(st, [levels[tier][j], levels[tier][k], levels[tier + 1][k], levels[tier + 1][j]])
	var top: Array[Vector3] = levels[4].duplicate()
	Art.face(st, top)
	return st.commit()

static func distant_height(world: Node3D, noise: FastNoiseLite, x: float, z: float) -> float:
	var edge: float = maxf(absf(x), absf(z)) - 40.0
	var blend: float = smoothstep(0.0, 24.0, edge)
	var erosion: float = noise.get_noise_2d(x, z)
	var ridge: float = pow(maxf(0.0, 1.0 - absf(erosion * 2.5)), 2.0)
	var hills: float = 3.0 + ridge * 28.0 + noise.get_noise_2d(x * 0.4 + 600, z * 0.4) * 21.0
	return lerpf(world.ground(x, z), hills, blend)

static func dress(world: Node3D, seed_value: int, terrain_mat: Material) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.016
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-220, 220, 4):
		for x in range(-220, 220, 4):
			if x >= -40 and x < 40 and z >= -40 and z < 40: continue
			var vertices: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				vertices.append(Vector3(x + offset.x, distant_height(world, noise, x + offset.x, z + offset.y), z + offset.y))
			Art.face(st, vertices)
	var apron := Art.mesh(world, st.commit(), Vector3.ZERO, terrain_mat)
	apron.name = "GeologicalApron"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 81
	# Eight silhouettes, instanced as weathered shelves and loose stones in one draw each.
	for variant in range(8):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = rock(seed_value + variant * 61)
		multimesh.instance_count = 140
		for i in range(140):
			var x: float = rng.randf_range(-145, 145)
			var z: float = rng.randf_range(-145, 145)
			var inside: bool = absf(x) < 39 and absf(z) < 39
			var y: float = world.ground(x, z) if inside else distant_height(world, noise, x, z)
			var scale_value: float = rng.randf_range(0.14, 0.7) if inside else rng.randf_range(1.0, 6.0)
			# Small debris stays outside the central build footprint of each cell.
			if inside:
				x = floor(x / 4) * 4 + rng.randf_range(0.1, 0.5)
				z = floor(z / 4) * 4 + rng.randf_range(0.1, 0.5)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale_value, scale_value * rng.randf_range(0.35, 0.75), scale_value * 1.35))
			multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y - 0.07, z)))
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = terrain_mat
		world.add_child(batch)
	# The cells already marked unbuildable get a distinct outcrop silhouette.
	for cell in world.snapshot.cells:
		if not cell.buildable:
			var node := Art.mesh(world, rock(seed_value + int(cell.x) * 13 + int(cell.z)), world.cell_position(cell.x, cell.z), terrain_mat)
			node.scale = Vector3(1.6, 1.7, 1.45)
