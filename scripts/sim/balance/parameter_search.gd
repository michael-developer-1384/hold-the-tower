class_name ParameterSearch
extends RefCounted

## Binary-search one monotonic difficulty parameter toward a target winrate.

static func search(
	tree: SceneTree,
	param: String,
	target_winrate: float,
	opts: Dictionary
) -> Dictionary:
	var BatchRunnerScript = load("res://scripts/sim/balance/batch_runner.gd")
	var low := float(opts.get("low", 1.0))
	var high := float(opts.get("high", 2.0))
	var runs := int(opts.get("runs", 20))
	var iterations := int(opts.get("iterations", 6))
	var samples: Array = []
	var best_m := low
	var best_diff := 999.0

	for _i in iterations:
		var mid := (low + high) * 0.5
		var one := opts.duplicate(true)
		one["runs"] = runs
		var cfg: Dictionary = one.get("config", {}).duplicate(true) if typeof(one.get("config", {})) == TYPE_DICTIONARY else {}
		cfg[param] = mid
		one["config"] = cfg
		var batch: Dictionary = await BatchRunnerScript.run_batch(tree, one)
		var agg: Dictionary = batch.get("aggregate", {})
		var wr := float(agg.get("winrate", 0.0))
		samples.append({"value": mid, "winrate": wr, "runs": runs})
		print("Search %s=%.3f → winrate %.1f%%" % [param, mid, wr * 100.0])
		var diff := absf(wr - target_winrate)
		if diff < best_diff:
			best_diff = diff
			best_m = mid
		# Assume higher param → lower winrate (enemy_health, etc.)
		if wr > target_winrate:
			low = mid
		else:
			high = mid

	return {
		"param": param,
		"target_winrate": target_winrate,
		"suggested": best_m,
		"samples": samples,
	}
