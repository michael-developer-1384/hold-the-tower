extends Node

signal wave_started(wave_number: int, enemy_count: int)
signal enemy_spawned(enemy: Node3D)
signal wave_spawn_finished(wave_number: int)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.8

## Wave table: [enemy_count, enemy_hp]
const WAVE_TABLE := [
	[10, 100.0],
	[12, 110.0],
	[14, 120.0],
	[16, 135.0],
	[20, 150.0],
]

var _path: PackedVector3Array = PackedVector3Array()
var _spawn_parent: Node3D
var _remaining: int = 0
var _spawning: bool = false
var _current_wave: int = 0
var _enemy_hp: float = 100.0


func setup(path: PackedVector3Array, spawn_parent: Node3D) -> void:
	_path = path
	_spawn_parent = spawn_parent


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
		enemy.call("setup", _path, _enemy_hp)
	enemy_spawned.emit(enemy)
	_remaining -= 1

	if _remaining > 0:
		get_tree().create_timer(spawn_interval).timeout.connect(_spawn_next)
	else:
		_spawning = false
		wave_spawn_finished.emit(_current_wave)
