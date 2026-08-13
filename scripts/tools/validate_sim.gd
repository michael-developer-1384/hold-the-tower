extends SceneTree

## Deterministic simulation regression test.
## godot --headless --path . --script res://scripts/tools/validate_sim.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_sim: starting")
	var ok := true
	ok = (await _test_seeded_replay()) and ok
	ok = (await _test_agent_completes("random")) and ok
	ok = (await _test_agent_completes("basic")) and ok
	ok = (await _test_agent_completes("smart")) and ok
	if ok:
		print("validate_sim: OK")
		quit(0)
	else:
		print("validate_sim: FAILED")
		quit(1)


func _make_sim(opts: Dictionary):
	var script = load("res://scripts/sim/game_simulation.gd")
	var sim = script.new()
	sim.setup(opts, self)
	return sim


func _test_seeded_replay() -> bool:
	print("test: seeded replay")
	var a := await _scripted_run(12345)
	var b := await _scripted_run(12345)
	if a.is_empty() or b.is_empty():
		push_error("Empty scripted result")
		return false
	for key in ["won", "enemies_killed", "enemies_leaked", "lives_remaining", "waves_reached", "towers_placed"]:
		if a.get(key) != b.get(key):
			push_error("Mismatch %s: %s vs %s" % [key, str(a.get(key)), str(b.get(key))])
			return false
	print("  seeded replay matched won=%s killed=%s lives=%s" % [
		str(a.get("won")), str(a.get("enemies_killed")), str(a.get("lives_remaining"))
	])
	return true


func _scripted_run(p_seed: int) -> Dictionary:
	var sim = _make_sim({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": p_seed,
		"time_scale": 50.0,
		"max_sim_seconds": 900.0,
	})
	await sim.await_ready()
	Engine.max_fps = 0
	var speed := 50.0
	Engine.time_scale = speed
	Engine.max_physics_steps_per_frame = 64
	var clock_dt := (1.0 / 60.0) * speed

	var scripted := [
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_C"},
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_B"},
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_A"},
		{"type": "START_WAVE"},
	]
	for action in scripted:
		sim.execute(action)
		for _i in 3:
			await physics_frame
			sim.clock.step(clock_dt)

	var frames := 0
	while not sim.is_finished() and frames < 120000:
		var st: Dictionary = sim.state()
		if not bool(st.get("wave_running")) and not bool(st.get("game_over")) and not bool(st.get("level_complete")):
			if int(st.get("gold", 0)) >= 150:
				var upgraded := false
				for a in sim.get_available_actions():
					if str(a.get("type")) == "UPGRADE_TOWER" and str(a.get("runtime_id")) == "T0001":
						sim.execute(a)
						upgraded = true
						break
				if not upgraded:
					for a2 in sim.get_available_actions():
						if str(a2.get("type")) == "PLACE_TOWER" and str(a2.get("tower_id")) == "basic_tower":
							sim.execute(a2)
							break
			sim.execute({"type": "START_WAVE"})
		await physics_frame
		sim.clock.step(clock_dt)
		frames += 1

	Engine.time_scale = 1.0
	var result: Dictionary = sim.finish()
	sim.cleanup()
	await process_frame
	return result


func _test_agent_completes(agent_id: String) -> bool:
	print("test: agent completes (%s)" % agent_id)
	var BatchRunnerScript = load("res://scripts/sim/balance/batch_runner.gd")
	var r: Dictionary = await BatchRunnerScript.run_one(self, {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 7,
		"agent_id": agent_id,
		"time_scale": 50.0,
		"max_sim_seconds": 900.0,
	})
	if not r.has("won"):
		push_error("Agent %s produced incomplete result: %s" % [agent_id, str(r)])
		return false
	print("  %s finished won=%s waves=%s duration=%.1fs speed=%.0fx" % [
		agent_id, str(r.get("won")), str(r.get("waves_reached")),
		float(r.get("duration", 0.0)), float(r.get("sim_speed", 0.0))
	])
	return true
