extends Node

signal wave_started(wave_number: int, enemy_count: int)
signal enemy_spawned(enemy: Node3D)
signal wave_spawn_finished(wave_number: int)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.8

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _spawn_parent: Node3D
var _spawning: bool = false
var _current_wave: int = 0
var _queue: Array = [] # [{enemy_id, hp, speed_mult, interval, wave_number}, ...]
var _enemy_defs: Dictionary = {}
var _spawn_wait: float = 0.0
var _waiting_to_spawn: bool = false
var _next_enemy_id: int = 1
var _pending_spawn_counts: Dictionary = {} # wave_number -> remaining to spawn


func setup(path: PackedVector3Array, spawn_parent: Node3D, path_meta: Dictionary = {}) -> void:
	_path = path
	_spawn_parent = spawn_parent
	if path_meta.has("waypoint_floors"):
		_waypoint_floors = path_meta["waypoint_floors"]
	if path_meta.has("floor_index_by_id"):
		_floor_index_by_id = path_meta["floor_index_by_id"]
	_enemy_defs.clear()
	for def in EnemyCatalogScript.create_all():
		_enemy_defs[str(def.enemy_id)] = def


func get_wave_count() -> int:
	return WaveCatalogScript.wave_count()


func get_enemy_path() -> PackedVector3Array:
	return _path


func is_spawning() -> bool:
	return _spawning


func queue_size() -> int:
	return _queue.size()


func start_wave(wave_number: int) -> bool:
	## Back-compat: enqueue a wave (allows overlap).
	return enqueue_wave(wave_number)


func enqueue_wave(wave_number: int) -> bool:
	if _path.is_empty() or _spawn_parent == null:
		push_warning("WaveManager: missing path or spawn parent")
		return false
	var wave := WaveCatalogScript.get_wave(wave_number)
	if wave.is_empty():
		return false
	var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
	var diff_id := "normal"
	if typeof(RunManager) != TYPE_NIL:
		diff_id = str(RunManager.difficulty_id)
	var entry: Dictionary = DifficultyCatalogScript.find(diff_id)
	var count_m := float(SimContextScript.get_override("enemy_count", entry.get("enemy_count_multiplier", 1.0)))
	var added := 0
	var batch: Array = []
	for group in wave.get("groups", []):
		var enemy_id := str(group.get("enemy_id", "bot"))
		var count := int(round(float(group.get("count", 0)) * count_m))
		var abs_hp := float(group.get("absolute_health", -1.0))
		var hp_mult := float(group.get("health_multiplier", 1.0))
		var speed_mult := float(group.get("speed_multiplier", 1.0))
		var interval := float(group.get("spawn_interval", spawn_interval))
		var def = _enemy_defs.get(enemy_id, null)
		var base_hp := float(def.base_max_health) if def != null else 100.0
		var hp := abs_hp if abs_hp > 0.0 else base_hp * hp_mult
		for _i in count:
			batch.append({
				"enemy_id": enemy_id,
				"hp": hp,
				"speed_mult": speed_mult,
				"interval": interval,
				"wave_number": wave_number,
			})
			added += 1
	if added <= 0:
		return false
	for item in batch:
		_queue.append(item)
	_pending_spawn_counts[wave_number] = int(_pending_spawn_counts.get(wave_number, 0)) + added
	_current_wave = wave_number
	wave_started.emit(wave_number, added)
	SimContextScript.log_msg("Wave %d enqueued (%d enemies, queue=%d)" % [wave_number, added, _queue.size()])
	if not _spawning:
		_spawning = true
		_waiting_to_spawn = false
		_spawn_wait = 0.0
		_spawn_next()
	return true


func stop_all() -> void:
	_spawning = false
	_queue.clear()
	_waiting_to_spawn = false
	_spawn_wait = 0.0
	_pending_spawn_counts.clear()


func _physics_process(delta: float) -> void:
	if _spawning and not _waiting_to_spawn and not _queue.is_empty():
		_spawn_next()
		return
	if not _waiting_to_spawn:
		return
	_spawn_wait -= delta
	if _spawn_wait > 0.0:
		return
	_waiting_to_spawn = false
	_spawn_next()


## Session restore: spawn a single enemy at path progress with HP (no wave queue).
func spawn_enemy_at_progress(enemy_id: String, hp: float, progress: float) -> Node3D:
	return restore_enemy_from_snapshot({
		"enemy_id": enemy_id,
		"health": hp,
		"path_progress": progress,
	})


## Restore a captured enemy. Does not re-apply difficulty (snapshot is already resolved).
func restore_enemy_from_snapshot(entry: Dictionary) -> Node3D:
	if _path.is_empty() or _spawn_parent == null:
		return null
	var enemy_id := str(entry.get("enemy_id", "bot"))
	var def = _enemy_defs.get(enemy_id, null)
	var scene: PackedScene = enemy_scene
	if def != null and def.runtime_scene != null:
		scene = def.runtime_scene
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node3D
	_spawn_parent.add_child(enemy)
	if def != null and enemy.has_method("configure_from_definition"):
		enemy.call("configure_from_definition", def)
	var max_hp := float(entry.get("max_health", -1.0))
	if max_hp <= 0.0:
		max_hp = float(entry.get("health", -1.0))
	if enemy.has_method("setup"):
		enemy.call("setup", _path, max_hp, _waypoint_floors, _floor_index_by_id, enemy_id)
	if enemy.has_method("restore_from_snapshot"):
		enemy.call("restore_from_snapshot", entry)
	elif enemy.has_method("restore_at_progress"):
		enemy.call("restore_at_progress", float(entry.get("path_progress", 0.0)), float(entry.get("health", -1.0)))
	_apply_difficulty(enemy, true)
	var alive := true
	if "combat_state" in enemy:
		alive = int(enemy.get("combat_state")) < 2
	if "health" in enemy and float(enemy.get("health")) <= 0.0:
		alive = false
	_assign_runtime_id(enemy, str(entry.get("runtime_id", "")))
	if alive:
		enemy_spawned.emit(enemy)
	return enemy


func _apply_difficulty(enemy: Node3D, combat_stats_only: bool = false) -> void:
	var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
	var diff_id := "normal"
	if typeof(RunManager) != TYPE_NIL:
		diff_id = str(RunManager.difficulty_id)
	var entry: Dictionary = DifficultyCatalogScript.find(diff_id)
	var hp_m := float(SimContextScript.get_override("enemy_health", entry.get("health_multiplier", 1.0)))
	var speed_m := float(SimContextScript.get_override("enemy_speed", entry.get("speed_multiplier", 1.0)))
	var dmg_m := float(SimContextScript.get_override("enemy_damage", entry.get("damage_multiplier", 1.0)))
	if not is_instance_valid(enemy):
		return
	if not combat_stats_only and hp_m != 1.0:
		if "max_health" in enemy:
			enemy.set("max_health", float(enemy.get("max_health")) * hp_m)
		if "health" in enemy:
			enemy.set("health", float(enemy.get("health")) * hp_m)
	if speed_m != 1.0 and "speed" in enemy:
		enemy.set("speed", float(enemy.get("speed")) * speed_m)
	if dmg_m != 1.0:
		if "melee_damage" in enemy:
			enemy.set("melee_damage", float(enemy.get("melee_damage")) * dmg_m)
		if "melee_interval" in enemy:
			var interval := float(enemy.get("melee_interval"))
			enemy.set("melee_interval", maxf(interval / dmg_m, 0.05))


func _spawn_next() -> void:
	if not _spawning:
		return
	if _queue.is_empty():
		_spawning = false
		return

	var item: Dictionary = _queue.pop_front()
	var enemy_id := str(item.get("enemy_id", "bot"))
	var wave_number := int(item.get("wave_number", _current_wave))
	var def = _enemy_defs.get(enemy_id, null)
	var scene: PackedScene = enemy_scene
	if def != null and def.runtime_scene != null:
		scene = def.runtime_scene
	if scene == null:
		push_warning("WaveManager: no runtime scene for %s" % enemy_id)
		_note_spawned(wave_number)
		_spawn_next()
		return

	var enemy := scene.instantiate() as Node3D
	_spawn_parent.add_child(enemy)
	if def != null and enemy.has_method("configure_from_definition"):
		enemy.call("configure_from_definition", def)
	if enemy.has_method("setup"):
		enemy.call(
			"setup",
			_path,
			float(item.get("hp", 100.0)),
			_waypoint_floors,
			_floor_index_by_id,
			enemy_id
		)
	var speed_mult := float(item.get("speed_mult", 1.0))
	if speed_mult != 1.0 and "speed" in enemy:
		enemy.set("speed", float(enemy.get("speed")) * speed_mult)
	_apply_difficulty(enemy)
	_assign_runtime_id(enemy, "")
	enemy_spawned.emit(enemy)
	_note_spawned(wave_number)

	if not _queue.is_empty():
		var wait := float(item.get("interval", spawn_interval))
		var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
		var diff_id := "normal"
		if typeof(RunManager) != TYPE_NIL:
			diff_id = str(RunManager.difficulty_id)
		var entry: Dictionary = DifficultyCatalogScript.find(diff_id)
		var rate_m := float(SimContextScript.get_override("spawn_rate", entry.get("spawn_rate_multiplier", 1.0)))
		if rate_m > 0.0:
			wait /= rate_m
		_spawn_wait = wait
		_waiting_to_spawn = true
	else:
		_spawning = false


func _note_spawned(wave_number: int) -> void:
	var left := int(_pending_spawn_counts.get(wave_number, 0)) - 1
	if left <= 0:
		_pending_spawn_counts.erase(wave_number)
		wave_spawn_finished.emit(wave_number)
	else:
		_pending_spawn_counts[wave_number] = left


func _assign_runtime_id(enemy: Node, forced: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not forced.is_empty():
		enemy.set("runtime_id", forced)
		var n := int(forced.trim_prefix("E"))
		_next_enemy_id = maxi(_next_enemy_id, n + 1)
		return
	if str(enemy.get("runtime_id")) != "":
		return
	enemy.set("runtime_id", "E%04d" % _next_enemy_id)
	_next_enemy_id += 1


func capture_spawn_state() -> Dictionary:
	return {
		"queue": _queue.duplicate(true),
		"spawn_wait": _spawn_wait,
		"waiting_to_spawn": _waiting_to_spawn,
		"spawning": _spawning,
		"current_wave": _current_wave,
		"next_enemy_id": _next_enemy_id,
		"pending_spawn_counts": _pending_spawn_counts.duplicate(true),
	}


func apply_spawn_state(data: Dictionary) -> void:
	_queue = data.get("queue", []).duplicate(true)
	_spawn_wait = float(data.get("spawn_wait", 0.0))
	_waiting_to_spawn = bool(data.get("waiting_to_spawn", false))
	_spawning = bool(data.get("spawning", false))
	_current_wave = int(data.get("current_wave", 0))
	_next_enemy_id = int(data.get("next_enemy_id", 1))
	# JSON object keys are strings; runtime lookups use int wave numbers.
	_pending_spawn_counts.clear()
	var pending: Dictionary = data.get("pending_spawn_counts", {})
	for k in pending.keys():
		_pending_spawn_counts[int(str(k))] = int(pending[k])
