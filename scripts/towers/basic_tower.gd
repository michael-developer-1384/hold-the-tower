extends Node3D

@export var attack_range: float = 3.5
@export var fire_rate: float = 1.0
@export var damage: float = 20.0

@onready var _turret: Node3D = $Turret
@onready var _muzzle: Marker3D = $Turret/Muzzle
@onready var _shot_line: MeshInstance3D = $Turret/ShotLine

var _cooldown: float = 0.0
var _shot_timer: float = 0.0


func _ready() -> void:
	add_to_group("towers")
	_shot_line.visible = false
	if _shot_line.mesh:
		_shot_line.mesh = _shot_line.mesh.duplicate()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_line.visible = false

	var target := _find_target()
	if target == null:
		return

	_face_target(target)
	if _cooldown <= 0.0:
		_fire(target)
		_cooldown = 1.0 / fire_rate


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dist := attack_range
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = enemy
	return best


func _face_target(target: Node3D) -> void:
	var aim := target.global_position
	aim.y = _turret.global_position.y
	if _turret.global_position.distance_to(aim) < 0.001:
		return
	_turret.look_at(aim, Vector3.UP)


func _fire(target: Node3D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	_show_shot(target.global_position + Vector3(0.0, 0.6, 0.0))


func _show_shot(target_pos: Vector3) -> void:
	var from := _muzzle.global_position
	var to := target_pos
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)
	_shot_line.visible = true
	_shot_line.global_position = mid
	var dir := (to - from).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.99:
		_shot_line.look_at(to, Vector3.UP)
	_shot_line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var mesh := _shot_line.mesh as CylinderMesh
	if mesh:
		mesh.height = maxf(length, 0.05)
	_shot_timer = 0.08
