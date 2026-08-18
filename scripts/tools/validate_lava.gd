extends SceneTree

## Headless lava surface + flow + catalog checks.


func _initialize() -> void:
	_run()


func _run() -> void:
	var ok := true
	ok = _test_index_support() and ok
	ok = _test_index_landing() and ok
	ok = _test_flow_and_drip() and ok
	ok = _test_fill_and_slip() and ok
	ok = _test_puddle_damage() and ok
	ok = _test_mass_scale_independence() and ok
	ok = _test_airborne_land_and_void() and ok
	ok = _test_catalog() and ok
	ok = _test_snapshot() and ok
	ok = _test_seeded_determinism() and ok
	ok = (await _test_sim_smoke()) and ok
	if ok:
		print("validate_lava: OK")
		quit(0)
	else:
		print("validate_lava: FAILED")
		quit(1)


func _level():
	var factory = load("res://scripts/level/test_level_factory.gd")
	return factory.create_level()


func _index():
	var IndexScript = load("res://scripts/level/platform_surface_index.gd")
	return IndexScript.from_level(_level())


func _lava():
	var node := Node.new()
	node.set_script(load("res://scripts/world/lava_system.gd"))
	node.call("setup", _level())
	return node


func _test_index_support() -> bool:
	var idx = _index()
	if not bool(idx.call("is_supported", 0, 4, "floor_3")):
		push_error("F3 north (0,4) should be supported")
		return false
	if not bool(idx.call("is_supported", 0, 4, "floor_2")):
		push_error("F2 east walk (0,4) should be supported")
		return false
	if bool(idx.call("is_supported", 0, 2, "floor_3")):
		push_error("Courtyard (0,2) on F3 should be void")
		return false
	print("lava index support: OK")
	return true


func _test_index_landing() -> bool:
	var idx = _index()
	var north: Dictionary = idx.call("hit_below", 0.0, 4.0, 5.5)
	if str(north.get("floor_id", "")) != "floor_2":
		push_error("Below F3 north should land on F2, got %s" % str(north))
		return false
	var west: Dictionary = idx.call("hit_below", -4.0, 2.0, 5.5)
	if str(west.get("floor_id", "")) != "floor_2":
		push_error("Below F3 west should land on F2, got %s" % str(west))
		return false
	var east: Dictionary = idx.call("hit_below", 4.0, -2.0, 5.5)
	if str(east.get("floor_id", "")) != "floor_1":
		push_error("Below F3 east should land on F1, got %s" % str(east))
		return false
	var turn: Dictionary = idx.call("hit_below", 2.0, 3.0, 5.9)
	if str(turn.get("floor_id", "")) != "floor_2":
		push_error("F3 north inner edge should land on F2 turn, got %s" % str(turn))
		return false
	var hole: Dictionary = idx.call("hit_below", 0.0, 2.0, 6.2)
	if not hole.is_empty():
		push_error("Courtyard (0,2) should be void, got %s" % str(hole))
		return false
	print("lava index landing: OK")
	return true


func _test_flow_and_drip() -> bool:
	var lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 40.0, "T1", {
		"lava_damage": 10.0,
		"flow_rate": 0.9,
		"lava_lifetime": 30.0,
	})
	if float(lava.call("mass_at", 0, 4, "floor_3")) < 30.0:
		push_error("Pour should create mass on F3 north")
		lava.free()
		return false
	for _i in 8:
		lava.call("pour", 0, 4, "floor_3", 8.0, "T1", {
			"lava_damage": 10.0,
			"flow_rate": 0.45,
			"lava_lifetime": 30.0,
		})
		lava.call("simulate", 0.05)
	if float(lava.call("mass_at", 0, 4, "floor_3")) < 90.0:
		push_error("Fed puddle should accumulate toward a full plate, mass=%s" % str(lava.call("mass_at", 0, 4, "floor_3")))
		lava.free()
		return false
	lava.call("pour", 0, 4, "floor_3", 20.0, "T1", {
		"lava_damage": 10.0,
		"flow_rate": 0.9,
		"lava_lifetime": 30.0,
	})
	for _j in 12:
		lava.call("simulate", 0.25)
	if int(lava.call("cell_count")) < 2 and int(lava.call("airborne_count")) < 1:
		push_error("Overflow past 100 should spread or drip")
		lava.free()
		return false
	print("lava flow: OK cells=%d air=%d mass=%.1f" % [
		int(lava.call("cell_count")),
		int(lava.call("airborne_count")),
		float(lava.call("mass_at", 0, 4, "floor_3")),
	])
	lava.free()
	lava = _lava()
	for _k in 180:
		if _k % 12 == 0:
			lava.call("pour", 0, 4, "floor_3", 2.0, "T1", {
				"lava_damage": 10.0,
				"flow_rate": 0.45,
				"lava_lifetime": 12.0,
			})
		lava.call("simulate", 1.0 / 60.0)
	var piled := float(lava.call("mass_at", 0, 4, "floor_3"))
	if piled < 20.0:
		push_error("60Hz pour must accumulate on the plate, mass=%s" % str(piled))
		lava.free()
		return false
	print("lava 60Hz fill: OK mass=%.1f" % piled)
	lava.free()
	return true


func _test_fill_and_slip() -> bool:
	var lava = _lava()
	var dirs: Array = lava.call("slip_dirs", 0, 4, "floor_3")
	var has_n := false
	var has_s := false
	for d in dirs:
		var v: Vector2i = d
		if v == Vector2i(0, 1):
			has_n = true
		if v == Vector2i(0, -1):
			has_s = true
	if dirs.size() < 2 or not has_n or not has_s:
		push_error("F3 north should slip north and south, got %s" % str(dirs))
		lava.free()
		return false
	lava.call("pour", 0, 4, "floor_3", 2.0, "T1", {"lava_damage": 10.0, "flow_rate": 0.45, "lava_lifetime": 30.0})
	var mass2 := float(lava.call("mass_at", 0, 4, "floor_3"))
	var dps2 := 10.0 * clampf(mass2 / 100.0, 0.0, 1.0)
	if mass2 < 1.9 or absf(dps2 - 0.2) > 0.02:
		push_error("2 drops should be 2%% / 0.2 dps, mass=%s dps=%s" % [str(mass2), str(dps2)])
		lava.free()
		return false
	lava.call("pour", 0, 4, "floor_3", 2.0, "T1", {"lava_damage": 10.0, "flow_rate": 0.45, "lava_lifetime": 30.0})
	var mass4 := float(lava.call("mass_at", 0, 4, "floor_3"))
	var dps4 := 10.0 * clampf(mass4 / 100.0, 0.0, 1.0)
	if mass4 < 3.8 or absf(dps4 - 0.4) > 0.03:
		push_error("4 drops should be 4%% / 0.4 dps, mass=%s dps=%s" % [str(mass4), str(dps4)])
		lava.free()
		return false
	lava.call("emit_toward", Vector3(0.0, 6.55, 4.0), Vector3(0.0, 6.32, 4.0), 2.0, "T2", {})
	for _i in 36:
		lava.call("simulate", 0.05)
	if float(lava.call("mass_at", 0, 4, "floor_3")) < 2.0:
		push_error("Landing blob should become a puddle on F3")
		lava.free()
		return false
	var other = _lava()
	other.call(
		"emit_toward",
		Vector3(0.0, 6.55, 4.0),
		Vector3(0.0, 5.70, 5.2),
		2.0,
		"T3",
		{"skip_floor": "floor_3"}
	)
	for _j in 40:
		other.call("simulate", 0.05)
	if float(other.call("mass_at", 0, 4, "floor_3")) > 0.5:
		push_error("Skip-floor blob should not puddle on the source plate")
		lava.free()
		other.free()
		return false
	print("lava fill/slip: OK")
	lava.free()
	other.free()
	return true


func _test_puddle_damage() -> bool:
	var lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 20.0, "T1", {
		"lava_damage": 10.0,
		"flow_rate": 0.45,
		"lava_lifetime": 30.0,
	})
	if not is_equal_approx(float(lava.call("dps_at", 0, 4, "floor_3")), 2.0):
		push_error("20 drops should be 2.0 dps, got %s" % str(lava.call("dps_at", 0, 4, "floor_3")))
		lava.free()
		return false
	var enemy := Node3D.new()
	enemy.set_script(load("res://scripts/enemies/enemy.gd"))
	enemy.position = Vector3(0.0, 6.2, 4.0)
	enemy.set("floor_id", "floor_3")
	enemy.set("health", 100.0)
	enemy.set("max_health", 100.0)
	var burned := float(lava.call("apply_burn", enemy, 1.0, null))
	var hp := float(enemy.get("health"))
	if burned < 1.9 or hp > 98.2:
		push_error("Puddle should burn a bot on the cell, burned=%s hp=%s" % [str(burned), str(hp)])
		enemy.free()
		lava.free()
		return false
	print("lava damage: OK burned=%.2f hp=%.2f" % [burned, hp])
	enemy.free()
	lava.free()
	return true


func _test_mass_scale_independence() -> bool:
	var lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 50.0, "Tcap", {
		"lava_damage": 10.0,
		"flow_rate": 0.0,
		"lava_lifetime": 30.0,
		"cell_mass_capacity": 100.0,
		"damage_full_mass": 50.0,
		"damage_threshold_mass": 2.0,
		"flow_start_mass": 99.5,
	})
	var dps_a := float(lava.call("dps_at", 0, 4, "floor_3"))
	if absf(dps_a - 10.0) > 0.05:
		push_error("G: 50 mass / damage_full_mass 50 should be full DPS, got %s" % str(dps_a))
		lava.free()
		return false
	lava.free()
	lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 50.0, "Tcap2", {
		"lava_damage": 10.0,
		"flow_rate": 0.0,
		"lava_lifetime": 30.0,
		"cell_mass_capacity": 200.0,
		"damage_full_mass": 100.0,
		"damage_threshold_mass": 2.0,
		"flow_start_mass": 99.5,
	})
	var dps_b := float(lava.call("dps_at", 0, 4, "floor_3"))
	if absf(dps_b - 5.0) > 0.05:
		push_error("G: capacity 200 must not change fill vs damage_full_mass 100, dps=%s" % str(dps_b))
		lava.free()
		return false
	lava.free()
	lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 40.0, "Tflow", {
		"lava_damage": 10.0,
		"flow_rate": 0.9,
		"lava_lifetime": 30.0,
		"cell_mass_capacity": 100.0,
		"damage_full_mass": 10.0,
		"damage_threshold_mass": 2.0,
		"flow_start_mass": 99.5,
	})
	for _i in 8:
		lava.call("simulate", 0.25)
	if int(lava.call("cell_count")) != 1:
		push_error("H: flow_start 99.5 should not spread at mass 40 even if damage is full, cells=%d" % int(lava.call("cell_count")))
		lava.free()
		return false
	lava.free()
	lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 40.0, "Tflow2", {
		"lava_damage": 10.0,
		"flow_rate": 0.9,
		"lava_lifetime": 30.0,
		"cell_mass_capacity": 100.0,
		"damage_full_mass": 100.0,
		"damage_threshold_mass": 2.0,
		"flow_start_mass": 20.0,
	})
	for _j in 10:
		lava.call("simulate", 0.25)
	if int(lava.call("cell_count")) < 2 and int(lava.call("airborne_count")) < 1:
		push_error("H: flow_start 20 should allow spread at mass 40, cells=%d air=%d" % [
			int(lava.call("cell_count")), int(lava.call("airborne_count"))
		])
		lava.free()
		return false
	print("lava mass scales: OK")
	lava.free()
	return true


func _test_airborne_land_and_void() -> bool:
	var lava = _lava()
	lava.call("_spawn_drip", Vector3(2.0, 5.9, 3.0), Vector3(0.0, -2.0, 0.0), 8.0, "T1", {})
	for _i in 24:
		lava.call("simulate", 0.05)
	if float(lava.call("mass_at", 2, 3, "floor_2")) < 4.0:
		push_error("Drip off F3 north should land on F2 turn")
		lava.free()
		return false
	lava.call("_spawn_drip", Vector3(0.0, 6.2, 2.0), Vector3(0.0, -4.0, 0.0), 2.0, "T1", {})
	for _i in 40:
		lava.call("simulate", 0.1)
	if int(lava.call("airborne_count")) != 0:
		push_error("Void drip should despawn, leftover air=%d" % int(lava.call("airborne_count")))
		lava.free()
		return false
	lava.call("_spawn_drip", Vector3(0.0, 5.9, 3.15), Vector3(0.0, -2.0, 0.0), 2.0, "T4", {
		"skip_floor": "floor_3",
	})
	for _k in 30:
		lava.call("simulate", 0.05)
	if float(lava.call("mass_at", 0, 2, "floor_3")) > 0.0 or float(lava.call("mass_at", 0, 3, "floor_3")) > 0.0:
		push_error("Falling lava must not puddle in F3 void")
		lava.free()
		return false
	print("lava airborne land/void: OK")
	lava.free()
	return true


func _test_catalog() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	var def = catalog.find_by_id(defs, "lava_tower")
	if def == null:
		push_error("Missing lava_tower definition")
		return false
	if int(def.cost) != 130 or str(def.range_shape) != "FLOOR_DISC":
		push_error("lava_tower def mismatch")
		return false
	if def.runtime_scene == null or def.visual_scene == null:
		push_error("lava_tower missing scenes")
		return false
	var features = load("res://scripts/meta/feature_catalog.gd")
	for fid in ["lava_flow", "cross_floor", "always_on"]:
		if features.get_feature(fid) == null:
			push_error("Missing feature %s" % fid)
			return false
	var liquidation = features.get_feature("lava_flow")
	if str(liquidation.display_name) != "LIQUIDATION":
		push_error("lava_flow display should be LIQUIDATION, got %s" % str(liquidation.display_name))
		return false
	var resolver = load("res://scripts/meta/blueprint_resolver.gd")
	var resolved: Dictionary = resolver.resolve("lava_tower", {
		"id": "research",
		"display_name": "Research",
		"allocations": {},
	})
	if not is_equal_approx(float(resolved.get("lava_damage", 0.0)), 10.0):
		push_error("lava resolve should use base damage")
		return false
	if not is_equal_approx(float(resolved.get("lava_lifetime", 0.0)), 8.0):
		push_error("0-RP lava_lifetime should be 8s, got %s" % str(resolved.get("lava_lifetime")))
		return false
	var scene := load("res://scenes/towers/lava_tower.tscn") as PackedScene
	var tower := scene.instantiate() as Node3D
	if tower == null or not tower.has_method("configure_built"):
		push_error("lava_tower scene missing configure_built")
		if tower:
			tower.free()
		return false
	if str(tower.call("get_range_shape")) != "FLOOR_DISC":
		push_error("lava_tower range shape should be FLOOR_DISC")
		tower.free()
		return false
	tower.free()
	print("lava catalog: OK")
	return true


func _test_snapshot() -> bool:
	var lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 20.0, "T9", {"lava_damage": 10.0, "flow_rate": 0.45, "lava_lifetime": 9.0})
	var snap: Dictionary = lava.call("capture_state")
	if (snap.get("cells", []) as Array).is_empty():
		push_error("capture_state should include poured cells")
		lava.free()
		return false
	var other = _lava()
	other.call("apply_state", snap)
	if float(other.call("mass_at", 0, 4, "floor_3")) < 10.0:
		push_error("apply_state should restore puddle mass")
		lava.free()
		other.free()
		return false
	print("lava snapshot: OK")
	lava.free()
	other.free()
	return true


func _run_seeded_pour(p_seed: int) -> Dictionary:
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	var SeededRngScript = load("res://scripts/sim/seeded_rng.gd")
	SimContextScript.begin(p_seed)
	SimContextScript.rng = SeededRngScript.new(p_seed)
	var lava = _lava()
	lava.call("pour", 0, 4, "floor_3", 40.0, "T1", {
		"lava_damage": 10.0,
		"flow_rate": 0.9,
		"lava_lifetime": 30.0,
	})
	for _i in 16:
		lava.call("pour", 0, 4, "floor_3", 8.0, "T1", {
			"lava_damage": 10.0,
			"flow_rate": 0.9,
			"lava_lifetime": 30.0,
		})
		lava.call("simulate", 0.05)
	lava.call(
		"emit_toward",
		Vector3(0.0, 6.55, 4.0),
		Vector3(0.0, 5.70, 5.2),
		2.0,
		"T1",
		{"skip_floor": "floor_3", "lava_damage": 10.0, "flow_rate": 0.9, "lava_lifetime": 30.0}
	)
	for _j in 24:
		lava.call("simulate", 0.05)
	var out := {
		"mass": float(lava.call("mass_at", 0, 4, "floor_3")),
		"cells": int(lava.call("cell_count")),
		"air": int(lava.call("airborne_count")),
	}
	lava.free()
	SimContextScript.end()
	return out


func _test_seeded_determinism() -> bool:
	var a := _run_seeded_pour(4242)
	var b := _run_seeded_pour(4242)
	if a.mass != b.mass or int(a.cells) != int(b.cells) or int(a.air) != int(b.air):
		push_error("Seeded pour diverged %s vs %s" % [str(a), str(b)])
		return false
	print("lava seeded: OK mass=%.1f cells=%d air=%d" % [float(a.mass), int(a.cells), int(a.air)])
	return true


func _test_sim_smoke() -> bool:
	print("test: lava sim smoke")
	var script = load("res://scripts/sim/game_simulation.gd")
	var sim = script.new()
	sim.setup({
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"seed": 77,
		"max_sim_seconds": 30.0,
	}, self)
	await sim.await_ready()
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	var clock_dt: float = SimRunnerScript.clock_dt()
	if not sim.execute({"type": "PLACE_TOWER", "tower_id": "lava_tower", "spot_id": "F3_D"}):
		push_error("Failed to place lava_tower on F3_D")
		sim.cleanup()
		return false
	for _i in 180:
		await physics_frame
		sim.clock.step(clock_dt)
	var cells := 0
	var air := 0
	var tl = sim.game.get("tower_level") if sim.game else null
	if tl != null and tl.has_method("get_lava_system"):
		var lava = tl.call("get_lava_system")
		if lava != null:
			cells = int(lava.call("cell_count"))
			air = int(lava.call("airborne_count"))
	sim.cleanup()
	await process_frame
	if cells + air < 1:
		push_error("Meltdown smoke should emit lava, cells=%d air=%d" % [cells, air])
		return false
	print("lava sim smoke: OK cells=%d air=%d" % [cells, air])
	return true
