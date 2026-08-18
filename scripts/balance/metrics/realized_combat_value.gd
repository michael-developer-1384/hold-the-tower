extends RefCounted

## Single realized combat-value function. Only measured counterfactual deltas count.


const Targets := preload("res://scripts/balance/balance_targets.gd")


static func weights() -> Dictionary:
	return Targets.combat_value_weights()


static func evaluate(metrics: Dictionary) -> Dictionary:
	var w: Dictionary = weights()
	var direct := float(metrics.get("direct_damage", 0.0)) * float(w.get("direct_damage", 1.0))
	var indirect := float(metrics.get("damage_enabled_for_other_towers", 0.0)) * float(w.get("indirect_damage", 1.0))
	var leaks := float(metrics.get("leaks_prevented", 0.0)) * float(w.get("leak_prevention", 0.0))
	var core := float(metrics.get("core_hp_preserved", 0.0)) * float(w.get("core_hp_preservation", 0.0))
	var other := float(metrics.get("other_measured_utility", 0.0)) * float(w.get("other_utility", 1.0))
	var total := direct + indirect + leaks + core + other
	var cost := maxf(float(metrics.get("cost", 1.0)), 1.0)
	return {
		"direct_damage_value": direct,
		"indirect_damage_value": indirect,
		"leak_prevention_value": leaks,
		"core_hp_preservation_value": core,
		"other_measured_utility": other,
		"combat_value": total,
		"value_per_gold": total / cost,
		"weights": w,
	}
