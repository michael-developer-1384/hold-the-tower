extends Node

## Inspect-only Time Machine: 5 Hz ring buffer of run snapshots.

const HZ := 5.0
const MAX_SECONDS := 120.0
const DUMP_PATH := "user://timeline_last_run.json"

var enabled: bool = true
var _buffer: Array = [] # Dictionary snapshots
var _accum: float = 0.0
var _game: Node
var _t: float = 0.0


func setup(game: Node) -> void:
	_game = game
	_buffer.clear()
	_accum = 0.0
	_t = 0.0


func _process(delta: float) -> void:
	if not enabled or _game == null:
		return
	if bool(_game.get("game_over")) or bool(_game.get("level_complete")):
		return
	_t += delta
	_accum += delta
	var interval := 1.0 / HZ
	if _accum < interval:
		return
	_accum = 0.0
	capture()
	var max_n := int(HZ * MAX_SECONDS)
	while _buffer.size() > max_n:
		_buffer.pop_front()


func capture() -> Dictionary:
	var snap := _build_snapshot()
	_buffer.append(snap)
	return snap


func snapshot_count() -> int:
	return _buffer.size()


func get_snapshot(index: int) -> Dictionary:
	if index < 0 or index >= _buffer.size():
		return {}
	return (_buffer[index] as Dictionary).duplicate(true)


func get_all() -> Array:
	return _buffer.duplicate(true)


func dump_last_run() -> void:
	var payload := {
		"hz": HZ,
		"count": _buffer.size(),
		"snapshots": _buffer,
	}
	var abs_path := ProjectSettings.globalize_path(DUMP_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(DUMP_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))
	f.close()


static func load_last_dump() -> Dictionary:
	if not FileAccess.file_exists(DUMP_PATH):
		return {}
	var f := FileAccess.open(DUMP_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _build_snapshot() -> Dictionary:
	var towers: Array = []
	var enemies: Array = []
	var guards: Array = []
	if _game == null:
		return {"t": _t}
	for t in _game.get_tree().get_nodes_in_group("towers"):
		if t == null or not is_instance_valid(t):
			continue
		var pos: Vector3 = (t as Node3D).global_position
		towers.append({
			"runtime_id": str(t.get("runtime_id")),
			"tower_type": str(t.get("tower_type")),
			"level": int(t.get("level")) if "level" in t else 1,
			"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		})
		if str(t.get("tower_type")) == "guard_post" and t.has_method("get_guards"):
			for g in t.call("get_guards"):
				if g == null or not is_instance_valid(g):
					continue
				var gp: Vector3 = (g as Node3D).global_position
				guards.append({
					"owner": str(t.get("runtime_id")),
					"slot_index": int(g.get("slot_index")) if "slot_index" in g else 0,
					"health": float(g.get("health")) if "health" in g else 0.0,
					"combat_state": int(g.get("combat_state")) if "combat_state" in g else 0,
					"position": {"x": gp.x, "y": gp.y, "z": gp.z},
				})
	for e in _game.get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		var ep: Vector3 = (e as Node3D).global_position
		enemies.append({
			"enemy_id": str(e.get("enemy_id")) if "enemy_id" in e else "bot",
			"health": float(e.get("health")) if "health" in e else 0.0,
			"path_progress": float(e.call("get_path_progress")) if e.has_method("get_path_progress") else 0.0,
			"floor_id": str(e.get("floor_id")) if "floor_id" in e else "",
			"position": {"x": ep.x, "y": ep.y, "z": ep.z},
		})
	return {
		"t": _t,
		"gold": int(_game.get("gold")),
		"core_hp": int(_game.get("core_hp")),
		"current_wave": int(_game.get("current_wave")),
		"active_wave": int(_game.get("active_wave")),
		"wave_running": bool(_game.get("wave_running")),
		"towers": towers,
		"enemies": enemies,
		"guards": guards,
	}
