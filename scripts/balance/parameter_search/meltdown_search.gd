extends RefCounted

## Multi-objective Meltdown search. Never writes catalog values.

const Isolated := preload("res://scripts/balance/isolated_tower_benchmark.gd")
const Targets := preload("res://scripts/balance/balance_targets.gd")


static func search_space(quick: bool = false) -> Dictionary:
	if quick:
		return {
			"flow_start_mass": [12.0, 20.0],
			"damage_full_mass": [24.0, 36.0],
			"pour_rate": [1.2],
			"lava_lifetime": [12.0, 16.0],
		}
	return {
		"flow_start_mass": [10.0, 16.0],
		"damage_full_mass": [28.0, 40.0],
		"pour_rate": [1.2, 1.6],
		"lava_lifetime": [12.0, 18.0],
	}


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var space: Dictionary = opts.get("search_space", search_space(bool(opts.get("quick", false))))
	var spots: PackedStringArray = opts.get("spots", PackedStringArray(["F3_D", "F2_B"]))
	var waves: Array = opts.get("build_waves", [1])
	var candidates: Array = _cartesian(space)
	var evaluated: Array = []
	var eval_count := 0
	for cand in candidates:
		var row: Dictionary = await _evaluate_candidate(tree, opts, cand, spots, waves)
		eval_count += int(row.get("eval_count", 0))
		evaluated.append(row)
	evaluated.sort_custom(func(a, b): return float(a.get("overall_score", -999.0)) > float(b.get("overall_score", -999.0)))
	var top: Array = []
	for i in mini(5, evaluated.size()):
		top.append(evaluated[i])
	var recommended = top[0] if not top.is_empty() else null
	return {
		"search_space": space,
		"candidate_count": candidates.size(),
		"evaluation_count": eval_count,
		"top_candidates": top,
		"recommended_candidate": recommended,
		"weights": Targets.meltdown_search_weights(),
		"applied": false,
	}


static func _evaluate_candidate(tree: SceneTree, opts: Dictionary, params: Dictionary, spots: PackedStringArray, waves: Array) -> Dictionary:
	var cfg: Dictionary = opts.get("config", {"starting_gold": 1000}).duplicate(true)
	for k in params.keys():
		cfg["lava_tower." + str(k)] = params[k]
	var values: Array = []
	var cross: Array = []
	var evals := 0
	for sid in spots:
		for w in waves:
			var iso: Dictionary = await Isolated.run(tree, {
				"tower_id": "lava_tower",
				"spot_id": str(sid),
				"build_wave": int(w),
				"seed": int(opts.get("seed", 7)),
				"difficulty_id": str(opts.get("difficulty_id", "normal")),
				"level_id": str(opts.get("level_id", "vertical_test")),
				"time_scale": float(opts.get("time_scale", 40.0)),
				"config": cfg,
			})
			values.append(float(iso.get("value_per_gold", 0.0)))
			var lava: Dictionary = iso.get("lava", {})
			var emitted := maxf(float(lava.get("emitted_mass", 0.0)), 0.0001)
			cross.append(float(lava.get("cross_floor_mass", 0.0)) / emitted)
			evals += 1
	var ramp_spot := str(spots[0]) if spots.size() > 0 else "F3_D"
	var ramp: Dictionary = await Isolated.run(tree, {
		"tower_id": "lava_tower",
		"spot_id": ramp_spot,
		"build_wave": 1,
		"seed": int(opts.get("seed", 7)),
		"difficulty_id": str(opts.get("difficulty_id", "normal")),
		"level_id": str(opts.get("level_id", "vertical_test")),
		"start_waves": false,
		"duration": 25.0,
		"time_scale": float(opts.get("time_scale", 40.0)),
		"config": cfg,
		"balance_ramp_series": true,
	})
	evals += 1
	var lava_r: Dictionary = ramp.get("lava", {})
	var stats: Dictionary = _stats(values)
	var t: Dictionary = Targets.for_tower("lava_tower")
	var economic := float(stats.get("median", 0.0))
	var rel := economic / maxf(float(opts.get("anchor", 11.29)), 0.0001)
	var cv := float(stats.get("cv", 0.0))
	var early := 1.0
	if waves.size() >= 2 and values.size() >= 2:
		var first := float(values[0])
		var last := float(values[values.size() - 1])
		if last > 0.0001:
			early = first / last
	var cross_mean := _mean(cross)
	var peak := float(lava_r.get("peak_cell_dps", 0.0))
	var peak_frac := peak / maxf(10.0, 0.0001)
	var t25 = lava_r.get("t_25_percent_damage", -1.0)
	var t50 = lava_r.get("t_50_percent_damage", -1.0)
	var emitted := maxf(float(lava_r.get("emitted_mass", 0.0)), 0.0001)
	var void_f := float(lava_r.get("void_lost_mass", 0.0)) / emitted
	var decay_f := float(lava_r.get("decayed_mass", 0.0)) / emitted
	var score := _score(t, rel, cv, early, cross_mean, t25, peak_frac, void_f, decay_f, params)
	return {
		"parameters": params,
		"economic_value": economic,
		"relative_anchor": rel,
		"placement_cv": cv,
		"early_ratio": early,
		"cross_floor_ratio": cross_mean,
		"t25": null if float(t25) < 0.0 else t25,
		"t50": null if float(t50) < 0.0 else t50,
		"peak_damage_fraction": peak_frac,
		"void_loss": void_f,
		"decay": decay_f,
		"overall_score": score,
		"eval_count": evals,
	}


static func _score(t: Dictionary, rel: float, cv: float, early: float, cross_mean: float, t25: Variant, peak_frac: float, void_f: float, decay_f: float, params: Dictionary) -> float:
	var w: Dictionary = Targets.meltdown_search_weights()
	var eco := _band_fit(rel, float(t.get("relative_value_gold_min", 0.7)), float(t.get("relative_value_gold_max", 1.4)))
	var plc := _band_fit(cv, float(t.get("placement_sensitivity_min", 0.3)), float(t.get("placement_sensitivity_max", 0.9)))
	var early_fit := _band_fit(early, float(t.get("early_late_ratio_min", 1.1)), float(t.get("early_late_ratio_max", 2.5)))
	var xf := clampf(cross_mean / maxf(float(t.get("cross_floor_min", 0.08)), 0.0001), 0.0, 1.5)
	var ramp_h := 0.0
	if t25 != null and float(t25) >= 0.0:
		ramp_h = clampf(1.0 - absf(float(t25) - 8.0) / 20.0, 0.0, 1.0)
		if peak_frac >= 0.25:
			ramp_h += 0.35
	var void_p := maxf(void_f - 0.25, 0.0)
	var decay_p := maxf(decay_f - 0.45, 0.0)
	var degen := 0.0
	if float(params.get("lava_damage", 10.0)) > 20.0:
		degen += 1.0
	if peak_frac > 0.98 and (t25 == null or float(t25) < 1.0):
		degen += 1.0
	return (
		float(w.economic_target_fit) * eco
		+ float(w.placement_target_fit) * plc
		+ float(w.early_roi_target_fit) * early_fit
		+ float(w.cross_floor_target_fit) * xf
		+ float(w.ramp_health) * ramp_h
		- float(w.excessive_void_loss_penalty) * void_p
		- float(w.excessive_decay_penalty) * decay_p
		- float(w.degenerate_behavior_penalty) * degen
	)


static func _band_fit(v: float, lo: float, hi: float) -> float:
	if v >= lo and v <= hi:
		return 1.0
	if v < lo:
		return clampf(1.0 - (lo - v) / maxf(lo, 0.0001), 0.0, 1.0)
	return clampf(1.0 - (v - hi) / maxf(hi, 0.0001), 0.0, 1.0)


static func _cartesian(space: Dictionary) -> Array:
	var keys: Array = space.keys()
	var out: Array = [{}]
	for k in keys:
		var next: Array = []
		var vals: Array = space[k]
		for prev in out:
			for v in vals:
				var d: Dictionary = (prev as Dictionary).duplicate(true)
				d[str(k)] = v
				next.append(d)
		out = next
	return out


static func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"median": 0.0, "cv": 0.0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	var med := float(sorted[sorted.size() / 2])
	var mean := _mean(values)
	var acc := 0.0
	for v in values:
		acc += (float(v) - mean) * (float(v) - mean)
	var sd := sqrt(acc / float(maxi(values.size(), 1)))
	return {"median": med, "cv": sd / maxf(mean, 0.0001), "mean": mean}


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var acc := 0.0
	for v in values:
		acc += float(v)
	return acc / float(values.size())


static func meets_dod(candidate: Dictionary) -> Dictionary:
	var params: Dictionary = candidate.get("parameters", {}) if typeof(candidate.get("parameters")) == TYPE_DICTIONARY else {}
	var t25 = candidate.get("t25")
	var peak := float(candidate.get("peak_damage_fraction", 0.0))
	var reasons: PackedStringArray = PackedStringArray()
	if t25 == null or float(t25) < 0.0:
		reasons.append("t_25 never reached")
	elif float(t25) < 0.4:
		reasons.append("t_25 too early (degenerate instant ramp)")
	if peak >= 0.98 and (t25 == null or float(t25) < 1.0):
		reasons.append("peak DPS matches instant full damage")
	if float(params.get("lava_damage", 10.0)) > 20.0:
		reasons.append("lava_damage is not a first-order knob")
	return {
		"ok": reasons.is_empty(),
		"reasons": reasons,
	}


static func apply_to_catalog(candidate: Dictionary) -> Dictionary:
	var gate: Dictionary = meets_dod(candidate)
	if not bool(gate.get("ok", false)):
		return {
			"applied": false,
			"reason": "Candidate failed DoD: " + ", ".join(gate.get("reasons", PackedStringArray())),
		}
	var params: Dictionary = candidate.get("parameters", {})
	if params.is_empty():
		return {"applied": false, "reason": "No parameters on candidate."}
	var flow_start := float(params.get("flow_start_mass", 14.0))
	var damage_full := float(params.get("damage_full_mass", 36.0))
	var lifetime := float(params.get("lava_lifetime", 16.0))
	var pour := float(params.get("pour_rate", 1.2))
	_rewrite_const("res://scripts/world/lava_config.gd", "DAMAGE_FULL_MASS", damage_full)
	_rewrite_const("res://scripts/world/lava_config.gd", "FLOW_START_MASS", flow_start)
	_rewrite_const("res://scripts/world/lava_config.gd", "DEFAULT_LIFETIME", lifetime)
	_rewrite_const("res://scripts/world/lava_system.gd", "DEFAULT_LIFETIME", lifetime)
	_patch_research_lifetime(lifetime)
	_patch_export_float("res://scripts/towers/lava_tower.gd", "lava_lifetime", lifetime)
	_patch_export_float("res://scripts/towers/lava_tower.gd", "pour_rate", pour)
	_patch_tscn_float("res://scenes/towers/lava_tower.tscn", "lava_lifetime", lifetime)
	_patch_tscn_float("res://scenes/towers/lava_tower.tscn", "pour_rate", pour)
	return {
		"applied": true,
		"parameters": params,
		"files": [
			"scripts/world/lava_config.gd",
			"scripts/world/lava_system.gd",
			"scripts/meta/research_config.gd",
			"scripts/towers/lava_tower.gd",
			"scenes/towers/lava_tower.tscn",
		],
	}


static func _rewrite_const(path: String, name: String, value: float) -> void:
	var txt := _read_text(path)
	if txt.is_empty():
		return
	var re := RegEx.new()
	re.compile("const %s := [0-9.]+" % name)
	txt = re.sub(txt, "const %s := %.1f" % [name, value], true)
	_write_text(path, txt)


static func _patch_research_lifetime(lifetime: float) -> void:
	var path := "res://scripts/meta/research_config.gd"
	var txt := _read_text(path)
	if txt.is_empty():
		return
	var re := RegEx.new()
	re.compile('"lava_lifetime": _stat\\("lava_lifetime", "Lava Lifetime", "Idle seconds before a puddle fades\\.", [0-9.]+')
	txt = re.sub(txt, '"lava_lifetime": _stat("lava_lifetime", "Lava Lifetime", "Idle seconds before a puddle fades.", %.1f' % lifetime, true)
	_write_text(path, txt)


static func _patch_export_float(path: String, name: String, value: float) -> void:
	var txt := _read_text(path)
	if txt.is_empty():
		return
	var re := RegEx.new()
	re.compile("@export var %s: float = [0-9.]+" % name)
	txt = re.sub(txt, "@export var %s: float = %.1f" % [name, value], true)
	_write_text(path, txt)


static func _patch_tscn_float(path: String, name: String, value: float) -> void:
	var txt := _read_text(path)
	if txt.is_empty():
		return
	var re := RegEx.new()
	re.compile("%s = [0-9.]+" % name)
	txt = re.sub(txt, "%s = %.1f" % [name, value], true)
	_write_text(path, txt)


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt


static func _write_text(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(txt)
	f.close()
