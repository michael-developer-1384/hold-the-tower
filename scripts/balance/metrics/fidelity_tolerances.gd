extends RefCounted

## Numeric tolerances for simulation-fidelity comparisons.


static func all() -> Dictionary:
	return {
		"spawn_count": {"abs": 0, "rel": 0.0},
		"enemy_path_progress": {"abs": 0.08, "rel": 0.02},
		"damage_dealt": {"abs": 0.75, "rel": 0.01},
		"kills": {"abs": 0, "rel": 0.0},
		"leaks": {"abs": 0, "rel": 0.0},
		"blocking_duration": {"abs": 0.25, "rel": 0.05},
		"projectile_hits": {"abs": 1, "rel": 0.02},
		"cross_floor_hits": {"abs": 0.75, "rel": 0.05},
		"tower_fire_count": {"abs": 1, "rel": 0.02},
		"core_hp": {"abs": 0, "rel": 0.0},
		"economy": {"abs": 0, "rel": 0.0},
		"wave_timing": {"abs": 0.05, "rel": 0.01},
	}


static func within(metric: String, a: Variant, b: Variant) -> bool:
	var spec: Dictionary = all().get(metric, {"abs": 0.01, "rel": 0.01})
	var fa := float(a)
	var fb := float(b)
	var abs_tol := float(spec.get("abs", 0.0))
	var rel_tol := float(spec.get("rel", 0.0))
	var err := absf(fa - fb)
	var denom := maxf(maxf(absf(fa), absf(fb)), 0.0001)
	return err <= abs_tol or (err / denom) <= rel_tol


static func relative_error(a: Variant, b: Variant) -> float:
	var fa := float(a)
	var fb := float(b)
	var denom := maxf(maxf(absf(fa), absf(fb)), 0.0001)
	return absf(fa - fb) / denom
