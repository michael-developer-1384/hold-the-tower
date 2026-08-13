extends Node3D

const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")

@export var speed: float = 28.0
@export var damage: float = 25.0

var _target: Node3D = null
var _source_tower: Node3D = null
var _alive: bool = true


func setup(target: Node3D, dmg: float, source_tower: Node3D = null, proj_speed: float = -1.0) -> void:
	_target = target
	damage = dmg
	_source_tower = source_tower
	if proj_speed > 0.0:
		speed = proj_speed


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
		var result: Dictionary = _target.call("take_damage", damage, _source_tower)
		AudioBridgeScript.play_3d("projectile_hit", global_position)
		if _source_tower != null and is_instance_valid(_source_tower) and _source_tower.has_method("record_overkill"):
			var actual := float(result.get("actual_damage", 0.0))
			var over := maxf(damage - actual, 0.0)
			if over > 0.0:
				_source_tower.call("record_overkill", over)
