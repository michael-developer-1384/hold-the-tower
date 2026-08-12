extends Node3D

signal reached_core(enemy: Node3D)
signal died(enemy: Node3D)

@export var max_health: float = 100.0
@export var speed: float = 2.2

var health: float = 100.0
var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_index: int = 0
var _alive: bool = true


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


func setup(path: PackedVector3Array) -> void:
	_path = path
	_waypoint_index = 0
	if _path.size() > 0:
		global_position = _path[0]


func _physics_process(delta: float) -> void:
	if not _alive or _path.is_empty():
		return
	if _waypoint_index >= _path.size():
		_alive = false
		reached_core.emit(self)
		queue_free()
		return

	var target := _path[_waypoint_index]
	var to_target := target - global_position
	var distance := to_target.length()
	var step := speed * delta
	if distance <= step:
		global_position = target
		_waypoint_index += 1
	else:
		var direction := to_target.normalized()
		global_position += direction * step
		# Face travel direction (including ramp slope).
		if absf(direction.dot(Vector3.UP)) < 0.98:
			look_at(global_position + direction, Vector3.UP)


func take_damage(amount: float) -> void:
	if not _alive:
		return
	health -= amount
	if health <= 0.0:
		_alive = false
		died.emit(self)
		queue_free()
