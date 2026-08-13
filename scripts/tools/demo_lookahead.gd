extends SceneTree

## One-shot true-lookahead example.
## godot --headless --path . --script res://scripts/tools/demo_lookahead.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 7,
		"time_scale": 10.0,
	}, self)
	await sim.await_ready()
	SimRunner.apply_speed(10.0)
	sim.execute({"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_C"})
	for _i in 3:
		await physics_frame
		sim.clock.step(SimRunner.STEP)

	var picked: Array = []
	for a in sim.get_available_actions():
		var key := "%s:%s:%s" % [str(a.get("type")), str(a.get("tower_id")), str(a.get("spot_id"))]
		if key == "PLACE_TOWER:basic_tower:F2_C" or key == "PLACE_TOWER:guard_post:F1_A" or str(a.get("type")) == "START_WAVE":
			picked.append(a)
	if picked.is_empty():
		picked = sim.get_available_actions().slice(0, mini(3, sim.get_available_actions().size()))

	print("LOOKAHEAD DEMO  t=%.2f gold=%s towers=%s" % [
		sim.clock.sim_time, str(sim.state().get("gold")), str(sim.state().get("towers").size())
	])
	var best := {}
	var best_s := -99999.0
	for a in picked:
		var t0 := Time.get_ticks_msec()
		var score: float = await sim.evaluate_action_with_lookahead(a, 3.0)
		print("  %s  future_score=%.1f  eval_ms=%d" % [_label(a), score, Time.get_ticks_msec() - t0])
		if score > best_s:
			best_s = score
			best = a
	print("Chosen: %s  (%.1f)" % [_label(best), best_s])
	var ls: Dictionary = sim.lookahead_stats
	print("clone_ms_avg=%.0f  evals=%d  future_seconds=%.1f" % [
		float(ls.get("clone_ms_sum", 0.0)) / maxf(float(ls.get("evals", 1)), 1.0),
		int(ls.get("evals", 0)),
		float(ls.get("future_seconds", 0.0)),
	])
	SimRunner.restore()
	sim.cleanup()
	quit(0)


func _label(a: Dictionary) -> String:
	var t := str(a.get("type", "?"))
	if t == "PLACE_TOWER":
		return "PLACE %s %s" % [str(a.get("tower_id")), str(a.get("spot_id"))]
	if t == "UPGRADE_TOWER":
		return "UPGRADE %s" % str(a.get("runtime_id"))
	return t
