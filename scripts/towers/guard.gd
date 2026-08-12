extends Node3D

## Melee guard owned by a Guard Post. Damage attributes to the post.

enum State { IDLE, CHASE, ATTACK, RETURN }

const MELEE_DISTANCE := 0.65
const MOVE_SPEED := 3.2

var owner_tower: Node3D = null
var home_offset: Vector3 = Vector3.ZERO
var guard_damage: float = 20.0
var attack_interval: float = 0.7

var _state: int = State.IDLE
var _target: Node3D = null
var _cooldown: float = 0.0
var _floor_y: float = 0.0


func setup(post: Node3D, offset: Vector3, damage: float, interval: float) -> void:
	owner_tower = post
	home_offset = offset
	guard_damage = damage
	attack_interval = interval
	_floor_y = post.global_position.y
	global_position = post.global_position + offset
	global_position.y = _floor_y


func _process(delta: float) -> void:
	if owner_tower == null or not is_instance_valid(owner_tower):
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_floor_y = owner_tower.global_position.y

	# Freed enemies must be cleared before any typed helper calls.
	if _target != null and not is_instance_valid(_target):
		_target = null
		if _state == State.CHASE or _state == State.ATTACK:
			_begin_return()
			return

	match _state:
		State.IDLE:
			_target = _pick_target()
			if _target != null:
				_state = State.CHASE
		State.CHASE:
			if not _is_valid_target(_target):
				_begin_return()
				return
			if _xz_distance_to(_target) <= MELEE_DISTANCE:
				_state = State.ATTACK
				return
			_move_toward(_target.global_position, delta)
		State.ATTACK:
			if not _is_valid_target(_target):
				_begin_return()
				return
			if _xz_distance_to(_target) > MELEE_DISTANCE * 1.35:
				_state = State.CHASE
				return
			_face_xz(_target.global_position)
			if _cooldown <= 0.0:
				_do_attack()
				_cooldown = attack_interval
		State.RETURN:
			var home := owner_tower.global_position + home_offset
			home.y = _floor_y
			if _xz_distance(global_position, home) <= 0.08:
				global_position = home
				_state = State.IDLE
				_target = null
				return
			_move_toward(home, delta)
			var retarget := _pick_target()
			if retarget != null:
				_target = retarget
				_state = State.CHASE


func _begin_return() -> void:
	_target = null
	_state = State.RETURN
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_guard_return"):
		owner_tower.call("record_guard_return")


func _do_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return
	if owner_tower != null and is_instance_valid(owner_tower) and owner_tower.has_method("record_shot"):
		owner_tower.call("record_shot")
	if owner_tower != null and is_instance_valid(owner_tower) and "guard_attacks" in owner_tower:
		owner_tower.guard_attacks = int(owner_tower.guard_attacks) + 1
	if _target.has_method("take_damage"):
		_target.call("take_damage", guard_damage, owner_tower)
	# Kill may free the target synchronously.
	if _target != null and not is_instance_valid(_target):
		_target = null


func _pick_target() -> Node3D:
	if owner_tower == null or not is_instance_valid(owner_tower):
		return null
	if not owner_tower.has_method("is_enemy_in_range"):
		return null
	var best: Node3D = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		if not bool(owner_tower.call("is_enemy_in_range", enemy)):
			continue
		var progress := 0.0
		if enemy.has_method("get_path_progress"):
			progress = float(enemy.call("get_path_progress"))
		if progress > best_progress:
			best_progress = progress
			best = enemy
	return best


## Untyped on purpose: freed Objects cannot be passed as Node3D.
func _is_valid_target(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	if owner_tower == null or not is_instance_valid(owner_tower):
		return false
	if not owner_tower.has_method("is_enemy_in_range"):
		return false
	return bool(owner_tower.call("is_enemy_in_range", enemy))


func _move_toward(world_target: Vector3, delta: float) -> void:
	var dest := world_target
	dest.y = _floor_y
	var to := dest - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.001:
		return
	var step := minf(MOVE_SPEED * delta, dist)
	var next := global_position + to.normalized() * step
	next.y = _floor_y
	next = _clamp_to_disc(next)
	_face_xz(dest)
	global_position = next


func _clamp_to_disc(pos: Vector3) -> Vector3:
	if owner_tower == null or not is_instance_valid(owner_tower) or not owner_tower.has_method("get_range_origin"):
		return pos
	var origin: Vector3 = owner_tower.call("get_range_origin")
	var radius: float = float(owner_tower.call("get_range_value")) if owner_tower.has_method("get_range_value") else 2.5
	var offset := Vector2(pos.x - origin.x, pos.z - origin.z)
	if offset.length() <= radius:
		pos.y = _floor_y
		return pos
	offset = offset.normalized() * radius
	return Vector3(origin.x + offset.x, _floor_y, origin.z + offset.y)


func _face_xz(world_target: Vector3) -> void:
	var flat := Vector3(world_target.x, global_position.y, world_target.z)
	if global_position.distance_to(flat) < 0.001:
		return
	look_at(flat, Vector3.UP)


func _xz_distance_to(node: Node3D) -> float:
	if node == null or not is_instance_valid(node):
		return INF
	return _xz_distance(global_position, node.global_position)


func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
