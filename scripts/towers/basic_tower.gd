extends Node3D

signal tower_clicked(tower: Node3D)
signal tower_hovered(tower: Node3D, hovered: bool)

const PROJECTILE_SCENE := preload("res://scenes/towers/basic_projectile.tscn")

@export var attack_range: float = 4.0
@export var fire_interval: float = 0.8
@export var damage: float = 25.0

var runtime_id: String = ""
var level: int = 1
var floor_id: String = ""
var floor_index: int = 0
var build_spot_id: String = ""
var selected: bool = false

var shots_fired: int = 0
var hits: int = 0
var damage_dealt: float = 0.0
var kills: int = 0
var same_floor_damage: float = 0.0
var cross_floor_damage: float = 0.0
var damage_by_target_floor: Dictionary = {}

@onready var _turret: Node3D = $Turret
@onready var _muzzle: Marker3D = $Turret/Muzzle
@onready var _range_origin: Marker3D = $RangeOrigin

var _cooldown: float = 0.0
var _pick_body: StaticBody3D


func _ready() -> void:
	add_to_group("towers")
	var shot_line := get_node_or_null("Turret/ShotLine")
	if shot_line:
		shot_line.visible = false
	_ensure_range_origin()
	_ensure_pick_body()


func get_range_origin() -> Vector3:
	_ensure_range_origin()
	return _range_origin.global_position


func get_range_origin_node() -> Node3D:
	_ensure_range_origin()
	return _range_origin


func _ensure_range_origin() -> void:
	if _range_origin != null and is_instance_valid(_range_origin):
		return
	_range_origin = get_node_or_null("RangeOrigin") as Marker3D
	if _range_origin != null:
		return
	_range_origin = Marker3D.new()
	_range_origin.name = "RangeOrigin"
	_range_origin.position = Vector3(0.0, 0.45, 0.0)
	add_child(_range_origin)


func configure_built(
	p_runtime_id: String,
	def: Resource,
	p_floor_id: String,
	p_floor_index: int,
	p_spot_id: String
) -> void:
	runtime_id = p_runtime_id
	floor_id = p_floor_id
	floor_index = p_floor_index
	build_spot_id = p_spot_id
	level = 1
	attack_range = float(def.base_range)
	damage = float(def.base_damage)
	fire_interval = float(def.base_fire_interval)
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)
	_ensure_pick_body()


func apply_range_upgrade(new_range: float) -> void:
	level = 2
	attack_range = new_range


func set_selected(value: bool) -> void:
	selected = value
	# Subtle scale cue on base
	var base := get_node_or_null("Base")
	if base:
		base.scale = Vector3.ONE * (1.08 if selected else 1.0)


func record_shot() -> void:
	shots_fired += 1


func record_hit(amount: float, target_floor_id: String, target_floor_index: int) -> void:
	hits += 1
	damage_dealt += amount
	if not damage_by_target_floor.has(target_floor_id):
		damage_by_target_floor[target_floor_id] = 0.0
	damage_by_target_floor[target_floor_id] = float(damage_by_target_floor[target_floor_id]) + amount
	if target_floor_index == floor_index:
		same_floor_damage += amount
	else:
		cross_floor_damage += amount


func record_kill() -> void:
	kills += 1


func _ensure_pick_body() -> void:
	if _pick_body != null:
		return
	_pick_body = StaticBody3D.new()
	_pick_body.name = "PickBody"
	_pick_body.collision_layer = 4
	_pick_body.collision_mask = 0
	_pick_body.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 1.0
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.45, 0.0)
	_pick_body.add_child(shape)
	add_child(_pick_body)
	_pick_body.mouse_entered.connect(func() -> void: tower_hovered.emit(self, true))
	_pick_body.mouse_exited.connect(func() -> void: tower_hovered.emit(self, false))
	_pick_body.input_event.connect(_on_pick_input)


func _on_pick_input(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				return
			tower_clicked.emit(self)
			get_viewport().set_input_as_handled()


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
	var origin := get_range_origin()
	var best: Node3D = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		var dist := origin.distance_to(enemy.global_position)
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
	record_shot()
	var projectile := PROJECTILE_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	if projectile.has_method("setup"):
		projectile.call("setup", target, damage, self)
