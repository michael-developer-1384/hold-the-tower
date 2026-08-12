extends Node3D

signal died(guard: Node3D, slot_index: int)

const HealthBarScript := preload("res://scripts/combat/health_bar_3d.gd")
const FloatingTextScript := preload("res://scripts/combat/floating_text_3d.gd")

enum GuardState { IDLE, CHASE, ENGAGED, RETURN, DEAD }

@export var max_health: float = 100.0
@export var melee_damage: float = 20.0
@export var melee_interval: float = 0.8
@export var move_speed: float = 3.2
@export var engage_range: float = 0.55
@export var healing_delay: float = 2.0
@export var healing_rate: float = 10.0

var health: float = 100.0
var slot_index: int = 0
var owner_tower: Node = null
var combat_state: int = GuardState.IDLE

var _home_local: Vector3 = Vector3.ZERO
var _target_enemy: Node = null
var _melee_cooldown: float = 0.0
var _ooc_timer: float = 0.0
var _hp_bar: Node3D
var _base_scale: Vector3 = Vector3.ONE
var _alive: bool = true
var _block_started_ms: int = 0


func setup(home_local: Vector3, tower: Node, slot: int) -> void:
	_home_local = home_local
	owner_tower = tower
	slot_index = slot
	position = home_local
	health = max_health
	combat_state = GuardState.IDLE
	_target_enemy = null
	_melee_cooldown = 0.0
	_ooc_timer = 0.0
	_alive = true
	_base_scale = scale
	_ensure_hp_bar()
	_refresh_hp_bar()


func is_alive() -> bool:
	return _alive and combat_state != GuardState.DEAD


func is_engaged() -> bool:
	return combat_state == GuardState.ENGAGED and _target_enemy != null and is_instance_valid(_target_enemy)


func engage(enemy: Node) -> bool:
	if not _alive or combat_state == GuardState.DEAD:
		return false
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_engaged") and bool(enemy.call("is_engaged")):
		return false
	if not enemy.has_method("engage"):
		return false
	if not bool(enemy.call("engage", self)):
		return false
	_target_enemy = enemy
	combat_state = GuardState.ENGAGED
	_melee_cooldown = 0.1
	_ooc_timer = 0.0
	_block_started_ms = Time.get_ticks_msec()
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_block_start"):
		owner_tower.call("record_block_start")
	_refresh_hp_bar(true)
	return true


func disengage() -> void:
	var enemy := _target_enemy
	_target_enemy = null
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("disengage"):
		enemy.call("disengage", self)
	_record_block_end()
	if _alive and combat_state == GuardState.ENGAGED:
		combat_state = GuardState.RETURN
	_refresh_hp_bar()


func take_damage(amount: float, _source: Node = null) -> Dictionary:
	var result := {
		"actual_damage": 0.0,
		"killed": false,
		"remaining_health": health,
	}
	if not _alive or amount <= 0.0 or combat_state == GuardState.DEAD:
		return result

	var actual := minf(amount, health)
	health = maxf(health - actual, 0.0)
	result["actual_damage"] = actual
	result["remaining_health"] = health
	_ooc_timer = 0.0

	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_guard_damage_taken"):
		owner_tower.call("record_guard_damage_taken", actual)

	FloatingTextScript.spawn(
		get_parent() if get_parent() else self,
		global_position,
		"-%d" % int(round(actual)),
		Color(1.0, 0.55, 0.4)
	)
	_play_hit_flash()
	_refresh_hp_bar(true)

	if health <= 0.0:
		result["killed"] = true
		_die()
	return result


func _die() -> void:
	if combat_state == GuardState.DEAD:
		return
	_alive = false
	combat_state = GuardState.DEAD
	var enemy := _target_enemy
	_target_enemy = null
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("disengage"):
		enemy.call("disengage", self)
	_record_block_end()
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("on_guard_died"):
		owner_tower.call("on_guard_died", slot_index)
	died.emit(self, slot_index)
	_play_death_then_free()


func _record_block_end() -> void:
	if _block_started_ms <= 0:
		return
	var elapsed := maxi(Time.get_ticks_msec() - _block_started_ms, 0)
	_block_started_ms = 0
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_block_end"):
		owner_tower.call("record_block_end", elapsed)


func _physics_process(delta: float) -> void:
	if not _alive or combat_state == GuardState.DEAD:
		return

	match combat_state:
		GuardState.IDLE:
			_process_idle(delta)
		GuardState.CHASE:
			_process_chase(delta)
		GuardState.ENGAGED:
			_process_engaged(delta)
		GuardState.RETURN:
			_process_return(delta)


func _process_idle(delta: float) -> void:
	_apply_healing(delta)
	var candidate := _find_best_target()
	if candidate != null:
		_target_enemy = candidate
		combat_state = GuardState.CHASE


func _process_chase(delta: float) -> void:
	if not _is_valid_engage_candidate(_target_enemy):
		_target_enemy = null
		combat_state = GuardState.RETURN
		return
	if not _is_inside_owner_disc(_target_enemy.global_position):
		_target_enemy = null
		combat_state = GuardState.RETURN
		return

	var target_pos: Vector3 = _target_enemy.global_position
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist <= engage_range:
		if engage(_target_enemy):
			return
		_target_enemy = null
		combat_state = GuardState.RETURN
		return

	var step := move_speed * delta
	var next := global_position + to_target.normalized() * minf(step, dist)
	global_position = _clamp_to_owner_disc(next)
	_face_point(target_pos)


func _process_engaged(delta: float) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		disengage()
		return
	if _target_enemy.has_method("is_engaged") and not bool(_target_enemy.call("is_engaged")):
		# Enemy disengaged elsewhere; resume pathing flow.
		_target_enemy = null
		combat_state = GuardState.RETURN
		return

	_face_point(_target_enemy.global_position)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = melee_interval
	_play_attack_lunge()
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_shot"):
		owner_tower.call("record_shot")
	if _target_enemy.has_method("take_damage"):
		_target_enemy.call("take_damage", melee_damage, owner_tower)


func _process_return(delta: float) -> void:
	_apply_healing(delta)
	var home_global := _home_global()
	var to_home := home_global - global_position
	to_home.y = 0.0
	var dist := to_home.length()
	if dist <= 0.08:
		global_position = home_global
		combat_state = GuardState.IDLE
		return
	global_position += to_home.normalized() * minf(move_speed * delta, dist)
	_face_point(home_global)

	# Opportunistic re-acquire while returning.
	var candidate := _find_best_target()
	if candidate != null:
		_target_enemy = candidate
		combat_state = GuardState.CHASE


func _apply_healing(delta: float) -> void:
	if health >= max_health:
		_ooc_timer = 0.0
		return
	_ooc_timer += delta
	if _ooc_timer < healing_delay:
		return
	var before := health
	health = minf(max_health, health + healing_rate * delta)
	var healed := health - before
	if healed > 0.0 and owner_tower != null and is_instance_valid(owner_tower) \
			and owner_tower.has_method("record_guard_healing_done"):
		owner_tower.call("record_guard_healing_done", healed)
	_refresh_hp_bar(true)


func _find_best_target() -> Node:
	if owner_tower == null or not is_instance_valid(owner_tower):
		return null
	if not owner_tower.has_method("get_disc_radius") or not owner_tower.has_method("get_floor_id"):
		return null
	var radius: float = float(owner_tower.call("get_disc_radius"))
	var owner_floor: String = str(owner_tower.call("get_floor_id"))
	var center: Vector3 = (owner_tower as Node3D).global_position
	var best: Node = null
	var best_progress := -INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_engage_candidate(enemy):
			continue
		if str(enemy.get("floor_id")) != owner_floor:
			continue
		var pos: Vector3 = enemy.global_position
		var flat := Vector2(pos.x - center.x, pos.z - center.z)
		if flat.length() > radius:
			continue
		var progress := 0.0
		if enemy.has_method("get_path_progress"):
			progress = float(enemy.call("get_path_progress"))
		if progress > best_progress:
			best_progress = progress
			best = enemy
	return best


func _is_valid_engage_candidate(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	if enemy.has_method("is_engaged") and bool(enemy.call("is_engaged")):
		return false
	var alive_flag = enemy.get("_alive")
	if alive_flag != null and not bool(alive_flag):
		return false
	return true


func _is_inside_owner_disc(world_pos: Vector3) -> bool:
	if owner_tower == null or not is_instance_valid(owner_tower) or not owner_tower.has_method("get_disc_radius"):
		return false
	var center: Vector3 = (owner_tower as Node3D).global_position
	var radius: float = float(owner_tower.call("get_disc_radius"))
	var flat := Vector2(world_pos.x - center.x, world_pos.z - center.z)
	return flat.length() <= radius + 0.02


func _clamp_to_owner_disc(world_pos: Vector3) -> Vector3:
	if owner_tower == null or not is_instance_valid(owner_tower) or not owner_tower.has_method("get_disc_radius"):
		return world_pos
	var center: Vector3 = (owner_tower as Node3D).global_position
	var radius: float = float(owner_tower.call("get_disc_radius"))
	var flat := Vector2(world_pos.x - center.x, world_pos.z - center.z)
	if flat.length() > radius:
		flat = flat.normalized() * radius
	return Vector3(center.x + flat.x, world_pos.y, center.z + flat.y)


func _home_global() -> Vector3:
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower is Node3D:
		return (owner_tower as Node3D).to_global(_home_local)
	return _home_local


func _face_point(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if global_position.distance_to(flat) < 0.001:
		return
	look_at(flat, Vector3.UP)


func _ensure_hp_bar() -> void:
	if _hp_bar != null and is_instance_valid(_hp_bar):
		return
	_hp_bar = Node3D.new()
	_hp_bar.set_script(HealthBarScript)
	_hp_bar.name = "HealthBar"
	_hp_bar.position = Vector3(0.0, 1.05, 0.0)
	add_child(_hp_bar)


func _refresh_hp_bar(force: bool = false) -> void:
	if _hp_bar == null or not is_instance_valid(_hp_bar):
		return
	if _hp_bar.has_method("set_health"):
		var show_heal := health < max_health and combat_state != GuardState.ENGAGED
		_hp_bar.call("set_health", health, max_health, force or is_engaged() or show_heal)


func _play_hit_flash() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.14, 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.08)


func _play_attack_lunge() -> void:
	if not is_inside_tree():
		return
	var forward := -global_transform.basis.z
	var origin := global_position
	var tween := create_tween()
	tween.tween_property(self, "global_position", origin + forward * 0.14, 0.07)
	tween.tween_property(self, "global_position", origin, 0.09)


func _play_death_then_free() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
	tween.tween_callback(queue_free)
