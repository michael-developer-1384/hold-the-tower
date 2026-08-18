class_name LavaConfig
extends RefCounted

## Named lava mass scales. Defaults match the historic 0–100 cell.

const CELL_MASS_CAPACITY := 100.0
const DAMAGE_FULL_MASS := 36.0
const DAMAGE_THRESHOLD_MASS := 2.0
const FLOW_START_MASS := 14.0
const DEFAULT_DAMAGE := 10.0
const DEFAULT_FLOW := 0.45
const DEFAULT_LIFETIME := 16.0


static func defaults() -> Dictionary:
	return {
		"cell_mass_capacity": CELL_MASS_CAPACITY,
		"damage_full_mass": DAMAGE_FULL_MASS,
		"damage_threshold_mass": DAMAGE_THRESHOLD_MASS,
		"flow_start_mass": FLOW_START_MASS,
		"lava_damage": DEFAULT_DAMAGE,
		"flow_rate": DEFAULT_FLOW,
		"lava_lifetime": DEFAULT_LIFETIME,
	}


static func resolve(stats: Dictionary = {}, cell: Dictionary = {}) -> Dictionary:
	var base := defaults()
	var src := stats if not stats.is_empty() else {}
	for key in [
		"cell_mass_capacity", "damage_full_mass", "damage_threshold_mass", "flow_start_mass",
		"lava_damage", "flow_rate", "lava_lifetime",
	]:
		if src.has(key):
			base[key] = float(src[key])
		elif not cell.is_empty() and cell.has(key):
			base[key] = float(cell[key])
	if src.has("lava_damage"):
		base["lava_damage"] = float(src["lava_damage"])
	elif cell.has("damage"):
		base["lava_damage"] = float(cell["damage"])
	if src.has("flow_rate"):
		base["flow_rate"] = float(src["flow_rate"])
	elif cell.has("flow_rate"):
		base["flow_rate"] = float(cell["flow_rate"])
	if src.has("lava_lifetime"):
		base["lava_lifetime"] = float(src["lava_lifetime"])
	elif cell.has("lifetime"):
		base["lava_lifetime"] = float(cell["lifetime"])
	base["cell_mass_capacity"] = maxf(float(base["cell_mass_capacity"]), 0.0001)
	base["damage_full_mass"] = maxf(float(base["damage_full_mass"]), 0.0001)
	base["damage_threshold_mass"] = maxf(float(base["damage_threshold_mass"]), 0.0)
	base["flow_start_mass"] = maxf(float(base["flow_start_mass"]), 0.0)
	return apply_sim_overrides(base)


static func apply_sim_overrides(base: Dictionary) -> Dictionary:
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	for key in [
		"cell_mass_capacity", "damage_full_mass", "damage_threshold_mass", "flow_start_mass",
		"lava_damage", "flow_rate", "lava_lifetime", "pour_rate",
	]:
		var ov = SimContextScript.get_override("lava_tower." + key, null)
		if ov != null:
			base[key] = float(ov)
	return base


static func override_float(key: String, current: float) -> float:
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	var ov = SimContextScript.get_override("lava_tower." + key, null)
	if ov != null:
		return float(ov)
	return current


static func fill_for_damage(mass: float, params: Dictionary) -> float:
	if mass < float(params.get("damage_threshold_mass", DAMAGE_THRESHOLD_MASS)):
		return 0.0
	return clampf(mass / float(params.get("damage_full_mass", DAMAGE_FULL_MASS)), 0.0, 1.0)


static func cell_dps(mass: float, lava_damage: float, params: Dictionary) -> float:
	return lava_damage * fill_for_damage(mass, params)
