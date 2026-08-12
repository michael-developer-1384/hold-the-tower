extends Node

signal wave_started(wave_number: int, enemy_count: int)
signal enemy_spawned(enemy: Node3D)
signal wave_spawn_finished(wave_number: int)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.8

const WAVE_TABLE := [
	[10, 100.0],
	[12, 110.0],
	[14, 120.0],
	[16, 135.0],
	[20, 150.0],
]

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _spawn_parent: Node3D
var _remaining: int = 0
var _spawning: bool = false
var _current_wave: int = 0
var _enemy_hp: float = 100.0


func setup(path: PackedVector3Array, spawn_parent: Node3D, path_meta: Dictionary = {}) -> void:
	_path = path
	_spawn_parent = spawn_parent
	if path_meta.has("waypoint_floors"):
		_waypoint_floors = path_meta["waypoint_floors"]
	if path_meta.has("floor_index_by_id"):
		_floor_index_by_id = path_meta["floor_index_by_id"]


func get_wave_count() -> int:
	return WAVE_TABLE.size()


func is_spawning() -> bool:
	return _spawning


func start_wave(wave_number: int) -> bool:
	if _spawning:
		return false
	if _path.is_empty() or enemy_scene == null or _spawn_parent == null:
		push_warning("WaveManager: missing path, scene, or spawn parent")
		return false
	var idx := wave_number - 1
	if idx < 0 or idx >= WAVE_TABLE.size():
		return false
	_current_wave = wave_number
	_remaining = int(WAVE_TABLE[idx][0])
	_enemy_hp = float(WAVE_TABLE[idx][1])
	_spawning = true
	wave_started.emit(_current_wave, _remaining)
	print("Wave %d started" % _current_wave)
	_spawn_next()
	return true


func stop_all() -> void:
	_spawning = false
	_remaining = 0


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
	if _remaining <= 0:
		_spawning = false
		wave_spawn_finished.emit(_current_wave)
		return

	var enemy := enemy_scene.instantiate() as Node3D
	_spawn_parent.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.call("setup", _path, _enemy_hp, _waypoint_floors, _floor_index_by_id)
	_apply_difficulty(enemy)
	enemy_spawned.emit(enemy)
	_remaining -= 1

	if _remaining > 0:
		get_tree().create_timer(spawn_interval).timeout.connect(_spawn_next)
	else:
		_spawning = false
		wave_spawn_finished.emit(_current_wave)
