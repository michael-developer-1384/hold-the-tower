extends RefCounted

## 0.18.1 report contract tests (A–Q). Invoked from validate_balance.gd.

var failures: Array[String] = []


func run(tree: SceneTree) -> bool:
	var ok := true
	ok = _test_null_ramps() and ok
	ok = _test_missing_cf_not_zero() and ok
	ok = _test_status_and_findings() and ok
	ok = _test_ai_schema_and_no_series() and ok
	ok = _test_json_contains_ai() and ok
	ok = _test_html_contains_sections() and ok
	ok = _test_metrics_vs_report_id() and ok
	ok = _test_comparator_skip() and ok
	ok = (await _test_margin_frontier(tree)) and ok
	return ok and failures.is_empty()


func _fail(msg: String) -> bool:
	failures.append(msg)
	push_error(msg)
	return false


func _parts() -> Dictionary:
	return {
		"level_pressure": {
			"whole_run_pressure_score": 1.0,
			"total_incoming_hp": 9160.0,
			"total_enemy_count": 72,
			"path_travel_time": 29.3,
			"theoretical_minimum_sustained_dps": 110.0,
			"ranged_pressure_factor": 1.0,
			"components": {},
		},
		"matrix": {
			"build_wave": 1,
			"rows": [
				{"tower_id": "basic_tower", "spot_id": "F1_C", "value_per_gold": 14.5, "actual_damage": 1450.0, "cost": 100.0, "hp_removed_fraction": 0.1, "exposure_seconds": 4.0, "block_seconds": 0.0, "cross_floor_damage": 0.0, "kills": 2, "leaks": 10, "core_hp": 10, "floor_id": "floor_1", "build_wave": 1},
				{"tower_id": "basic_tower", "spot_id": "F3_E", "value_per_gold": 9.5, "actual_damage": 950.0, "cost": 100.0, "hp_removed_fraction": 0.08, "exposure_seconds": 3.0, "block_seconds": 0.0, "cross_floor_damage": 0.0, "kills": 1, "leaks": 12, "core_hp": 8, "floor_id": "floor_3", "build_wave": 1},
				{"tower_id": "guard_post", "spot_id": "F1_B", "value_per_gold": 11.0, "actual_damage": 1320.0, "cost": 120.0, "hp_removed_fraction": 0.09, "exposure_seconds": 5.0, "block_seconds": 2.0, "cross_floor_damage": 0.0, "kills": 1, "leaks": 11, "core_hp": 9, "floor_id": "floor_1", "build_wave": 1},
				{"tower_id": "guard_post", "spot_id": "F3_E", "value_per_gold": 9.0, "actual_damage": 1080.0, "cost": 120.0, "hp_removed_fraction": 0.07, "exposure_seconds": 3.0, "block_seconds": 1.0, "cross_floor_damage": 0.0, "kills": 1, "leaks": 12, "core_hp": 8, "floor_id": "floor_3", "build_wave": 1},
				{"tower_id": "lava_tower", "spot_id": "F3_D", "value_per_gold": 0.15, "actual_damage": 20.0, "cost": 130.0, "hp_removed_fraction": 0.002, "exposure_seconds": 8.0, "block_seconds": 0.0, "cross_floor_damage": 1.0, "kills": 0, "leaks": 14, "core_hp": 6, "floor_id": "floor_3", "build_wave": 1},
			],
			"by_tower": {
				"basic_tower": {"median": 12.0, "mean": 12.0, "min": 9.5, "max": 14.5, "p25": 9.5, "p75": 14.5, "cv": 0.11, "best_spot": "F1_C", "worst_spot": "F3_E", "placement_sensitivity_band": "LOW"},
				"guard_post": {"median": 10.0, "mean": 10.0, "min": 9.0, "max": 11.0, "p25": 9.0, "p75": 11.0, "cv": 0.18, "best_spot": "F1_B", "worst_spot": "F3_E", "placement_sensitivity_band": "MEDIUM"},
				"lava_tower": {"median": 0.15, "mean": 0.15, "min": 0.15, "max": 0.15, "p25": 0.15, "p75": 0.15, "cv": 0.0, "best_spot": "F3_D", "worst_spot": "F3_D", "placement_sensitivity_band": "LOW"},
			},
		},
		"early_build": {
			"basic_tower": {"early_build_multiplier": 1.04, "by_wave": {1: 12.5, 5: 12.0}},
			"guard_post": {"early_build_multiplier": 1.00, "by_wave": {1: 10.0, 5: 10.0}},
			"lava_tower": {"early_build_multiplier": 1.11, "by_wave": {1: 0.17, 5: 0.15}},
		},
		"meltdown_ramp": {
			"peak_cell_dps": 0.56,
			"active_cells": 4,
			"active_damage_cells": 1,
			"cross_floor_cells": 0,
			"emitted_mass": 30.0,
			"landed_mass": 28.0,
			"same_floor_mass": 28.0,
			"cross_floor_mass": 0.0,
			"decayed_mass": 10.0,
			"void_lost_mass": 2.0,
			"total_lava_mass": 16.0,
			"t_first_damage": 2.0,
			"t_25_percent_damage": -1.0,
			"t_50_percent_damage": -1.0,
			"t_90_percent_damage": -1.0,
			"series": [{"time": 0.25, "total_mass": 1.0, "active_cells": 1, "damage_cells": 0, "peak_cell_dps": 0.1, "aggregate_field_dps": 0.1}],
		},
	}


func _report() -> Dictionary:
	var Model = load("res://scripts/balance/report/balance_report_model.gd")
	return Model.build(_parts(), {"game_version": "0.18.1", "seed": 7, "difficulty_id": "normal", "level_id": "vertical_test"})


func _test_null_ramps() -> bool:
	var melt: Dictionary = _report().get("meltdown", {})
	var ramp: Dictionary = melt.get("ramp", {})
	if ramp.get("t_25") != null:
		return _fail("A: t_25 must be null when probe never reached 25%")
	if ramp.get("t_50") != null or ramp.get("t_90") != null:
		return _fail("A: t_50/t_90 must be null when unreached")
	if bool(ramp.get("t_25_reached", true)):
		return _fail("A: t_25_reached should be false")
	print("A null ramps: OK")
	return true


func _test_missing_cf_not_zero() -> bool:
	var r := _report()
	if r.get("counterfactual") != null:
		return _fail("B: missing counterfactual must be null, not a numeric zero")
	if r.get("shapley") != null:
		return _fail("B: missing shapley must be null")
	if r.get("defense_margin") != null:
		return _fail("B: default defense_margin must be null")
	if r.get("difficulty_frontier") != null:
		return _fail("B: default difficulty_frontier must be null")
	print("B missing measures are null: OK")
	return true


func _test_status_and_findings() -> bool:
	var r := _report()
	if str(r.get("tower_status", {}).get("lava_tower", "")) != "SEVERELY_BELOW_TARGET":
		return _fail("C: Meltdown should be SEVERELY_BELOW_TARGET")
	if str(r.get("tower_status", {}).get("basic_tower", "")) != "WITHIN_TARGET":
		return _fail("C: Sentry should be WITHIN_TARGET")
	var codes: Array = []
	for f in r.get("findings", []):
		codes.append(str(f.get("code", "")))
	if not ("MELTDOWN_RAMP_NOT_REACHED" in codes or "MELTDOWN_BELOW_TARGET" in codes):
		return _fail("C: expected Meltdown finding codes")
	print("C status/findings: OK")
	return true


func _test_ai_schema_and_no_series() -> bool:
	var Ai = load("res://scripts/balance/report/balance_ai_exporter.gd")
	var ai: Dictionary = Ai.export(_report())
	if str(ai.get("schema", "")) != "hodl_balance_ai_export":
		return _fail("D: AI schema name")
	if int(ai.get("schema_version", 0)) != 1:
		return _fail("D: AI schema_version")
	var melt: Dictionary = ai.get("meltdown", {})
	if melt.has("series"):
		return _fail("E: AI export must omit time series")
	var blob := JSON.stringify(ai)
	if blob.find("\"series\"") >= 0:
		return _fail("E: AI JSON must not contain series key")
	if blob.length() > 100000:
		return _fail("E: AI export should stay compact")
	print("D/E AI schema + no series: OK")
	return true


func _test_json_contains_ai() -> bool:
	var r := _report()
	var Ai = load("res://scripts/balance/report/balance_ai_exporter.gd")
	var ai: Dictionary = Ai.export(r)
	for tid in (ai.get("towers", {}) as Dictionary).keys():
		if not (r.get("towers", {}) as Dictionary).has(tid):
			return _fail("F: full JSON missing tower %s from AI export" % str(tid))
		var a_med = (ai.get("towers", {}) as Dictionary)[tid].get("median_value_per_gold")
		var j_med = (r.get("towers", {}) as Dictionary)[tid].get("median_value_per_gold")
		if a_med != j_med:
			return _fail("F: AI median must match JSON for %s" % str(tid))
	print("F JSON contains AI metrics: OK")
	return true


func _test_html_contains_sections() -> bool:
	var Html = load("res://scripts/balance/report/balance_html_reporter.gd")
	var html := str(Html.render(_report()))
	for needle in ["BALANCE LAB", "Sentry", "Guard", "Meltdown", "Designer summary", "0.18.1"]:
		if html.find(needle) < 0:
			return _fail("G: HTML missing '%s'" % needle)
	print("G HTML sections: OK")
	return true


func _test_metrics_vs_report_id() -> bool:
	var a := _report()
	var b := _report()
	if str(a.get("report_meta", {}).get("report_id")) == "":
		return _fail("H: report_id required")
	var va = a.get("towers", {}).get("basic_tower", {}).get("median_value_per_gold")
	var vb = b.get("towers", {}).get("basic_tower", {}).get("median_value_per_gold")
	if va != vb:
		return _fail("H: metrics must not depend on report_id")
	print("H deterministic metrics: OK")
	return true


func _test_comparator_skip() -> bool:
	var Cmp = load("res://scripts/balance/report/balance_report_comparator.gd")
	var a := _report()
	var other := a.duplicate(true)
	other["report_meta"] = (a.get("report_meta", {}) as Dictionary).duplicate(true)
	(other["report_meta"] as Dictionary)["seed"] = 99
	var delta = Cmp.compare(a, other)
	if typeof(delta) != TYPE_DICTIONARY:
		return _fail("I: comparator should return a dict")
	if bool(delta.get("comparable", true)):
		return _fail("I: different seeds must not be comparable")
	if str(delta.get("message", "")).find("not directly comparable") < 0:
		return _fail("I: expected incompatibility message")
	print("I comparator skip: OK")
	return true


func _test_margin_frontier(tree: SceneTree) -> bool:
	var Full = load("res://scripts/balance/full_build_benchmark.gd")
	var rec: Dictionary = await Full.record_scripted(tree, {
		"seed": 21,
		"difficulty_id": "normal",
		"time_scale": 40.0,
		"max_sim_seconds": 180.0,
		"config": {"starting_gold": 1000},
	})
	var log: Array = rec.get("action_log", [])
	if log.is_empty():
		return _fail("P: scripted fixture log should not be empty")
	var Margin = load("res://scripts/balance/defense_margin_search.gd")
	var opts := {
		"action_log": log,
		"seed": 21,
		"difficulty_id": "normal",
		"time_scale": 40.0,
		"config": {"starting_gold": 1000},
		"axes": ["enemy_health"],
		"lo": 1.0,
		"hi": 1.2,
		"iters": 2,
	}
	var m1: Dictionary = await Margin.run(tree, opts)
	var m2: Dictionary = await Margin.run(tree, opts)
	var a1 = str((m1.get("axes", {}) as Dictionary).get("enemy_health", {}))
	var a2 = str((m2.get("axes", {}) as Dictionary).get("enemy_health", {}))
	if a1 != a2:
		return _fail("P: defense-margin should be reproducible")
	var Front = load("res://scripts/balance/difficulty_frontier.gd")
	var fopts := {
		"action_log": log,
		"seed": 21,
		"difficulty_id": "normal",
		"time_scale": 40.0,
		"config": {"starting_gold": 1000},
		"health_min": 1.0,
		"health_max": 1.0,
		"speed_min": 1.0,
		"speed_max": 1.0,
		"step": 0.1,
	}
	var f1: Dictionary = await Front.run(tree, fopts)
	var f2: Dictionary = await Front.run(tree, fopts)
	if str(f1.get("cells", [])) != str(f2.get("cells", [])):
		return _fail("Q: difficulty frontier should be reproducible")
	if (f1.get("cells", []) as Array).is_empty():
		return _fail("Q: frontier should contain at least one cell")
	print("P/Q margin+frontier: OK")
	return true
