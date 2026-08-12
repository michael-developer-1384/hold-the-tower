class_name ResearchResolver
extends RefCounted

const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")

const VALUE_EXPONENT := 0.70


static func value_for(spec: Dictionary, invested_rp: int) -> float:
	var base := float(spec["base"])
	var best := float(spec["best"])
	var max_rp := maxi(1, int(spec["max_investment_rp"]))
	var invested := clampi(invested_rp, 0, max_rp)
	var progress := float(invested) / float(max_rp)
	var value_progress := pow(progress, VALUE_EXPONENT)
	return lerpf(base, best, value_progress)


static func params_from_allocations(tower_id: String, allocations: Dictionary) -> Dictionary:
	var out := ResearchConfigScript.base_params(tower_id)
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		var invested := int(allocations.get(sid, 0))
		out[sid] = value_for(spec, invested)
	return out


static func total_invested(allocations: Dictionary) -> int:
	var sum := 0
	for k in allocations.keys():
		sum += maxi(0, int(allocations[k]))
	return sum


static func level_cap_for_stat(spec: Dictionary, player_level: int) -> int:
	return ProgressionConfigScript.investment_cap_rp(int(spec["max_investment_rp"]), player_level)


static func clamp_allocations(tower_id: String, allocations: Dictionary, player_level: int) -> Dictionary:
	var out := ResearchConfigScript.zero_allocations(tower_id)
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		var cap := level_cap_for_stat(spec, player_level)
		out[sid] = clampi(int(allocations.get(sid, 0)), 0, cap)
	return out


static func normalize_allocations(tower_id: String, allocations: Dictionary) -> Dictionary:
	var out := ResearchConfigScript.zero_allocations(tower_id)
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		var max_rp := int(spec["max_investment_rp"])
		out[sid] = clampi(int(allocations.get(sid, 0)), 0, max_rp)
	return out


## Invert float params onto the investment curve (migration). Values worse than base → 0 RP.
static func allocations_from_params(tower_id: String, params: Dictionary) -> Dictionary:
	var out := ResearchConfigScript.zero_allocations(tower_id)
	var inv_exp := 1.0 / VALUE_EXPONENT
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		var base := float(spec["base"])
		var best := float(spec["best"])
		var max_rp := int(spec["max_investment_rp"])
		var value := float(params.get(sid, base))
		var t := 0.0
		if str(spec.get("direction", "higher")) == "lower":
			if best < base and value < base:
				t = clampf((base - value) / (base - best), 0.0, 1.0)
		else:
			if best > base and value > base:
				t = clampf((value - base) / (best - base), 0.0, 1.0)
		out[sid] = clampi(roundi(float(max_rp) * pow(t, inv_exp)), 0, max_rp)
	return out


static func level_unlock_for_investment(spec: Dictionary, target_rp: int) -> int:
	var max_rp := int(spec["max_investment_rp"])
	var need := clampi(target_rp, 0, max_rp)
	for level in range(1, ProgressionConfigScript.max_level() + 1):
		if level_cap_for_stat(spec, level) >= need:
			return level
	return ProgressionConfigScript.max_level()


static func allocations_equal(a: Dictionary, b: Dictionary, tower_id: String) -> bool:
	var ca := normalize_allocations(tower_id, a)
	var cb := normalize_allocations(tower_id, b)
	for spec in ResearchConfigScript.specs_for(tower_id):
		var sid := str(spec["id"])
		if int(ca.get(sid, 0)) != int(cb.get(sid, 0)):
			return false
	return true


static func format_value(spec: Dictionary, value: float) -> String:
	var fmt := str(spec.get("value_format", "%.2f"))
	return fmt % value
