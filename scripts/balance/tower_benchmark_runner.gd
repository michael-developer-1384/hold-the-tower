extends RefCounted

## Tower × spot matrix, placement sensitivity, early/late timing.

const Isolated := preload("res://scripts/balance/isolated_tower_benchmark.gd")
const Model := preload("res://scripts/balance/combat_value_model.gd")
const Targets := preload("res://scripts/balance/balance_targets.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


static func default_towers() -> PackedStringArray:
	return PackedStringArray(["basic_tower", "guard_post", "lava_tower"])


static func default_spots() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for s in Model.level_spots():
		ids.append(str(s.get("spot_id")))
	return ids


static func run_matrix(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var towers: PackedStringArray = opts.get("towers", default_towers())
	var spots: PackedStringArray = opts.get("spots", default_spots())
	var build_wave := int(opts.get("build_wave", 1))
	var rows: Array = []
	for tid in towers:
		for sid in spots:
			var one := opts.duplicate(true)
			one["tower_id"] = str(tid)
			one["spot_id"] = str(sid)
			one["build_wave"] = build_wave
			var row: Dictionary = await Isolated.run(tree, one)
			rows.append(row)
	return {
		"build_wave": build_wave,
		"rows": rows,
		"by_tower": summarize_by_tower(rows),
	}


static func run_timing(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var towers: PackedStringArray = opts.get("towers", default_towers())
	var spots: PackedStringArray = opts.get("spots", default_spots())
	var waves: Array = opts.get("build_waves", [1, 2, 3, 4, 5])
	var rows: Array = []
	for tid in towers:
		for sid in spots:
			for w in waves:
				var one := opts.duplicate(true)
				one["tower_id"] = str(tid)
				one["spot_id"] = str(sid)
				one["build_wave"] = int(w)
				rows.append(await Isolated.run(tree, one))
	return {"rows": rows, "by_tower": summarize_timing(rows)}


static func summarize_by_tower(rows: Array) -> Dictionary:
	var grouped := {}
	for row in rows:
		var tid := str(row.get("tower_id", ""))
		if not grouped.has(tid):
			grouped[tid] = []
		(grouped[tid] as Array).append(row)
	var out := {}
	for tid in grouped.keys():
		out[tid] = placement_stats(grouped[tid])
	return out


static func placement_stats(rows: Array) -> Dictionary:
	var values: Array = []
	var best := {}
	var worst := {}
	for row in rows:
		var v := float(row.get("value_per_gold", 0.0))
		values.append(v)
		if best.is_empty() or v > float(best.get("value_per_gold", -INF)):
			best = row
		if worst.is_empty() or v < float(worst.get("value_per_gold", INF)):
			worst = row
	values.sort()
	var st := _stats(values)
	st["best_spot"] = str(best.get("spot_id", ""))
	st["worst_spot"] = str(worst.get("spot_id", ""))
	st["best_value_per_gold"] = float(best.get("value_per_gold", 0.0))
	st["worst_value_per_gold"] = float(worst.get("value_per_gold", 0.0))
	st["placement_sensitivity"] = st["cv"]
	st["placement_sensitivity_band"] = Targets.sensitivity_band(float(st["cv"]))
	st["tower_id"] = str(best.get("tower_id", ""))
	st["role"] = ""
	var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), str(best.get("tower_id", "")))
	if def != null:
		st["role"] = str(def.role)
	return st


static func summarize_timing(rows: Array) -> Dictionary:
	var grouped := {}
	for row in rows:
		var tid := str(row.get("tower_id", ""))
		if not grouped.has(tid):
			grouped[tid] = []
		(grouped[tid] as Array).append(row)
	var out := {}
	for tid in grouped.keys():
		var by_wave := {}
		var vals: Array = []
		for row in grouped[tid]:
			var w := int(row.get("build_wave", 1))
			var v := float(row.get("value_per_gold", 0.0))
			if not by_wave.has(w):
				by_wave[w] = []
			(by_wave[w] as Array).append(v)
			vals.append(v)
		var med := float(_stats(vals).get("median", 0.0))
		var wave_means := {}
		for w in by_wave.keys():
			wave_means[w] = _mean(by_wave[w])
		var early := float(wave_means.get(1, 0.0))
		out[tid] = {
			"by_wave": wave_means,
			"median_build_value": med,
			"early_build_multiplier": early / maxf(med, 0.0001),
		}
	return out


static func _stats(values: Array) -> Dictionary:
	var n := values.size()
	if n <= 0:
		return {"min": 0.0, "max": 0.0, "mean": 0.0, "median": 0.0, "stdev": 0.0, "p25": 0.0, "p75": 0.0, "cv": 0.0}
	var mn := float(values[0])
	var mx := float(values[n - 1])
	var sum := 0.0
	for v in values:
		sum += float(v)
	var mean := sum / float(n)
	var var_acc := 0.0
	for v2 in values:
		var d := float(v2) - mean
		var_acc += d * d
	var stdev := sqrt(var_acc / float(n))
	return {
		"min": mn,
		"max": mx,
		"mean": mean,
		"median": _percentile(values, 0.5),
		"stdev": stdev,
		"p25": _percentile(values, 0.25),
		"p75": _percentile(values, 0.75),
		"cv": stdev / maxf(mean, 0.0001),
	}


static func _percentile(sorted_values: Array, p: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var idx := clampf(p, 0.0, 1.0) * float(sorted_values.size() - 1)
	var lo := int(floor(idx))
	var hi := int(ceil(idx))
	if lo == hi:
		return float(sorted_values[lo])
	var t := idx - float(lo)
	return float(sorted_values[lo]) * (1.0 - t) + float(sorted_values[hi]) * t


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())
