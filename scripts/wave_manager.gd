extends Node

signal wave_started(wave_number: int, enemy_count: int)
signal enemy_spawned(enemy: Node3D)
signal wave_spawn_finished(wave_number: int)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.8

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _spawn_parent: Node3D
var _spawning: bool = false
var _current_wave: int = 0
var _queue: Array = [] # [{enemy_id, hp, speed_mult, interval}, ...]
var _enemy_defs: Dictionary = {}


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


func is_spawning() -> bool:
	return _spawning


func start_wave(wave_number: int) -> bool:
	if _spawning:
		return false
	if _path.is_empty() or _spawn_parent == null:
		push_warning("WaveManager: missing path or spawn parent")
		return false
	var wave := WaveCatalogScript.get_wave(wave_number)
	if wave.is_empty():
		return false
	_current_wave = wave_number
	_queue.clear()
	for group in wave.get("groups", []):
		var enemy_id := str(group.get("enemy_id", "bot"))
		var count := int(group.get("count", 0))
		var abs_hp := float(group.get("absolute_health", -1.0))
		var hp_mult := float(group.get("health_multiplier", 1.0))
		var speed_mult := float(group.get("speed_multiplier", 1.0))
		var interval := float(group.get("spawn_interval", spawn_interval))
		var def = _enemy_defs.get(enemy_id, null)
		var base_hp := float(def.base_max_health) if def != null else 100.0
		var hp := abs_hp if abs_hp > 0.0 else base_hp * hp_mult
		for _i in count:
			_queue.append({
				"enemy_id": enemy_id,
				"hp": hp,
				"speed_mult": speed_mult,
				"interval": interval,
			})
	if _queue.is_empty():
		return false
	_spawning = true
	wave_started.emit(_current_wave, _queue.size())
	print("Wave %d started (%d enemies)" % [_current_wave, _queue.size()])
	_spawn_next()
	return true


func stop_all() -> void:
	_spawning = false
	_queue.clear()


func _apply_difficulty(enemy: Node3D) -> void:
	var m := 1.0
	if typeof(RunManager) != TYPE_NIL:
		m = float(RunManager.difficulty_multiplier)
	if m == 1.0 or not is_instance_valid(enemy):
		return
	if "max_health" in enemy:
		enemy.set("max_health", float(enemy.get("max_health")) * m)
	if "health" in enemy:
		enemy.set("health", float(enemy.get("health")) * m)
	if "speed" in enemy:
		enemy.set("speed", float(enemy.get("speed")) * m)
	if "melee_damage" in enemy:
		enemy.set("melee_damage", float(enemy.get("melee_damage")) * m)
	if "melee_interval" in enemy:
		var interval := float(enemy.get("melee_interval"))
		enemy.set("melee_interval", maxf(interval / m, 0.05))


func _spawn_next() -> void:
	if not _spawning:
		return
	if _queue.is_empty():
		_spawning = false
		wave_spawn_finished.emit(_current_wave)
		return

	var item: Dictionary = _queue.pop_front()
	var enemy_id := str(item.get("enemy_id", "bot"))
	var def = _enemy_defs.get(enemy_id, null)
	var scene: PackedScene = enemy_scene
	if def != null and def.runtime_scene != null:
		scene = def.runtime_scene
	if scene == null:
		push_warning("WaveManager: no runtime scene for %s" % enemy_id)
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
	enemy_spawned.emit(enemy)

	if not _queue.is_empty():
		var wait := float(item.get("interval", spawn_interval))
		get_tree().create_timer(wait).timeout.connect(_spawn_next)
	else:
		_spawning = false
		wave_spawn_finished.emit(_current_wave)
