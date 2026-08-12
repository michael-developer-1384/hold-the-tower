extends Node3D

const PROJECTILE_SCENE := preload("res://scenes/towers/basic_projectile.tscn")

@export var attack_range: float = 4.0
@export var fire_interval: float = 0.8
@export var damage: float = 25.0

@onready var _turret: Node3D = $Turret
@onready var _muzzle: Marker3D = $Turret/Muzzle

var _cooldown: float = 0.0


func _ready() -> void:
	add_to_group("towers")
	var shot_line := get_node_or_null("Turret/ShotLine")
	if shot_line:
		shot_line.visible = false


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := _find_target()
	if target == null:
		return
	_face_target(target)
	if _cooldown <= 0.0:
		_fire(target)
		_cooldown = fire_interval


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		var dist := global_position.distance_to(enemy.global_position)
		if dist > attack_range:
			continue
		var progress := 0.0
		if enemy.has_method("get_path_progress"):
			progress = float(enemy.call("get_path_progress"))
		if progress > best_progress:
			best_progress = progress
			best = enemy
	return best


func _face_target(target: Node3D) -> void:
	var aim := target.global_position
	aim.y = _turret.global_position.y
	if _turret.global_position.distance_to(aim) < 0.001:
		return
	_turret.look_at(aim, Vector3.UP)


func _fire(target: Node3D) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	if projectile.has_method("setup"):
		projectile.call("setup", target, damage)
