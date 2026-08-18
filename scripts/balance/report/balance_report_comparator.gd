extends RefCounted

## Delta vs a previous latest report when the same analysis fingerprint applies.


static func compare(current: Dictionary, previous: Dictionary) -> Variant:
	if previous.is_empty():
		return null
	var a: Dictionary = current.get("report_meta", {})
	var b: Dictionary = previous.get("report_meta", {})
	if str(a.get("level_id", "")) != str(b.get("level_id", "")):
		return _skip()
	if str(a.get("difficulty_id", "")) != str(b.get("difficulty_id", "")):
		return _skip()
	if int(a.get("seed", -1)) != int(b.get("seed", -2)):
		return _skip()
	if str(a.get("parameter_fingerprint", "")) != str(b.get("parameter_fingerprint", "")):
		return _skip()
	var towers: Dictionary = {}
	var cur_t: Dictionary = current.get("towers", {})
	var prev_t: Dictionary = previous.get("towers", {})
	for tid in cur_t.keys():
		var c: Dictionary = cur_t[tid]
		var p: Dictionary = prev_t.get(tid, {})
		if p.is_empty():
			continue
		towers[tid] = {
			"median_delta": _sub(c.get("median_value_per_gold"), p.get("median_value_per_gold")),
			"relative_delta": _sub(c.get("relative_to_anchor_median"), p.get("relative_to_anchor_median")),
			"placement_cv_delta": _sub(c.get("placement_cv"), p.get("placement_cv")),
			"early_build_delta": _sub(c.get("early_build_multiplier"), p.get("early_build_multiplier")),
			"status_was": p.get("status"),
			"status_now": c.get("status"),
			"economic_efficiency": _cls(_sub(c.get("median_value_per_gold"), p.get("median_value_per_gold"))),
			"placement_sensitivity": _cls(_sub(c.get("placement_cv"), p.get("placement_cv")), true),
		}
	return {
		"comparable": true,
		"previous_report_id": b.get("report_id"),
		"towers": towers,
		"economic_efficiency": _section(current.get("towers"), previous.get("towers")),
		"placement_sensitivity": _cls(_avg_cv(current) - _avg_cv(previous), true),
		"build_timing": _cls(_sub(_early(current, "basic_tower"), _early(previous, "basic_tower"))),
		"counterfactual": _present_cls(current.get("counterfactual"), previous.get("counterfactual")),
		"shapley": _present_cls(current.get("shapley"), previous.get("shapley")),
		"full_build": _present_cls(current.get("full_builds"), previous.get("full_builds")),
		"defense_margin": _cls(_sub(_margin(current), _margin(previous))),
		"difficulty_frontier": _present_cls(current.get("difficulty_frontier"), previous.get("difficulty_frontier")),
		"meltdown_ramp": _cls(_sub(_peak(current), _peak(previous))),
		"simulation_fidelity": _fid_cls(current, previous),
	}


static func _skip() -> Dictionary:
	return {
		"comparable": false,
		"message": "Previous report not directly comparable.",
		"classification": "NOT_COMPARABLE",
	}


static func _cls(delta: Variant, invert: bool = false) -> String:
	if delta == null:
		return "NOT_COMPARABLE"
	var d := float(delta)
	if invert:
		d = -d
	if absf(d) < 0.0005:
		return "UNCHANGED"
	if d > 0.0:
		return "IMPROVED"
	return "REGRESSED"


static func _present_cls(cur: Variant, prev: Variant) -> String:
	if cur == null or (typeof(cur) == TYPE_ARRAY and (cur as Array).is_empty()):
		if prev == null:
			return "UNCHANGED"
		return "NOT_COMPARABLE"
	if prev == null:
		return "IMPROVED"
	return "UNCHANGED"


static func _fid_cls(current: Dictionary, previous: Dictionary) -> String:
	var a := str((current.get("data_quality", {}) as Dictionary).get("sim_fidelity", ""))
	var b := str((previous.get("data_quality", {}) as Dictionary).get("sim_fidelity", ""))
	if a == b:
		return "UNCHANGED"
	if a == "PASS" and b != "PASS":
		return "IMPROVED"
	if a != "PASS" and b == "PASS":
		return "REGRESSED"
	return "NOT_COMPARABLE"


static func _sub(a: Variant, b: Variant) -> Variant:
	if a == null or b == null:
		return null
	return float(a) - float(b)


static func _avg_cv(report: Dictionary) -> float:
	var acc := 0.0
	var n := 0
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var cv = report.get("towers", {}).get(tid, {}).get("placement_cv")
		if cv != null:
			acc += float(cv)
			n += 1
	return acc / float(maxi(n, 1))


static func _early(report: Dictionary, tid: String) -> Variant:
	return report.get("towers", {}).get(tid, {}).get("early_build_multiplier")


static func _margin(report: Dictionary) -> Variant:
	var dm = report.get("defense_margin")
	if typeof(dm) != TYPE_DICTIONARY:
		return null
	return dm.get("margin")


static func _peak(report: Dictionary) -> Variant:
	return report.get("meltdown", {}).get("peak_damage_fraction")


static func _section(cur: Variant, prev: Variant) -> String:
	if typeof(cur) != TYPE_DICTIONARY or typeof(prev) != TYPE_DICTIONARY:
		return "NOT_COMPARABLE"
	return "UNCHANGED"
