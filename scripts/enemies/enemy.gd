extends Node3D

signal reached_core(enemy: Node3D)
signal died(enemy: Node3D)

@export var max_health: float = 100.0
@export var speed: float = 2.2

var health: float = 100.0
var floor_id: String = ""
var floor_index: int = 0

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _waypoint_index: int = 0
var _alive: bool = true
var _kill_attributed: bool = false
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


func setup(
	path: PackedVector3Array,
	hp: float = -1.0,
	waypoint_floors: PackedStringArray = PackedStringArray(),
	floor_index_by_id: Dictionary = {}
) -> void:
	_path = path
	_waypoint_floors = waypoint_floors
	_floor_index_by_id = floor_index_by_id
	_waypoint_index = 0
	_kill_attributed = false
	_slow_factor = 1.0
	_slow_timer = 0.0
	if hp > 0.0:
		max_health = hp
	health = max_health
	if _path.size() > 0:
		global_position = _path[0]
	_update_floor_from_waypoint()


func get_path_progress() -> float:
	if _path.is_empty():
		return 0.0
	if _waypoint_index >= _path.size():
		return float(_path.size())
	var target := _path[_waypoint_index]
	var prev: Vector3 = global_position
	if _waypoint_index > 0:
		prev = _path[_waypoint_index - 1]
	var seg_len := prev.distance_to(target)
	var t := 0.0
	if seg_len > 0.001:
		t = clampf(1.0 - global_position.distance_to(target) / seg_len, 0.0, 1.0)
	return float(_waypoint_index) + t


func get_current_floor_id() -> String:
	return floor_id


func get_current_floor_index() -> int:
	return floor_index


## Refreshable slow; keep calling while the aura is active.
func apply_slow(factor: float, duration: float) -> void:
	if not _alive or factor <= 0.0 or duration <= 0.0:
		return
	_slow_factor = minf(_slow_factor, clampf(factor, 0.05, 1.0))
	_slow_timer = maxf(_slow_timer, duration)


func take_damage(amount: float, source: Node = null) -> Dictionary:
	var result := {
		"actual_damage": 0.0,
		"killed": false,
		"remaining_health": health,
		"hp_before": health,
	}
	if not _alive or amount <= 0.0:
		return result

	var hp_before := health
	var actual := minf(amount, hp_before)
	health = maxf(hp_before - actual, 0.0)
	var killed := health <= 0.0
	result["actual_damage"] = actual
	result["killed"] = killed
	result["remaining_health"] = health
	result["hp_before"] = hp_before

	if source != null and is_instance_valid(source) and source.has_method("record_hit"):
		source.call("record_hit", actual, floor_id, floor_index)

	if killed and not _kill_attributed:
		_kill_attributed = true
		_alive = false
		if source != null and is_instance_valid(source) and source.has_method("record_kill"):
			source.call("record_kill")
		_notify_telemetry_kill(source, actual, hp_before)
		var source_id := str(source.get("runtime_id")) if source != null and is_instance_valid(source) else "?"
		print("Enemy killed by %s: actual_damage=%.1f" % [source_id, actual])
		died.emit(self)
		queue_free()

	return result


func _notify_telemetry_kill(source: Node, final_hit_damage: float, hp_before: float) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var telemetry := tree.root.find_child("TelemetryManager", true, false)
	if telemetry == null:
		return
	if telemetry.has_method("on_enemy_killed"):
		telemetry.call(
			"on_enemy_killed",
			source,
			self,
			final_hit_damage,
			hp_before,
			floor_id,
			floor_index
		)
	elif telemetry.has_method("on_enemy_damaged"):
		telemetry.call(
			"on_enemy_damaged",
			source,
			self,
			final_hit_damage,
			true,
			floor_id,
			floor_index
		)


func _update_floor_from_waypoint() -> void:
	var idx := mini(_waypoint_index, maxi(_waypoint_floors.size() - 1, 0))
	if _waypoint_floors.size() > 0:
		floor_id = _waypoint_floors[idx]
	if _floor_index_by_id.has(floor_id):
		floor_index = int(_floor_index_by_id[floor_id])
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)


func _physics_process(delta: float) -> void:
	if not _alive or _path.is_empty():
		return
	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	if _waypoint_index >= _path.size():
		_alive = false
		reached_core.emit(self)
		queue_free()
		return

	var target := _path[_waypoint_index]
	var to_target := target - global_position
	var distance := to_target.length()
	var step := speed * _slow_factor * delta
	if distance <= step:
		global_position = target
		_waypoint_index += 1
		_update_floor_from_waypoint()
	else:
		var direction := to_target.normalized()
		global_position += direction * step
		if absf(direction.dot(Vector3.UP)) < 0.98:
			look_at(global_position + direction, Vector3.UP)
