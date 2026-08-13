extends SceneTree

## Snapshot at t=60, continue +30s vs restore+continue.
## godot --headless --path . --script res://scripts/tools/validate_sim_clone.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_sim_clone: starting")
	var log_run: Dictionary = await _scripted(90.0, {}, [])
	var log: Array = log_run.get("action_log", [])
	print("  recorded %d actions over %.1fs" % [log.size(), float(log_run.get("duration", 0.0))])

	var original: Dictionary = await _scripted(90.0, {}, log)
	var split: Dictionary = await _clone_split(log, 60.0, 30.0)
	var a: Dictionary = original
	var b: Dictionary = split
	var ok := true
	var diffs: Array = []
	for k in ["won", "waves_reached", "enemies_killed", "enemies_leaked", "lives_remaining", "towers_placed", "gold"]:
		if a.get(k) != b.get(k):
			ok = false
			diffs.append("%s  %s vs %s" % [k, str(a.get(k)), str(b.get(k))])
	for fk in ["total_damage", "core_hp_end"]:
		if absf(float(a.get(fk, 0.0)) - float(b.get(fk, 0.0))) > 0.75:
			ok = false
			diffs.append("%s  %s vs %s" % [fk, str(a.get(fk)), str(b.get(fk))])

	print("  original@90  killed=%s lives=%s gold=%s dmg=%.1f" % [
		str(a.get("enemies_killed")), str(a.get("lives_remaining")), str(a.get("gold")), float(a.get("total_damage", 0.0))
	])
	print("  clone@90     killed=%s lives=%s gold=%s dmg=%.1f" % [
		str(b.get("enemies_killed")), str(b.get("lives_remaining")), str(b.get("gold")), float(b.get("total_damage", 0.0))
	])
	if ok:
		print("validate_sim_clone: PASS")
		quit(0)
	else:
		print("validate_sim_clone: FAIL")
		for d in diffs:
			print("  %s" % d)
		quit(1)


func _scripted(until: float, _unused: Dictionary, replay: Array) -> Dictionary:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var Policy = load("res://scripts/sim/fidelity/scripted_policy.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 42,
		"time_scale": 1.0,
		"max_sim_seconds": until + 1.0,
	}, self)
	await sim.await_ready()
	if replay.is_empty():
		for a in Policy.opening_actions():
			sim.execute(a)
	else:
		sim.set_replay(replay)
	SimRunner.apply_speed(1.0)
	var frames := 0
	while not sim.is_finished() and sim.clock.sim_time < until and frames < 200000:
		if replay.is_empty():
			Policy.maybe_act(sim)
		else:
			sim.replay_due_actions()
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		frames += 1
	SimRunner.restore()
	var result: Dictionary = sim.finish()
	result["gold"] = int(sim.state().get("gold", 0))
	result["core_hp_end"] = int(sim.state().get("core_hp", 0))
	sim.cleanup()
	await process_frame
	return result


func _clone_split(replay: Array, capture_at: float, extra: float) -> Dictionary:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var Snap = load("res://scripts/sim/sim_snapshot.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 42,
		"time_scale": 1.0,
		"max_sim_seconds": capture_at + extra + 1.0,
	}, self)
	await sim.await_ready()
	sim.set_replay(replay)
	SimRunner.apply_speed(1.0)
	var frames := 0
	while not sim.is_finished() and sim.clock.sim_time < capture_at and frames < 200000:
		sim.replay_due_actions()
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		frames += 1
	var snap: Dictionary = Snap.capture(sim)
	sim.cleanup()
	await process_frame

	var clone_sim = SimScript.new()
	clone_sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 42,
		"time_scale": 1.0,
		"max_sim_seconds": capture_at + extra + 1.0,
	}, self)
	await clone_sim.await_ready()
	Snap.restore(clone_sim, snap)
	clone_sim.set_replay(replay)
	var target := capture_at + extra
	frames = 0
	while not clone_sim.is_finished() and clone_sim.clock.sim_time < target and frames < 200000:
		clone_sim.replay_due_actions()
		await physics_frame
		clone_sim.clock.step(SimRunner.STEP)
		frames += 1
	SimRunner.restore()
	var result: Dictionary = clone_sim.finish()
	result["gold"] = int(clone_sim.state().get("gold", 0))
	result["core_hp_end"] = int(clone_sim.state().get("core_hp", 0))
	clone_sim.cleanup()
	await process_frame
	return result
