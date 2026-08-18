extends Node

## Persistent player profile at user://profile.json

const PROFILE_PATH := "user://profile.json"
const PROFILE_VERSION := 13
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const MarketConfigScript := preload("res://scripts/market/market_config.gd")
const MarketPricingScript := preload("res://scripts/market/market_pricing.gd")
const PortfolioAccountScript := preload("res://scripts/economy/portfolio_account.gd")
const PortfolioSettlementScript := preload("res://scripts/economy/portfolio_settlement.gd")
const SessionStoreScript := preload("res://scripts/run/session_store.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const HISTORY_CAP := 20
const MAX_BLUEPRINTS_PER_TOWER := 8

var _profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func get_profile() -> Dictionary:
	return _profile


func get_research_points() -> int:
	return int(_profile.get("research_points", 0))


func get_research_xp_total() -> int:
	return int(_profile.get("research_xp_total", 0))


func get_player_level() -> int:
	return ProgressionConfigScript.level_from_xp(get_research_xp_total())


func get_portfolio() -> Dictionary:
	return PortfolioAccountScript.normalize(_profile.get("portfolio", {}))


func get_account_balance_cents() -> int:
	return int(get_portfolio().get("account_balance_cents", 0))


func get_run_history() -> Array:
	return _profile.get("run_history", [])


func get_market() -> Dictionary:
	return _profile.get("market", _default_market()).duplicate(true)


func get_global_hodl_price() -> float:
	return MarketPricingScript.sanitize_persisted_price(
		float(get_market().get("current_price", MarketConfigScript.INITIAL_HODL_PRICE))
	)


func get_global_hodl_ath() -> float:
	return float(get_market().get("all_time_high", get_global_hodl_price()))


func get_next_ath_research_threshold() -> float:
	var anchor := float(get_market().get("ath_reward_anchor", get_global_hodl_ath()))
	return PortfolioSettlementScript.next_ath_threshold(anchor)


## Gameplay reward: +RP and +XP.
func grant_research_reward(amount: int) -> void:
	if amount <= 0 or _player_persist_blocked():
		return
	_profile["research_points"] = get_research_points() + amount
	_profile["research_xp_total"] = get_research_xp_total() + amount
	_profile["player_level"] = get_player_level()
	save_profile()


## Respec / research refund: +RP only (never XP).
func refund_research(amount: int) -> void:
	if amount <= 0 or _player_persist_blocked():
		return
	_profile["research_points"] = get_research_points() + amount
	save_profile()


func spend_research(amount: int) -> bool:
	if amount < 0 or _player_persist_blocked():
		return false
	if get_research_points() < amount:
		return false
	_profile["research_points"] = get_research_points() - amount
	save_profile()
	return true


## Legacy alias — refunds only (no XP). Prefer refund_research / grant_research_reward.
func add_research(amount: int) -> void:
	refund_research(amount)


func is_level_unlocked(level_id: String) -> bool:
	var unlocked: Array = _profile.get("unlocked_levels", [])
	return unlocked.has(level_id)


func is_tower_unlocked(tower_id: String) -> bool:
	var unlocked: Array = _profile.get("unlocked_towers", [])
	return unlocked.has(tower_id)


func get_max_blueprints_per_tower() -> int:
	return int(_profile.get("max_blueprints_per_tower", MAX_BLUEPRINTS_PER_TOWER))


func get_tower_research(tower_id: String) -> Dictionary:
	var all_research: Dictionary = _profile.get("tower_research", {})
	var entry: Dictionary = all_research.get(tower_id, {})
	var allocations: Dictionary
	if entry.is_empty():
		allocations = ResearchConfigScript.zero_allocations(tower_id)
	else:
		allocations = ResearchResolverScript.clamp_allocations(
			tower_id,
			entry.get("allocations", ResearchConfigScript.zero_allocations(tower_id)),
			get_player_level()
		)
	var params := ResearchResolverScript.params_from_allocations(tower_id, allocations)
	return {
		"allocations": allocations,
		"params": params,
		"committed": ResearchResolverScript.total_invested(allocations),
	}


func get_tower_research_allocations(tower_id: String) -> Dictionary:
	return get_tower_research(tower_id).get("allocations", {}).duplicate(true)


func get_tower_research_params(tower_id: String) -> Dictionary:
	return get_tower_research(tower_id).get("params", {}).duplicate(true)


func get_committed_research_cost(tower_id: String) -> int:
	return int(get_tower_research(tower_id).get("committed", 0))


func get_tower_capacity(tower_id: String) -> int:
	return ResearchResolverScript.tower_capacity(tower_id, get_player_level())


func apply_tower_research_allocations(tower_id: String, allocations: Dictionary) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	var level := get_player_level()
	var clamped := ResearchResolverScript.clamp_allocations(tower_id, allocations, level)
	var new_cost := ResearchResolverScript.total_invested(clamped)
	var capacity := ResearchResolverScript.tower_capacity(tower_id, level)
	if new_cost > capacity:
		return {
			"ok": false,
			"reason": "Capacity exceeded by %d RP" % (new_cost - capacity),
			"delta": new_cost - get_committed_research_cost(tower_id),
			"capacity": capacity,
			"invested": new_cost,
		}
	var committed := get_committed_research_cost(tower_id)
	var delta := new_cost - committed
	if delta > 0 and get_research_points() < delta:
		return {"ok": false, "reason": "Not enough research points", "delta": delta}
	_apply_rp_delta(delta)
	_set_tower_research(tower_id, clamped)
	_sync_blueprint_active_flags(tower_id)
	save_profile()
	return {"ok": true, "delta": delta, "committed": new_cost, "allocations": clamped}


func apply_tower_research(tower_id: String, params: Dictionary) -> Dictionary:
	## Compatibility: treat params as values to invert into allocations.
	var alloc := ResearchResolverScript.allocations_from_params(tower_id, params)
	return apply_tower_research_allocations(tower_id, alloc)


func preview_research_delta(tower_id: String, allocations: Dictionary) -> int:
	var clamped := ResearchResolverScript.clamp_allocations(tower_id, allocations, get_player_level())
	return ResearchResolverScript.total_invested(clamped) - get_committed_research_cost(tower_id)


func get_tower_blueprints(tower_id: String) -> Array:
	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	return all_bp.get(tower_id, [])


## Active only when a saved blueprint's allocations exactly match current research.
func get_active_blueprint_id(tower_id: String) -> String:
	_sync_blueprint_active_flags(tower_id)
	for bp in get_tower_blueprints(tower_id):
		if bool(bp.get("active", false)):
			return str(bp.get("id", ""))
	return ""


func get_active_blueprint(tower_id: String) -> Dictionary:
	var aid := get_active_blueprint_id(tower_id)
	if aid.is_empty():
		var alloc := get_tower_research_allocations(tower_id)
		return {
			"id": "research",
			"display_name": "Research",
			"allocations": alloc,
			"params": ResearchResolverScript.params_from_allocations(tower_id, alloc),
			"active": true,
		}
	return get_blueprint(tower_id, aid)


func get_matching_blueprint(tower_id: String) -> Dictionary:
	var aid := get_active_blueprint_id(tower_id)
	if aid.is_empty():
		return {}
	return get_blueprint(tower_id, aid)


func allocations_equal(a: Dictionary, b: Dictionary, tower_id: String) -> bool:
	return ResearchResolverScript.allocations_equal(a, b, tower_id)


func params_equal(a: Dictionary, b: Dictionary, tower_id: String) -> bool:
	## Legacy helper — compares resolved values from inverted allocations.
	var aa := ResearchResolverScript.allocations_from_params(tower_id, a)
	var bb := ResearchResolverScript.allocations_from_params(tower_id, b)
	return allocations_equal(aa, bb, tower_id)


func get_blueprint(tower_id: String, blueprint_id: String) -> Dictionary:
	for bp in get_tower_blueprints(tower_id):
		if str(bp.get("id", "")) == blueprint_id:
			return bp
	return {}


func create_blueprint(tower_id: String, display_name: String, allocations: Dictionary = {}) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	var list := get_tower_blueprints(tower_id)
	if list.size() >= get_max_blueprints_per_tower():
		return {"ok": false, "reason": "Blueprint limit reached"}
	if allocations.is_empty():
		allocations = get_tower_research_allocations(tower_id)
	allocations = ResearchResolverScript.clamp_allocations(tower_id, allocations, get_player_level())
	var params := ResearchResolverScript.params_from_allocations(tower_id, allocations)
	var bp_id := "%s_%d" % [tower_id, Time.get_ticks_msec()]
	var bp_name := display_name.strip_edges()
	if bp_name.is_empty():
		bp_name = "Blueprint %d" % (list.size() + 1)
	list.append({
		"id": bp_id,
		"display_name": bp_name,
		"active": false,
		"allocations": allocations,
		"params": params,
	})
	_set_tower_blueprints(tower_id, list)
	_sync_blueprint_active_flags(tower_id)
	save_profile()
	return {"ok": true, "id": bp_id}


func overwrite_blueprint(tower_id: String, blueprint_id: String, allocations: Dictionary = {}) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	if allocations.is_empty():
		allocations = get_tower_research_allocations(tower_id)
	allocations = ResearchResolverScript.clamp_allocations(tower_id, allocations, get_player_level())
	var params := ResearchResolverScript.params_from_allocations(tower_id, allocations)
	var list := get_tower_blueprints(tower_id)
	var idx := _find_blueprint_index(list, blueprint_id)
	if idx < 0:
		return {"ok": false, "reason": "Unknown blueprint"}
	list[idx]["allocations"] = allocations
	list[idx]["params"] = params
	_set_tower_blueprints(tower_id, list)
	_sync_blueprint_active_flags(tower_id)
	save_profile()
	return {"ok": true}


func rename_blueprint(tower_id: String, blueprint_id: String, display_name: String) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	var list := get_tower_blueprints(tower_id)
	var idx := _find_blueprint_index(list, blueprint_id)
	if idx < 0:
		return {"ok": false, "reason": "Unknown blueprint"}
	var bp_name := display_name.strip_edges()
	if bp_name.is_empty():
		return {"ok": false, "reason": "Name required"}
	list[idx]["display_name"] = bp_name
	_set_tower_blueprints(tower_id, list)
	save_profile()
	return {"ok": true}


func delete_blueprint(tower_id: String, blueprint_id: String) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	var list := get_tower_blueprints(tower_id)
	var idx := _find_blueprint_index(list, blueprint_id)
	if idx < 0:
		return {"ok": false, "reason": "Unknown blueprint"}
	list.remove_at(idx)
	_set_tower_blueprints(tower_id, list)
	save_profile()
	return {"ok": true}


func save_blueprint(tower_id: String, blueprint_id: String, display_name: String, allocations: Dictionary) -> Dictionary:
	if _player_persist_blocked():
		return {"ok": false, "reason": "Simulation does not write the player profile"}
	allocations = ResearchResolverScript.clamp_allocations(tower_id, allocations, get_player_level())
	var params := ResearchResolverScript.params_from_allocations(tower_id, allocations)
	var list := get_tower_blueprints(tower_id)
	var idx := _find_blueprint_index(list, blueprint_id)
	if idx < 0:
		return {"ok": false, "reason": "Unknown blueprint"}
	list[idx]["display_name"] = display_name
	list[idx]["allocations"] = allocations
	list[idx]["params"] = params
	_set_tower_blueprints(tower_id, list)
	_sync_blueprint_active_flags(tower_id)
	save_profile()
	return {"ok": true, "delta": 0}


func activate_blueprint(tower_id: String, blueprint_id: String) -> Dictionary:
	var target := get_blueprint(tower_id, blueprint_id)
	if target.is_empty():
		return {"ok": false, "reason": "Unknown blueprint"}
	var alloc: Dictionary = target.get("allocations", {})
	if alloc.is_empty() and target.has("params"):
		alloc = ResearchResolverScript.allocations_from_params(tower_id, target.get("params", {}))
	var result := apply_tower_research_allocations(tower_id, alloc)
	if not bool(result.get("ok", false)):
		return result
	result["id"] = blueprint_id
	return result


func get_tower_lifetime(tower_id: String) -> Dictionary:
	var life: Dictionary = _profile.get("lifetime_stats", {})
	var towers: Dictionary = life.get("towers", {})
	return towers.get(tower_id, _empty_tower_stats())


func get_enemy_lifetime(enemy_id: String) -> Dictionary:
	var life: Dictionary = _profile.get("lifetime_stats", {})
	var enemies: Dictionary = life.get("enemies", {})
	return enemies.get(enemy_id, _empty_enemy_stats())


func get_blueprint_stats(tower_id: String, blueprint_id: String) -> Dictionary:
	var life: Dictionary = _profile.get("lifetime_stats", {})
	var by_bp: Dictionary = life.get("by_blueprint", {})
	var tower_map: Dictionary = by_bp.get(tower_id, {})
	return tower_map.get(blueprint_id, _empty_tower_stats())


func settle_run(run: Dictionary) -> Dictionary:
	if _player_persist_blocked():
		var skipped := run.duplicate(true)
		skipped["settlement_status"] = "simulated"
		skipped["portfolio_pnl_cents"] = 0
		skipped["ath_rp_earned"] = 0
		skipped["ath_xp_earned"] = 0
		return skipped
	var run_id := str(run.get("run_id", ""))
	if run_id.is_empty():
		run_id = "run_%d_%06d" % [
			int(Time.get_unix_time_from_system() * 1000.0),
			randi_range(0, 999999),
		]
		run["run_id"] = run_id
	var settled_ids: Array = _profile.get("settled_run_ids", [])
	if settled_ids.has(run_id):
		for existing in _profile.get("run_history", []):
			if str(existing.get("run_id", "")) == run_id:
				return existing.duplicate(true)
		return {}

	var assisted := bool(run.get("assisted", false))
	var result := run.duplicate(true)
	if assisted:
		result["settlement_status"] = "assisted_non_ranked"
		result["portfolio_pnl_cents"] = 0
		result["ath_rp_earned"] = 0
		result["ath_xp_earned"] = 0
	else:
		var settlement := PortfolioSettlementScript.settle(
			get_portfolio(),
			get_market(),
			result
		)
		result = settlement.get("run", result)
		_profile["portfolio"] = settlement.get("portfolio", get_portfolio())
		_profile["market"] = settlement.get("market", get_market())
		var rp := int(result.get("ath_rp_earned", 0))
		var xp := int(result.get("ath_xp_earned", 0))
		_profile["research_points"] = get_research_points() + rp
		_profile["research_xp_total"] = get_research_xp_total() + xp
		_profile["player_level"] = get_player_level()
		result["research_total"] = get_research_points()
		result["research_xp_total_end"] = get_research_xp_total()
		result["player_level_end"] = get_player_level()
		_commit_market_history(result)
		result["settlement_status"] = "committed"

	settled_ids.append(run_id)
	while settled_ids.size() > MarketConfigScript.RUN_CANDLES_CAP:
		settled_ids.pop_front()
	_profile["settled_run_ids"] = settled_ids
	record_run(result, false)
	save_profile()
	return result


func commit_pending_last_run() -> Dictionary:
	var run_manager := _run_manager_or_null()
	if run_manager == null:
		return {}
	var run: Dictionary = run_manager.get("last_run")
	if typeof(run) != TYPE_DICTIONARY or run.is_empty():
		return {}
	var status := str(run.get("settlement_status", ""))
	if status == "committed" or status == "assisted_non_ranked" or status == "simulated":
		return run
	if _player_persist_blocked():
		run["settlement_status"] = "simulated"
		run_manager.set("last_run", run)
		return run
	var settled := settle_run(run)
	if not settled.is_empty():
		run_manager.set("last_run", settled)
	return settled


func record_run(run: Dictionary, save_now: bool = true) -> void:
	if _player_persist_blocked():
		return
	var history: Array = _profile.get("run_history", [])
	history.push_front(run.duplicate(true))
	while history.size() > HISTORY_CAP:
		history.pop_back()
	_profile["run_history"] = history

	var life: Dictionary = _profile.get("lifetime_stats", {})
	if life.is_empty():
		life = {"towers": {}, "by_blueprint": {}, "enemies": {}, "games": 0}
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

	var enemies_life: Dictionary = life.get("enemies", {})
	var enemy_stats: Array = run.get("enemy_type_stats", [])
	for entry in enemy_stats:
		var eid := str(entry.get("enemy_id", ""))
		if eid.is_empty():
			continue
		enemies_life[eid] = _merge_enemy_stats(enemies_life.get(eid, _empty_enemy_stats()), entry)

	life["towers"] = towers_life
	life["by_blueprint"] = by_bp
	life["enemies"] = enemies_life
	_profile["lifetime_stats"] = life

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

	if save_now:
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
	if name != "ProfileManager":
		return
	if not _sim_allows_persist():
		return
	var abs_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Profile save failed: %s" % PROFILE_PATH)
		return
	f.store_string(JSON.stringify(_profile, "\t"))
	f.close()


func reset_profile() -> void:
	## Wipes progression, market, portfolio, history, and research. Keeps device settings.
	var keep_settings: Dictionary = _profile.get("settings", {}).duplicate(true)
	_profile = _default_profile()
	if not keep_settings.is_empty():
		_profile["settings"] = keep_settings
	SessionStoreScript.clear()
	if is_inside_tree():
		var run_manager := get_node_or_null("/root/RunManager")
		if run_manager != null and run_manager.has_method("clear_last_run"):
			run_manager.call("clear_last_run")
	save_profile()


func _run_manager_or_null() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RunManager")


func _is_live_player_autoload() -> bool:
	return name == "ProfileManager"


func _sim_allows_persist() -> bool:
	return SimContextScript.should_persist_profile()


func _player_persist_blocked() -> bool:
	return _is_live_player_autoload() and not _sim_allows_persist()


func _apply_rp_delta(delta: int) -> void:
	if delta > 0:
		spend_research(delta)
	elif delta < 0:
		refund_research(-delta)


func _set_tower_blueprints(tower_id: String, list: Array) -> void:
	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	all_bp[tower_id] = list
	_profile["tower_blueprints"] = all_bp


func _set_tower_research(tower_id: String, allocations: Dictionary) -> void:
	var clamped := ResearchResolverScript.clamp_allocations(tower_id, allocations, get_player_level())
	var params := ResearchResolverScript.params_from_allocations(tower_id, clamped)
	var all_research: Dictionary = _profile.get("tower_research", {})
	all_research[tower_id] = {
		"allocations": clamped,
		"params": params,
		"committed": ResearchResolverScript.total_invested(clamped),
	}
	_profile["tower_research"] = all_research


func _sync_blueprint_active_flags(tower_id: String) -> void:
	var research := get_tower_research_allocations(tower_id)
	var list := get_tower_blueprints(tower_id)
	if list.is_empty():
		return
	var matched := false
	for i in list.size():
		var bp_alloc: Dictionary = list[i].get("allocations", {})
		if bp_alloc.is_empty() and list[i].has("params"):
			bp_alloc = ResearchResolverScript.allocations_from_params(tower_id, list[i].get("params", {}))
		var is_match := (not matched) and allocations_equal(bp_alloc, research, tower_id)
		list[i]["active"] = is_match
		if is_match:
			matched = true
	_set_tower_blueprints(tower_id, list)


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
	var loaded_version := int(_profile.get("profile_version", 0))
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

	if not _profile.has("max_blueprints_per_tower"):
		_profile["max_blueprints_per_tower"] = MAX_BLUEPRINTS_PER_TOWER

	var unlocked_towers: Array = _profile.get("unlocked_towers", [])
	if not unlocked_towers.has("lava_tower"):
		unlocked_towers.append("lava_tower")
		_profile["unlocked_towers"] = unlocked_towers

	var version := loaded_version
	if version < 13:
		_migrate_v13_market_and_portfolio()
	_profile["research_xp_total"] = maxi(0, int(_profile.get("research_xp_total", 0)))
	if version < PROFILE_VERSION and get_research_xp_total() == 0:
		_profile["research_xp_total"] = _reconstruct_xp_from_history()
	_profile["player_level"] = ProgressionConfigScript.level_from_xp(get_research_xp_total())
	_sanitize_persisted_market()

	var all_bp: Dictionary = _profile.get("tower_blueprints", {})
	var all_research: Dictionary = _profile.get("tower_research", {})
	var refund_total := 0
	var needs_migrate := version < PROFILE_VERSION

	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		if not all_bp.has(tid):
			all_bp[tid] = []

		var list: Array = all_bp[tid]
		for i in list.size():
			list[i] = _migrate_blueprint_entry(tid, list[i])
		all_bp[tid] = list

		if not all_research.has(tid):
			var params := ResearchConfigScript.base_params(tid)
			var migrated := false
			for bp in list:
				if bool(bp.get("active", false)):
					params = bp.get("params", params)
					migrated = true
					break
			if not migrated and not list.is_empty():
				params = list[0].get("params", params)
			var alloc := ResearchResolverScript.allocations_from_params(tid, params)
			var capped := _clamp_research_for_storage(tid, alloc)
			refund_total += ResearchResolverScript.total_invested(alloc) - ResearchResolverScript.total_invested(capped)
			all_research[tid] = {
				"allocations": capped,
				"params": ResearchResolverScript.params_from_allocations(tid, capped),
				"committed": ResearchResolverScript.total_invested(capped),
			}
		else:
			var entry: Dictionary = all_research[tid]
			var alloc: Dictionary
			if entry.has("allocations") and typeof(entry["allocations"]) == TYPE_DICTIONARY:
				alloc = entry["allocations"]
			elif entry.has("params"):
				alloc = ResearchResolverScript.allocations_from_params(tid, entry.get("params", {}))
			else:
				alloc = ResearchConfigScript.zero_allocations(tid)
			alloc = ResearchResolverScript.normalize_allocations(tid, alloc)
			var capped := _clamp_research_for_storage(tid, alloc)
			if needs_migrate or ResearchResolverScript.total_invested(alloc) != ResearchResolverScript.total_invested(capped):
				refund_total += ResearchResolverScript.total_invested(alloc) - ResearchResolverScript.total_invested(capped)
			all_research[tid] = {
				"allocations": capped,
				"params": ResearchResolverScript.params_from_allocations(tid, capped),
				"committed": ResearchResolverScript.total_invested(capped),
			}

	_profile["tower_blueprints"] = all_bp
	_profile["tower_research"] = all_research

	if refund_total > 0:
		_profile["research_points"] = get_research_points() + refund_total
	if needs_migrate:
		_profile["profile_version"] = PROFILE_VERSION

	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		_sync_blueprint_active_flags(tid)

	var life: Dictionary = _profile.get("lifetime_stats", {})
	if not life.has("enemies"):
		life["enemies"] = {}
	if not life.has("towers"):
		life["towers"] = {}
	if not life.has("by_blueprint"):
		life["by_blueprint"] = {}
	if not life.has("games"):
		life["games"] = 0
	var enemies: Dictionary = life.get("enemies", {})
	if not enemies.has("bot"):
		enemies["bot"] = _empty_enemy_stats()
	life["enemies"] = enemies
	_profile["lifetime_stats"] = life
	_profile["player_level"] = get_player_level()


func _reconstruct_xp_from_history() -> int:
	var sum := 0
	for run in _profile.get("run_history", []):
		if typeof(run) != TYPE_DICTIONARY:
			continue
		var earned := int(run.get("research_xp_earned", run.get("research_earned", 0)))
		if earned > 0:
			sum += earned
	return sum


func _migrate_v13_market_and_portfolio() -> void:
	_profile["portfolio"] = PortfolioAccountScript.normalize(_profile.get("portfolio", {}))
	var trusted_current := MarketConfigScript.INITIAL_HODL_PRICE
	var trusted_ath := trusted_current
	for run in _profile.get("run_history", []):
		if typeof(run) != TYPE_DICTIONARY:
			continue
		if run.has("hodl_close"):
			trusted_current = float(run.get("hodl_close", trusted_current))
		if run.has("hodl_high"):
			trusted_ath = maxf(trusted_ath, float(run.get("hodl_high", trusted_ath)))
		elif run.has("hodl_candles"):
			for candle in run.get("hodl_candles", []):
				trusted_ath = maxf(trusted_ath, float(candle.get("high", trusted_ath)))
	var market := _default_market()
	market["current_price"] = trusted_current
	market["all_time_high"] = maxf(trusted_ath, trusted_current)
	# Migration deliberately anchors rewards at the migrated ATH: no retroactive RP/XP.
	market["ath_reward_anchor"] = float(market["all_time_high"])
	_profile["market"] = market
	if not _profile.has("settled_run_ids"):
		_profile["settled_run_ids"] = []


func _commit_market_history(run: Dictionary) -> void:
	var market: Dictionary = get_market()
	var run_candle := {
		"run_id": str(run.get("run_id", "")),
		"wall_time_ms": int(run.get("wall_time_ms", Time.get_unix_time_from_system() * 1000.0)),
		"open": float(run.get("hodl_open", get_global_hodl_price())),
		"high": float(run.get("hodl_high", get_global_hodl_price())),
		"low": float(run.get("hodl_low", get_global_hodl_price())),
		"close": float(run.get("hodl_close", get_global_hodl_price())),
		"session_return": float(run.get("session_return", 0.0)),
	}
	var run_candles: Array = market.get("run_candles", [])
	run_candles.append(run_candle)
	_trim_front(run_candles, MarketConfigScript.RUN_CANDLES_CAP)
	market["run_candles"] = run_candles

	var recent: Array = market.get("recent_run_tapes", [])
	if run.has("market_tape"):
		recent.append({
			"run_id": str(run.get("run_id", "")),
			"opening_price": float(run.get("hodl_open", 0.0)),
			"entries": run.get("market_tape", []).duplicate(true),
		})
		_trim_front(recent, MarketConfigScript.RECENT_RUN_TAPE_CAP)
	market["recent_run_tapes"] = recent

	for spec in [
		["market_candles_1m", "candles_1m", MarketConfigScript.CANDLES_1M_CAP, 60000],
		["market_candles_1h", "candles_1h", MarketConfigScript.CANDLES_1H_CAP, 3600000],
		["market_candles_1d", "candles_1d", MarketConfigScript.CANDLES_1D_CAP, 86400000],
	]:
		var target: Array = market.get(str(spec[1]), [])
		for candle in run.get(str(spec[0]), []):
			var global_candle: Dictionary = candle.duplicate(true)
			global_candle["wall_time_ms"] = (
				int(run.get("wall_time_ms", 0))
				+ int(global_candle.get("start_ms", 0))
			)
			global_candle["run_id"] = str(run.get("run_id", ""))
			_append_global_candle(target, global_candle, int(spec[3]))
		_trim_front(target, int(spec[2]))
		market[str(spec[1])] = target
	_profile["market"] = market


func _trim_front(values: Array, cap: int) -> void:
	while values.size() > cap:
		values.pop_front()


func _append_global_candle(target: Array, candle: Dictionary, interval_ms: int) -> void:
	var wall_time := int(candle.get("wall_time_ms", 0))
	var bucket := int(floor(float(wall_time) / float(interval_ms))) * interval_ms
	candle["bucket_wall_time_ms"] = bucket
	if not target.is_empty():
		var last: Dictionary = target.back()
		if int(last.get("bucket_wall_time_ms", -1)) == bucket:
			last["high"] = maxf(float(last.get("high", 0.0)), float(candle.get("high", 0.0)))
			last["low"] = minf(float(last.get("low", 0.0)), float(candle.get("low", 0.0)))
			last["close"] = float(candle.get("close", last.get("close", 0.0)))
			last["events"] = int(last.get("events", 0)) + int(candle.get("events", 0))
			target[target.size() - 1] = last
			return
	target.append(candle)


func _clamp_research_for_storage(tower_id: String, allocations: Dictionary) -> Dictionary:
	var level := get_player_level()
	var capped := ResearchResolverScript.clamp_allocations(tower_id, allocations, level)
	if not ResearchResolverScript.capacity_ok(tower_id, capped, level):
		capped = ResearchResolverScript.clamp_to_capacity(tower_id, capped, level)
	return capped


func _migrate_blueprint_entry(tower_id: String, bp: Dictionary) -> Dictionary:
	var out := bp.duplicate(true)
	var alloc: Dictionary
	if out.has("allocations") and typeof(out["allocations"]) == TYPE_DICTIONARY:
		alloc = out["allocations"]
	elif out.has("params"):
		alloc = ResearchResolverScript.allocations_from_params(tower_id, out.get("params", {}))
	else:
		alloc = ResearchConfigScript.zero_allocations(tower_id)
	alloc = ResearchResolverScript.normalize_allocations(tower_id, alloc)
	# Blueprints keep absolute allocations (may exceed current level cap); activate clamps on load.
	out["allocations"] = alloc
	out["params"] = ResearchResolverScript.params_from_allocations(tower_id, alloc)
	return out


func _default_profile() -> Dictionary:
	return {
		"profile_version": PROFILE_VERSION,
		"research_points": 150,
		"research_xp_total": 0,
		"player_level": 1,
		"unlocked_levels": ["vertical_test"],
		"unlocked_towers": ["basic_tower", "guard_post", "lava_tower"],
		"max_blueprints_per_tower": MAX_BLUEPRINTS_PER_TOWER,
		"tower_research": {
			"basic_tower": _default_research("basic_tower"),
			"guard_post": _default_research("guard_post"),
			"lava_tower": _default_research("lava_tower"),
		},
		"tower_blueprints": {
			"basic_tower": [],
			"guard_post": [],
			"lava_tower": [],
		},
		"lifetime_stats": {"towers": {}, "by_blueprint": {}, "enemies": {"bot": _empty_enemy_stats()}, "games": 0},
		"run_history": [],
		"settled_run_ids": [],
		"portfolio": PortfolioAccountScript.default_state(),
		"market": _default_market(),
		"level_clears": {},
		"best_results": {},
		"settings": {
			"show_debug_hud": false,
		},
	}


func _default_market() -> Dictionary:
	return {
		"current_price": MarketConfigScript.INITIAL_HODL_PRICE,
		"all_time_high": MarketConfigScript.INITIAL_HODL_PRICE,
		"ath_reward_anchor": MarketConfigScript.INITIAL_HODL_PRICE,
		"recent_run_tapes": [],
		"candles_1m": [],
		"candles_1h": [],
		"candles_1d": [],
		"run_candles": [],
	}


func _sanitize_persisted_market() -> void:
	var market: Dictionary = _profile.get("market", _default_market()).duplicate(true)
	var raw := float(market.get("current_price", MarketConfigScript.INITIAL_HODL_PRICE))
	var sanitized := MarketPricingScript.sanitize_persisted_price(raw)
	if is_equal_approx(raw, sanitized):
		return
	market["current_price"] = sanitized
	market["all_time_high"] = maxf(float(market.get("all_time_high", sanitized)), sanitized)
	_profile["market"] = market


func _default_research(tower_id: String) -> Dictionary:
	var allocations := ResearchConfigScript.zero_allocations(tower_id)
	return {
		"allocations": allocations,
		"params": ResearchResolverScript.params_from_allocations(tower_id, allocations),
		"committed": 0,
	}


func _find_blueprint_index(list: Array, blueprint_id: String) -> int:
	for i in list.size():
		if str(list[i].get("id", "")) == blueprint_id:
			return i
	return -1


func _empty_tower_stats() -> Dictionary:
	return {
		"games_used": 0,
		"times_built": 0,
		"buying_power_invested": 0.0,
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


func _empty_enemy_stats() -> Dictionary:
	return {
		"encountered": 0,
		"killed": 0,
		"leaks": 0,
		"damage_taken": 0.0,
		"blocked": 0,
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
		"buying_power_invested", "damage_dealt", "overkill_damage", "same_floor_damage",
		"cross_floor_damage", "total_path_coverage", "target_time", "no_target_time",
		"guard_damage_taken", "guard_healing_done",
	]:
		out[key] = float(out.get(key, 0.0)) + float(b.get(key, 0.0))
	if b.has("gold_invested"):
		out["buying_power_invested"] = (
			float(out.get("buying_power_invested", 0.0))
			+ float(b.get("gold_invested", 0.0))
		)
	out["peak_simultaneous_blocks"] = maxi(
		int(out.get("peak_simultaneous_blocks", 0)),
		int(b.get("peak_simultaneous_blocks", 0))
	)
	return out


func _merge_enemy_stats(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in ["encountered", "killed", "leaks", "blocked"]:
		out[key] = int(out.get(key, 0)) + int(b.get(key, 0))
	out["damage_taken"] = float(out.get("damage_taken", 0.0)) + float(b.get("damage_taken", 0.0))
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
