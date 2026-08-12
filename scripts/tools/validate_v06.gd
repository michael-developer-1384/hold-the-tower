extends SceneTree

## Headless acceptance helpers for v0.6.1 / v0.7 / v0.8 / v0.9.


func _init() -> void:
	var ok := true
	ok = _test_coverage() and ok
	ok = _test_floor_disc_coverage() and ok
	ok = _test_tower_def() and ok
	ok = _test_catalog() and ok
	ok = _test_actual_damage() and ok
	ok = _test_kill_before_died() and ok
	ok = _test_hover_modes() and ok
	ok = _test_range_origin_api() and ok
	ok = _test_guard_post_api() and ok
	ok = _test_guard_post_no_slow() and ok
	ok = _test_engagement_exclusivity() and ok
	ok = _test_research_cost_curve() and ok
	ok = _test_blueprint_resolve_immutable_catalog() and ok
	ok = _test_upgrade_range_bonus() and ok
	ok = _test_difficulty_catalog() and ok
	if ok:
		print("v0.9 validate: OK")
		quit(0)
	else:
		print("v0.9 validate: FAILED")
		quit(1)


func _test_coverage() -> bool:
	var calc = load("res://scripts/level/path_coverage_calculator.gd")
	var path := PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(4, 0, 0),
		Vector3(4, 3, 0),
		Vector3(8, 3, 0),
	])
	var floors := PackedStringArray(["f0", "f0", "f1"])
	var near: Dictionary = calc.compute(Vector3(2, 0, 0), 4.0, path, floors)
	var covered: Array = near.get("covered_indices", [])
	if covered.is_empty():
		push_error("Expected nearby segments covered")
		return false
	var by_floor: Dictionary = near.get("coverage_by_floor", {})
	if not by_floor.has("f0"):
		push_error("Expected f0 coverage")
		return false
	print("coverage sphere: OK")
	return true


func _test_floor_disc_coverage() -> bool:
	var calc = load("res://scripts/level/path_coverage_calculator.gd")
	var path := PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(4, 0, 0),
		Vector3(4, 3, 0),
		Vector3(8, 3, 0),
	])
	var floors := PackedStringArray(["f0", "ramp", "f1"])
	var disc: Dictionary = calc.compute_for_tower(
		Vector3(2, 10, 0), # Y must not matter for disc
		2.5,
		"FLOOR_DISC",
		"f0",
		path,
		floors
	)
	var by_floor: Dictionary = disc.get("coverage_by_floor", {})
	if by_floor.has("f1") or by_floor.has("ramp"):
		push_error("Floor disc must ignore other floors")
		return false
	if not by_floor.has("f0"):
		push_error("Floor disc should cover f0")
		return false
	var sphere: Dictionary = calc.compute_for_tower(
		Vector3(4, 1.5, 0),
		3.0,
		"SPHERE_3D",
		"",
		path,
		floors
	)
	if (sphere.get("covered_indices", []) as Array).is_empty():
		push_error("Sphere should still cover nearby segments")
		return false
	print("coverage disc: OK floor-local only")
	return true


func _test_tower_def() -> bool:
	var def_script = load("res://scripts/towers/tower_definition.gd")
	var def = def_script.new()
	if float(def.base_range) != 4.0 or float(def.upgraded_range) != 5.5:
		push_error("Unexpected tower ranges")
		return false
	print("tower_def: OK")
	return true


func _test_catalog() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	if defs.size() < 2:
		push_error("Catalog should include basic + guard")
		return false
	var ids: Array = []
	for def in defs:
		ids.append(str(def.tower_id))
	if not ids.has("basic_tower") or not ids.has("guard_post"):
		push_error("Missing tower ids in catalog")
		return false
	var guard = catalog.find_by_id(defs, "guard_post")
	if int(guard.cost) != 120 or int(guard.max_level) != 1:
		push_error("Guard post def mismatch")
		return false
	if not is_equal_approx(float(guard.base_fire_interval), 0.8):
		push_error("Guard post attack interval should be 0.8")
		return false
	print("catalog: OK basic+guard")
	return true


func _test_actual_damage() -> bool:
	var enemy_script = load("res://scripts/enemies/enemy.gd")
	var enemy = enemy_script.new()
	enemy.health = 10.0
	enemy.max_health = 10.0
	enemy._alive = true
	var tower := Node3D.new()
	tower.set_script(load("res://scripts/towers/basic_tower.gd"))
	tower.floor_index = 0
	tower.runtime_id = "TTEST"
	tower.hits = 0
	tower.damage_dealt = 0.0
	tower.kills = 0
	tower.same_floor_damage = 0.0
	tower.cross_floor_damage = 0.0
	tower.damage_by_target_floor = {}
	var result: Dictionary = enemy.take_damage(25.0, tower)
	var ok := true
	if not bool(result.get("killed", false)):
		push_error("Expected kill")
		ok = false
	elif not is_equal_approx(float(result.get("actual_damage", 0.0)), 10.0):
		push_error("Expected actual_damage=10")
		ok = false
	elif not is_equal_approx(float(tower.damage_dealt), 10.0):
		push_error("Tower damage_dealt should be 10")
		ok = false
	else:
		print("actual_damage: OK")
	tower.free()
	if is_instance_valid(enemy):
		enemy.free()
	return ok


func _test_kill_before_died() -> bool:
	var enemy_script = load("res://scripts/enemies/enemy.gd")
	var enemy = enemy_script.new()
	enemy.health = 10.0
	enemy.max_health = 10.0
	enemy._alive = true
	var tower := Node3D.new()
	tower.set_script(load("res://scripts/towers/basic_tower.gd"))
	tower.floor_index = 0
	tower.runtime_id = "TORDER"
	tower.kills = 0
	tower.hits = 0
	tower.damage_dealt = 0.0
	tower.same_floor_damage = 0.0
	tower.cross_floor_damage = 0.0
	tower.damage_by_target_floor = {}
	var kills_at_died := [-1]
	enemy.died.connect(func(_e: Node3D) -> void:
		kills_at_died[0] = int(tower.kills)
	)
	enemy.take_damage(25.0, tower)
	var ok: bool = int(kills_at_died[0]) == 1
	if ok:
		print("kill_order: OK")
	else:
		push_error("Expected kills==1 at died emit")
	tower.free()
	if is_instance_valid(enemy):
		enemy.free()
	return ok


func _test_hover_modes() -> bool:
	var ctrl = load("res://scripts/level/floor_visual_controller.gd")
	if ctrl.mode_for_floor_indices(2, 0, 2) != "hover_ghost":
		push_error("Expected hover_ghost")
		return false
	print("hover_modes: OK")
	return true


func _test_range_origin_api() -> bool:
	var scene := load("res://scenes/towers/basic_tower.tscn") as PackedScene
	var tower := scene.instantiate() as Node3D
	if tower == null or not tower.has_method("get_range_origin"):
		push_error("BasicTower missing get_range_origin")
		if tower:
			tower.free()
		return false
	if str(tower.call("get_range_shape")) != "SPHERE_3D":
		push_error("BasicTower should be SPHERE_3D")
		tower.free()
		return false
	print("range_origin basic: OK")
	tower.free()
	return true


func _test_guard_post_api() -> bool:
	var scene := load("res://scenes/towers/guard_post.tscn") as PackedScene
	if scene == null:
		push_error("Missing guard_post scene")
		return false
	var tower := scene.instantiate() as Node3D
	if tower == null or not tower.has_method("get_range_shape"):
		push_error("GuardPost missing range API")
		if tower:
			tower.free()
		return false
	if str(tower.call("get_range_shape")) != "FLOOR_DISC":
		push_error("GuardPost should be FLOOR_DISC")
		tower.free()
		return false
	if not is_equal_approx(float(tower.call("get_range_value")), 2.5):
		push_error("GuardPost radius should be 2.5")
		tower.free()
		return false
	if "slow_factor" in tower:
		push_error("GuardPost should not expose slow_factor")
		tower.free()
		return false
	if not tower.has_method("get_alive_guard_count") or not tower.has_method("get_next_respawn_eta"):
		push_error("GuardPost missing respawn HUD helpers")
		tower.free()
		return false
	print("guard_post: OK FLOOR_DISC 2.5 combat")
	tower.free()
	return true


func _test_guard_post_no_slow() -> bool:
	var src := FileAccess.get_file_as_string("res://scripts/towers/guard_post.gd")
	if src.is_empty():
		push_error("Could not read guard_post.gd")
		return false
	if src.contains("apply_slow") or src.contains("_apply_zone_slow") or src.contains("slow_factor"):
		push_error("GuardPost must not call or define slow aura")
		return false
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	if not enemy_src.contains("func apply_slow"):
		push_error("Enemy.apply_slow should remain available (unused)")
		return false
	print("guard_post no_slow: OK")
	return true


func _test_engagement_exclusivity() -> bool:
	var enemy_script = load("res://scripts/enemies/enemy.gd")
	var guard_script = load("res://scripts/towers/guard.gd")
	var e1 = enemy_script.new()
	var e2 = enemy_script.new()
	e1._alive = true
	e2._alive = true
	e1.combat_state = e1.CombatState.MOVING
	e2.combat_state = e2.CombatState.MOVING
	var g1 := Node3D.new()
	g1.set_script(guard_script)
	g1._alive = true
	g1.combat_state = g1.GuardState.IDLE
	var g2 := Node3D.new()
	g2.set_script(guard_script)
	g2._alive = true
	g2.combat_state = g2.GuardState.IDLE

	if not bool(g1.call("engage", e1)):
		push_error("Guard1 should engage enemy1")
		_free_nodes([g1, g2, e1, e2])
		return false
	if bool(g2.call("engage", e1)):
		push_error("Guard2 must not steal engaged enemy1")
		_free_nodes([g1, g2, e1, e2])
		return false
	if not bool(g2.call("engage", e2)):
		push_error("Guard2 should engage free enemy2")
		_free_nodes([g1, g2, e1, e2])
		return false
	if not bool(e1.call("is_engaged")) or not bool(e2.call("is_engaged")):
		push_error("Both enemies should be engaged")
		_free_nodes([g1, g2, e1, e2])
		return false
	print("engagement exclusivity: OK 1:1")
	_free_nodes([g1, g2, e1, e2])
	return true


func _free_nodes(nodes: Array) -> void:
	for n in nodes:
		if n != null and is_instance_valid(n):
			n.free()


func _test_research_cost_curve() -> bool:
	var cost_script = load("res://scripts/meta/research_cost.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var base: Dictionary = cfg.base_params("basic_tower")
	var base_cost: float = cost_script.total("basic_tower", base)
	if base_cost > 0.01:
		push_error("Base blueprint should cost ~0")
		return false
	var tiny := base.duplicate(true)
	tiny["range"] = 4.08
	var tiny_cost: float = cost_script.total("basic_tower", tiny)
	if tiny_cost <= 0.0 or tiny_cost > 5.0:
		push_error("Tiny range bump should be cheap, got %.3f" % tiny_cost)
		return false
	var big := base.duplicate(true)
	big["range"] = 6.0
	var big_cost: float = cost_script.total("basic_tower", big)
	if big_cost <= tiny_cost:
		push_error("Larger upgrade should cost more")
		return false
	print("research_cost: OK curve + tiny delta")
	return true


func _test_blueprint_resolve_immutable_catalog() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var resolver = load("res://scripts/meta/blueprint_resolver.gd")
	var defs_before: Array = catalog.create_all()
	var basic_before = catalog.find_by_id(defs_before, "basic_tower")
	var range_before := float(basic_before.base_range)
	var bp := {
		"id": "basic_tower_A",
		"display_name": "Test",
		"params": {"damage": 30.0, "range": 4.6, "fire_interval": 0.7, "projectile_speed": 32.0},
	}
	var resolved: Dictionary = resolver.resolve("basic_tower", bp)
	var defs_after: Array = catalog.create_all()
	var basic_after = catalog.find_by_id(defs_after, "basic_tower")
	if not is_equal_approx(float(basic_after.base_range), range_before):
		push_error("Catalog base_range mutated by resolve")
		return false
	if not is_equal_approx(float(resolved.get("range", 0.0)), 4.6):
		push_error("Resolved range mismatch")
		return false
	print("blueprint_resolve: OK catalog immutable")
	return true


func _test_upgrade_range_bonus() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	var basic = catalog.find_by_id(defs, "basic_tower")
	if not is_equal_approx(float(basic.upgrade_range_bonus), 1.5):
		push_error("Expected upgrade_range_bonus=1.5")
		return false
	var current := 4.6
	var final_range := current + float(basic.upgrade_range_bonus)
	if not is_equal_approx(final_range, 6.1):
		push_error("Expected 4.6+1.5=6.1")
		return false
	print("upgrade_bonus: OK +1.5 on current")
	return true


func _test_difficulty_catalog() -> bool:
	var diff = load("res://scripts/meta/difficulty_catalog.gd")
	var ids := {}
	for e in diff.all():
		ids[str(e["id"])] = float(e["multiplier"])
	if not ids.has("easy") or not is_equal_approx(ids["easy"], 0.8):
		push_error("Easy multiplier mismatch")
		return false
	if not ids.has("brutal") or not is_equal_approx(ids["brutal"], 1.5):
		push_error("Brutal multiplier mismatch")
		return false
	var hard_rp: int = diff.research_reward("hard")
	if hard_rp != 63:
		push_error("Hard RP reward expected 63, got %d" % hard_rp)
		return false
	print("difficulty: OK")
	return true
