extends RefCounted

## Short PLAY-graph fidelity probe: same scripted log at 1x and 40x.


const Tolerances := preload("res://scripts/balance/metrics/fidelity_tolerances.gd")
const Policy := preload("res://scripts/sim/fidelity/scripted_policy.gd")


static func run(tree: SceneTree, opts: Dictionary = {}) -> Dictionary:
	var duration := float(opts.get("duration", 12.0))
	var seed_value := int(opts.get("seed", 12345))
	var record: Dictionary = await _run_speed(tree, 1.0, [], true, duration, seed_value)
	if record.is_empty():
		return {
			"status": "BLOCKED",
			"confidence": "NOT_MEASURED",
			"reason": "Could not record baseline fidelity fixture.",
			"compared_metrics": {},
			"deviations": [],
			"max_relative_error": null,
		}
	var replay_log: Array = record.get("action_log", [])
	var fast: Dictionary = await _run_speed(tree, 40.0, replay_log, false, duration, seed_value)
	var compared := {
		"spawn_count": {"a": record.get("enemies_spawned"), "b": fast.get("enemies_spawned")},
		"damage_dealt": {"a": record.get("total_damage"), "b": fast.get("total_damage")},
		"kills": {"a": record.get("enemies_killed"), "b": fast.get("enemies_killed")},
		"leaks": {"a": record.get("enemies_leaked"), "b": fast.get("enemies_leaked")},
		"blocking_duration": {"a": record.get("block_seconds"), "b": fast.get("block_seconds")},
		"projectile_hits": {"a": record.get("total_hits"), "b": fast.get("total_hits")},
		"cross_floor_hits": {"a": record.get("cross_floor_damage"), "b": fast.get("cross_floor_damage")},
		"tower_fire_count": {"a": record.get("total_shots"), "b": fast.get("total_shots")},
		"core_hp": {"a": record.get("lives_remaining"), "b": fast.get("lives_remaining")},
		"economy": {"a": record.get("gold"), "b": fast.get("gold")},
		"wave_timing": {"a": record.get("duration"), "b": fast.get("duration")},
		"enemy_path_progress": {"a": record.get("path_progress_sum"), "b": fast.get("path_progress_sum")},
	}
	var deviations: Array = []
	var max_rel := 0.0
	for metric in compared.keys():
		var pair: Dictionary = compared[metric]
		var a = pair.get("a")
		var b = pair.get("b")
		if a == null or b == null:
			deviations.append({
				"metric": metric,
				"status": "NOT_MEASURED",
				"reason": "Metric missing from simulation result.",
			})
			continue
		var rel := Tolerances.relative_error(a, b)
		max_rel = maxf(max_rel, rel)
		if not Tolerances.within(str(metric), a, b):
			deviations.append({
				"metric": metric,
				"a": a,
				"b": b,
				"relative_error": rel,
				"status": "FAIL",
			})
	var status := "PASS"
	if not deviations.is_empty():
		status = "FAIL"
		for d in deviations:
			if str(d.get("status")) == "NOT_MEASURED":
				status = "BLOCKED"
				break
	return {
		"status": status,
		"confidence": "HIGH" if status == "PASS" else ("LOW" if status == "FAIL" else "NOT_MEASURED"),
		"compared_metrics": compared,
		"deviations": deviations,
		"max_relative_error": max_rel,
		"speeds": [1.0, 40.0],
		"duration": duration,
		"seed": seed_value,
	}


static func _run_speed(tree: SceneTree, speed: float, replay_log: Array, record_policy: bool, duration: float, seed_value: int) -> Dictionary:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": seed_value,
		"time_scale": speed,
		"max_sim_seconds": duration + 2.0,
		"config": {"starting_gold": 1000},
	}, tree)
	await sim.await_ready()
	if not record_policy:
		sim.set_replay(replay_log)
	else:
		for action in Policy.opening_actions():
			sim.execute(action)
	SimRunner.apply_speed(speed)
	var frames := 0
	while not sim.is_finished() and sim.clock.sim_time + 0.0001 < duration and frames < 400000:
		if record_policy:
			Policy.maybe_act(sim)
		else:
			sim.replay_due_actions()
		await tree.physics_frame
		sim.clock.step(SimRunner.STEP)
		sim.after_tick()
		frames += 1
	SimRunner.restore()
	var result: Dictionary = sim.finish()
	result["gold"] = int(sim.state().get("gold", 0))
	result["path_progress_sum"] = _path_progress_sum(sim)
	result["block_seconds"] = _block_seconds(result)
	result["action_log"] = sim.action_log.duplicate(true)
	sim.cleanup()
	await tree.process_frame
	return result


static func _path_progress_sum(sim) -> float:
	var total := 0.0
	if sim == null or sim.game == null or sim.game.get_tree() == null:
		return total
	for e in sim.game.get_tree().get_nodes_in_group("enemies"):
		if e != null and is_instance_valid(e) and e.has_method("get_path_progress"):
			total += float(e.call("get_path_progress"))
	return total


static func _block_seconds(result: Dictionary) -> float:
	var acc := 0.0
	for row in result.get("tower_stats", []):
		acc += float(row.get("total_block_time_ms", 0.0)) / 1000.0
	return acc
