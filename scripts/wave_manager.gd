extends Node

signal wave_started(enemy_count: int)
signal enemy_spawned(enemy: Node3D)
signal wave_finished

@export var enemy_scene: PackedScene
@export var enemy_count: int = 10
@export var spawn_interval: float = 0.8

var _path: PackedVector3Array = PackedVector3Array()
var _spawn_parent: Node3D
var _remaining: int = 0
var _active: bool = false


func setup(path: PackedVector3Array, spawn_parent: Node3D) -> void:
	_path = path
	_spawn_parent = spawn_parent


func start_wave() -> void:
	if _path.is_empty() or enemy_scene == null or _spawn_parent == null:
		push_warning("WaveManager: missing path, scene, or spawn parent")
		return
	_remaining = enemy_count
	_active = true
	wave_started.emit(enemy_count)
	print("Wave started: %d enemies" % enemy_count)
	_spawn_next()


func _spawn_next() -> void:
	if not _active or _remaining <= 0:
		_active = false
		wave_finished.emit()
		return
	var enemy := enemy_scene.instantiate() as Node3D
	_spawn_parent.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.call("setup", _path)
	enemy_spawned.emit(enemy)
	_remaining -= 1
	if _remaining > 0:
		get_tree().create_timer(spawn_interval).timeout.connect(_spawn_next)
	else:
		_active = false
		wave_finished.emit()
