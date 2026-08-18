extends RefCounted

## Canonical 0.19.0 report. Presentation layers must not recompute statuses.

const Status := preload("res://scripts/balance/report/balance_status.gd")
const Fingerprint := preload("res://scripts/balance/report/balance_fingerprint.gd")
const Targets := preload("res://scripts/balance/balance_targets.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const LavaConfigScript := preload("res://scripts/world/lava_config.gd")
const Pressure := preload("res://scripts/balance/difficulty_pressure_model.gd")


static func null_time(v: Variant) -> Variant:
	if v == null:
		return null
	var t := float(v)
	if t < 0.0:
		return null
	return t


static func _as_dict(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return v as Dictionary
	return {}


static func compact_placement(row: Dictionary) -> Dictionary:
	return {
		"tower_id": str(row.get("tower_id", "")),
		"spot_id": str(row.get("spot_id", "")),
		"floor_id": str(row.get("floor_id", "")),
		"build_wave": int(row.get("build_wave", 1)),
		"cost": float(row.get("cost", 0.0)),
		"value_per_gold": float(row.get("value_per_gold", 0.0)),
		"actual_damage": float(row.get("actual_damage", 0.0)),
		"hp_removed_fraction": float(row.get("hp_removed_fraction", 0.0)),
		"exposure_seconds": float(row.get("exposure_seconds", 0.0)),
		"block_seconds": float(row.get("block_seconds", 0.0)),
		"cross_floor_damage": float(row.get("cross_floor_damage", 0.0)),
		"kills": int(row.get("kills", 0)),
		"leaks": int(row.get("leaks", 0)),
		"core_hp": int(row.get("core_hp", 0)),
	}


static func build(parts: Dictionary, meta: Dictionary = {}) -> Dictionary:
	var matrix: Dictionary = _as_dict(parts.get("matrix", {}))
	var by_tower: Dictionary = _as_dict(matrix.get("by_tower", {}))
	var rows: Array = []
	if typeof(matrix.get("rows")) == TYPE_ARRAY:
		rows = matrix["rows"] as Array
	var sentry_med := float(by_tower.get("basic_tower", {}).get("median", 0.0))
	var guard_med := float(by_tower.get("guard_post", {}).get("median", 0.0))
	var has_anchor := by_tower.has("basic_tower") and by_tower.has("guard_post")
	var anchor := (sentry_med + guard_med) * 0.5 if has_anchor else 0.0
	var placements: Array = []
	for row in rows:
		placements.append(compact_placement(row))
	var timing: Dictionary = _as_dict(parts.get("early_build", {}))
	var towers := {}
	var eff := {}
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var st: Dictionary = _as_dict(by_tower.get(tid, {}))
		var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tid)
		var med := float(st.get("median", 0.0)) if not st.is_empty() else 0.0
		var rel: Variant = null
		if has_anchor and not st.is_empty():
			rel = med / maxf(anchor, 0.0001)
		var trow: Dictionary = _as_dict(timing.get(tid, {}))
		var by_wave: Dictionary = _as_dict(trow.get("by_wave", {}))
		var late: Variant = by_wave.get(5, by_wave.get("5", null))
		var status := Status.tower_status(tid, rel)
		var display: String = str(def.display_name) if def else tid
		var cost: float = float(def.cost) if def else 0.0
		towers[tid] = {
			"tower_id": tid,
			"display_name": display,
			"role": str(def.role) if def else "",
			"cost": cost,
			"median_value_per_gold": med if not st.is_empty() else null,
			"mean_value_per_gold": st.get("mean") if not st.is_empty() else null,
			"min_value_per_gold": st.get("min") if not st.is_empty() else null,
			"max_value_per_gold": st.get("max") if not st.is_empty() else null,
			"p25": st.get("p25") if not st.is_empty() else null,
			"p75": st.get("p75") if not st.is_empty() else null,
			"relative_to_anchor_median": rel,
			"best_spot": st.get("best_spot") if not st.is_empty() else null,
			"worst_spot": st.get("worst_spot") if not st.is_empty() else null,
			"placement_cv": st.get("cv") if not st.is_empty() else null,
			"placement_classification": st.get("placement_sensitivity_band") if not st.is_empty() else null,
			"early_build_multiplier": trow.get("early_build_multiplier") if not trow.is_empty() else null,
			"late_value_per_gold": late,
			"status": status,
			"status_label": Status.display_status(status),
		}
		eff[tid] = {
			"value_per_gold": med,
			"relative_to_anchor_median": rel if rel != null else 0.0,
			"role": str(def.role) if def else "",
			"display_name": display,
		}
	var melt_raw: Dictionary = _as_dict(parts.get("meltdown_ramp", {}))
	var lava_dmg := float(LavaConfigScript.DEFAULT_DAMAGE)
	var peak := float(melt_raw.get("peak_cell_dps", 0.0))
	var peak_frac: Variant = null
	if not melt_raw.is_empty():
		peak_frac = peak / maxf(lava_dmg, 0.0001)
	var t25: Variant = null
	var t50: Variant = null
	var t90: Variant = null
	var tfirst: Variant = null
	if not melt_raw.is_empty():
		t25 = null_time(melt_raw.get("t_25_percent_damage", -1.0))
		t50 = null_time(melt_raw.get("t_50_percent_damage", -1.0))
		t90 = null_time(melt_raw.get("t_90_percent_damage", -1.0))
		tfirst = null_time(melt_raw.get("t_first_damage", -1.0))
	var emitted := float(melt_raw.get("emitted_mass", 0.0))
	var landed := float(melt_raw.get("landed_mass", 0.0))
	var series: Array = []
	if melt_raw.has("series") and typeof(melt_raw.get("series")) == TYPE_ARRAY:
		series = melt_raw["series"] as Array
	var melt := {
		"parameters": _meltdown_params(_as_dict(meta.get("parameter_overrides", {}))),
		"median_value_per_gold": towers.get("lava_tower", {}).get("median_value_per_gold"),
		"relative_anchor": towers.get("lava_tower", {}).get("relative_to_anchor_median"),
		"best_spot": towers.get("lava_tower", {}).get("best_spot"),
		"worst_spot": towers.get("lava_tower", {}).get("worst_spot"),
		"peak_cell_dps": peak if not melt_raw.is_empty() else null,
		"peak_damage_fraction": peak_frac,
		"active_cells": melt_raw.get("active_cells") if not melt_raw.is_empty() else null,
		"active_damage_cells": melt_raw.get("active_damage_cells") if not melt_raw.is_empty() else null,
		"cross_floor_cells": melt_raw.get("cross_floor_cells") if not melt_raw.is_empty() else null,
		"mass_balance": {
			"emitted": emitted,
			"landed": landed,
			"same_floor": float(melt_raw.get("same_floor_mass", 0.0)),
			"cross_floor": float(melt_raw.get("cross_floor_mass", 0.0)),
			"decayed": float(melt_raw.get("decayed_mass", 0.0)),
			"void_lost": float(melt_raw.get("void_lost_mass", 0.0)),
			"active": float(melt_raw.get("total_lava_mass", 0.0)),
			"void_loss_fraction": float(melt_raw.get("void_lost_mass", 0.0)) / maxf(emitted, 0.0001),
			"decay_fraction": float(melt_raw.get("decayed_mass", 0.0)) / maxf(emitted, 0.0001),
		} if not melt_raw.is_empty() else null,
		"ramp": {
			"t_first_damage": tfirst,
			"t_25": t25,
			"t_50": t50,
			"t_90": t90,
			"t_25_reached": t25 != null,
			"t_50_reached": t50 != null,
			"t_90_reached": t90 != null,
		} if not melt_raw.is_empty() else null,
		"series": series,
		"status": str(towers.get("lava_tower", {}).get("status", Status.NOT_MEASURED)),
	}
	var cf_raw = parts.get("counterfactual", null)
	var syn_raw = parts.get("synergy", null)
	var sh_raw = parts.get("shapley", null)
	var has_cf := typeof(cf_raw) == TYPE_DICTIONARY and not (cf_raw as Dictionary).is_empty()
	var has_sh := typeof(sh_raw) == TYPE_DICTIONARY and not bool((sh_raw as Dictionary).get("skipped", false))
	var full_builds: Array = []
	if typeof(parts.get("full_builds")) == TYPE_ARRAY:
		full_builds = parts["full_builds"] as Array
	var has_fb := full_builds.size() > 0
	var competent = parts.get("competent_build", null)
	var optimizer = parts.get("optimizer_build", null)
	var fid_raw = parts.get("simulation_fidelity", null)
	var fid_status := ""
	if typeof(fid_raw) == TYPE_DICTIONARY:
		fid_status = str(fid_raw.get("status", ""))
	var pressure: Dictionary = _as_dict(parts.get("level_pressure", Pressure.report(str(meta.get("difficulty_id", "normal")))))
	var warn_ctx := {
		"towers": towers,
		"meltdown": melt,
		"level": pressure,
		"counterfactual": cf_raw if has_cf else null,
		"has_full_build": has_fb,
	}
	var warnings: Array = Status.warnings(warn_ctx)
	var overrides: Dictionary = _as_dict(meta.get("parameter_overrides", {}))
	var seed := int(meta.get("seed", 7))
	var report_id := "bal_%s_%d" % [Time.get_datetime_string_from_system(true, true).replace(":", ""), seed]
	var git := Fingerprint.git_commit()
	var fp := Fingerprint.compute(overrides)
	var confidence := _confidence(has_cf, has_fb, has_sh, fid_status, parts)
	var designer := _designer_summary(towers, melt, has_fb, sentry_med, guard_med, anchor, parts)
	var sorted := placements.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("value_per_gold", 0.0)) > float(b.get("value_per_gold", 0.0)))
	var top: Array = []
	var bottom: Array = []
	for i in mini(5, sorted.size()):
		top.append(sorted[i])
	for j in mini(5, sorted.size()):
		bottom.append(sorted[sorted.size() - 1 - j])
	var diff_status := Status.difficulty_status({
		"has_full_build": has_fb,
		"fidelity_status": fid_status,
		"defense_margin": parts.get("defense_margin"),
		"competent_build": competent,
		"optimizer_build": optimizer,
	})
	var replay_fid := "PASS" if bool(parts.get("replay_fidelity_pass", false)) else str(parts.get("replay_fidelity", "NOT_MEASURED"))
	var sim_fid := fid_status if fid_status != "" else "NOT_MEASURED"
	return {
		"schema_version": "0.19.0",
		"version": "0.19.0",
		"title": "Deterministic Balancing Lab",
		"report_meta": {
			"report_id": report_id,
			"timestamp": Time.get_datetime_string_from_system(true, true),
			"game_version": str(meta.get("game_version", "0.19.0")),
			"git_commit": git,
			"level_id": str(meta.get("level_id", "vertical_test")),
			"difficulty_id": str(meta.get("difficulty_id", "normal")),
			"seed": seed,
			"sim_mode": str(meta.get("sim_mode", "headless")),
			"simulation_mode": str(meta.get("sim_mode", "headless")),
			"research_profile": "base_catalog",
			"parameter_fingerprint": fp,
			"parameter_overrides": overrides,
			"benchmark": str(meta.get("benchmark", "isolated_matrix+timing+ramp")),
			"agent_configuration": meta.get("agent_configuration", {}),
			"search_configuration": meta.get("search_configuration", {}),
			"schema_version": "0.19.0",
		},
		"designer_summary": designer,
		"tower_status": {
			"basic_tower": str(towers.get("basic_tower", {}).get("status", Status.NOT_MEASURED)),
			"guard_post": str(towers.get("guard_post", {}).get("status", Status.NOT_MEASURED)),
			"lava_tower": str(towers.get("lava_tower", {}).get("status", Status.NOT_MEASURED)),
			"difficulty": diff_status,
		},
		"level": pressure,
		"difficulty": {
			"components": pressure.get("components", {}),
			"status": diff_status,
			"status_label": Status.display_status(diff_status),
		},
		"anchor": {
			"definition": "mean(sentry_median_value_per_gold, guard_median_value_per_gold)",
			"value_per_gold": anchor if has_anchor else null,
		},
		"towers": towers,
		"placements": placements,
		"build_timing": timing,
		"meltdown": melt,
		"full_builds": full_builds,
		"competent_build": competent,
		"optimizer_build": optimizer,
		"defense_margin": parts.get("defense_margin", null),
		"difficulty_frontier": parts.get("difficulty_frontier", null),
		"counterfactual": cf_raw if has_cf else null,
		"synergy": syn_raw if typeof(syn_raw) == TYPE_DICTIONARY and not (syn_raw as Dictionary).is_empty() else null,
		"shapley": sh_raw if has_sh else null,
		"simulation_fidelity": fid_raw if typeof(fid_raw) == TYPE_DICTIONARY else null,
		"parameter_search": parts.get("parameter_search", null),
		"recommended_balance_changes": parts.get("recommended_balance_changes", null),
		"warnings": warnings,
		"findings": Status.findings(warnings),
		"data_quality": {
			"isolated_matrix": not placements.is_empty(),
			"build_timing": not timing.is_empty(),
			"meltdown_ramp": not melt_raw.is_empty(),
			"counterfactual": has_cf,
			"shapley": has_sh,
			"full_build": has_fb,
			"defense_margin": parts.get("defense_margin") != null,
			"difficulty_frontier": parts.get("difficulty_frontier") != null,
			"replay_fidelity": replay_fid,
			"sim_fidelity": sim_fid,
		},
		"confidence": confidence,
		"recommended_next_analysis": _next_steps(has_cf, has_fb, str(towers.get("lava_tower", {}).get("status", ""))),
		"previous_delta": parts.get("previous_delta", null),
		"targets": Targets.all(),
		"level_pressure": pressure,
		"economic_efficiency": eff,
		"anchor_median_value_per_gold": anchor,
		"anchor_formula": "mean(sentry_median_value_per_gold, guard_median_value_per_gold)",
		"placement_sensitivity": by_tower,
		"placement_sensitivity_formula": "coefficient of variation = stdev / mean of isolated value_per_gold across spots",
		"early_build": timing,
		"matrix": {"build_wave": matrix.get("build_wave", 1), "by_tower": by_tower, "rows": placements},
		"top_spots": top,
		"bottom_spots": bottom,
		"meltdown_ramp": melt,
		"design_targets": Targets.all(),
	}


static func _meltdown_params(overrides: Dictionary) -> Dictionary:
	var p: Dictionary = LavaConfigScript.defaults()
	var ResearchConfigScript = load("res://scripts/meta/research_config.gd")
	var base: Dictionary = ResearchConfigScript.base_params("lava_tower")
	for k in base.keys():
		p[k] = base[k]
	for k in overrides.keys():
		var key := str(k).trim_prefix("lava_tower.")
		if p.has(key) or key in ["pour_rate", "lava_damage", "flow_rate", "lava_lifetime"]:
			p[key] = overrides[k]
	return p


static func _confidence(has_cf: bool, has_fb: bool, has_sh: bool, fid_status: String, _parts: Dictionary) -> Dictionary:
	var guard_level := "NOT_MEASURED"
	var guard_reason := "Counterfactual analysis missing."
	if has_cf:
		guard_level = "HIGH" if has_sh else "MEDIUM"
		guard_reason = "Mixed-build counterfactual (and Shapley) measured." if has_sh else "Leave-one-out counterfactual measured; Shapley not run."
	var fid_conf := "HIGH" if fid_status == "PASS" else ("LOW" if fid_status == "FAIL" else "NOT_MEASURED")
	return {
		"sentry_isolated": {"level": "HIGH", "reason": "Isolated tower×spot matrix."},
		"guard_direct": {"level": "HIGH", "reason": "Isolated actual damage."},
		"guard_total_value": {"level": guard_level, "reason": guard_reason},
		"meltdown_underperformance": {"level": "HIGH", "reason": "Isolated actuals and ramp probe agree."},
		"normal_difficulty": {
			"level": "HIGH" if has_fb and fid_status == "PASS" and _parts.get("defense_margin") != null else "LOW",
			"reason": "Competent/optimizer full-build plus margin and fidelity." if has_fb and fid_status == "PASS" else "Full-build, fidelity, or defense margin missing.",
		},
		"shapley": {"level": "HIGH" if has_sh else "NOT_MEASURED", "reason": "Executed." if has_sh else "Not executed."},
		"simulation_fidelity": {"level": fid_conf, "reason": fid_status if fid_status != "" else "Not executed."},
	}


static func _designer_summary(towers: Dictionary, melt: Dictionary, has_fb: bool, sentry_med: float, guard_med: float, _anchor: float, parts: Dictionary = {}) -> String:
	var s: Dictionary = _as_dict(towers.get("basic_tower", {}))
	var g: Dictionary = _as_dict(towers.get("guard_post", {}))
	var m: Dictionary = _as_dict(towers.get("lava_tower", {}))
	var rel_s = s.get("relative_to_anchor_median")
	var rel_g = g.get("relative_to_anchor_median")
	var rel_m = m.get("relative_to_anchor_median")
	var lines: PackedStringArray = PackedStringArray()
	if str(s.get("status", "")) == Status.WITHIN:
		lines.append("Sentry is within its isolated economic target; that reading is HIGH confidence.")
	elif rel_s != null:
		lines.append("Sentry isolated status is %s (relative %.2f)." % [str(s.get("status")), float(rel_s)])
	if str(g.get("status", "")) == Status.WITHIN:
		lines.append("Guard isolated (direct) value is within target; total value including blocking is only HIGH after counterfactual/Shapley.")
	var cf = parts.get("counterfactual")
	if typeof(cf) == TYPE_DICTIONARY and not (cf as Dictionary).is_empty():
		lines.append("Mixed-build counterfactuals were measured, so Guard indirect damage can be discussed.")
	else:
		lines.append("Guard total value still needs mixed-build measurement.")
	if rel_m != null and float(rel_m) < 0.35:
		var frac = melt.get("peak_damage_fraction")
		var pct := 0.0
		if frac != null:
			pct = float(frac) * 100.0
		lines.append("Meltdown underperformance is HIGH confidence: relative %.2f× and peak cell %.1f%% of nominal." % [float(rel_m), pct])
	elif str(m.get("status", "")) == Status.WITHIN:
		lines.append("Meltdown is inside the economic band on this run.")
	var fid = parts.get("simulation_fidelity")
	var fid_ok := typeof(fid) == TYPE_DICTIONARY and str(fid.get("status", "")) == "PASS"
	var competent = parts.get("competent_build")
	var optimizer = parts.get("optimizer_build")
	var margin = parts.get("defense_margin")
	if has_fb and fid_ok and margin != null:
		var cwon := typeof(competent) == TYPE_DICTIONARY and bool(competent.get("won", false))
		var owon := typeof(optimizer) == TYPE_DICTIONARY and bool(optimizer.get("won", false))
		var mv = (margin as Dictionary).get("margin") if typeof(margin) == TYPE_DICTIONARY else null
		lines.append("Normal is classifiable: competent %s, optimizer %s, defense margin %s." % [
			"wins" if cwon else "loses",
			"wins" if owon else "loses",
			str(mv) if mv != null else "NOT_MEASURED",
		])
	else:
		lines.append("Normal difficulty is not yet classifiable; full-build, fidelity, or margin is missing.")
	var rec = parts.get("recommended_balance_changes")
	if rec == null:
		rec = parts.get("parameter_search")
	if typeof(rec) == TYPE_DICTIONARY:
		var cand = rec.get("recommended_candidate", rec)
		if typeof(cand) == TYPE_DICTIONARY and cand.has("parameters"):
			lines.append("Recommended Meltdown parameters: %s (score %.2f). Catalog writes require an explicit apply step." % [
				str(cand.get("parameters")),
				float(cand.get("overall_score", 0.0)),
			])
	return " ".join(lines)


static func _next_steps(has_cf: bool, has_fb: bool, melt_status: String) -> Array:
	var out: Array = []
	if melt_status == Status.SEVERELY:
		out.append("Review recommended Meltdown candidate; apply only via explicit tooling.")
	if not has_cf:
		out.append("Run counterfactual/Shapley on a mixed Sentry+Guard build to quantify Guard indirect value.")
	if not has_fb:
		out.append("Measure a competent/optimizer full-build fixture and defense-margin search on Normal.")
	return out
