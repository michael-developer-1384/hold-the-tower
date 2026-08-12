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
	var target_floor_id := "unknown"
	var target_floor_index := 0
	if _target.has_method("get_current_floor_id"):
		target_floor_id = str(_target.call("get_current_floor_id"))
	if _target.has_method("get_current_floor_index"):
		target_floor_index = int(_target.call("get_current_floor_index"))

	var hp_before := float(_target.get("health")) if "health" in _target else 0.0
	var will_kill := hp_before > 0.0 and damage >= hp_before

	if _target.has_method("take_damage"):
		_target.call("take_damage", damage)

	if _source_tower != null and is_instance_valid(_source_tower):
		if _source_tower.has_method("record_hit"):
			_source_tower.call("record_hit", damage, target_floor_id, target_floor_index)
		if will_kill and _source_tower.has_method("record_kill"):
			_source_tower.call("record_kill")
		var tree := get_tree()
		if tree and will_kill:
			var telemetry := tree.root.find_child("TelemetryManager", true, false)
			if telemetry and telemetry.has_method("on_enemy_damaged"):
				telemetry.call(
					"on_enemy_damaged",
					_source_tower,
					null,
					damage,
					true,
					target_floor_id,
					target_floor_index
				)
