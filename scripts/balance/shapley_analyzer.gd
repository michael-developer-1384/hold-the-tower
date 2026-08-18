extends RefCounted

## Exact Shapley for small builds (N <= MAX_N). Optional.

const Counterfactual := preload("res://scripts/balance/counterfactual_runner.gd")

const MAX_N := 5


static func score_of(result: Dictionary, kind: String) -> float:
	match kind:
		"core_hp_preserved":
			return float(result.get("lives_remaining", 0))
		"leaks_prevented":
			return -float(result.get("enemies_leaked", 0))
		_:
			return float(result.get("total_damage", 0.0))


static func analyze(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var spots: PackedStringArray = Counterfactual.placed_spots(log)
	var n := spots.size()
	var kind := str(opts.get("score", "hp_removed"))
	if n == 0:
		return {"skipped": true, "reason": "no_towers"}
	if n > MAX_N:
		return {"skipped": true, "reason": "n_gt_max", "n": n, "max_n": MAX_N}
	var cache := {}
	var subset_count := 1 << n
	for mask in subset_count:
		var filtered := _filter_mask(log, spots, mask)
		var one := opts.duplicate(true)
		one["action_log"] = filtered
		var result: Dictionary = await Counterfactual.replay(tree, one)
		cache[mask] = score_of(result, kind)
	var shapley := {}
	var fact_n := _factorial(n)
	for i in n:
		var acc := 0.0
		for mask in subset_count:
			if (mask & (1 << i)) != 0:
				continue
			var s := _popcount(mask)
			var weight := float(_factorial(s) * _factorial(n - s - 1)) / float(fact_n)
			var with_i := float(cache[mask | (1 << i)])
			var without_v := float(cache[mask])
			acc += weight * (with_i - without_v)
		shapley[spots[i]] = acc
	var grand := float(cache[subset_count - 1])
	var empty := float(cache[0])
	var sum := 0.0
	for k in shapley.keys():
		sum += float(shapley[k])
	return {
		"skipped": false,
		"n": n,
		"score": kind,
		"shapley": shapley,
		"grand_coalition": grand,
		"empty_coalition": empty,
		"sum": sum,
		"sum_matches_grand": absf(sum - (grand - empty)) < 0.5,
		"max_n": MAX_N,
	}


static func _filter_mask(log: Array, spots: PackedStringArray, mask: int) -> Array:
	var keep := {}
	for i in spots.size():
		if (mask & (1 << i)) != 0:
			keep[spots[i]] = true
	var out: Array = []
	for entry in log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		var t := str(action.get("type", ""))
		var sid := str(action.get("spot_id", ""))
		if t == "PLACE_TOWER" or t == "UPGRADE_TOWER":
			if not keep.has(sid):
				continue
		out.append(entry)
	return out


static func _factorial(n: int) -> int:
	var v := 1
	for i in range(2, n + 1):
		v *= i
	return v


static func _popcount(mask: int) -> int:
	var c := 0
	var m := mask
	while m > 0:
		c += m & 1
		m >>= 1
	return c
