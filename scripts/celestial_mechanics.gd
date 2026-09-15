extends RefCounted
## Double-precision scalar coordinates in AU, relative to a stellar origin.
## Circular two-body ephemerides; no perturbations or invented remote measurements.
const Atlas = preload("res://scripts/world_atlas.gd")
const AU_KM := 149597870.7
const LY_AU := 63241.0770842663
const EARTH_SOLAR := 3.0034896e-6
const YEAR_HOURS := 8766.0
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/celestial.json"))

static func star(session: RefCounted, id: String) -> Dictionary:
	if CONFIG.stars.has(id): return CONFIG.stars[id]
	var evidence: Dictionary = session.prospects.evidence(id)
	return CONFIG.stellar_priors.get(evidence.get("type", "G V"), CONFIG.stellar_priors["G V"])

static func properties(session: RefCounted, id: String) -> Dictionary:
	if CONFIG.bodies.has(id): return CONFIG.bodies[id].duplicate(true)
	var body: Dictionary = session.expedition.state.bodies[id]
	var result: Dictionary = CONFIG.unmeasured_moon.duplicate(true) if body.kind == "moon" else CONFIG.unmeasured_planet.duplicate(true)
	result.estimated = true
	var evidence: Dictionary = session.prospects.body_evidence(id)
	if body.kind != "moon" and evidence.has("radius_earth"):
		result.radius_km = evidence.radius_earth * 6371.0
		result.mass_earth = evidence.mass_earth
		result.locked = evidence.locked
		result.estimated = false
	return result

static func orbit(session: RefCounted, id: String) -> Dictionary:
	var body: Dictionary = session.expedition.state.bodies[id]
	var result := Atlas.orbit(body, session.prospects.evidence(body.system))
	var central_mass: float = star(session, body.system).mass_solar if result.parent == body.system else properties(session, result.parent).mass_earth * EARTH_SOLAR
	result.period_years = sqrt(pow(result.au, 3.0) / (central_mass + properties(session, id).mass_earth * EARTH_SOLAR))
	return result

static func add(a: Array, b: Array) -> Array:
	return [float(a[0]) + b[0], float(a[1]) + b[1], float(a[2]) + b[2]]

static func subtract(a: Array, b: Array) -> Array:
	return [float(a[0]) - b[0], float(a[1]) - b[1], float(a[2]) - b[2]]

static func mix_position(a: Array, b: Array, weight: float) -> Array:
	return [lerpf(a[0], b[0], weight), lerpf(a[1], b[1], weight), lerpf(a[2], b[2], weight)]

static func vector(a: Array, divisor: float = 1.0) -> Vector3:
	return Vector3(a[0] / divisor, a[1] / divisor, a[2] / divisor)

static func body_position(session: RefCounted, id: String, hours: float) -> Array:
	var body: Dictionary = session.expedition.state.bodies[id]
	var fit := orbit(session, id)
	var angle: float = fit.phase + fmod(hours / YEAR_HOURS, fit.period_years) / fit.period_years * TAU
	var point := [cos(angle) * fit.au, 0.0, sin(angle) * fit.au]
	return point if fit.parent == body.system else add(body_position(session, fit.parent, hours), point)

static func normal(region: Vector2i) -> Vector3:
	var geo := Atlas.coordinates(region)
	var lon := deg_to_rad(geo.x)
	var lat := deg_to_rad(geo.y)
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))

static func region_at(normal_value: Vector3) -> Vector2i:
	var n := normal_value.normalized()
	return Vector2i(posmod(int(floor((rad_to_deg(atan2(n.x, n.z)) + 180.0) / 5.0)), 72), clampi(int(floor((90.0 - rad_to_deg(asin(clampf(n.y, -1, 1)))) / 5.0)), 0, 35))

static func orientation(session: RefCounted, id: String, hours: float) -> Basis:
	var data := properties(session, id)
	var spin: float = deg_to_rad(data.get("prime_deg", 0.0)) + fmod(hours, data.get("day_hours", 24.0)) / data.get("day_hours", 24.0) * TAU
	if data.get("locked", false):
		var fit := orbit(session, id)
		# Zero longitude faces the parent; a circular synchronously rotating body.
		spin = -fit.phase - fmod(hours / YEAR_HOURS, fit.period_years) / fit.period_years * TAU - PI / 2.0
	return Basis(Vector3.BACK, deg_to_rad(data.get("tilt_deg", 0.0))) * Basis(Vector3.UP, spin)

static func sun_direction(session: RefCounted, id: String, hours: float) -> Vector3:
	return -vector(body_position(session, id, hours)).normalized()

static func surface_sun(session: RefCounted, id: String, region: Vector2i, hours: float) -> Vector3:
	var local_sun := orientation(session, id, hours).inverse() * sun_direction(session, id, hours)
	var up := normal(region)
	var east := Vector3(up.z, 0, -up.x).normalized()
	var north := up.cross(east).normalized()
	# Surface +x east, +y up, -z north.
	return Vector3(local_sun.dot(east), local_sun.dot(up), -local_sun.dot(north)).normalized()

static func distance_text(au: float) -> String:
	if au >= LY_AU * 0.1: return "%.2f ly" % (au / LY_AU)
	if au >= 0.01: return "%.3f AU" % au
	return "%.0f km" % (au * AU_KM)
