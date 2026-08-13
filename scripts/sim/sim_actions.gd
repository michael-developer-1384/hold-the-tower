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

	var wave_running := bool(game.get("wave_running"))
	if not wave_running:
		var wm = game.get("wave_manager")
		var current_wave := int(game.get("current_wave"))
		var wave_count := 0
		if wm != null and wm.has_method("get_wave_count"):
			wave_count = int(wm.call("get_wave_count"))
		if current_wave > 0 and current_wave <= wave_count:
			out.append({"type": TYPE_START_WAVE})

	var build = game.get("build_manager")
	if build == null:
		return out
	var gold := int(game.get("gold"))
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
			if gold < int(def.cost):
				continue
			out.append({
				"type": TYPE_PLACE,
				"tower_id": str(def.tower_id),
				"spot_id": spot_id,
				"cost": int(def.cost),
			})

	for t in game.get_tree().get_nodes_in_group("towers"):
		if t == null or not is_instance_valid(t):
			continue
		if str(t.get("tower_type")) != "basic_tower":
			continue
		if build.has_method("can_upgrade") and bool(build.call("can_upgrade", t)):
			out.append({
				"type": TYPE_UPGRADE,
				"runtime_id": str(t.get("runtime_id")),
				"spot_id": str(t.get("build_spot_id")),
				"cost": 150,
			})
	return out


static func execute(game: Node, action: Dictionary) -> bool:
	if game == null or action.is_empty():
		return false
	var t := str(action.get("type", ""))
	match t:
		TYPE_WAIT:
			return true
		TYPE_START_WAVE:
			if game.has_method("start_next_wave"):
				game.call("start_next_wave")
				return bool(game.get("wave_running"))
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
			"gold_invested": int(t.get("gold_invested")) if "gold_invested" in t else 0,
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
	return {
		"gold": int(game.get("gold")),
		"core_hp": int(game.get("core_hp")),
		"current_wave": int(game.get("current_wave")),
		"active_wave": int(game.get("active_wave")),
		"wave_running": bool(game.get("wave_running")),
		"enemies_alive": int(game.get("enemies_alive")),
		"game_over": bool(game.get("game_over")),
		"level_complete": bool(game.get("level_complete")),
		"towers": towers,
		"enemies": enemies,
		"free_spots": free_spots,
	}
