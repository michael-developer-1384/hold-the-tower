extends Node

## Time Machine: 5 Hz ring buffer. Snapshots are session-restore compatible.

const HZ := 5.0
const MAX_SECONDS := 120.0
const DUMP_PATH := "user://timeline_last_run.json"
const SessionStoreScript := preload("res://scripts/run/session_store.gd")

var enabled: bool = true
var recording: bool = true
var _buffer: Array = []
var _kills: Array = []
var _accum: float = 0.0
var _game: Node
var _t: float = 0.0


func setup(game: Node) -> void:
	_game = game
	_buffer.clear()
	_kills.clear()
	_accum = 0.0
	_t = 0.0
	recording = true


func _process(delta: float) -> void:
	if not enabled or not recording or _game == null:
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
	var snap := SessionStoreScript.capture_from_game(_game, true)
	snap["t"] = _t
	snap["kills"] = _kills.duplicate(true)
	_buffer.append(snap)
	return snap


func record_kill(enemy: Node3D) -> void:
	if not enabled or not recording or enemy == null or not is_instance_valid(enemy):
		return
	_kills.append({
		"t": _t,
		"enemy_id": str(enemy.get("enemy_id")) if "enemy_id" in enemy else "bot",
		"position": {
			"x": enemy.global_position.x,
			"y": enemy.global_position.y,
			"z": enemy.global_position.z,
		},
	})


func snapshot_count() -> int:
	return _buffer.size()


func get_snapshot(index: int) -> Dictionary:
	if index < 0 or index >= _buffer.size():
		return {}
	return (_buffer[index] as Dictionary).duplicate(true)


func get_all() -> Array:
	return _buffer.duplicate(true)


func latest_index() -> int:
	return _buffer.size() - 1


func truncate_after(index: int) -> void:
	if index < 0:
		_buffer.clear()
		_kills.clear()
		return
	if index >= _buffer.size() - 1:
		return
	_buffer = _buffer.slice(0, index + 1)
	if not _buffer.is_empty():
		_t = float((_buffer.back() as Dictionary).get("t", _t))
		var kept: Array = []
		for k in _kills:
			if typeof(k) != TYPE_DICTIONARY:
				continue
			if float(k.get("t", 0.0)) <= _t + 0.0001:
				kept.append(k)
		_kills = kept


func set_recording(active: bool) -> void:
	recording = active
	if active:
		_accum = 0.0


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
