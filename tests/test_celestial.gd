extends SceneTree
const Session = preload("res://scripts/session.gd")
const Physics = preload("res://scripts/celestial_mechanics.gd")
const Display = preload("res://scripts/display_controls.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; printerr("FAIL: " + message)

func _initialize() -> void:
	var session = Session.new()
	var unchanged: String = session.save_json()
	var planet := Physics.body_position(session, "eir_iii", 0.0)
	var moon := Physics.body_position(session, "nacre", 0.0)
	check(absf(Physics.vector(planet).length() - 1.15) < 0.000001, "Planet is 1.15 AU from its star")
	check(absf(Physics.vector(Physics.subtract(moon, planet)).length() - 0.00257) < 0.00000001, "Moon separation is measured from its parent without enlargement")
	var fit := Physics.orbit(session, "eir_iii")
	check(absf(fit.period_years * fit.period_years - pow(1.15, 3) / (0.9 + Physics.EARTH_SOLAR)) < 1e-12, "Kepler period includes the parent mass")
	var one_year := Physics.body_position(session, "eir_iii", fit.period_years * Physics.YEAR_HOURS)
	check(Physics.vector(Physics.subtract(one_year, planet)).length() < 1e-10, "A full period closes the orbit")
	var half_year := Physics.body_position(session, "eir_iii", fit.period_years * Physics.YEAR_HOURS * 0.5)
	check(Physics.vector(Physics.add(half_year, planet)).length() < 1e-10, "Half a circular orbit reaches the opposite side")
	var reference := Physics.orientation(session, "eir_iii", 0.0)
	check(reference.is_equal_approx(Physics.orientation(session, "eir_iii", 24.0)), "Sidereal rotation closes after the configured day")
	check(not reference.is_equal_approx(Physics.orientation(session, "eir_iii", 6.0)), "Hourly time changes body orientation")
	for hours in [0.0, 123.0, 7319.0]:
		var toward_parent := Physics.vector(Physics.subtract(Physics.body_position(session, "eir_iii", hours), Physics.body_position(session, "nacre", hours))).normalized()
		check((Physics.orientation(session, "nacre", hours) * Vector3.BACK).dot(toward_parent) > 0.99999, "Synchronous moon always presents zero longitude to parent")
	var region := Vector2i(48, 15)
	check(Physics.region_at(Physics.normal(region)) == region, "Geography round-trips through the shared spherical coordinates")
	for sample in [Vector2i(0, 0), Vector2i(71, 35), Vector2i(0, 18), Vector2i(71, 18)]:
		check(Physics.region_at(Physics.normal(sample)) == sample, "Poles and longitude seam retain their cell address")
	var local_sun := Physics.surface_sun(session, "eir_iii", region, 0)
	var world_up := reference * Physics.normal(region)
	check(absf(local_sun.y - world_up.dot(Physics.sun_direction(session, "eir_iii", 0))) < 1e-6, "Surface sun altitude agrees with the orbital terminator")
	check(Physics.surface_sun(session, "eir_iii", region, 0).y * Physics.surface_sun(session, "eir_iii", region, 12).y < 0, "Opposite times of day cross the surface horizon")
	var tiny_offset := Physics.subtract([1.150000000001, 0.0, 0.0], [1.15, 0.0, 0.0])
	check(Physics.vector(tiny_offset, 1e-12).x > 0.999 and Physics.vector(tiny_offset, 1e-12).x < 1.001, "Subtract double coordinates before creating renderer vectors")
	check(Physics.properties(session, "prospect_0_b").estimated, "Unprobed radius is an explicit prior")
	check(not session.prospects.evidence("prospect_0").has("mass_earth"), "Mass does not leak before a local probe")
	check(session.save_json() == unchanged, "All camera ephemeris queries leave authoritative state unchanged")
	var restored = Session.new()
	check(restored.restore_json(unchanged).ok, "Existing saves remain compatible")
	check(Physics.body_position(restored, "nacre", 73210.0) == Physics.body_position(session, "nacre", 73210.0), "Save reload gives the same ephemeris")
	var key := InputEventKey.new(); key.pressed = true; key.keycode = KEY_F; key.ctrl_pressed = true; key.meta_pressed = true
	check(Display.is_shortcut(key), "Control–Command–F is a fullscreen shortcut")
	key.meta_pressed = false
	check(not Display.is_shortcut(key), "Ordinary Control–F is left alone")
	key.ctrl_pressed = false; key.alt_pressed = true; key.keycode = KEY_ENTER
	check(Display.is_shortcut(key), "Option/Alt–Return is a fullscreen shortcut")
	key.echo = true
	check(not Display.is_shortcut(key), "Key repeat does not flicker fullscreen")
	print("Celestial mechanics and display: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
