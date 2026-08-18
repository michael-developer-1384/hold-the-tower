extends RefCounted

## Replay a run with one PLACE neutralized. Other actions stay at the same times.

const Realized := preload("res://scripts/balance/metrics/realized_combat_value.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


static func filter_log(action_log: Array, spot_id: String) -> Array:
	var out: Array = []
	for entry in action_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		var t := str(action.get("type", ""))
		if t == "PLACE_TOWER" and str(action.get("spot_id", "")) == spot_id:
			continue
		if t == "UPGRADE_TOWER" and str(action.get("spot_id", "")) == spot_id:
			continue
		out.append(entry)
	return out


static func placed_spots(action_log: Array) -> PackedStringArray:
	var spots: PackedStringArray = PackedStringArray()
	for entry in action_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		if str(action.get("type", "")) != "PLACE_TOWER":
			continue
		var sid := str(action.get("spot_id", ""))
		if sid.is_empty() or sid in spots:
			continue
		spots.append(sid)
	return spots


static func replay(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var sim_opts := {
		"level_id": str(opts.get("level_id", "vertical_test")),
		"difficulty_id": str(opts.get("difficulty_id", "normal")),
		"seed": int(opts.get("seed", 7)),
		"config": opts.get("config", {"starting_gold": 1000}),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
	}
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup(sim_opts, tree)
	sim.set_replay(replay_log)
	await sim.await_ready()
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(tree, sim, {
		"time_scale": float(opts.get("time_scale", 40.0)),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
		"decide": false,
	})
	var result: Dictionary = sim.finish()
	result["replayed_action_log"] = sim.action_log.duplicate(true)
	sim.cleanup()
	await tree.process_frame
	return result


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var spot_id := str(opts.get("spot_id", ""))
	var baseline: Dictionary = await replay(tree, opts)
	var without_opts := opts.duplicate(true)
	without_opts["action_log"] = filter_log(replay_log, spot_id)
	var without: Dictionary = await replay(tree, without_opts)
	return _pack_one(replay_log, spot_id, baseline, without, without_opts["action_log"])


static func analyze_build(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var spots: PackedStringArray = placed_spots(replay_log)
	var baseline: Dictionary = await replay(tree, opts)
	var by_tower: Array = []
	for sid in spots:
		var without_opts := opts.duplicate(true)
		without_opts["action_log"] = filter_log(replay_log, str(sid))
		var without: Dictionary = await replay(tree, without_opts)
		by_tower.append(_metrics_for(str(sid), baseline, without, replay_log))
	return {
		"full_build": _compact_result(baseline),
		"by_tower": by_tower,
		"spot_count": spots.size(),
	}


static func _pack_one(replay_log: Array, spot_id: String, baseline: Dictionary, without: Dictionary, filtered: Array) -> Dictionary:
	var metrics: Dictionary = _metrics_for(spot_id, baseline, without, replay_log)
	return {
		"spot_id": spot_id,
		"baseline": baseline,
		"without": without,
		"filtered_log": filtered,
		"other_actions_unchanged": _same_non_target_actions(replay_log, without.get("replayed_action_log", []), spot_id),
		"delta": _delta(baseline, without),
		"metrics": metrics,
	}


static func _metrics_for(spot_id: String, baseline: Dictionary, without: Dictionary, replay_log: Array) -> Dictionary:
	var row: Dictionary = _row_for_spot(baseline, spot_id)
	var others_base := float(baseline.get("total_damage", 0.0)) - float(row.get("damage", 0.0))
	var others_without := 0.0
	var others_kills_base := int(baseline.get("enemies_killed", 0)) - int(row.get("kills", 0))
	var others_kills_without := 0
	for other in without.get("tower_stats", []):
		others_without += float(other.get("damage", 0.0))
		others_kills_without += int(other.get("kills", 0))
	var damage_enabled := others_base - others_without
	var kills_enabled := others_kills_base - others_kills_without
	var leaks_prevented := int(without.get("enemies_leaked", 0)) - int(baseline.get("enemies_leaked", 0))
	var core_preserved := int(baseline.get("lives_remaining", 0)) - int(without.get("lives_remaining", 0))
	var cost := cost_for(str(row.get("tower_type", "")), replay_log, spot_id)
	var blocking := float(row.get("total_block_time_ms", 0.0)) / 1000.0
	var measured := {
		"tower_id": str(row.get("tower_type", "")),
		"spot_id": spot_id,
		"cost": cost,
		"direct_damage": float(row.get("damage", 0.0)),
		"direct_kills": int(row.get("kills", 0)),
		"blocking_seconds": blocking,
		"damage_enabled_for_other_towers": damage_enabled,
		"kills_enabled_for_other_towers": kills_enabled,
		"leaks_prevented": leaks_prevented,
		"core_hp_preserved": core_preserved,
		"other_measured_utility": 0.0,
	}
	var realized: Dictionary = Realized.evaluate(measured)
	measured["marginal_total_damage"] = float(baseline.get("total_damage", 0.0)) - float(without.get("total_damage", 0.0))
	measured["marginal_total_value"] = float(realized.get("combat_value", 0.0))
	measured["marginal_value_per_gold"] = float(realized.get("value_per_gold", 0.0))
	measured["combat_value"] = realized
	return measured


static func cost_for(tower_id: String, replay_log: Array, spot_id: String) -> float:
	for entry in replay_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		if str(action.get("type", "")) == "PLACE_TOWER" and str(action.get("spot_id", "")) == spot_id:
			if action.has("cost"):
				return float(action.get("cost"))
			tower_id = str(action.get("tower_id", tower_id))
			break
	var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tower_id)
	return float(def.cost) if def else 100.0


static func _row_for_spot(result: Dictionary, spot_id: String) -> Dictionary:
	for row in result.get("tower_stats", []):
		if str(row.get("spot_id")) == spot_id:
			return row
	return {}


static func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"won": bool(result.get("won", false)),
		"total_damage": float(result.get("total_damage", 0.0)),
		"enemies_killed": int(result.get("enemies_killed", 0)),
		"enemies_leaked": int(result.get("enemies_leaked", 0)),
		"lives_remaining": int(result.get("lives_remaining", 0)),
	}


static func _same_non_target_actions(original: Array, replayed: Array, spot_id: String) -> bool:
	var a := _compact(original, spot_id)
	var b := _compact(replayed, spot_id)
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i].get("type")) != str(b[i].get("type")):
			return false
		if str(a[i].get("spot_id", "")) != str(b[i].get("spot_id", "")):
			return false
		if str(a[i].get("tower_id", "")) != str(b[i].get("tower_id", "")):
			return false
	return true


static func _compact(entries: Array, skip_spot: String) -> Array:
	var out: Array = []
	for entry in entries:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		if str(action.get("spot_id", "")) == skip_spot:
			continue
		out.append(action)
	return out


static func _delta(baseline: Dictionary, without: Dictionary) -> Dictionary:
	return {
		"delta_total_damage": float(baseline.get("total_damage", 0.0)) - float(without.get("total_damage", 0.0)),
		"delta_leaks": int(baseline.get("enemies_leaked", 0)) - int(without.get("enemies_leaked", 0)),
		"delta_core_hp": int(baseline.get("lives_remaining", 0)) - int(without.get("lives_remaining", 0)),
		"delta_duration": float(baseline.get("duration", 0.0)) - float(without.get("duration", 0.0)),
		"delta_kills": int(baseline.get("enemies_killed", 0)) - int(without.get("enemies_killed", 0)),
		"delta_other_tower_damage": float(baseline.get("total_damage", 0.0)) - float(without.get("total_damage", 0.0)),
	}
