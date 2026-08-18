extends RefCounted

## Optional health × speed grid on a frozen log.

const CF := preload("res://scripts/balance/counterfactual_runner.gd")
const Full := preload("res://scripts/balance/full_build_benchmark.gd")


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var h0 := float(opts.get("health_min", 0.9))
	var h1 := float(opts.get("health_max", 1.5))
	var s0 := float(opts.get("speed_min", 0.9))
	var s1 := float(opts.get("speed_max", 1.5))
	var step := float(opts.get("step", 0.1))
	var cells: Array = []
	var h := h0
	while h <= h1 + 0.0001:
		var s := s0
		while s <= s1 + 0.0001:
			var replay_opts := opts.duplicate(true)
			replay_opts["action_log"] = log
			var cfg: Dictionary = replay_opts.get("config", {"starting_gold": 1000}).duplicate(true)
			cfg["enemy_health"] = snapped(h, 0.01)
			cfg["enemy_speed"] = snapped(s, 0.01)
			replay_opts["config"] = cfg
			var result: Dictionary = await CF.replay(tree, replay_opts)
			cells.append({
				"enemy_health": snapped(h, 0.01),
				"enemy_speed": snapped(s, 0.01),
				"outcome": Full._outcome(result),
				"core_hp": int(result.get("lives_remaining", 0)),
				"leaks": int(result.get("enemies_leaked", 0)),
				"won": bool(result.get("won", false)),
			})
			s += step
		h += step
	return {
		"measured": true,
		"health_min": h0,
		"health_max": h1,
		"speed_min": s0,
		"speed_max": s1,
		"step": step,
		"cells": cells,
	}
