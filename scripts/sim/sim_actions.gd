class_name SimActions
extends RefCounted

## Shared command surface for UI, agents, tests, and replays.

const TYPE_PLACE := "PLACE_TOWER"
const TYPE_UPGRADE := "UPGRADE_TOWER"
const TYPE_START_WAVE := "START_WAVE"
const TYPE_WAIT := "WAIT"


static func get_available_actions(game: Node) -> Array:
	var out: Array = []
	if game == null or not is_instance_valid(game):
		return out
	if bool(game.get("game_over")) or bool(game.get("level_complete")):
		return out

	out.append({"type": TYPE_WAIT})

	var build = game.get("build_manager")
	var can_start := false
	if game.has_method("can_start_next_wave"):
		can_start = bool(game.call("can_start_next_wave"))
	else:
		var wave_running := bool(game.get("wave_running"))
		if not wave_running:
			var wm = game.get("wave_manager")
			var current_wave := int(game.get("current_wave"))
			var wave_count := 0
			if wm != null and wm.has_method("get_wave_count"):
				wave_count = int(wm.call("get_wave_count"))
			can_start = current_wave > 0 and current_wave <= wave_count
	if can_start:
		var bonus := 0
		if game.has_method("current_call_bonus"):
			bonus = int(game.call("current_call_bonus"))
		out.append({"type": TYPE_START_WAVE, "call_bonus": bonus})

	if build == null:
		return out
	var buying_power := int(game.get("buying_power")) if "buying_power" in game else int(game.get("gold"))
	var defs: Array = []
	if build.has_method("get_tower_defs"):
		defs = build.call("get_tower_defs")
	var spots: Array = []
	if build.has_method("get_spots"):
		spots = build.call("get_spots")

	for spot in spots:
		if spot == null or not is_instance_valid(spot):
			continue
		if bool(spot.get("occupied")):
			continue
		var spot_id := str(spot.get("spot_id"))
		for def in defs:
			if def == null:
				continue
			if bool(def.coming_soon) or not bool(def.unlocked):
				continue
			var quote := int(build.call("get_tower_quote", def)) if build.has_method("get_tower_quote") else int(def.cost)
			if buying_power < quote:
				continue
			var payload := {
				"type": TYPE_PLACE,
				"tower_id": str(def.tower_id),
				"spot_id": spot_id,
				"cost": quote,
				"base_cost": int(def.cost),
				"base_range": float(def.base_range),
				"base_damage": float(def.base_damage),
				"base_fire_interval": float(def.base_fire_interval),
				"range_shape": str(def.range_shape) if "range_shape" in def else "SPHERE_3D",
				"unit_count": int(def.unit_count) if "unit_count" in def else 1,
				"feature_ids": def.feature_ids if "feature_ids" in def else PackedStringArray(),
				"role": str(def.role) if "role" in def else "",
				"upgrade_cost": int(def.upgrade_cost) if "upgrade_cost" in def else 0,
				"upgrade_range_bonus": float(def.upgrade_range_bonus) if "upgrade_range_bonus" in def else 0.0,
				"can_in_run_upgrade": bool(def.can_in_run_upgrade) if "can_in_run_upgrade" in def else false,
			}
			var ResearchConfigScript = load("res://scripts/meta/research_config.gd")
			var params: Dictionary = ResearchConfigScript.base_params(str(def.tower_id))
			if typeof(RunManager) != TYPE_NIL:
				var snap = RunManager.research_snapshot.get(str(def.tower_id), {})
				if typeof(snap) == TYPE_DICTIONARY and not snap.is_empty():
					params = snap.duplicate(true)
			for k in params.keys():
				if not payload.has(k):
					payload[k] = params[k]
			out.append(payload)

	for t in game.get_tree().get_nodes_in_group("towers"):
		if t == null or not is_instance_valid(t):
			continue
		if str(t.get("tower_type")) != "basic_tower":
			continue
		if build.has_method("can_upgrade") and bool(build.call("can_upgrade", t)):
			var basic_def = _basic_definition(defs)
			var up_cost := (
				int(build.call("get_upgrade_quote", basic_def))
				if basic_def != null and build.has_method("get_upgrade_quote")
				else _basic_upgrade_cost(defs)
			)
			out.append({
				"type": TYPE_UPGRADE,
				"runtime_id": str(t.get("runtime_id")),
				"spot_id": str(t.get("build_spot_id")),
				"cost": up_cost,
				"upgrade_range_bonus": _basic_upgrade_bonus(defs),
			})
	return out


static func _basic_upgrade_cost(defs: Array) -> int:
	for def in defs:
		if def != null and str(def.tower_id) == "basic_tower":
			return int(def.upgrade_cost)
	return 150


static func _basic_definition(defs: Array) -> Resource:
	for def in defs:
		if def != null and str(def.tower_id) == "basic_tower":
			return def
	return null


static func _basic_upgrade_bonus(defs: Array) -> float:
	for def in defs:
		if def != null and str(def.tower_id) == "basic_tower":
			return float(def.upgrade_range_bonus)
	return 1.5


static func execute(game: Node, action: Dictionary) -> bool:
	if game == null or action.is_empty():
		return false
	var t := str(action.get("type", ""))
	match t:
		TYPE_WAIT:
			return true
		TYPE_START_WAVE:
			if game.has_method("start_next_wave"):
				return bool(game.call("start_next_wave", true))
			return false
		TYPE_PLACE:
			var build = game.get("build_manager")
			if build == null or not build.has_method("build_at_spot"):
				return false
			var tower = build.call("build_at_spot", str(action.get("spot_id", "")), str(action.get("tower_id", "")))
			return tower != null
		TYPE_UPGRADE:
			var build2 = game.get("build_manager")
			if build2 == null:
				return false
			var tower2 = null
			if build2.has_method("find_tower_by_runtime_id"):
				tower2 = build2.call("find_tower_by_runtime_id", str(action.get("runtime_id", "")))
			if tower2 == null:
				return false
			if build2.has_method("upgrade_tower"):
				return bool(build2.call("upgrade_tower", tower2))
			return false
		_:
			return false


static func read_state(game: Node) -> Dictionary:
	if game == null:
		return {}
	var towers: Array = []
	for t in game.get_tree().get_nodes_in_group("towers"):
		if t == null or not is_instance_valid(t):
			continue
		var tid := str(t.get("tower_type"))
		if tid.is_empty():
			continue
		towers.append({
			"runtime_id": str(t.get("runtime_id")),
			"tower_type": tid,
			"spot_id": str(t.get("build_spot_id")),
			"floor_id": str(t.get("floor_id")),
			"level": int(t.get("level")) if "level" in t else 1,
			"buying_power_invested": (
				int(t.get("buying_power_invested"))
				if "buying_power_invested" in t
				else int(t.get("gold_invested")) if "gold_invested" in t else 0
			),
			"damage_dealt": float(t.get("damage_dealt")) if "damage_dealt" in t else 0.0,
			"kills": int(t.get("kills")) if "kills" in t else 0,
			"attack_range": float(t.get("attack_range")) if "attack_range" in t else float(t.call("get_range_value")) if t.has_method("get_range_value") else 0.0,
			"position": t.global_position if t is Node3D else Vector3.ZERO,
		})
	var enemies: Array = []
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		enemies.append({
			"runtime_id": str(e.get("runtime_id")) if "runtime_id" in e else "",
			"enemy_id": str(e.get("enemy_id")) if "enemy_id" in e else "bot",
			"health": float(e.get("health")) if "health" in e else 0.0,
			"path_progress": float(e.call("get_path_progress")) if e.has_method("get_path_progress") else 0.0,
			"floor_id": str(e.get("floor_id")) if "floor_id" in e else "",
			"position": e.global_position if e is Node3D else Vector3.ZERO,
		})
	var free_spots: Array = []
	var build = game.get("build_manager")
	if build != null and build.has_method("get_spots"):
		for spot in build.call("get_spots"):
			if spot != null and is_instance_valid(spot) and not bool(spot.get("occupied")):
				free_spots.append({
					"spot_id": str(spot.get("spot_id")),
					"floor_id": str(spot.get("floor_id")),
					"position": spot.global_position if spot is Node3D else Vector3.ZERO,
				})
	var market = game.get("market_session")
	var hodl_price := float(market.get("current_price")) if market != null else 0.0
	var hodl_open := float(market.get("run_open_price")) if market != null and "run_open_price" in market else hodl_price
	return {
		"buying_power": int(game.get("buying_power")) if "buying_power" in game else int(game.get("gold")),
		# Replay compatibility for schema-1 packages.
		"gold": int(game.get("buying_power")) if "buying_power" in game else int(game.get("gold")),
		"hodl_price": hodl_price,
		"hodl_open": hodl_open,
		"core_hp": int(game.get("core_hp")),
		"current_wave": int(game.get("current_wave")),
		"active_wave": int(game.get("active_wave")),
		"wave_running": bool(game.get("wave_running")),
		"enemies_alive": int(game.get("enemies_alive")),
		"game_over": bool(game.get("game_over")),
		"level_complete": bool(game.get("level_complete")),
		"call_bonus": int(game.call("current_call_bonus")) if game.has_method("current_call_bonus") else 0,
		"phase_remaining": float(game.call("phase_remaining")) if game.has_method("phase_remaining") else 0.0,
		"phase_duration": float(game.get("phase_duration")) if "phase_duration" in game else 0.0,
		"phase_active": bool(game.get("phase_active")) if "phase_active" in game else false,
		"can_start_wave": bool(game.call("can_start_next_wave")) if game.has_method("can_start_next_wave") else false,
		"waves_started": int(game.get("waves_started")) if "waves_started" in game else 0,
		"towers": towers,
		"enemies": enemies,
		"free_spots": free_spots,
	}
