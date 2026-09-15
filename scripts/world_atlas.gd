extends RefCounted
## Stable addresses. No scene nodes, camera state or frame time enter world generation.
## Catalogue fields are synthetic; circular coplanar orbit fits use AU and years.
const CELL_LY := 12.0
const GALAXY_RADIUS_LY := 50000.0
const DEFAULT_REGION := Vector2i(40, 18)
const REGION_GRID := Vector2i(72, 36)

static func address(body: String, region: Vector2i) -> String:
	return body if region == DEFAULT_REGION else "%s@%d,%d" % [body, region.x, region.y]

static func parse_address(value: String) -> Dictionary:
	var parts := value.split("@")
	if parts.size() == 1: return {"body": value, "region": DEFAULT_REGION}
	if parts.size() != 2: return {}
	var xy := parts[1].split(",")
	if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int(): return {}
	var region := Vector2i(int(xy[0]), int(xy[1]))
	if region.x < 0 or region.x >= REGION_GRID.x or region.y < 0 or region.y >= REGION_GRID.y: return {}
	if address(parts[0], region) != value: return {}
	return {"body": parts[0], "region": region}

static func coordinates(region: Vector2i) -> Vector2:
	return Vector2((region.x + 0.5) * 5.0 - 180.0, 90.0 - (region.y + 0.5) * 5.0)

static func region_label(region: Vector2i) -> String:
	var point := coordinates(region)
	return "%.1f°%s · %.1f°%s" % [absf(point.y), "N" if point.y >= 0 else "S", absf(point.x), "E" if point.x >= 0 else "W"]

static func region_context(base: Dictionary, body: String, region: Vector2i) -> Dictionary:
	var context := base.duplicate(true)
	if region == DEFAULT_REGION: return context
	var source_seed: int = int(context.get("seed", 1701))
	var rng := RandomNumberGenerator.new()
	rng.seed = source_seed * 100003 + region.y * 72 + region.x + 19
	context.seed = rng.randi_range(1, 999999)
	var latitude := deg_to_rad(coordinates(region).y)
	# Screening priors: annual-mean latitude proxy, not a resolved weather model.
	context.solar_factor = float(base.get("solar_factor", 1.0)) * (0.18 + 0.82 * cos(latitude))
	context.ore_factor = float(base.get("ore_factor", 1.0)) * rng.randf_range(0.35, 1.8)
	context.ice_factor = float(base.get("ice_factor", 1.0)) * (0.45 + absf(sin(latitude)) * 1.5) * rng.randf_range(0.6, 1.4)
	context["body"] = body
	return context

static func orbit(body: Dictionary, evidence: Dictionary = {}) -> Dictionary:
	var id: String = body.id
	var parent: String = body.system
	var au := 1.15
	var period := 1.3
	if id == "nacre": parent = "eir_iii"; au = 0.00257; period = 0.075
	elif id == "vesper_b": parent = "vesper_a"; au = 0.0041; period = 0.13
	elif id == "eir_ii": au = 0.55; period = 0.408
	elif id == "eir_iv": au = 2.8; period = 4.685
	elif id == "vesper_a": au = 5.5; period = 15.5
	elif body.get("generated", false):
		au = (float(evidence.get("orbit_low", 0.6)) + float(evidence.get("orbit_high", 1.4))) * 0.5
		if id.ends_with("_c"): parent = body.system + "_b"; au = 0.0025; period = 0.07
		elif id.ends_with("_d"): au *= 2.4
		if not id.ends_with("_c"):
			var mass := 0.35 if evidence.get("type") == "M V" else (0.75 if evidence.get("type") == "K V" else 1.0)
			period = sqrt(au * au * au / mass)
	return {"parent": parent, "au": au, "period_years": period, "phase": fmod(float(body.seed) * 2.399963, TAU)}

static func extra_reference_bodies() -> Array:
	var result: Array = []
	for spec in [["eir_ii", "eir", "Eir II", 390.0, 89.0], ["eir_iv", "eir", "Eir IV", 150.0, 113.0], ["vesper_a", "vesper", "Vesper A", 105.0, 141.0]]:
		result.append({"id": spec[0], "system": spec[1], "name": spec[2], "kind": "world", "description": "A neighbouring world. Local reconnaissance is required before choosing a surface site.", "baseline": spec[3], "temperature": spec[3], "deposit": 220.0, "seed": spec[4], "spatial": true})
	return result
