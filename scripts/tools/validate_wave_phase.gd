extends SceneTree

## Wave duration timer, spawn-complete early call, auto-start.
## godot --headless --path . --script res://scripts/tools/validate_wave_phase.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_wave_phase: starting")
	var ok := true
	ok = _test_path_duration() and ok
	ok = (await _test_blocked_until_spawn_done()) and ok
	ok = (await _test_manual_bonus_after_spawn()) and ok
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


func _force_spawn_done(sim) -> void:
	var game = sim.game
	if sim.wave_manager and sim.wave_manager.has_method("stop_all"):
		sim.wave_manager.call("stop_all")
	game.set("_spawn_finished", true)
	game.set("_bonus_decay_start", float(game.get("phase_elapsed")))
	if game.has_method("_emit_call_bonus"):
		game.call("_emit_call_bonus", true)


func _test_blocked_until_spawn_done() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	if not bool(game.call("start_next_wave", true)):
		print("  spawn gate FAIL  could not start wave 1")
		sim.cleanup()
		return false
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	for _i in 20:
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
	var blocked := not bool(game.call("can_start_next_wave"))
	var started_two := bool(game.call("start_next_wave", true))
	var ok := blocked and not started_two and int(game.get("waves_started")) == 1
	if ok:
		print("  spawn gate PASS  blocked while spawning")
	else:
		print("  spawn gate FAIL  blocked=%s started_two=%s waves=%d" % [
			str(blocked), str(started_two), int(game.get("waves_started")),
		])
	sim.cleanup()
	await process_frame
	return ok


func _test_manual_bonus_after_spawn() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	if not bool(game.call("start_next_wave", true)):
		print("  manual bonus FAIL  could not start wave 1")
		sim.cleanup()
		return false
	_force_spawn_done(sim)
	if not bool(game.call("can_start_next_wave")):
		print("  manual bonus FAIL  should start after spawn complete")
		sim.cleanup()
		return false
	var bonus: int = int(game.call("current_call_bonus"))
	var gold1: int = int(game.get("gold"))
	var alive: int = int(game.get("enemies_alive"))
	if not bool(game.call("start_next_wave", true)):
		print("  manual bonus FAIL  could not start wave 2")
		sim.cleanup()
		return false
	var awarded: int = int(game.get("gold")) - gold1
	var waves: int = int(game.get("waves_started"))
	var ok := waves >= 2 and awarded == bonus and bonus == int(game.get("call_bonus_cap"))
	if ok:
		print("  manual bonus PASS  bonus=%d awarded=%d alive=%d waves=%d" % [
			bonus, awarded, alive, waves,
		])
	else:
		print("  manual bonus FAIL  bonus=%d awarded=%d waves=%d" % [bonus, awarded, waves])
	sim.cleanup()
	await process_frame
	return ok


func _test_auto_zero_bonus() -> bool:
	var sim = await _boot_sim()
	var game = sim.game
	game.call("start_next_wave", true)
	_force_spawn_done(sim)
	game.set("phase_duration", 0.2)
	game.set("phase_pause", 0.2)
	game.set("phase_elapsed", 0.0)
	game.set("_bonus_decay_start", 0.0)
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
	game.set("phase_elapsed", float(game.get("phase_duration")) + float(game.get("phase_pause")))
	var end_bonus: int = int(game.call("current_call_bonus"))
	var ok := int(game.get("waves_started")) >= 2 and end_bonus == 0
	if ok:
		print("  auto zero PASS  waves=%d end_bonus=%d gold_delta=%d" % [
			int(game.get("waves_started")), end_bonus, int(game.get("gold")) - gold_before,
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
	_force_spawn_done(sim)
	game.set("_bonus_decay_start", 0.0)
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
