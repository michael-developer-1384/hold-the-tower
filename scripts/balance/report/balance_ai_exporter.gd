extends RefCounted

## Compact AI export. No time series, no parameter prescriptions.


static func export(report: Dictionary) -> Dictionary:
	var meta: Dictionary = report.get("report_meta", {})
	var melt: Dictionary = report.get("meltdown", {})
	var ramp = melt.get("ramp")
	var melt_out := {
		"parameters": melt.get("parameters", {}),
		"median_value_per_gold": melt.get("median_value_per_gold"),
		"relative_anchor": melt.get("relative_anchor"),
		"best_spot": melt.get("best_spot"),
		"worst_spot": melt.get("worst_spot"),
		"peak_cell_dps": melt.get("peak_cell_dps"),
		"peak_damage_fraction": melt.get("peak_damage_fraction"),
		"active_cells": melt.get("active_cells"),
		"active_damage_cells": melt.get("active_damage_cells"),
		"cross_floor_cells": melt.get("cross_floor_cells"),
		"mass_balance": melt.get("mass_balance"),
		"ramp": ramp,
		"status": melt.get("status"),
	}
	var towers_out := {}
	var towers: Dictionary = report.get("towers", {})
	for tid in towers.keys():
		var row: Dictionary = towers[tid]
		towers_out[tid] = {
			"display_name": row.get("display_name"),
			"cost": row.get("cost"),
			"median_value_per_gold": row.get("median_value_per_gold"),
			"mean_value_per_gold": row.get("mean_value_per_gold"),
			"relative_to_anchor_median": row.get("relative_to_anchor_median"),
			"best_spot": row.get("best_spot"),
			"worst_spot": row.get("worst_spot"),
			"placement_cv": row.get("placement_cv"),
			"placement_classification": row.get("placement_classification"),
			"early_build_multiplier": row.get("early_build_multiplier"),
			"status": row.get("status"),
		}
	return {
		"schema": "hodl_balance_ai_export",
		"schema_version": 1,
		"report_meta": {
			"report_id": meta.get("report_id"),
			"timestamp": meta.get("timestamp"),
			"game_version": meta.get("game_version"),
			"git_commit": meta.get("git_commit"),
			"level_id": meta.get("level_id"),
			"difficulty_id": meta.get("difficulty_id"),
			"seed": meta.get("seed"),
			"parameter_fingerprint": meta.get("parameter_fingerprint"),
			"parameter_overrides": meta.get("parameter_overrides", {}),
			"benchmark": meta.get("benchmark"),
		},
		"designer_summary": report.get("designer_summary", ""),
		"tower_status": report.get("tower_status", {}),
		"anchor": report.get("anchor", {}),
		"towers": towers_out,
		"top_spots": report.get("top_spots", []),
		"bottom_spots": report.get("bottom_spots", []),
		"meltdown": melt_out,
		"full_builds": report.get("full_builds", []),
		"competent_build": report.get("competent_build"),
		"optimizer_build": report.get("optimizer_build"),
		"defense_margin": report.get("defense_margin"),
		"difficulty_frontier": report.get("difficulty_frontier"),
		"counterfactual": _compact_cf(report.get("counterfactual")),
		"shapley": report.get("shapley"),
		"simulation_fidelity": report.get("simulation_fidelity"),
		"parameter_search": _compact_search(report.get("parameter_search")),
		"recommended_balance_changes": report.get("recommended_balance_changes"),
		"warnings": report.get("warnings", []),
		"findings": report.get("findings", []),
		"confidence": report.get("confidence", {}),
		"data_quality": report.get("data_quality", {}),
		"recommended_next_analysis": report.get("recommended_next_analysis", []),
		"previous_delta": report.get("previous_delta"),
		"combat_values_unchanged": true,
	}


static func _compact_cf(cf: Variant) -> Variant:
	if cf == null or typeof(cf) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = cf
	if d.is_empty():
		return null
	return {
		"spot_id": d.get("spot_id"),
		"delta": d.get("delta"),
		"other_actions_unchanged": d.get("other_actions_unchanged"),
		"by_tower": d.get("by_tower"),
		"spot_count": d.get("spot_count"),
	}


static func _compact_search(search: Variant) -> Variant:
	if search == null or typeof(search) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = search
	return {
		"candidate_count": d.get("candidate_count"),
		"evaluation_count": d.get("evaluation_count"),
		"top_candidates": d.get("top_candidates"),
		"recommended_candidate": d.get("recommended_candidate"),
		"applied": d.get("applied", false),
	}
