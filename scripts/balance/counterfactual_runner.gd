extends RefCounted

## Replay a run with one PLACE neutralized. Other actions stay at the same times.


static func filter_log(action_log: Array, spot_id: String) -> Array:
	var out: Array = []
	for entry in action_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		var t := str(action.get("type", ""))
		if t == "PLACE_TOWER" and str(action.get("spot_id", "")) == spot_id:
			continue
		if t == "UPGRADE_TOWER" and str(action.get("spot_id", "")) == spot_id:
			continue
		out.append(entry)
	return out


static func placed_spots(action_log: Array) -> PackedStringArray:
	var spots: PackedStringArray = PackedStringArray()
	for entry in action_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		if str(action.get("type", "")) != "PLACE_TOWER":
			continue
		var sid := str(action.get("spot_id", ""))
		if sid.is_empty() or sid in spots:
			continue
		spots.append(sid)
	return spots


static func replay(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var sim_opts := {
		"level_id": str(opts.get("level_id", "vertical_test")),
		"difficulty_id": str(opts.get("difficulty_id", "normal")),
		"seed": int(opts.get("seed", 7)),
		"config": opts.get("config", {"starting_gold": 1000}),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
	}
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup(sim_opts, tree)
	sim.set_replay(log)
	await sim.await_ready()
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(tree, sim, {
		"time_scale": float(opts.get("time_scale", 40.0)),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
		"decide": false,
	})
	var result: Dictionary = sim.finish()
	result["replayed_action_log"] = sim.action_log.duplicate(true)
	sim.cleanup()
	await tree.process_frame
	return result


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var spot_id := str(opts.get("spot_id", ""))
	var baseline: Dictionary = await replay(tree, opts)
	var without_opts := opts.duplicate(true)
	without_opts["action_log"] = filter_log(log, spot_id)
	var without: Dictionary = await replay(tree, without_opts)
	return {
		"spot_id": spot_id,
		"baseline": baseline,
		"without": without,
		"filtered_log": without_opts["action_log"],
		"other_actions_unchanged": _same_non_target_actions(log, without.get("replayed_action_log", []), spot_id),
		"delta": _delta(baseline, without),
	}


static func _same_non_target_actions(original: Array, replayed: Array, spot_id: String) -> bool:
	var a := _compact(original, spot_id)
	var b := _compact(replayed, spot_id)
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i].get("type")) != str(b[i].get("type")):
			return false
		if str(a[i].get("spot_id", "")) != str(b[i].get("spot_id", "")):
			return false
		if str(a[i].get("tower_id", "")) != str(b[i].get("tower_id", "")):
			return false
	return true


static func _compact(log: Array, skip_spot: String) -> Array:
	var out: Array = []
	for entry in log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		if str(action.get("spot_id", "")) == skip_spot:
			continue
		out.append(action)
	return out


static func _delta(baseline: Dictionary, without: Dictionary) -> Dictionary:
	return {
		"delta_total_damage": float(baseline.get("total_damage", 0.0)) - float(without.get("total_damage", 0.0)),
		"delta_leaks": int(baseline.get("enemies_leaked", 0)) - int(without.get("enemies_leaked", 0)),
		"delta_core_hp": int(baseline.get("lives_remaining", 0)) - int(without.get("lives_remaining", 0)),
		"delta_duration": float(baseline.get("duration", 0.0)) - float(without.get("duration", 0.0)),
		"delta_kills": int(baseline.get("enemies_killed", 0)) - int(without.get("enemies_killed", 0)),
		"delta_other_tower_damage": _other_damage(baseline) - _other_damage(without),
	}


static func _other_damage(result: Dictionary) -> float:
	# Used after pairing; here it's total. SynergyAnalyzer splits per tower.
	return float(result.get("total_damage", 0.0))
