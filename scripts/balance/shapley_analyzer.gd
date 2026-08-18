extends RefCounted

## Exact Shapley for small builds; seedable sampled Shapley for larger N.

const Counterfactual := preload("res://scripts/balance/counterfactual_runner.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")

const MAX_EXACT := 5
const DEFAULT_SAMPLES := 24


static func score_of(result: Dictionary, kind: String) -> float:
	match kind:
		"core_hp_preserved":
			return float(result.get("lives_remaining", 0))
		"leaks_prevented":
			return -float(result.get("enemies_leaked", 0))
		"combat_value":
			return float(result.get("total_damage", 0.0)) + float(result.get("lives_remaining", 0)) * 120.0 - float(result.get("enemies_leaked", 0)) * 120.0
		_:
			return float(result.get("total_damage", 0.0))


static func analyze(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var spots: PackedStringArray = Counterfactual.placed_spots(replay_log)
	var n := spots.size()
	var kind := str(opts.get("score", "combat_value"))
	if n == 0:
		return {"skipped": true, "reason": "no_towers"}
	if n <= MAX_EXACT:
		return await _exact(tree, opts, spots, kind)
	return await _sampled(tree, opts, spots, kind)


static func _exact(tree: SceneTree, opts: Dictionary, spots: PackedStringArray, kind: String) -> Dictionary:
	var n := spots.size()
	var cache := {}
	var subset_count := 1 << n
	for mask in subset_count:
		var filtered := _filter_mask(opts.get("action_log", []), spots, mask)
		var one := opts.duplicate(true)
		one["action_log"] = filtered
		var result: Dictionary = await Counterfactual.replay(tree, one)
		cache[mask] = {"score": score_of(result, kind), "result": result}
	var shapley := {}
	var fact_n := _factorial(n)
	for i in n:
		var acc := 0.0
		for mask in subset_count:
			if (mask & (1 << i)) != 0:
				continue
			var s := _popcount(mask)
			var weight := float(_factorial(s) * _factorial(n - s - 1)) / float(fact_n)
			var with_i := float(cache[mask | (1 << i)].score)
			var without_v := float(cache[mask].score)
			acc += weight * (with_i - without_v)
		shapley[spots[i]] = acc
	var grand := float(cache[subset_count - 1].score)
	var empty := float(cache[0].score)
	return _pack(spots, shapley, grand, empty, n, kind, "exact", subset_count, opts, cache[subset_count - 1].result, HIGH_CONF(n))


static func _sampled(tree: SceneTree, opts: Dictionary, spots: PackedStringArray, kind: String) -> Dictionary:
	var n := spots.size()
	var samples := int(opts.get("shapley_samples", DEFAULT_SAMPLES))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 7))
	var cache := {}
	var shapley_acc := {}
	for sid in spots:
		shapley_acc[sid] = 0.0
	for _s in samples:
		var order: Array = []
		for i in n:
			order.append(i)
		_shuffle(order, rng)
		var mask := 0
		var prev := await _cached_score(tree, opts, spots, mask, kind, cache)
		for idx in order:
			mask = mask | (1 << int(idx))
			var now := await _cached_score(tree, opts, spots, mask, kind, cache)
			shapley_acc[spots[int(idx)]] = float(shapley_acc[spots[int(idx)]]) + (now - prev)
			prev = now
	var shapley := {}
	for sid in spots:
		shapley[sid] = float(shapley_acc[sid]) / float(maxi(samples, 1))
	var full_mask := (1 << n) - 1
	var grand := await _cached_score(tree, opts, spots, full_mask, kind, cache)
	var empty := await _cached_score(tree, opts, spots, 0, kind, cache)
	var full_result: Dictionary = cache[full_mask].result
	return _pack(spots, shapley, grand, empty, n, kind, "sampled", samples, opts, full_result, "MEDIUM")


static func _cached_score(tree: SceneTree, opts: Dictionary, spots: PackedStringArray, mask: int, kind: String, cache: Dictionary) -> float:
	if cache.has(mask):
		return float(cache[mask].score)
	var filtered := _filter_mask(opts.get("action_log", []), spots, mask)
	var one := opts.duplicate(true)
	one["action_log"] = filtered
	var result: Dictionary = await Counterfactual.replay(tree, one)
	cache[mask] = {"score": score_of(result, kind), "result": result}
	return float(cache[mask].score)


static func _pack(spots: PackedStringArray, shapley: Dictionary, grand: float, empty: float, n: int, kind: String, mode: String, sample_count: int, opts: Dictionary, full_result: Dictionary, confidence: String) -> Dictionary:
	var sum := 0.0
	for k in shapley.keys():
		sum += float(shapley[k])
	var by_tower: Array = []
	var replay_log: Array = opts.get("action_log", [])
	for sid in spots:
		var row: Dictionary = _row_for_spot(full_result, str(sid))
		var cost := Counterfactual.cost_for(str(row.get("tower_type", "")), replay_log, str(sid))
		var direct := float(row.get("damage", 0.0))
		var sv := float(shapley.get(sid, 0.0))
		by_tower.append({
			"tower_id": str(row.get("tower_type", "")),
			"spot_id": str(sid),
			"cost": cost,
			"direct_value": direct,
			"counterfactual_value": sv,
			"shapley_value": sv,
			"shapley_value_per_gold": sv / maxf(cost, 1.0),
			"synergy_delta": sv - direct,
			"confidence": confidence,
			"sample_count": sample_count,
		})
	return {
		"skipped": false,
		"n": n,
		"score": kind,
		"mode": mode,
		"shapley": shapley,
		"by_tower": by_tower,
		"grand_coalition": grand,
		"empty_coalition": empty,
		"sum": sum,
		"sum_matches_grand": absf(sum - (grand - empty)) < maxf(0.5, absf(grand - empty) * 0.08),
		"max_n": MAX_EXACT,
		"sample_count": sample_count,
		"confidence": confidence,
	}


static func HIGH_CONF(n: int) -> String:
	return "HIGH" if n <= MAX_EXACT else "MEDIUM"


static func _filter_mask(replay_log: Array, spots: PackedStringArray, mask: int) -> Array:
	var keep := {}
	for i in spots.size():
		if (mask & (1 << i)) != 0:
			keep[spots[i]] = true
	var out: Array = []
	for entry in replay_log:
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


static func _row_for_spot(result: Dictionary, spot_id: String) -> Dictionary:
	for row in result.get("tower_stats", []):
		if str(row.get("spot_id")) == spot_id:
			return row
	return {}


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


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
