extends SceneTree

## Save / load / replay-to-end plus seek 30 / 60 / 20 determinism.
## godot --headless --path . --script res://scripts/tools/validate_replay.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_replay: starting")
	var recorded: Dictionary = await _record_package()
	if recorded.has("error"):
		print("validate_replay: FAIL record  %s" % str(recorded.get("error")))
		quit(1)
		return
	var pkg: Dictionary = recorded.get("package", {})
	var path: String = str(recorded.get("path", ""))
	print("  saved %s  actions=%d  keyframes=%d  bytes=%s" % [
		path,
		(pkg.get("action_log", []) as Array).size(),
		(pkg.get("keyframes", []) as Array).size(),
		str(pkg.get("storage", {}).get("bytes", 0)),
	])

	var loaded: Dictionary = load("res://scripts/sim/replay/replay_store.gd").load_path(path)
	if loaded.has("error"):
		print("validate_replay: FAIL load  %s" % str(loaded.get("message", loaded.get("error"))))
		quit(1)
		return

	var baseline: Dictionary = pkg.get("final_result", {})
	var ok := true
	ok = (await _assert_replay_end(loaded, baseline, "load→end")) and ok
	ok = (await _assert_seek_then_end(loaded, baseline, 30.0, "seek30→end")) and ok
	ok = (await _assert_seek_then_end(loaded, baseline, 60.0, "seek60→end")) and ok
	ok = (await _assert_seek_chain(loaded, baseline, 60.0, 20.0, "seek60→20→end")) and ok

	if ok:
		print("validate_replay: PASS")
		quit(0)
	else:
		print("validate_replay: FAIL")
		quit(1)


func _record_package() -> Dictionary:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var Policy = load("res://scripts/sim/fidelity/scripted_policy.gd")
	var ReplayPackage = load("res://scripts/sim/replay/replay_package.gd")
	var ReplayStore = load("res://scripts/sim/replay/replay_store.gd")
	var opts := {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 42,
		"record": ReplayPackage.MODE_REPLAY,
		"max_sim_seconds": 130.0,
		"agent_id": "scripted",
	}
	var sim = SimScript.new()
	sim.setup(opts, self)
	await sim.await_ready()
	for a in Policy.opening_actions():
		sim.execute(a)
	SimRunner.apply_speed(40.0)
	var frames := 0
	while not sim.is_finished() and sim.clock.sim_time < 120.0 and frames < 200000:
		Policy.maybe_act(sim)
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		sim.after_tick()
		frames += 1
	SimRunner.restore()
	var result: Dictionary = sim.finish()
	result["gold"] = int(sim.state().get("gold", 0))
	var pkg: Dictionary = ReplayPackage.build(sim, opts, result)
	var path: String = ReplayStore.save(pkg)
	sim.cleanup()
	await process_frame
	if path.is_empty():
		return {"error": "save_failed"}
	return {"package": pkg, "path": path}


func _boot_replay(pkg: Dictionary):
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": str(pkg.get("level_id", "vertical_test")),
		"difficulty_id": str(pkg.get("difficulty_id", "normal")),
		"seed": int(pkg.get("seed", 42)),
		"record": "none",
		"max_sim_seconds": 180.0,
	}, self)
	await sim.await_ready()
	sim.set_replay(pkg.get("action_log", []))
	return sim


func _play_to_end(sim, until: float = -1.0) -> Dictionary:
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var cap := until if until > 0.0 else 180.0
	SimRunner.apply_speed(40.0)
	var frames := 0
	while not sim.is_finished() and frames < 200000:
		sim.replay_due_actions()
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		frames += 1
		if sim.clock and sim.clock.sim_time + 0.0001 >= cap:
			break
	SimRunner.restore()
	var result: Dictionary = sim.finish()
	result["gold"] = int(sim.state().get("gold", 0))
	result["core_hp_end"] = int(sim.state().get("core_hp", 0))
	return result


func _assert_replay_end(pkg: Dictionary, baseline: Dictionary, label: String) -> bool:
	var sim = await _boot_replay(pkg)
	var until := float(pkg.get("metrics", {}).get("duration", 120.0))
	var got: Dictionary = await _play_to_end(sim, until)
	sim.cleanup()
	await process_frame
	return _compare(label, baseline, got)


func _assert_seek_then_end(pkg: Dictionary, baseline: Dictionary, at: float, label: String) -> bool:
	var sim = await _boot_replay(pkg)
	var Seek = load("res://scripts/sim/replay/replay_seek.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	SimRunner.apply_speed(40.0)
	Seek.apply_seek(sim, pkg, at)
	await Seek.tick_toward(self, sim, at)
	SimRunner.restore()
	var until := float(pkg.get("metrics", {}).get("duration", 120.0))
	var got: Dictionary = await _play_to_end(sim, until)
	sim.cleanup()
	await process_frame
	return _compare(label, baseline, got)


func _assert_seek_chain(pkg: Dictionary, baseline: Dictionary, a: float, b: float, label: String) -> bool:
	var sim = await _boot_replay(pkg)
	var Seek = load("res://scripts/sim/replay/replay_seek.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	SimRunner.apply_speed(40.0)
	Seek.apply_seek(sim, pkg, a)
	await Seek.tick_toward(self, sim, a)
	Seek.apply_seek(sim, pkg, b)
	await Seek.tick_toward(self, sim, b)
	SimRunner.restore()
	var until := float(pkg.get("metrics", {}).get("duration", 120.0))
	var got: Dictionary = await _play_to_end(sim, until)
	sim.cleanup()
	await process_frame
	return _compare(label, baseline, got)


func _compare(label: String, a: Dictionary, b: Dictionary) -> bool:
	var ok := true
	var diffs: Array = []
	for k in ["won", "enemies_killed", "enemies_leaked", "lives_remaining"]:
		if a.get(k) != b.get(k):
			ok = false
			diffs.append("%s  %s vs %s" % [k, str(a.get(k)), str(b.get(k))])
	for fk in ["total_damage"]:
		if absf(float(a.get(fk, 0.0)) - float(b.get(fk, 0.0))) > 0.75:
			ok = false
			diffs.append("%s  %s vs %s" % [fk, str(a.get(fk)), str(b.get(fk))])
	if a.has("gold") and b.has("gold") and int(a.get("gold")) != int(b.get("gold")):
		ok = false
		diffs.append("gold  %s vs %s" % [str(a.get("gold")), str(b.get("gold"))])
	var ca: Dictionary = load("res://scripts/sim/replay/replay_package.gd").tower_composition(a)
	var cb: Dictionary = load("res://scripts/sim/replay/replay_package.gd").tower_composition(b)
	if str(ca) != str(cb):
		ok = false
		diffs.append("composition  %s vs %s" % [str(ca), str(cb)])
	if ok:
		print("  %s PASS  won=%s killed=%s leaks=%s core=%s dmg=%.1f" % [
			label, str(b.get("won")), str(b.get("enemies_killed")), str(b.get("enemies_leaked")),
			str(b.get("lives_remaining")), float(b.get("total_damage", 0.0)),
		])
	else:
		print("  %s FAIL" % label)
		for d in diffs:
			print("    %s" % d)
	return ok
