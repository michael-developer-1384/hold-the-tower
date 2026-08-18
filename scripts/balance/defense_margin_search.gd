extends RefCounted

## Binary-search one SimContext axis at a time on a frozen log.

const CF := preload("res://scripts/balance/counterfactual_runner.gd")

const AXES := ["enemy_health", "enemy_speed", "spawn_rate", "enemy_count"]


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var axes: Array = opts.get("axes", AXES)
	var lo := float(opts.get("lo", 1.0))
	var hi := float(opts.get("hi", 3.0))
	var iters := int(opts.get("iters", 8))
	var out := {}
	for axis in axes:
		out[str(axis)] = await _search_axis(tree, opts, log, str(axis), lo, hi, iters)
	return {"measured": true, "axes": out}


static func _search_axis(tree: SceneTree, opts: Dictionary, log: Array, axis: String, lo: float, hi: float, iters: int) -> Dictionary:
	var first_leak: Variant = null
	var first_core: Variant = null
	var first_loss: Variant = null
	var baseline: Dictionary = await _replay_mult(tree, opts, log, axis, 1.0)
	var core0 := int(baseline.get("lives_remaining", 0))
	var low := lo
	var high := hi
	for _i in iters:
		var mid := (low + high) * 0.5
		var r: Dictionary = await _replay_mult(tree, opts, log, axis, mid)
		var leak := int(r.get("enemies_leaked", 0)) > 0
		var core_drop := int(r.get("lives_remaining", core0)) < core0
		var loss := not bool(r.get("won", false))
		if leak and first_leak == null:
			first_leak = mid
		if core_drop and first_core == null:
			first_core = mid
		if loss and first_loss == null:
			first_loss = mid
		if leak or core_drop or loss:
			high = mid
		else:
			low = mid
	return {
		"axis": axis,
		"first_leak_multiplier": first_leak,
		"first_core_damage_multiplier": first_core,
		"first_loss_multiplier": first_loss,
		"baseline_core_hp": core0,
		"baseline_leaks": int(baseline.get("enemies_leaked", 0)),
		"baseline_won": bool(baseline.get("won", false)),
	}


static func _replay_mult(tree: SceneTree, opts: Dictionary, log: Array, axis: String, mult: float) -> Dictionary:
	var replay_opts := opts.duplicate(true)
	replay_opts["action_log"] = log
	var cfg: Dictionary = replay_opts.get("config", {"starting_gold": 1000}).duplicate(true)
	cfg[axis] = mult
	replay_opts["config"] = cfg
	return await CF.replay(tree, replay_opts)
