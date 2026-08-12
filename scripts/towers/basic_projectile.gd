extends Node3D

@export var speed: float = 28.0
@export var damage: float = 25.0

var _target: Node3D = null
var _source_tower: Node3D = null
var _alive: bool = true


func setup(target: Node3D, dmg: float, source_tower: Node3D = null) -> void:
	_target = target
	damage = dmg
	_source_tower = source_tower


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _target == null or not is_instance_valid(_target):
		_alive = false
		queue_free()
		return

	var aim: Vector3 = _target.global_position + Vector3(0.0, 0.45, 0.0)
	var to_target := aim - global_position
	var dist := to_target.length()
	var step := speed * delta
	if dist <= step:
		global_position = aim
		_apply_hit()
		_alive = false
		queue_free()
		return

	global_position += to_target.normalized() * step


func _apply_hit() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("take_damage"):
		_target.call("take_damage", damage, _source_tower)
