extends SceneTree

## Headless acceptance helpers for v0.6 (coverage + upgrade data).


func _init() -> void:
	var ok := true
	ok = _test_coverage() and ok
	ok = _test_tower_def() and ok
	if ok:
		print("v0.6 validate: OK")
		quit(0)
	else:
		print("v0.6 validate: FAILED")
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
