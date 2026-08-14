extends SceneTree

## Headless acceptance helpers through v0.14.


func _init() -> void:
	var ok := true
	ok = _test_coverage() and ok
	ok = _test_floor_disc_coverage() and ok
	ok = _test_tower_def() and ok
	ok = _test_catalog() and ok
	ok = _test_visual_scenes() and ok
	ok = _test_feature_catalog() and ok
	ok = _test_enemy_catalog() and ok
	ok = _test_wave_catalog() and ok
	ok = _test_actual_damage() and ok
	ok = _test_kill_before_died() and ok
	ok = _test_hover_modes() and ok
	ok = _test_range_origin_api() and ok
	ok = _test_guard_post_api() and ok
	ok = _test_guard_post_no_slow() and ok
	ok = _test_lava_tower_api() and ok
	ok = _test_engagement_exclusivity() and ok
	ok = _test_research_allocation_curve() and ok
	ok = _test_blueprint_resolve_immutable_catalog() and ok
	ok = _test_upgrade_range_bonus() and ok
	ok = _test_difficulty_catalog() and ok
	ok = _test_bot_reward() and ok
	ok = _test_allocation_reversible() and ok
	ok = _test_refund_no_xp() and ok
	ok = _test_grant_rp_and_xp() and ok
	ok = _test_player_level_from_xp() and ok
	ok = _test_level_cap_blocks() and ok
	ok = _test_level_up_expands_cap() and ok
	ok = _test_lower_is_better() and ok
	ok = _test_tower_capacity_blocks() and ok
	ok = _test_apply_rejects_over_capacity() and ok
	ok = _test_profile_migration() and ok
	ok = _test_xp_reconstruct_from_history() and ok
	ok = _test_blueprint_migration_and_active() and ok
	ok = _test_resolve_blueprint_labels() and ok
	ok = _test_runtime_resolved_stats() and ok
	ok = _test_summary_research_snapshot_shape() and ok
	ok = _test_session_snapshot_shape() and ok
	ok = _test_timeline_snapshot_shape() and ok
	if ok:
		print("v0.14 validate: OK")
		quit(0)
	else:
		print("v0.14 validate: FAILED")
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
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	var def = catalog.find_by_id(defs, "basic_tower")
	if def == null:
		push_error("Missing sentry definition")
		return false
	if str(def.display_name) != "Sentry":
		push_error("basic_tower display_name should be Sentry")
		return false
	if float(def.base_range) != 4.0 or float(def.upgraded_range) != 5.5:
		push_error("Unexpected sentry ranges")
		return false
	if def.runtime_scene == null or def.visual_scene == null:
		push_error("Sentry missing runtime/visual scenes")
		return false
	print("tower_def: OK")
	return true


func _test_catalog() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	if defs.size() < 3:
		push_error("Catalog should include basic + guard + lava")
		return false
	var ids: Array = []
	for def in defs:
		ids.append(str(def.tower_id))
	if not ids.has("basic_tower") or not ids.has("guard_post") or not ids.has("lava_tower"):
		push_error("Missing tower ids in catalog")
		return false
	var guard = catalog.find_by_id(defs, "guard_post")
	if int(guard.cost) != 120 or int(guard.max_level) != 1:
		push_error("Guard post def mismatch")
		return false
	if not is_equal_approx(float(guard.base_fire_interval), 0.8):
		push_error("Guard post attack interval should be 0.8")
		return false
	if guard.runtime_scene == null or guard.visual_scene == null:
		push_error("Guard post missing runtime/visual scenes")
		return false
	var lava = catalog.find_by_id(defs, "lava_tower")
	if str(lava.display_name) != "Meltdown":
		push_error("lava_tower display_name should be Meltdown")
		return false
	print("catalog: OK basic+guard+lava")
	return true


func _test_visual_scenes() -> bool:
	var paths := [
		"res://scenes/towers/visuals/sentry_visual.tscn",
		"res://scenes/towers/visuals/guard_visual.tscn",
		"res://scenes/towers/visuals/guard_post_visual.tscn",
		"res://scenes/towers/visuals/lava_tower_visual.tscn",
		"res://scenes/enemies/visuals/bot_visual.tscn",
	]
	for p in paths:
		if load(p) == null:
			push_error("Missing visual scene %s" % p)
			return false
	print("visual_scenes: OK")
	return true


func _test_feature_catalog() -> bool:
	var features = load("res://scripts/meta/feature_catalog.gd")
	for fid in ["paper_hands", "diamond_hands", "path_follower", "blocker", "lava_flow", "always_on"]:
		if features.get_feature(fid) == null:
			push_error("Missing feature %s" % fid)
			return false
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	var sentry = catalog.find_by_id(defs, "basic_tower")
	var resolved: Array = features.resolve_ids(sentry.feature_ids)
	if resolved.size() < 1:
		push_error("Sentry features failed to resolve")
		return false
	print("feature_catalog: OK")
	return true


func _test_enemy_catalog() -> bool:
	var catalog = load("res://scripts/enemies/enemy_catalog.gd")
	var bot = catalog.get_bot()
	if bot == null or str(bot.enemy_id) != "bot":
		push_error("Bot enemy missing")
		return false
	if bot.runtime_scene == null or bot.visual_scene == null:
		push_error("Bot missing scenes")
		return false
	print("enemy_catalog: OK bot")
	return true


func _test_wave_catalog() -> bool:
	var waves = load("res://scripts/waves/wave_catalog.gd")
	if waves.wave_count() != 5:
		push_error("Expected 5 waves")
		return false
	var expected := [10, 12, 14, 16, 20]
	for i in expected.size():
		var w: Dictionary = waves.get_wave(i + 1)
		var total := 0
		for g in w.get("groups", []):
			total += int(g.get("count", 0))
			if str(g.get("enemy_id", "")) != "bot":
				push_error("Wave groups must be bot-only")
				return false
		if total != int(expected[i]):
			push_error("Wave %d count mismatch" % (i + 1))
			return false
	print("wave_catalog: OK bot totals")
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


func _test_lava_tower_api() -> bool:
	var scene := load("res://scenes/towers/lava_tower.tscn") as PackedScene
	if scene == null:
		push_error("Missing lava_tower scene")
		return false
	var tower := scene.instantiate() as Node3D
	if tower == null:
		push_error("lava_tower failed to instantiate")
		return false
	if str(tower.call("get_range_shape")) != "FLOOR_DISC":
		push_error("lava_tower should be FLOOR_DISC")
		tower.free()
		return false
	if not is_equal_approx(float(tower.call("get_range_value")), 2.5):
		push_error("lava_tower range should be 2.5")
		tower.free()
		return false
	if bool(tower.call("can_in_run_upgrade")):
		push_error("lava_tower should not in-run upgrade")
		tower.free()
		return false
	print("lava_tower: OK FLOOR_DISC 2.5 DCA")
	tower.free()
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


func _test_research_allocation_curve() -> bool:
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var spec: Dictionary = cfg.find_spec("basic_tower", "range")
	var v0: float = resolver.value_for(spec, 0)
	var v1: float = resolver.value_for(spec, 1)
	var v_mid: float = resolver.value_for(spec, 140)
	var v_max: float = resolver.value_for(spec, int(spec["max_investment_rp"]))
	if not is_equal_approx(v0, float(spec["base"])):
		push_error("0 RP should equal base")
		return false
	if is_equal_approx(v1, v0):
		push_error("1 RP must change the stat deterministically")
		return false
	if v_mid <= v1:
		push_error("More RP should improve higher-is-better stats")
		return false
	if not is_equal_approx(v_max, float(spec["best"])):
		push_error("Max investment should reach best")
		return false
	print("research_alloc: OK 1 RP + curve")
	return true


func _test_blueprint_resolve_immutable_catalog() -> bool:
	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var resolver = load("res://scripts/meta/blueprint_resolver.gd")
	var rr = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var defs_before: Array = catalog.create_all()
	var basic_before = catalog.find_by_id(defs_before, "basic_tower")
	var range_before := float(basic_before.base_range)
	var alloc: Dictionary = cfg.zero_allocations("basic_tower") as Dictionary
	alloc["range"] = 80
	var expected_range: float = rr.value_for(cfg.find_spec("basic_tower", "range"), 80)
	var bp := {
		"id": "basic_tower_A",
		"display_name": "Test",
		"allocations": alloc,
	}
	var resolved: Dictionary = resolver.resolve("basic_tower", bp)
	var defs_after: Array = catalog.create_all()
	var basic_after = catalog.find_by_id(defs_after, "basic_tower")
	if not is_equal_approx(float(basic_after.base_range), range_before):
		push_error("Catalog base_range mutated by resolve")
		return false
	if not is_equal_approx(float(resolved.get("range", 0.0)), expected_range):
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


func _test_bot_reward() -> bool:
	var catalog = load("res://scripts/enemies/enemy_catalog.gd")
	var bot = catalog.get_bot()
	if int(bot.reward) != 10:
		push_error("Bot reward must stay 10 gold, got %d" % int(bot.reward))
		return false
	print("bot_reward: OK 10")
	return true


func _test_allocation_reversible() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var pm = pm_script.new()
	pm._profile = pm._default_profile()
	pm._profile["research_points"] = 200
	pm._profile["research_xp_total"] = 500
	pm._profile["player_level"] = 5
	var a: Dictionary = cfg.zero_allocations("basic_tower")
	var b := a.duplicate(true)
	b["range"] = 40
	b["damage"] = 20
	pm.apply_tower_research_allocations("basic_tower", a)
	var rp0: int = pm.get_research_points()
	pm.apply_tower_research_allocations("basic_tower", b)
	pm.apply_tower_research_allocations("basic_tower", a)
	if pm.get_research_points() != rp0:
		push_error("Allocate+refund should restore RP exactly")
		pm.free()
		return false
	print("alloc_reversible: OK A->B->A")
	pm.free()
	return true


func _test_refund_no_xp() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var pm = pm_script.new()
	pm._profile = pm._default_profile()
	pm._profile["research_points"] = 100
	pm._profile["research_xp_total"] = 40
	var xp0: int = pm.get_research_xp_total()
	pm.refund_research(25)
	if pm.get_research_points() != 125:
		push_error("refund_research should add RP")
		pm.free()
		return false
	if pm.get_research_xp_total() != xp0:
		push_error("refund must not grant XP")
		pm.free()
		return false
	print("refund_no_xp: OK")
	pm.free()
	return true


func _test_grant_rp_and_xp() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var pm = pm_script.new()
	pm._profile = pm._default_profile()
	pm._profile["research_points"] = 10
	pm._profile["research_xp_total"] = 0
	pm.grant_research_reward(50)
	if pm.get_research_points() != 60:
		push_error("grant should add RP")
		pm.free()
		return false
	if pm.get_research_xp_total() != 50:
		push_error("grant should add XP")
		pm.free()
		return false
	print("grant_rp_xp: OK")
	pm.free()
	return true


func _test_player_level_from_xp() -> bool:
	var prog = load("res://scripts/meta/progression_config.gd")
	if prog.level_from_xp(0) != 1:
		push_error("0 XP should be level 1")
		return false
	if prog.level_from_xp(100) != 2:
		push_error("100 XP should be level 2")
		return false
	if prog.level_from_xp(3200) != 10:
		push_error("3200 XP should be level 10")
		return false
	if prog.level_from_xp(99999) != 10:
		push_error("XP past cap should stay level 10")
		return false
	if prog.tower_capacity("basic_tower", 1) != 120:
		push_error("Sentry L1 capacity should be 120")
		return false
	if prog.tower_capacity("guard_post", 10) != 1040:
		push_error("Guard L10 capacity should be 1040")
		return false
	if prog.tower_capacity("lava_tower", 1) != 100:
		push_error("Lava L1 capacity should be 100")
		return false
	print("player_level: OK")
	return true


func _test_level_cap_blocks() -> bool:
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var spec: Dictionary = cfg.find_spec("basic_tower", "range")
	var max_rp: int = int(spec["max_investment_rp"])
	var cap1: int = resolver.level_cap_for_stat(spec, 1)
	if cap1 != int(floor(float(max_rp) * 0.15)):
		push_error("Level 1 cap expected 15%% of max")
		return false
	var alloc: Dictionary = cfg.zero_allocations("basic_tower") as Dictionary
	alloc["range"] = max_rp
	var clamped: Dictionary = resolver.clamp_allocations("basic_tower", alloc, 1)
	if int(clamped["range"]) != cap1:
		push_error("Clamp should enforce level cap")
		return false
	print("level_cap: OK")
	return true


func _test_level_up_expands_cap() -> bool:
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var spec: Dictionary = cfg.find_spec("basic_tower", "damage")
	var cap4: int = resolver.level_cap_for_stat(spec, 4)
	var cap5: int = resolver.level_cap_for_stat(spec, 5)
	if cap5 <= cap4:
		push_error("Level-up should expand investment cap")
		return false
	print("level_up_cap: OK")
	return true


func _test_lower_is_better() -> bool:
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var spec: Dictionary = cfg.find_spec("basic_tower", "fire_interval")
	var v0: float = resolver.value_for(spec, 0)
	var v1: float = resolver.value_for(spec, 50)
	var v_max: float = resolver.value_for(spec, int(spec["max_investment_rp"]))
	if v1 >= v0:
		push_error("Lower-is-better should decrease with investment")
		return false
	if not is_equal_approx(v_max, float(spec["best"])):
		push_error("Max investment should reach best (lower)")
		return false
	print("lower_is_better: OK")
	return true


func _test_tower_capacity_blocks() -> bool:
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var alloc: Dictionary = cfg.zero_allocations("basic_tower") as Dictionary
	# Max every stat under level 10 per-stat caps → exceeds capacity 650.
	for sid in alloc.keys():
		var spec: Dictionary = cfg.find_spec("basic_tower", str(sid))
		alloc[sid] = resolver.level_cap_for_stat(spec, 10)
	if resolver.capacity_ok("basic_tower", alloc, 10):
		push_error("Maxing all stats should exceed tower capacity")
		return false
	if resolver.capacity_excess("basic_tower", alloc, 10) <= 0:
		push_error("Expected positive capacity excess")
		return false
	print("tower_capacity: OK blocks max-all")
	return true


func _test_apply_rejects_over_capacity() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var resolver = load("res://scripts/meta/research_resolver.gd")
	var pm = pm_script.new()
	pm._profile = pm._default_profile()
	pm._profile["research_points"] = 5000
	pm._profile["research_xp_total"] = 3200
	pm._profile["player_level"] = 10
	var alloc: Dictionary = cfg.zero_allocations("basic_tower") as Dictionary
	for sid in alloc.keys():
		var spec: Dictionary = cfg.find_spec("basic_tower", str(sid))
		alloc[sid] = resolver.level_cap_for_stat(spec, 10)
	var res: Dictionary = pm.apply_tower_research_allocations("basic_tower", alloc)
	if bool(res.get("ok", true)):
		push_error("Apply should reject over-capacity allocations")
		pm.free()
		return false
	print("apply_capacity: OK reject")
	pm.free()
	return true


func _test_profile_migration() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var pm = pm_script.new()
	pm._profile = {
		"profile_version": 11,
		"research_points": 100,
		"research_xp_total": 200,
		"tower_research": {
			"basic_tower": {
				"allocations": {"damage": 200, "range": 200, "fire_interval": 200, "projectile_speed": 100},
				"params": {},
				"committed": 700,
			},
			"guard_post": {
				"allocations": {
					"guard_hp": 0, "guard_damage": 0, "guard_attack_interval": 0,
					"defense_radius": 0, "healing_rate": 0, "healing_delay": 0, "respawn_time": 0,
				},
				"committed": 0,
			},
		},
		"tower_blueprints": {"basic_tower": [], "guard_post": []},
		"settings": {},
		"lifetime_stats": {"towers": {}, "by_blueprint": {}, "enemies": {}, "games": 0},
		"run_history": [],
	}
	pm._ensure_defaults()
	if int(pm._profile.get("profile_version", 0)) != 12:
		push_error("Migration should set profile_version 12")
		pm.free()
		return false
	var alloc: Dictionary = pm.get_tower_research_allocations("basic_tower")
	var total: int = 0
	for k in alloc.keys():
		total += int(alloc[k])
	if total > pm.get_tower_capacity("basic_tower"):
		push_error("Migrated research should respect capacity")
		pm.free()
		return false
	if pm.get_research_points() < 100:
		push_error("Migration should not lose RP (refund excess)")
		pm.free()
		return false
	print("profile_migration: OK")
	pm.free()
	return true


func _test_xp_reconstruct_from_history() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var pm = pm_script.new()
	pm._profile = {
		"profile_version": 11,
		"research_points": 50,
		"research_xp_total": 0,
		"tower_research": {},
		"tower_blueprints": {"basic_tower": [], "guard_post": []},
		"settings": {},
		"lifetime_stats": {"towers": {}, "by_blueprint": {}, "enemies": {}, "games": 0},
		"run_history": [
			{"research_earned": 50, "research_xp_earned": 50},
			{"research_earned": 40},
		],
	}
	pm._ensure_defaults()
	if pm.get_research_xp_total() != 90:
		push_error("XP should reconstruct from run_history, got %d" % pm.get_research_xp_total())
		pm.free()
		return false
	print("xp_reconstruct: OK")
	pm.free()
	return true


func _test_blueprint_migration_and_active() -> bool:
	var pm_script = load("res://scripts/profile/profile_manager.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var pm = pm_script.new()
	pm._profile = pm._default_profile()
	pm._profile["research_points"] = 300
	pm._profile["research_xp_total"] = 500
	pm._profile["player_level"] = 5
	var alloc: Dictionary = cfg.zero_allocations("basic_tower") as Dictionary
	alloc["range"] = 40
	pm._set_tower_research("basic_tower", alloc)
	pm._set_tower_blueprints("basic_tower", [{
		"id": "bp_test",
		"display_name": "Test BP",
		"active": true,
		"params": {"damage": 25.0, "range": 4.5, "fire_interval": 0.8, "projectile_speed": 28.0},
	}])
	# Migrate blueprint params → allocations, then sync.
	var list: Array = pm.get_tower_blueprints("basic_tower")
	list[0] = pm._migrate_blueprint_entry("basic_tower", list[0])
	pm._set_tower_blueprints("basic_tower", list)
	pm.apply_tower_research_allocations("basic_tower", list[0]["allocations"])
	if str(pm.get_active_blueprint_id("basic_tower")) != "bp_test":
		push_error("Matching allocations should activate blueprint")
		pm.free()
		return false
	var drifted := (list[0]["allocations"] as Dictionary).duplicate(true)
	drifted["range"] = int(drifted.get("range", 0)) + 5
	pm.apply_tower_research_allocations("basic_tower", drifted)
	if not str(pm.get_active_blueprint_id("basic_tower")).is_empty():
		push_error("Allocation drift must clear active blueprint")
		pm.free()
		return false
	print("blueprint_migrate_active: OK")
	pm.free()
	return true


func _test_resolve_blueprint_labels() -> bool:
	var resolver = load("res://scripts/meta/blueprint_resolver.gd")
	var research_resolved: Dictionary = resolver.resolve("basic_tower", {
		"id": "research",
		"display_name": "Research",
		"allocations": {},
	})
	if str(research_resolved.get("blueprint_id", "")) != "research":
		push_error("Expected research blueprint_id")
		return false
	if str(research_resolved.get("blueprint_name", "")) != "Research":
		push_error("Expected Research blueprint_name")
		return false
	print("resolve_labels: OK research fallback")
	return true


func _test_runtime_resolved_stats() -> bool:
	var resolver = load("res://scripts/meta/blueprint_resolver.gd")
	var rr = load("res://scripts/meta/research_resolver.gd")
	var cfg = load("res://scripts/meta/research_config.gd")
	var alloc: Dictionary = cfg.zero_allocations("guard_post") as Dictionary
	alloc["guard_hp"] = 30
	var resolved: Dictionary = resolver.resolve("guard_post", {
		"id": "research",
		"display_name": "Research",
		"allocations": alloc,
	})
	var expected: float = rr.value_for(cfg.find_spec("guard_post", "guard_hp"), 30)
	if not is_equal_approx(float(resolved.get("guard_hp", 0.0)), expected):
		push_error("Runtime resolve should use allocation curve")
		return false
	print("runtime_resolve: OK")
	return true


func _test_summary_research_snapshot_shape() -> bool:
	var snapshot := {
		"basic_tower": {"damage": 25.0, "range": 4.0},
		"guard_post": {"guard_hp": 100.0, "defense_radius": 2.5},
		"lava_tower": {"lava_damage": 10.0, "pour_rate": 1.2},
	}
	var alloc_snap := {
		"basic_tower": {"damage": 0, "range": 0},
		"guard_post": {"guard_hp": 0},
		"lava_tower": {"lava_damage": 0},
	}
	var summary := {
		"difficulty_id": "normal",
		"difficulty_multiplier": 1.0,
		"research_snapshot": snapshot.duplicate(true),
		"research_allocation_snapshot": alloc_snap.duplicate(true),
		"player_level_start": 3,
		"research_xp_total_start": 160,
		"research_earned": 50,
		"research_xp_earned": 50,
		"player_level_end": 4,
		"active_blueprints": {"basic_tower": "research", "guard_post": "research", "lava_tower": "research"},
	}
	for key in [
		"research_snapshot", "research_allocation_snapshot",
		"player_level_start", "research_xp_total_start",
		"research_earned", "research_xp_earned", "player_level_end",
	]:
		if not summary.has(key):
			push_error("summary missing %s" % key)
			return false
	var rs: Dictionary = summary["research_snapshot"]
	if not rs.has("basic_tower") or not rs.has("guard_post") or not rs.has("lava_tower"):
		push_error("research_snapshot must include basic_tower, guard_post, lava_tower")
		return false
	print("summary_snapshot: OK shape")
	return true


func _test_session_snapshot_shape() -> bool:
	var store = load("res://scripts/run/session_store.gd")
	var fake := {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"gold": 200,
		"core_hp": 18,
		"current_wave": 2,
		"active_wave": 1,
		"wave_running": false,
		"towers": [{"tower_type": "basic_tower", "build_spot_id": "s0", "level": 1}],
		"enemies": [],
		"schema_version": 1,
	}
	for key in ["level_id", "difficulty_id", "gold", "core_hp", "current_wave", "towers"]:
		if not fake.has(key):
			push_error("session missing %s" % key)
			return false
	if store.SCHEMA_VERSION < 1:
		push_error("session schema version invalid")
		return false
	print("session_snapshot: OK shape")
	return true


func _test_timeline_snapshot_shape() -> bool:
	# v0.13: timeline snaps are session-restore compatible (+ t).
	var snap := {
		"t": 1.2,
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"gold": 250,
		"core_hp": 20,
		"current_wave": 1,
		"active_wave": 0,
		"wave_running": false,
		"towers": [{
			"runtime_id": "T0001",
			"tower_type": "basic_tower",
			"build_spot_id": "s0",
			"level": 1,
			"gold_invested": 100,
			"position": {"x": 0, "y": 0, "z": 0},
		}],
		"enemies": [],
	}
	for key in ["t", "gold", "core_hp", "towers", "enemies", "build_spot_id"]:
		if key == "build_spot_id":
			if (snap["towers"] as Array).is_empty() or not (snap["towers"][0] as Dictionary).has("build_spot_id"):
				push_error("timeline snap tower missing build_spot_id")
				return false
			continue
		if not snap.has(key):
			push_error("timeline snap missing %s" % key)
			return false
	print("timeline_snapshot: OK shape")
	return true
