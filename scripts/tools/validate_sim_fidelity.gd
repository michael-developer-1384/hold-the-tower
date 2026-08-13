extends SceneTree

## Replay the same action log at multiple speeds. Gameplay step stays 1/60.
## godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_sim_fidelity: starting")
	var speeds := [1.0, 5.0, 10.0, 20.0, 40.0]
	var record: Dictionary = await _run_speed(1.0, [], true)
	if record.is_empty():
		print("validate_sim_fidelity: FAILED (no baseline)")
		quit(1)
		return
	var log: Array = record.get("action_log", [])
	var baseline_checks: Array = record.get("checkpoints", [])
	print("  recorded %d actions, duration=%.1fs" % [log.size(), float(record.get("duration", 0.0))])

	var rows: Array = []
	var all_ok := true
	for speed in speeds:
		var r: Dictionary = await _run_speed(speed, log, false)
		var cmp: Dictionary = _compare(record, r, baseline_checks, r.get("checkpoints", []))
		var ok: bool = bool(cmp.get("ok", false))
		all_ok = all_ok and ok
		rows.append({
			"speed": speed,
			"wall": float(r.get("wall_clock", 0.0)),
			"sim": float(r.get("duration", 0.0)),
			"effective": float(r.get("sim_speed", 0.0)),
			"ok": ok,
			"mismatch": cmp.get("mismatch", {}),
		})
		print("  %.0fx  %s  wall=%.2fs sim=%.1fs effective=%.0fx" % [
			speed, "PASS" if ok else "FAIL",
			float(r.get("wall_clock", 0.0)), float(r.get("duration", 0.0)), float(r.get("sim_speed", 0.0))
		])
		if not ok:
			var m: Dictionary = cmp.get("mismatch", {})
			print("    first divergence t=%.3fs field=%s  %s vs %s" % [
				float(m.get("t", -1.0)), str(m.get("field", "?")), str(m.get("a")), str(m.get("b"))
			])

	print("\nSIM FIDELITY REPORT")
	print("Baseline: 1x")
	print("Speed Mode | Wall Clock | Simulated Time | Effective Speed | Fidelity")
	for row in rows:
		print("%5.0fx     | %8.2fs | %8.1fs | %8.0fx | %s" % [
			float(row.speed), float(row.wall), float(row.sim), float(row.effective),
			"PASS" if bool(row.ok) else "FAIL"
		])
	if all_ok:
		print("validate_sim_fidelity: OK")
		quit(0)
	else:
		print("validate_sim_fidelity: FAILED")
		quit(1)


func _run_speed(speed: float, replay_log: Array, record_policy: bool) -> Dictionary:
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var Policy = load("res://scripts/sim/fidelity/scripted_policy.gd")
	var Checkpoint = load("res://scripts/sim/fidelity/checkpoint.gd")
	var sim = SimScript.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 12345,
		"time_scale": speed,
		"max_sim_seconds": 900.0,
	}, self)
	await sim.await_ready()
	if not record_policy:
		sim.set_replay(replay_log)
	else:
		for a in Policy.opening_actions():
			sim.execute(a)
	SimRunner.apply_speed(speed)
	var checks: Array = []
	var next_check := 0.5
	var frames := 0
	while not sim.is_finished() and frames < 400000:
		if record_policy:
			Policy.maybe_act(sim)
		else:
			sim.replay_due_actions()
		await physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.clock.sim_time + 0.0001 >= next_check:
			checks.append(Checkpoint.capture(sim))
			next_check += 0.5
		frames += 1
	SimRunner.restore()
	var result: Dictionary = sim.finish()
	result["checkpoints"] = checks
	sim.cleanup()
	await process_frame
	return result


func _compare(base: Dictionary, other: Dictionary, base_checks: Array, other_checks: Array) -> Dictionary:
	var keys := [
		"won", "waves_reached", "enemies_spawned", "enemies_killed", "enemies_leaked",
		"lives_remaining", "credits_earned", "credits_spent", "towers_placed",
	]
	for k in keys:
		if base.get(k) != other.get(k):
			return {"ok": false, "mismatch": {"field": k, "a": base.get(k), "b": other.get(k), "t": -1.0}}
	for fk in ["total_damage", "total_shots", "total_hits", "total_overkill", "same_floor_damage", "cross_floor_damage"]:
		if absf(float(base.get(fk, 0.0)) - float(other.get(fk, 0.0))) > 0.5:
			return {"ok": false, "mismatch": {"field": fk, "a": base.get(fk), "b": other.get(fk), "t": -1.0}}
	if str(base.get("tower_levels", {})) != str(other.get("tower_levels", {})):
		return {"ok": false, "mismatch": {"field": "tower_levels", "a": base.get("tower_levels"), "b": other.get("tower_levels"), "t": -1.0}}
	var Checkpoint = load("res://scripts/sim/fidelity/checkpoint.gd")
	var n: int = mini(base_checks.size(), other_checks.size())
	for i in n:
		var diff: Dictionary = Checkpoint.first_diff(base_checks[i], other_checks[i])
		if not diff.is_empty():
			diff["t"] = float(base_checks[i].get("t", -1.0))
			return {"ok": false, "mismatch": diff}
	return {"ok": true, "mismatch": {}}
