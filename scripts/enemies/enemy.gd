extends Node3D

signal reached_core(enemy: Node3D)
signal died(enemy: Node3D)

enum CombatState { MOVING, ENGAGED, DEAD, REACHED_CORE }

const HealthBarScript := preload("res://scripts/combat/health_bar_3d.gd")
const FloatingTextScript := preload("res://scripts/combat/floating_text_3d.gd")

@export var max_health: float = 100.0
@export var speed: float = 2.2
@export var melee_damage: float = 15.0
@export var melee_interval: float = 1.0

## Reserved for future enemy healing (inactive in v0.8).
@export var healing_delay: float = 0.0
@export var healing_rate: float = 0.0

var health: float = 100.0
var floor_id: String = ""
var floor_index: int = 0
var combat_state: int = CombatState.MOVING

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _waypoint_index: int = 0
var _alive: bool = true
var _kill_attributed: bool = false
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _engaged_guard: Node = null
var _melee_cooldown: float = 0.0
var _hp_bar: Node3D
var _visual_root: Node3D
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_ensure_visual_root()
	_ensure_hp_bar()


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
	_engaged_guard = null
	_melee_cooldown = 0.0
	combat_state = CombatState.MOVING
	_alive = true
	if hp > 0.0:
		max_health = hp
	health = max_health
	if _path.size() > 0:
		global_position = _path[0]
	_update_floor_from_waypoint()
	_ensure_hp_bar()
	_refresh_hp_bar()


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


func is_engaged() -> bool:
	return combat_state == CombatState.ENGAGED and _engaged_guard != null and is_instance_valid(_engaged_guard)


func engage(guard: Node) -> bool:
	if not _alive or combat_state == CombatState.DEAD:
		return false
	if is_engaged() and _engaged_guard != guard:
		return false
	if guard == null or not is_instance_valid(guard):
		return false
	_engaged_guard = guard
	combat_state = CombatState.ENGAGED
	_melee_cooldown = 0.15
	_refresh_hp_bar(true)
	return true


func disengage(guard: Node = null) -> void:
	if guard != null and _engaged_guard != null and is_instance_valid(_engaged_guard) and _engaged_guard != guard:
		return
	_engaged_guard = null
	if _alive and combat_state == CombatState.ENGAGED:
		combat_state = CombatState.MOVING
	_refresh_hp_bar()


## Kept for future towers; Guard Post no longer uses this.
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
	if not _alive or amount <= 0.0 or combat_state == CombatState.DEAD:
		return result

	var hp_before := health
	var actual := minf(amount, hp_before)
	health = maxf(hp_before - actual, 0.0)
	var killed := health <= 0.0
	result["actual_damage"] = actual
	result["killed"] = killed
	result["remaining_health"] = health
	result["hp_before"] = hp_before

	_spawn_damage_number(actual)
	_play_hit_flash()
	_refresh_hp_bar(true)

	if source != null and is_instance_valid(source) and source.has_method("record_hit"):
		source.call("record_hit", actual, floor_id, floor_index)

	if killed and not _kill_attributed:
		_kill_attributed = true
		_alive = false
		combat_state = CombatState.DEAD
		var guard := _engaged_guard
		_engaged_guard = null
		if guard != null and is_instance_valid(guard) and guard.has_method("disengage"):
			guard.call("disengage")
		if source != null and is_instance_valid(source) and source.has_method("record_kill"):
			source.call("record_kill")
		_notify_telemetry_kill(source, actual, hp_before)
		var source_id := str(source.get("runtime_id")) if source != null and is_instance_valid(source) else "?"
		print("Enemy killed by %s: actual_damage=%.1f" % [source_id, actual])
		died.emit(self)
		_play_death_then_free()

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


func _update_floor_from_waypoint() -> void:
	var idx := mini(_waypoint_index, maxi(_waypoint_floors.size() - 1, 0))
	if _waypoint_floors.size() > 0:
		floor_id = _waypoint_floors[idx]
	if _floor_index_by_id.has(floor_id):
		floor_index = int(_floor_index_by_id[floor_id])
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)


func _physics_process(delta: float) -> void:
	if not _alive or combat_state == CombatState.DEAD:
		return
	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	if combat_state == CombatState.ENGAGED:
		_process_engaged(delta)
		return

	if combat_state != CombatState.MOVING or _path.is_empty():
		return
	if _waypoint_index >= _path.size():
		_alive = false
		combat_state = CombatState.REACHED_CORE
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


func _process_engaged(delta: float) -> void:
	if _engaged_guard == null or not is_instance_valid(_engaged_guard):
		disengage()
		return
	_face_partner(_engaged_guard)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = melee_interval
	_play_attack_lunge()
	if _engaged_guard.has_method("take_damage"):
		_engaged_guard.call("take_damage", melee_damage, self)


func _face_partner(partner: Node) -> void:
	if partner == null or not is_instance_valid(partner) or not (partner is Node3D):
		return
	var p := (partner as Node3D).global_position
	var flat := Vector3(p.x, global_position.y, p.z)
	if global_position.distance_to(flat) < 0.001:
		return
	look_at(flat, Vector3.UP)


func _ensure_visual_root() -> void:
	_visual_root = self
	_base_scale = scale


func _ensure_hp_bar() -> void:
	if _hp_bar != null and is_instance_valid(_hp_bar):
		return
	_hp_bar = Node3D.new()
	_hp_bar.set_script(HealthBarScript)
	_hp_bar.name = "HealthBar"
	_hp_bar.position = Vector3(0.0, 1.15, 0.0)
	add_child(_hp_bar)


func _refresh_hp_bar(force: bool = false) -> void:
	if _hp_bar == null or not is_instance_valid(_hp_bar):
		return
	if _hp_bar.has_method("set_health"):
		_hp_bar.call("set_health", health, max_health, force or is_engaged())


func _spawn_damage_number(amount: float) -> void:
	FloatingTextScript.spawn(
		get_parent() if get_parent() else self,
		global_position,
		"-%d" % int(round(amount)),
		Color(1.0, 0.45, 0.35)
	)


func _play_hit_flash() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.12, 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.08)


func _play_attack_lunge() -> void:
	if not is_inside_tree():
		return
	var forward := -global_transform.basis.z
	var origin := global_position
	var tween := create_tween()
	tween.tween_property(self, "global_position", origin + forward * 0.12, 0.07)
	tween.tween_property(self, "global_position", origin, 0.09)


func _play_death_then_free() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tween.tween_callback(queue_free)
