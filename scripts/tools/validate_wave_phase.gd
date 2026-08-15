extends SceneTree

## Wave phase duration, early-call bonus, overlap, auto-start.
## godot --headless --path . --script res://scripts/tools/validate_wave_phase.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_wave_phase: starting")
	var ok := true
	ok = _test_path_duration() and ok
	ok = (await _test_manual_bonus_and_overlap()) and ok
	ok = (await _test_auto_zero_bonus()) and ok
	ok = (await _test_bonus_endpoints()) and ok
	if ok:
		print("validate_wave_phase: PASS")
		quit(0)
	else:
		print("validate_wave_phase: FAIL")
		quit(1)


func _test_path_duration() -> bool:
	var PathTravel = load("res://scripts/level/path_travel.gd")
	var WaveCatalog = load("res://scripts/waves/wave_catalog.gd")
	var path := PackedVector3Array([
		Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10), Vector3(0, 0, 10),
	])
	var length: float = PathTravel.path_length(path)
	if length < 29.0 or length > 31.0:
		print("  path_length FAIL  got=%.2f" % length)
		return false
	var d: float = PathTravel.wave_phase_duration(path, WaveCatalog.get_wave(1), 1.0)
	if d < 5.0:
		print("  wave_phase_duration FAIL  too small %.2f" % d)
		return false
	print("  path_duration PASS  length=%.1f D=%.1f" % [length, d])
	return true


func _boot_sim():
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 11,
		"record": "none",
		"max_sim_seconds": 600.0,
		"time_scale": 1.0,
	}, self)
	await sim.await_ready()
	return sim


func _test_manual_bonus_and_overlap() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	var gold0: int = int(game.get("gold"))
	if not bool(game.call("start_next_wave", true)):
		print("  manual overlap FAIL  could not start wave 1")
		sim.cleanup()
		return false
	# Advance a little, then early-call wave 2 while wave 1 still running.
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	for _i in 30:
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
	var bonus: int = int(game.call("current_call_bonus"))
	var gold1: int = int(game.get("gold"))
	if not bool(game.call("start_next_wave", true)):
		print("  manual overlap FAIL  could not start wave 2")
		sim.cleanup()
		return false
	var gold2: int = int(game.get("gold"))
	var awarded: int = gold2 - gold1
	var waves: int = int(game.get("waves_started"))
	var alive: int = int(game.get("enemies_alive"))
	var spawning: bool = bool(sim.wave_manager.call("is_spawning"))
	var ok := waves >= 2 and awarded == bonus and (alive > 0 or spawning)
	if ok:
		print("  manual overlap PASS  bonus=%d awarded=%d waves=%d alive=%d" % [bonus, awarded, waves, alive])
	else:
		print("  manual overlap FAIL  bonus=%d awarded=%d waves=%d alive=%d gold0=%d" % [
			bonus, awarded, waves, alive, gold0,
		])
	sim.cleanup()
	await process_frame
	return ok


func _test_auto_zero_bonus() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	game.call("start_next_wave", true)
	# Force short phase so auto fires quickly.
	game.set("phase_duration", 0.2)
	game.set("phase_pause", 0.2)
	game.set("phase_elapsed", 0.0)
	game.set("_auto_start_armed", true)
	var gold_before: int = int(game.get("gold"))
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	for _i in 120:
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		if int(game.get("waves_started")) >= 2:
			break
	var gold_after: int = int(game.get("gold"))
	# Kill gold may have arrived; auto itself must not grant call bonus.
	# Detect by ensuring waves_started advanced while call_bonus at fire time would be ~0.
	var ok := int(game.get("waves_started")) >= 2
	# Re-run: at the moment auto arms at end, bonus must be 0.
	game.set("phase_elapsed", float(game.get("phase_duration")) + float(game.get("phase_pause")))
	var end_bonus: int = int(game.call("current_call_bonus"))
	ok = ok and end_bonus == 0
	if ok:
		print("  auto zero PASS  waves=%d end_bonus=%d gold_delta=%d" % [
			int(game.get("waves_started")), end_bonus, gold_after - gold_before,
		])
	else:
		print("  auto zero FAIL  waves=%d end_bonus=%d" % [int(game.get("waves_started")), end_bonus])
	sim.cleanup()
	await process_frame
	return ok


func _test_bonus_endpoints() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	game.call("start_next_wave", true)
	game.set("phase_elapsed", 0.0)
	var at_start: int = int(game.call("current_call_bonus"))
	game.set("phase_elapsed", float(game.get("phase_duration")) + float(game.get("phase_pause")))
	var at_end: int = int(game.call("current_call_bonus"))
	var ok := at_start == int(game.get("call_bonus_cap")) and at_end == 0
	if ok:
		print("  bonus endpoints PASS  start=%d end=%d" % [at_start, at_end])
	else:
		print("  bonus endpoints FAIL  start=%d end=%d cap=%s" % [
			at_start, at_end, str(game.get("call_bonus_cap")),
		])
	sim.cleanup()
	await process_frame
	return ok
