class_name ResearchCost
extends RefCounted

const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const COST_EXPONENT := 1.7


static func total(tower_id: String, params: Dictionary) -> float:
	var sum := 0.0
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		var value := float(params.get(sid, spec["base"]))
		sum += stat_cost(spec, value)
	return sum


## Player-facing integer total used for spend/refund (curve stays float underneath).
static func total_int(tower_id: String, params: Dictionary) -> int:
	return roundi(total(tower_id, params))


static func stat_cost(spec: Dictionary, value: float) -> float:
	var n := normalized_upgrade(spec, value)
	if n <= 0.0:
		return 0.0
	return float(spec["max_cost"]) * pow(n, COST_EXPONENT)


static func normalized_upgrade(spec: Dictionary, value: float) -> float:
	var base := float(spec["base"])
	var min_v := float(spec["min"])
	var max_v := float(spec["max"])
	var direction := str(spec.get("direction", "higher"))
	value = clampf(value, min_v, max_v)
	if direction == "lower":
		if base <= min_v:
			return 0.0
		# Improvement only when value is below base (faster / shorter).
		if value >= base:
			return 0.0
		return clampf((base - value) / (base - min_v), 0.0, 1.0)
	# higher
	if max_v <= base:
		return 0.0
	if value <= base:
		return 0.0
	return clampf((value - base) / (max_v - base), 0.0, 1.0)


static func clamp_params(tower_id: String, params: Dictionary) -> Dictionary:
	var out := ResearchConfigScript.base_params(tower_id)
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		if params.has(sid):
			out[sid] = clampf(float(params[sid]), float(spec["min"]), float(spec["max"]))
	return out
