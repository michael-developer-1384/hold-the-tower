extends Node

## Persistent player profile at user://profile.json

const PROFILE_PATH := "user://profile.json"
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchCostScript := preload("res://scripts/meta/research_cost.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const HISTORY_CAP := 20

var _profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func get_profile() -> Dictionary:
	return _profile


func get_research_points() -> int:
	return int(_profile.get("research_points", 0))


func add_research(amount: int) -> void:
	if amount == 0:
		return
	_profile["research_points"] = maxi(0, get_research_points() + amount)
	save_profile()


func spend_research(amount: int) -> bool:
	if amount < 0:
		return false
	if get_research_points() < amount:
		return false
	_profile["research_points"] = get_research_points() - amount
	save_profile()
	return true


func is_level_unlocked(level_id: String) -> bool:
	var unlocked: Array = _profile.get("unlocked_levels", [])
	return unlocked.has(level_id)


func is_tower_unlocked(tower_id: String) -> bool:
	var unlocked: Array = _profile.get("unlocked_towers", [])
	return unlocked.has(tower_id)


func get_tower_blueprints(tower_id: String) -> Array:
	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	return all_bp.get(tower_id, [])


func get_active_blueprint_id(tower_id: String) -> String:
	for bp in get_tower_blueprints(tower_id):
		if bool(bp.get("active", false)):
			return str(bp.get("id", ""))
	var list := get_tower_blueprints(tower_id)
	if list.size() > 0:
		return str(list[0].get("id", ""))
	return ""


func get_active_blueprint(tower_id: String) -> Dictionary:
	var aid := get_active_blueprint_id(tower_id)
	return get_blueprint(tower_id, aid)


func get_blueprint(tower_id: String, blueprint_id: String) -> Dictionary:
	for bp in get_tower_blueprints(tower_id):
		if str(bp.get("id", "")) == blueprint_id:
			return bp
	return {}


func get_committed_research_cost(tower_id: String) -> float:
	var active := get_active_blueprint(tower_id)
	if active.is_empty():
		return 0.0
	return ResearchCostScript.total(tower_id, active.get("params", {}))


func save_blueprint(tower_id: String, blueprint_id: String, display_name: String, params: Dictionary) -> Dictionary:
	params = ResearchCostScript.clamp_params(tower_id, params)
	var list := get_tower_blueprints(tower_id)
	var idx := -1
	for i in list.size():
		if str(list[i].get("id", "")) == blueprint_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "Unknown blueprint"}

	var was_active := bool(list[idx].get("active", false))
	var new_cost := ResearchCostScript.total(tower_id, params)
	var delta := 0.0
	if was_active:
		var committed := get_committed_research_cost(tower_id)
		delta = new_cost - committed
		if delta > 0.0 and get_research_points() < int(ceili(delta)):
			return {"ok": false, "reason": "Not enough research points", "delta": delta}
		_apply_rp_delta(delta)

	list[idx]["display_name"] = display_name
	list[idx]["params"] = params
	_set_tower_blueprints(tower_id, list)
	save_profile()
	return {"ok": true, "delta": delta}


func activate_blueprint(tower_id: String, blueprint_id: String) -> Dictionary:
	var target := get_blueprint(tower_id, blueprint_id)
	if target.is_empty():
		return {"ok": false, "reason": "Unknown blueprint"}
	if bool(target.get("active", false)):
		return {"ok": true, "delta": 0.0}

	var new_cost := ResearchCostScript.total(tower_id, target.get("params", {}))
	var committed := get_committed_research_cost(tower_id)
	var delta := new_cost - committed
	if delta > 0.0 and get_research_points() < int(ceili(delta)):
		return {"ok": false, "reason": "Not enough research points", "delta": delta}
	_apply_rp_delta(delta)

	var list := get_tower_blueprints(tower_id)
	for i in list.size():
		list[i]["active"] = str(list[i].get("id", "")) == blueprint_id
	_set_tower_blueprints(tower_id, list)
	save_profile()
	return {"ok": true, "delta": delta}


func get_tower_lifetime(tower_id: String) -> Dictionary:
	var life: Dictionary = _profile.get("lifetime_stats", {})
	var towers: Dictionary = life.get("towers", {})
	return towers.get(tower_id, _empty_tower_stats())


func get_blueprint_stats(tower_id: String, blueprint_id: String) -> Dictionary:
	var life: Dictionary = _profile.get("lifetime_stats", {})
	var by_bp: Dictionary = life.get("by_blueprint", {})
	var tower_map: Dictionary = by_bp.get(tower_id, {})
	return tower_map.get(blueprint_id, _empty_tower_stats())


func record_run(run: Dictionary) -> void:
	var history: Array = _profile.get("run_history", [])
	history.push_front(run.duplicate(true))
	while history.size() > HISTORY_CAP:
		history.pop_back()
	_profile["run_history"] = history

	var life: Dictionary = _profile.get("lifetime_stats", {})
	if life.is_empty():
		life = {"towers": {}, "by_blueprint": {}, "games": 0}
	life["games"] = int(life.get("games", 0)) + 1

	var towers_life: Dictionary = life.get("towers", {})
	var by_bp: Dictionary = life.get("by_blueprint", {})
	var type_stats: Array = run.get("tower_type_stats", [])
	for entry in type_stats:
		var tid := str(entry.get("tower_type", ""))
		if tid.is_empty():
			continue
		towers_life[tid] = _merge_stats(towers_life.get(tid, _empty_tower_stats()), entry)
		var bid := str(entry.get("blueprint_id", ""))
		if not bid.is_empty():
			if not by_bp.has(tid):
				by_bp[tid] = {}
			var bp_map: Dictionary = by_bp[tid]
			bp_map[bid] = _merge_stats(bp_map.get(bid, _empty_tower_stats()), entry)
			by_bp[tid] = bp_map

	life["towers"] = towers_life
	life["by_blueprint"] = by_bp
	_profile["lifetime_stats"] = life

	# Per-instance also rolls times_built / gold into lifetime via type_stats.
	if str(run.get("result", "")) == "level_complete":
		var level_id := str(run.get("level_id", ""))
		var clears: Dictionary = _profile.get("level_clears", {})
		clears[level_id] = int(clears.get(level_id, 0)) + 1
		_profile["level_clears"] = clears
		var best: Dictionary = _profile.get("best_results", {})
		var prev := str(best.get(level_id, ""))
		var diff := str(run.get("difficulty_id", "normal"))
		if prev.is_empty() or _difficulty_rank(diff) >= _difficulty_rank(prev):
			best[level_id] = diff
			_profile["best_results"] = best

	save_profile()


func load_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if f:
			var text := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				_profile = parsed
				_ensure_defaults()
				return
	_profile = _default_profile()
	save_profile()


func save_profile() -> void:
	var abs_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Profile save failed: %s" % PROFILE_PATH)
		return
	f.store_string(JSON.stringify(_profile, "\t"))
	f.close()


func _apply_rp_delta(delta: float) -> void:
	if absf(delta) < 0.001:
		return
	if delta > 0.0:
		spend_research(int(ceili(delta)))
	else:
		add_research(int(floor(-delta)))


func _set_tower_blueprints(tower_id: String, list: Array) -> void:
	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	all_bp[tower_id] = list
	_profile["tower_blueprints"] = all_bp


func get_setting(key: String, default_value: Variant = null) -> Variant:
	var settings: Dictionary = _profile.get("settings", {})
	if settings.has(key):
		return settings[key]
	return default_value


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = _profile.get("settings", {})
	settings[key] = value
	_profile["settings"] = settings
	save_profile()


func is_debug_hud_enabled() -> bool:
	return bool(get_setting("show_debug_hud", false))


func set_debug_hud_enabled(enabled: bool) -> void:
	set_setting("show_debug_hud", enabled)


func _ensure_defaults() -> void:
	var d := _default_profile()
	for k in d.keys():
		if not _profile.has(k):
			_profile[k] = d[k]
	var settings: Dictionary = _profile.get("settings", {})
	var default_settings: Dictionary = d.get("settings", {})
	for sk in default_settings.keys():
		if not settings.has(sk):
			settings[sk] = default_settings[sk]
	_profile["settings"] = settings
	# Ensure blueprints exist for known towers.
	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	for tid in ["basic_tower", "guard_post"]:
		if not all_bp.has(tid) or (all_bp[tid] as Array).is_empty():
			all_bp[tid] = _default_blueprints(tid)
	_profile["tower_blueprints"] = all_bp


func _default_profile() -> Dictionary:
	return {
		"research_points": 150,
		"unlocked_levels": ["vertical_test"],
		"unlocked_towers": ["basic_tower", "guard_post"],
		"tower_blueprints": {
			"basic_tower": _default_blueprints("basic_tower"),
			"guard_post": _default_blueprints("guard_post"),
		},
		"lifetime_stats": {"towers": {}, "by_blueprint": {}, "games": 0},
		"run_history": [],
		"level_clears": {},
		"best_results": {},
		"settings": {
			"show_debug_hud": false,
		},
	}


func _default_blueprints(tower_id: String) -> Array:
	var base := ResearchConfigScript.base_params(tower_id)
	var labels := ["Blueprint A", "Blueprint B", "Blueprint C"]
	var ids := ["%s_A" % tower_id, "%s_B" % tower_id, "%s_C" % tower_id]
	var out: Array = []
	for i in 3:
		out.append({
			"id": ids[i],
			"display_name": labels[i],
			"active": i == 0,
			"params": base.duplicate(true),
		})
	return out


func _empty_tower_stats() -> Dictionary:
	return {
		"games_used": 0,
		"times_built": 0,
		"gold_invested": 0.0,
		"damage_dealt": 0.0,
		"kills": 0,
		"hits": 0,
		"shots": 0,
		"overkill_damage": 0.0,
		"same_floor_damage": 0.0,
		"cross_floor_damage": 0.0,
		"total_path_coverage": 0.0,
		"target_time": 0.0,
		"no_target_time": 0.0,
		"enemies_blocked": 0,
		"total_block_time_ms": 0,
		"guards_died": 0,
		"guards_respawned": 0,
		"guard_damage_taken": 0.0,
		"guard_healing_done": 0.0,
		"peak_simultaneous_blocks": 0,
	}


func _merge_stats(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	out["games_used"] = int(out.get("games_used", 0)) + 1
	for key in [
		"times_built", "kills", "hits", "shots", "enemies_blocked",
		"total_block_time_ms", "guards_died", "guards_respawned",
	]:
		out[key] = int(out.get(key, 0)) + int(b.get(key, 0))
	for key in [
		"gold_invested", "damage_dealt", "overkill_damage", "same_floor_damage",
		"cross_floor_damage", "total_path_coverage", "target_time", "no_target_time",
		"guard_damage_taken", "guard_healing_done",
	]:
		out[key] = float(out.get(key, 0.0)) + float(b.get(key, 0.0))
	out["peak_simultaneous_blocks"] = maxi(
		int(out.get("peak_simultaneous_blocks", 0)),
		int(b.get("peak_simultaneous_blocks", 0))
	)
	return out


func _difficulty_rank(id: String) -> int:
	match id:
		"easy":
			return 1
		"normal":
			return 2
		"hard":
			return 3
		"brutal":
			return 4
		_:
			return 0
