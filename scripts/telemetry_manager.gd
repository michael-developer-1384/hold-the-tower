extends Node

const DAMAGE_EPS := 0.01

var run_id: String = ""
var _started_ms: int = 0
var _events_path := "res://telemetry/last_run_events.jsonl"
var _summary_path := "res://telemetry/last_run_summary.json"
var _active: bool = false

var starting_gold: int = 0
var starting_core_hp: int = 0
var level_id: String = "test_vertical_platforms"
var ending_gold: int = 0
var ending_core_hp: int = 0

var waves_started: int = 0
var waves_completed: int = 0
var enemies_spawned: int = 0
var enemies_killed: int = 0
var enemies_leaked: int = 0
var towers_built: int = 0
var upgrades_purchased: int = 0

var _wave_gold_before: int = 0
var _wave_core_before: int = 0
var _wave_start_ms: int = 0
var _wave_spawned: int = 0
var _wave_killed: int = 0
var _wave_leaked: int = 0
var _wave_summaries: Array = []
var _towers: Dictionary = {} # runtime_id -> snapshot dict
var _ended: bool = false


func start_run(p_level_id: String, gold: int, core_hp: int) -> void:
	_ended = false
	_active = true
	run_id = _make_run_id()
	_started_ms = Time.get_ticks_msec()
	level_id = p_level_id
	starting_gold = gold
	starting_core_hp = core_hp
	ending_gold = gold
	ending_core_hp = core_hp
	waves_started = 0
	waves_completed = 0
	enemies_spawned = 0
	enemies_killed = 0
	enemies_leaked = 0
	towers_built = 0
	upgrades_purchased = 0
	_wave_summaries.clear()
	_towers.clear()
	_write_text(_events_path, "")
	log_event("run_started", {
		"starting_gold": starting_gold,
		"starting_core_hp": starting_core_hp,
		"level_id": level_id,
	})


func log_event(event_name: String, data: Dictionary = {}) -> void:
	if not _active:
		return
	var payload := {
		"event": event_name,
		"run_id": run_id,
		"timestamp_ms": Time.get_ticks_msec() - _started_ms,
	}
	for k in data.keys():
		payload[k] = data[k]
	var line := JSON.stringify(payload)
	_append_line(_events_path, line)


func on_floor_focused(floor_index: int) -> void:
	log_event("floor_focused", {"floor_index": floor_index})


func on_wave_started(wave_number: int, enemy_count: int, gold: int, core_hp: int) -> void:
	waves_started += 1
	_wave_gold_before = gold
	_wave_core_before = core_hp
	_wave_start_ms = Time.get_ticks_msec()
	_wave_spawned = 0
	_wave_killed = 0
	_wave_leaked = 0
	log_event("wave_started", {
		"wave": wave_number,
		"enemy_count": enemy_count,
		"gold": gold,
		"core_hp": core_hp,
	})


func on_enemy_spawned() -> void:
	enemies_spawned += 1
	_wave_spawned += 1


func on_wave_completed(wave_number: int, gold: int, core_hp: int) -> void:
	waves_completed += 1
	var summary := {
		"wave_number": wave_number,
		"duration_ms": Time.get_ticks_msec() - _wave_start_ms,
		"spawned": _wave_spawned,
		"killed": _wave_killed,
		"leaked": _wave_leaked,
		"gold_before": _wave_gold_before,
		"gold_after": gold,
		"core_hp_before": _wave_core_before,
		"core_hp_after": core_hp,
	}
	_wave_summaries.append(summary)
	if _wave_spawned != _wave_killed + _wave_leaked:
		push_warning(
			"Telemetry wave integrity: wave %d spawned=%d killed=%d leaked=%d" % [
				wave_number, _wave_spawned, _wave_killed, _wave_leaked
			]
		)
	else:
		print("Wave %d complete: %d/%d resolved" % [wave_number, _wave_killed + _wave_leaked, _wave_spawned])
	log_event("wave_completed", summary)


func on_tower_built(tower: Node3D, cost: int, gold_after: int, wave: int, coverage: Dictionary) -> void:
	towers_built += 1
	_capture_tower(tower, coverage)
	log_event("tower_built", {
		"tower_runtime_id": tower.get("runtime_id"),
		"tower_type": str(tower.get("tower_type")),
		"floor_id": tower.get("floor_id"),
		"build_spot_id": tower.get("build_spot_id"),
		"position": _vec3(tower.global_position),
		"cost": cost,
		"wave": wave,
		"gold_after": gold_after,
		"coverage_by_floor": coverage.get("coverage_by_floor", {}),
	})


func on_tower_upgraded(tower: Node3D, cost: int, gold_after: int, range_before: float, coverage: Dictionary) -> void:
	upgrades_purchased += 1
	var to_level: int = int(tower.get("level"))
	_capture_tower(tower, coverage)
	log_event("tower_upgraded", {
		"tower_runtime_id": tower.get("runtime_id"),
		"from_level": maxi(to_level - 1, 1),
		"to_level": to_level,
		"cost": cost,
		"range_before": range_before,
		"range_after": float(tower.get("attack_range")),
		"gold_after": gold_after,
		"coverage_by_floor": coverage.get("coverage_by_floor", {}),
	})


func on_enemy_killed(
	source: Node,
	_enemy: Node3D,
	final_hit_damage: float,
	enemy_hp_before: float,
	target_floor_id: String,
	target_floor_index: int
) -> void:
	enemies_killed += 1
	_wave_killed += 1
	var source_floor := "unknown"
	var source_idx := 0
	var runtime_id := ""
	if source != null and is_instance_valid(source):
		source_floor = str(source.get("floor_id"))
		source_idx = int(source.get("floor_index"))
		runtime_id = str(source.get("runtime_id"))
	var delta := target_floor_index - source_idx
	log_event("enemy_killed", {
		"tower_runtime_id": runtime_id,
		"source_floor": source_floor,
		"target_floor": target_floor_id,
		"floor_delta": delta,
		"cross_floor": delta != 0,
		"final_hit_damage": final_hit_damage,
		"enemy_hp_before": enemy_hp_before,
	})
	if source != null and is_instance_valid(source) and source is Node3D:
		_capture_tower(source as Node3D, {})


## Backward-compatible alias; only counts kills.
func on_enemy_damaged(
	source_tower: Node3D,
	enemy: Node3D,
	amount: float,
	killed: bool,
	target_floor_id: String,
	target_floor_index: int
) -> void:
	if not killed:
		return
	on_enemy_killed(source_tower, enemy, amount, amount, target_floor_id, target_floor_index)


func on_enemy_reached_core(enemy: Node3D, wave: int) -> void:
	enemies_leaked += 1
	_wave_leaked += 1
	var hp := float(enemy.get("health")) if is_instance_valid(enemy) and "health" in enemy else 0.0
	log_event("enemy_reached_core", {"wave": wave, "enemy_remaining_hp": hp})


func end_run(result: String, gold: int, core_hp: int, towers: Array = []) -> void:
	if _ended or not _active:
		return
	_ended = true
	ending_gold = gold
	ending_core_hp = core_hp
	for t in towers:
		if is_instance_valid(t):
			_capture_tower(t, {})
	if result == "game_over":
		log_event("game_over", {"core_hp": core_hp})
	elif result == "level_complete":
		log_event("level_completed", {})
	log_event("run_ended", {"result": result})
	_write_summary(result)
	_active = false


func _capture_tower(tower: Node3D, coverage: Dictionary) -> void:
	var id := str(tower.get("runtime_id"))
	var tower_type := str(tower.get("tower_type"))
	var range_value = tower.get("attack_range")
	if tower.has_method("get_range_value"):
		range_value = tower.call("get_range_value")
	var snap := {
		"tower_runtime_id": id,
		"tower_type": tower_type,
		"floor_id": tower.get("floor_id"),
		"build_spot_id": tower.get("build_spot_id"),
		"level": tower.get("level"),
		"range": range_value,
		"shots_fired": tower.get("shots_fired"),
		"hits": tower.get("hits"),
		"damage_dealt": tower.get("damage_dealt"),
		"kills": tower.get("kills"),
		"same_floor_damage": tower.get("same_floor_damage"),
		"cross_floor_damage": tower.get("cross_floor_damage"),
		"damage_by_target_floor": tower.get("damage_by_target_floor"),
	}
	if "guard_attacks" in tower:
		snap["guard_attacks"] = tower.get("guard_attacks")
	if "guard_returns" in tower:
		snap["guard_returns"] = tower.get("guard_returns")
	if coverage.has("coverage_by_floor"):
		snap["coverage_by_floor"] = coverage["coverage_by_floor"]
	elif _towers.has(id) and _towers[id].has("coverage_by_floor"):
		snap["coverage_by_floor"] = _towers[id]["coverage_by_floor"]
	_towers[id] = snap


func _write_summary(result: String) -> void:
	var total_damage := 0.0
	var same := 0.0
	var cross := 0.0
	var tower_stats: Array = []
	for id in _towers.keys():
		var t: Dictionary = _towers[id]
		tower_stats.append(t)
		total_damage += float(t.get("damage_dealt", 0.0))
		same += float(t.get("same_floor_damage", 0.0))
		cross += float(t.get("cross_floor_damage", 0.0))
	_check_run_integrity(total_damage, same, cross)
	var summary := {
		"run_id": run_id,
		"result": result,
		"duration_ms": Time.get_ticks_msec() - _started_ms,
		"level_id": level_id,
		"starting_gold": starting_gold,
		"ending_gold": ending_gold,
		"starting_core_hp": starting_core_hp,
		"ending_core_hp": ending_core_hp,
		"waves_started": waves_started,
		"waves_completed": waves_completed,
		"enemies_spawned": enemies_spawned,
		"enemies_killed": enemies_killed,
		"enemies_leaked": enemies_leaked,
		"towers_built": towers_built,
		"upgrades_purchased": upgrades_purchased,
		"total_damage": total_damage,
		"same_floor_damage": same,
		"cross_floor_damage": cross,
		"wave_summaries": _wave_summaries,
		"tower_stats": tower_stats,
	}
	_write_text(_summary_path, JSON.stringify(summary, "\t"))


func _check_run_integrity(total_damage: float, same: float, cross: float) -> void:
	var ok := true
	if enemies_spawned != enemies_killed + enemies_leaked:
		ok = false
		push_warning(
			"Telemetry integrity: spawned=%d killed=%d leaked=%d" % [
				enemies_spawned, enemies_killed, enemies_leaked
			]
		)
	if waves_completed > waves_started:
		ok = false
		push_warning(
			"Telemetry integrity: waves_completed=%d > waves_started=%d" % [
				waves_completed, waves_started
			]
		)
	if absf((same + cross) - total_damage) > DAMAGE_EPS:
		ok = false
		push_warning(
			"Telemetry integrity: same(%.2f)+cross(%.2f) != total(%.2f)" % [
				same, cross, total_damage
			]
		)
	for id in _towers.keys():
		var t: Dictionary = _towers[id]
		if str(t.get("tower_type", "")) == "guard_post":
			if float(t.get("cross_floor_damage", 0.0)) > DAMAGE_EPS:
				ok = false
				push_warning(
					"Telemetry integrity: guard_post %s has cross_floor_damage=%.2f" % [
						id, float(t.get("cross_floor_damage", 0.0))
					]
				)
	if ok:
		print("Telemetry integrity OK")


func _make_run_id() -> String:
	return "run_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]


func _vec3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _write_text(path: String, text: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_warning("Telemetry write failed: %s (%s)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(text)
	f.close()


func _append_line(path: String, line: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(abs_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_warning("Telemetry append failed: %s" % path)
		return
	f.seek_end()
	f.store_line(line)
	f.close()
