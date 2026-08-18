extends SceneTree

## Deterministic Balancing Lab tests (v0.19.0).


var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var ok := true
	ok = _test_sphere_segment() and ok
	ok = _test_disc_segment() and ok
	ok = _test_exposure_scales_with_range() and ok
	ok = _test_exposure_seconds() and ok
	ok = _test_sentry_dps() and ok
	ok = _test_guard_interval() and ok
	ok = _test_difficulty_components() and ok
	ok = (await _test_isolated_and_ramp()) and ok
	ok = (await _test_counterfactual_and_shapley()) and ok
	ok = (await _test_guard_indirect()) and ok
	ok = _test_realized_value() and ok
	ok = (await _test_agent_legal()) and ok
	ok = (await _test_fidelity_probe()) and ok
	ok = _test_report_sections() and ok
	ok = _test_previous_delta_classes() and ok
	var ReportTests = load("res://scripts/tools/validate_balance_report.gd").new()
	ok = (await ReportTests.run(self)) and ok
	if not ReportTests.failures.is_empty():
		for f2 in ReportTests.failures:
			failures.append(f2)
	if ok and failures.is_empty():
		print("validate_balance: OK")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		print("validate_balance: FAILED")
		quit(1)


func _fail(msg: String) -> bool:
	failures.append(msg)
	push_error(msg)
	return false


func _test_sphere_segment() -> bool:
	var Exp = load("res://scripts/level/path_exposure_calculator.gd")
	var hits: Array = Exp.segment_sphere(Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3.ZERO, 1.0)
	if hits.is_empty():
		return _fail("A: sphere should hit the segment")
	var t0 := float(hits[0].x)
	var t1 := float(hits[0].y)
	var length := 4.0 * (t1 - t0)
	if absf(length - 2.0) > 0.02:
		return _fail("A: expected covered length 2, got %s" % str(length))
	print("A sphere-segment: OK")
	return true


func _test_disc_segment() -> bool:
	var Exp = load("res://scripts/level/path_exposure_calculator.gd")
	var hits: Array = Exp.segment_disc_xz(Vector3(-2, 3, 0), Vector3(2, 3, 0), Vector3(0, 9, 0), 1.0)
	if hits.is_empty():
		return _fail("B: floor disc should ignore Y")
	var length := 4.0 * (float(hits[0].y) - float(hits[0].x))
	if absf(length - 2.0) > 0.02:
		return _fail("B: expected XZ chord 2, got %s" % str(length))
	print("B floor-disc: OK")
	return true


func _test_exposure_scales_with_range() -> bool:
	var Exp = load("res://scripts/level/path_exposure_calculator.gd")
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0)])
	var floors := PackedStringArray(["floor_1"])
	var a: Dictionary = Exp.compute(Vector3(0, 0, 0), 2.0, "SPHERE_3D", "floor_1", path, floors, 2.0)
	var b: Dictionary = Exp.compute(Vector3(0, 0, 0), 4.0, "SPHERE_3D", "floor_1", path, floors, 2.0)
	if float(b.covered_length_total) <= float(a.covered_length_total) + 0.5:
		return _fail("C: larger range should cover more path")
	print("C range monotonic: OK")
	return true


func _test_exposure_seconds() -> bool:
	var Exp = load("res://scripts/level/path_exposure_calculator.gd")
	if absf(Exp.exposure_seconds(4.4, 2.2) - 2.0) > 0.0001:
		return _fail("D: exposure_seconds should be length/speed")
	print("D exposure seconds: OK")
	return true


func _test_sentry_dps() -> bool:
	var Combat = load("res://scripts/balance/combat_value_model.gd")
	var dps := float(Combat.theoretical_dps({
		"tower_id": "basic_tower",
		"base_damage": 25.0,
		"base_fire_interval": 0.8,
		"unit_count": 1,
	}))
	if absf(dps - (25.0 / 0.8)) > 0.001:
		return _fail("E: sentry DPS expected 31.25, got %s" % str(dps))
	print("E sentry dps: OK")
	return true


func _test_guard_interval() -> bool:
	var Guard = load("res://scripts/balance/guard_value_model.gd")
	var dps := float(Guard.theoretical_melee_dps({
		"tower_id": "guard_post",
		"guard_damage": 20.0,
		"guard_attack_interval": 0.8,
		"unit_count": 2,
	}))
	if absf(dps - 50.0) > 0.001:
		return _fail("F: guard melee DPS expected 50, got %s" % str(dps))
	print("F guard unit_count/interval: OK")
	return true


func _test_difficulty_components() -> bool:
	var Pressure = load("res://scripts/balance/difficulty_pressure_model.gd")
	var n: Dictionary = Pressure.components("normal")
	var h: Dictionary = Pressure.components("hard")
	if absf(float(n.health_multiplier) - 1.0) > 0.0001:
		return _fail("N: normal health should be 1")
	if absf(float(h.health_multiplier) - 1.25) > 0.0001:
		return _fail("N: hard health should be 1.25")
	if absf(float(h.speed_multiplier) - 1.25) > 0.0001:
		return _fail("N: hard speed should be 1.25")
	if absf(float(h.spawn_rate_multiplier) - 1.0) > 0.0001:
		return _fail("N: hard spawn_rate should stay 1.0")
	var factor := float(Pressure.ranged_pressure_factor("hard"))
	if absf(factor - 1.25 * 1.25) > 0.0001:
		return _fail("N: HP×speed factor expected 1.5625, got %s" % str(factor))
	print("N difficulty components: OK")
	return true


func _test_isolated_and_ramp() -> bool:
	var Isolated = load("res://scripts/balance/isolated_tower_benchmark.gd")
	var opts := {
		"tower_id": "basic_tower",
		"spot_id": "F1_C",
		"build_wave": 1,
		"seed": 11,
		"difficulty_id": "normal",
		"time_scale": 40.0,
	}
	var a: Dictionary = await Isolated.run(self, opts)
	var b: Dictionary = await Isolated.run(self, opts)
	if absf(float(a.get("actual_damage", 0.0)) - float(b.get("actual_damage", 0.0))) > 0.05:
		return _fail("J: isolated benchmark should be deterministic")
	var vg := float(a.get("value_per_gold", 0.0))
	if vg < 6.0 or vg > 22.0:
		return _fail("J: Sentry isolated value/gold out of expected band, got %s" % str(vg))
	var ramp_a: Dictionary = await Isolated.run(self, {
		"tower_id": "lava_tower",
		"spot_id": "F3_D",
		"build_wave": 1,
		"seed": 11,
		"start_waves": false,
		"duration": 8.0,
		"time_scale": 40.0,
	})
	var ramp_b: Dictionary = await Isolated.run(self, {
		"tower_id": "lava_tower",
		"spot_id": "F3_D",
		"build_wave": 1,
		"seed": 11,
		"start_waves": false,
		"duration": 8.0,
		"time_scale": 40.0,
	})
	var la: Dictionary = ramp_a.get("lava", {})
	var lb: Dictionary = ramp_b.get("lava", {})
	if absf(float(la.get("total_lava_mass", 0.0)) - float(lb.get("total_lava_mass", 0.0))) > 0.2:
		return _fail("I: meltdown ramp should be seed-reproducible")
	print("I/J isolated+ramp: OK")
	return true


func _test_counterfactual_and_shapley() -> bool:
	var Policy = load("res://scripts/sim/fidelity/scripted_policy.gd")
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup({
		"seed": 21,
		"difficulty_id": "normal",
		"config": {"starting_gold": 1000},
		"max_sim_seconds": 180.0,
	}, self)
	await sim.await_ready()
	for action in Policy.opening_actions():
		sim.execute(action)
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(self, sim, {"time_scale": 40.0, "decide": false, "max_sim_seconds": 180.0})
	var baseline: Dictionary = sim.finish()
	var log: Array = baseline.get("action_log", [])
	sim.cleanup()
	await process_frame
	var CF = load("res://scripts/balance/counterfactual_runner.gd")
	var spots: PackedStringArray = CF.placed_spots(log)
	if spots.size() < 2:
		return _fail("K: expected at least two placed towers in scripted run")
	var cf: Dictionary = await CF.run(self, {
		"action_log": log,
		"seed": 21,
		"spot_id": spots[0],
		"config": {"starting_gold": 1000},
		"time_scale": 40.0,
	})
	if not bool(cf.get("other_actions_unchanged", false)):
		return _fail("L: counterfactual must keep other actions")
	var without: Dictionary = cf.get("without", {})
	var cf2: Dictionary = await CF.replay(self, {
		"action_log": CF.filter_log(log, spots[0]),
		"seed": 21,
		"config": {"starting_gold": 1000},
		"time_scale": 40.0,
	})
	if int(without.get("enemies_killed", -1)) != int(cf2.get("enemies_killed", -2)):
		return _fail("K: counterfactual without-tower should be reproducible")
	var Sh = load("res://scripts/balance/shapley_analyzer.gd")
	var sh: Dictionary = await Sh.analyze(self, {
		"action_log": log,
		"seed": 21,
		"config": {"starting_gold": 1000},
		"time_scale": 40.0,
		"score": "hp_removed",
	})
	if bool(sh.get("skipped", true)):
		return _fail("M: shapley should run for N<=5")
	if not bool(sh.get("sum_matches_grand", false)):
		return _fail("M: shapley sum should match grand coalition")
	print("K/L/M counterfactual+shapley: OK")
	return true


func _test_guard_indirect() -> bool:
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup({
		"seed": 21,
		"difficulty_id": "normal",
		"config": {"starting_gold": 1000},
		"max_sim_seconds": 180.0,
	}, self)
	await sim.await_ready()
	sim.execute({"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_C"})
	sim.execute({"type": "PLACE_TOWER", "tower_id": "guard_post", "spot_id": "F1_B"})
	sim.execute({"type": "START_WAVE"})
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(self, sim, {"time_scale": 40.0, "decide": false, "max_sim_seconds": 180.0})
	var baseline: Dictionary = sim.finish()
	var replay_log: Array = baseline.get("action_log", [])
	sim.cleanup()
	await process_frame
	var CF = load("res://scripts/balance/counterfactual_runner.gd")
	var built: Dictionary = await CF.analyze_build(self, {
		"action_log": replay_log,
		"seed": 21,
		"config": {"starting_gold": 1000},
		"time_scale": 40.0,
	})
	var guard_row := {}
	for row in built.get("by_tower", []):
		if str(row.get("tower_id")) == "guard_post":
			guard_row = row
			break
	if guard_row.is_empty():
		return _fail("CF: expected a Guard in mixed fixture")
	if float(guard_row.get("damage_enabled_for_other_towers", 0.0)) <= 0.0 and float(guard_row.get("marginal_total_damage", 0.0)) <= 0.0:
		return _fail("CF: blocking tower should enable positive indirect or marginal damage")
	print("CF guard indirect: OK")
	return true


func _test_realized_value() -> bool:
	var Realized = load("res://scripts/balance/metrics/realized_combat_value.gd")
	var v: Dictionary = Realized.evaluate({
		"direct_damage": 100.0,
		"damage_enabled_for_other_towers": 40.0,
		"leaks_prevented": 1,
		"core_hp_preserved": 0,
		"cost": 120.0,
	})
	if absf(float(v.get("combat_value", 0.0)) - 260.0) > 0.01:
		return _fail("RV: expected 100+40+120 leak units")
	print("RV realized value: OK")
	return true


func _test_agent_legal() -> bool:
	var Full = load("res://scripts/balance/full_build_benchmark.gd")
	var rec: Dictionary = await Full.record_agent(self, {
		"role": "COMPETENT",
		"seed": 7,
		"difficulty_id": "normal",
		"time_scale": 40.0,
		"max_sim_seconds": 90.0,
		"config": {"starting_gold": 1000},
	})
	if not bool(rec.get("legal_actions", false)):
		return _fail("AG: agent produced illegal PLACE")
	if (rec.get("action_log", []) as Array).is_empty():
		return _fail("AG: agent should emit an action log")
	print("AG legal agent: OK")
	return true


func _test_fidelity_probe() -> bool:
	var Fid = load("res://scripts/balance/simulation/fidelity_probe.gd")
	var r: Dictionary = await Fid.run(self, {"duration": 6.0, "seed": 12345})
	if str(r.get("status", "")) != "PASS":
		return _fail("FID: probe status %s %s" % [str(r.get("status")), str(r.get("deviations"))])
	print("FID probe: %s" % str(r.get("status")))
	return true


func _test_report_sections() -> bool:
	var Model = load("res://scripts/balance/report/balance_report_model.gd")
	var ReportTests = load("res://scripts/tools/validate_balance_report.gd").new()
	var report: Dictionary = Model.build(ReportTests._parts(), {"game_version": "0.19.0", "seed": 7})
	for key in ["counterfactual", "shapley", "full_builds", "competent_build", "optimizer_build", "defense_margin", "difficulty_frontier", "simulation_fidelity", "parameter_search", "recommended_balance_changes"]:
		if not report.has(key):
			return _fail("REP: missing section %s" % key)
	if str(report.get("schema_version")) != "0.19.0":
		return _fail("REP: schema_version should be 0.19.0")
	print("REP sections: OK")
	return true


func _test_previous_delta_classes() -> bool:
	var Cmp = load("res://scripts/balance/report/balance_report_comparator.gd")
	var Model = load("res://scripts/balance/report/balance_report_model.gd")
	var ReportTests = load("res://scripts/tools/validate_balance_report.gd").new()
	var a: Dictionary = Model.build(ReportTests._parts(), {"seed": 7, "game_version": "0.19.0"})
	var b: Dictionary = a.duplicate(true)
	b["report_meta"] = (a.get("report_meta", {}) as Dictionary).duplicate(true)
	var delta = Cmp.compare(a, b)
	if typeof(delta) != TYPE_DICTIONARY or not bool(delta.get("comparable", false)):
		return _fail("PD: identical fingerprint reports should compare")
	if str(delta.get("simulation_fidelity")) != "UNCHANGED":
		return _fail("PD: fidelity class expected UNCHANGED")
	print("PD previous delta: OK")
	return true

