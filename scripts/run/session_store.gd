class_name SessionStore
extends RefCounted

## Wave-/pause-safe active run persistence at user://session.json

const SESSION_PATH := "user://session.json"
const SCHEMA_VERSION := 1


static func has_session() -> bool:
	return FileAccess.file_exists(SESSION_PATH)


static func clear() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


static func load_session() -> Dictionary:
	if not has_session():
		return {}
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func save_session(data: Dictionary) -> void:
	var payload := data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_at_ms"] = Time.get_ticks_msec()
	var abs_path := ProjectSettings.globalize_path(SESSION_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Session save failed")
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()


static func capture_from_game(game: Node) -> Dictionary:
	if game == null:
		return {}
	var towers: Array = []
	for t in game.get_tree().get_nodes_in_group("towers"):
		if t == null or not is_instance_valid(t):
			continue
		var tid := str(t.get("tower_type"))
		if tid.is_empty():
			continue
		var entry := {
			"tower_type": tid,
			"build_spot_id": str(t.get("build_spot_id")),
			"runtime_id": str(t.get("runtime_id")),
			"level": int(t.get("level")) if "level" in t else 1,
			"blueprint_id": str(t.get("blueprint_id")) if "blueprint_id" in t else "research",
			"gold_invested": int(t.get("gold_invested")) if "gold_invested" in t else 0,
			"position": _vec3(t.global_position),
		}
		var guards: Array = []
		if tid == "guard_post" and t.has_method("get_guards"):
			for g in t.call("get_guards"):
				if g == null or not is_instance_valid(g):
					continue
				guards.append({
					"slot_index": int(g.get("slot_index")) if "slot_index" in g else 0,
					"health": float(g.get("health")) if "health" in g else 0.0,
					"combat_state": int(g.get("combat_state")) if "combat_state" in g else 0,
					"position": _vec3(g.global_position),
				})
		if not guards.is_empty():
			entry["guards"] = guards
		towers.append(entry)

	var enemies: Array = []
	if bool(game.get("wave_running")):
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if e == null or not is_instance_valid(e):
				continue
			if "combat_state" in e and int(e.get("combat_state")) >= 2:
				continue
			enemies.append({
				"enemy_id": str(e.get("enemy_id")) if "enemy_id" in e else "bot",
				"health": float(e.get("health")) if "health" in e else 0.0,
				"max_health": float(e.get("max_health")) if "max_health" in e else 0.0,
				"path_progress": float(e.call("get_path_progress")) if e.has_method("get_path_progress") else 0.0,
				"floor_id": str(e.get("floor_id")) if "floor_id" in e else "",
				"position": _vec3(e.global_position),
			})

	var level_id := "vertical_test"
	var difficulty_id := "normal"
	var rm = _run_manager()
	if rm != null:
		level_id = str(rm.get("level_id"))
		difficulty_id = str(rm.get("difficulty_id"))

	return {
		"level_id": level_id,
		"difficulty_id": difficulty_id,
		"gold": int(game.get("gold")),
		"core_hp": int(game.get("core_hp")),
		"current_wave": int(game.get("current_wave")),
		"active_wave": int(game.get("active_wave")),
		"wave_running": bool(game.get("wave_running")),
		"towers": towers,
		"enemies": enemies,
	}


static func _vec3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func vec3_from(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))


static func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("RunManager")
