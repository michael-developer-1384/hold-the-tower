extends SceneTree

## Headless acceptance helpers for v0.6 / v0.6.1.


func _init() -> void:
	var ok := true
	ok = _test_coverage() and ok
	ok = _test_tower_def() and ok
	ok = _test_actual_damage() and ok
	ok = _test_kill_before_died() and ok
	ok = _test_hover_modes() and ok
	ok = _test_range_origin_api() and ok
	if ok:
		print("v0.6.1 validate: OK")
		quit(0)
	else:
		print("v0.6.1 validate: FAILED")
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
	var far: Dictionary = calc.compute(Vector3(100, 0, 0), 1.0, path, floors)
	if not (far.get("covered_indices", []) as Array).is_empty():
		push_error("Expected no far coverage")
		return false
	print("coverage: OK covered=%s by_floor=%s" % [str(covered), str(by_floor)])
	return true


func _test_tower_def() -> bool:
	var def_script = load("res://scripts/towers/tower_definition.gd")
	var def = def_script.new()
	if float(def.base_range) != 4.0 or float(def.upgraded_range) != 5.5:
		push_error("Unexpected tower ranges")
		return false
	if int(def.upgrade_cost) != 150 or int(def.max_level) != 2:
		push_error("Unexpected upgrade fields")
		return false
	print("tower_def: OK range 4->5.5 cost 150")
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
		push_error("Expected actual_damage=10, got %s" % str(result.get("actual_damage")))
		ok = false
	elif not is_equal_approx(float(tower.damage_dealt), 10.0):
		push_error("Tower damage_dealt should be 10, got %s" % str(tower.damage_dealt))
		ok = false
	elif int(tower.kills) != 1:
		push_error("Expected 1 kill")
		ok = false
	else:
		print("actual_damage: OK overkill 25 vs hp 10 -> 10")
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
		print("kill_order: OK record_kill before died")
	else:
		push_error("Expected kills==1 at died emit, got %s" % str(kills_at_died[0]))
	tower.free()
	if is_instance_valid(enemy):
		enemy.free()
	return ok


func _test_hover_modes() -> bool:
	var ctrl = load("res://scripts/level/floor_visual_controller.gd")
	if ctrl.mode_for_floor_indices(2, 0, 2) != "hover_ghost":
		push_error("Expected hover_ghost for floor 2 when focus 0 hover 2")
		return false
	if ctrl.mode_for_floor_indices(1, 0, 2) != "ghost":
		push_error("Expected ghost for non-hovered upper floor")
		return false
	if ctrl.mode_for_floor_indices(0, 0, 2) != "normal":
		push_error("Expected normal for focus floor")
		return false
	if ctrl.mode_for_floor_indices(1, 2, 1) != "hover":
		push_error("Expected hover for lower hovered floor")
		return false
	if ctrl.mode_for_floor_indices(2, 2, 2) != "normal":
		push_error("Expected normal when hover == focus")
		return false
	print("hover_modes: OK")
	return true


func _test_range_origin_api() -> bool:
	var scene := load("res://scenes/towers/basic_tower.tscn") as PackedScene
	if scene == null:
		push_error("Missing basic_tower scene")
		return false
	var tower := scene.instantiate() as Node3D
	if tower == null or not tower.has_method("get_range_origin"):
		push_error("BasicTower missing get_range_origin")
		if tower:
			tower.free()
		return false
	var marker := tower.get_node_or_null("RangeOrigin")
	if marker == null:
		push_error("RangeOrigin marker missing in scene")
		tower.free()
		return false
	print("range_origin: OK marker + API")
	tower.free()
	return true
