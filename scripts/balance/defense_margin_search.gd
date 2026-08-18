extends RefCounted

## Bracket then binary-search combined pressure (health×speed) on a frozen log.

const CF := preload("res://scripts/balance/counterfactual_runner.gd")
const Full := preload("res://scripts/balance/full_build_benchmark.gd")

const AXES := ["enemy_health", "enemy_speed", "spawn_rate", "enemy_count"]


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var baseline: Dictionary = await _replay_pressure(tree, opts, replay_log, 1.0, 1.0)
	if not bool(baseline.get("won", false)):
		return {
			"measured": true,
			"base_result": Full.outcome_of(baseline),
			"max_survivable_pressure": null,
			"failure_pressure": 1.0,
			"margin": 0.0,
			"core_hp_at_base": int(baseline.get("lives_remaining", 0)),
			"leaks_at_threshold": int(baseline.get("enemies_leaked", 0)),
			"confidence": "HIGH",
			"axes": {},
		}
	var bracket := await _bracket(tree, opts, replay_log)
	var lo := float(bracket.get("lo", 1.0))
	var hi := float(bracket.get("hi", 1.05))
	var iters := int(opts.get("iters", 6))
	for _i in iters:
		var mid := (lo + hi) * 0.5
		var r: Dictionary = await _replay_pressure(tree, opts, replay_log, mid, mid)
		if bool(r.get("won", false)):
			lo = mid
		else:
			hi = mid
	var at_lo: Dictionary = await _replay_pressure(tree, opts, replay_log, lo, lo)
	var axes := {}
	if bool(opts.get("include_axes", true)):
		for axis in opts.get("axes", AXES):
			axes[str(axis)] = await _search_axis(tree, opts, replay_log, str(axis), 1.0, float(opts.get("hi", 2.2)), int(opts.get("axis_iters", 5)))
	return {
		"measured": true,
		"base_result": Full.outcome_of(baseline),
		"max_survivable_pressure": lo,
		"failure_pressure": hi,
		"margin": lo,
		"core_hp_at_base": int(baseline.get("lives_remaining", 0)),
		"leaks_at_threshold": int(at_lo.get("enemies_leaked", 0)),
		"confidence": "HIGH",
		"axes": axes,
	}


static func _bracket(tree: SceneTree, opts: Dictionary, replay_log: Array) -> Dictionary:
	var lo := 1.0
	var hi := 1.05
	var cap := float(opts.get("hi", 2.4))
	while hi <= cap:
		var r: Dictionary = await _replay_pressure(tree, opts, replay_log, hi, hi)
		if not bool(r.get("won", false)):
			return {"lo": lo, "hi": hi}
		lo = hi
		hi = snapped(hi + 0.05, 0.01)
	return {"lo": lo, "hi": hi}


static func _search_axis(tree: SceneTree, opts: Dictionary, replay_log: Array, axis: String, lo0: float, hi0: float, iters: int) -> Dictionary:
	var baseline: Dictionary = await _replay_mult(tree, opts, replay_log, axis, 1.0)
	var low := lo0
	var high := hi0
	var first_loss: Variant = null
	for _i in iters:
		var mid := (low + high) * 0.5
		var r: Dictionary = await _replay_mult(tree, opts, replay_log, axis, mid)
		if not bool(r.get("won", false)):
			first_loss = mid
			high = mid
		else:
			low = mid
	return {
		"axis": axis,
		"max_survivable": low,
		"failure_pressure": high,
		"first_loss_multiplier": first_loss,
		"baseline_won": bool(baseline.get("won", false)),
	}


static func _replay_pressure(tree: SceneTree, opts: Dictionary, replay_log: Array, health_m: float, speed_m: float) -> Dictionary:
	var replay_opts := opts.duplicate(true)
	replay_opts["action_log"] = replay_log
	var cfg: Dictionary = replay_opts.get("config", {"starting_gold": 1000}).duplicate(true)
	cfg["enemy_health"] = health_m
	cfg["enemy_speed"] = speed_m
	replay_opts["config"] = cfg
	return await CF.replay(tree, replay_opts)


static func _replay_mult(tree: SceneTree, opts: Dictionary, replay_log: Array, axis: String, mult: float) -> Dictionary:
	var replay_opts := opts.duplicate(true)
	replay_opts["action_log"] = replay_log
	var cfg: Dictionary = replay_opts.get("config", {"starting_gold": 1000}).duplicate(true)
	cfg[axis] = mult
	replay_opts["config"] = cfg
	return await CF.replay(tree, replay_opts)
