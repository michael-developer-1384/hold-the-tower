extends Node3D

signal tower_clicked(tower: Node3D)
signal tower_hovered(tower: Node3D, hovered: bool)

const GuardScript := preload("res://scripts/towers/guard.gd")

@export var floor_radius: float = 2.5
@export var guard_count: int = 2
@export var guard_damage: float = 20.0
@export var attack_interval: float = 0.7
@export var slow_factor: float = 0.55
@export var slow_refresh: float = 0.2

var runtime_id: String = ""
var tower_type: String = "guard_post"
var level: int = 1
var floor_id: String = ""
var floor_index: int = 0
var build_spot_id: String = ""
var selected: bool = false

var shots_fired: int = 0 # guard attacks
var hits: int = 0
var damage_dealt: float = 0.0
var kills: int = 0
var same_floor_damage: float = 0.0
var cross_floor_damage: float = 0.0
var damage_by_target_floor: Dictionary = {}
var guard_attacks: int = 0
var guard_returns: int = 0

var _range_origin: Marker3D
var _pick_body: StaticBody3D
var _guards: Array = []
var _guards_root: Node3D


func _ready() -> void:
	add_to_group("towers")
	_ensure_range_origin()
	_ensure_pick_body()
	_ensure_guards_root()


func _process(_delta: float) -> void:
	_apply_zone_slow()


func _apply_zone_slow() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		if not is_enemy_in_range(enemy):
			continue
		if enemy.has_method("apply_slow"):
			enemy.call("apply_slow", slow_factor, slow_refresh)


func get_range_origin() -> Vector3:
	_ensure_range_origin()
	return _range_origin.global_position


func get_range_origin_node() -> Node3D:
	_ensure_range_origin()
	return _range_origin


func get_range_shape() -> String:
	return "FLOOR_DISC"


func get_range_value() -> float:
	return floor_radius


## Untyped so callers can safely pass potentially freed refs.
func is_enemy_in_range(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	var node := enemy as Node3D
	var enemy_floor := ""
	if node.has_method("get_current_floor_id"):
		enemy_floor = str(node.call("get_current_floor_id"))
	elif "floor_id" in node:
		enemy_floor = str(node.get("floor_id"))
	if enemy_floor != floor_id:
		return false
	var origin := get_range_origin()
	var dist := Vector2(
		node.global_position.x - origin.x,
		node.global_position.z - origin.z
	).length()
	return dist <= floor_radius


func configure_built(
	p_runtime_id: String,
	def: Resource,
	p_floor_id: String,
	p_floor_index: int,
	p_spot_id: String
) -> void:
	runtime_id = p_runtime_id
	tower_type = str(def.tower_id) if def else "guard_post"
	floor_id = p_floor_id
	floor_index = p_floor_index
	build_spot_id = p_spot_id
	level = 1
	floor_radius = float(def.base_range) if def else 2.5
	guard_damage = float(def.base_damage) if def else 20.0
	attack_interval = float(def.base_fire_interval) if def else 0.7
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)
	_ensure_range_origin()
	_ensure_pick_body()
	_spawn_guards()


func set_selected(value: bool) -> void:
	selected = value
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


func record_guard_return() -> void:
	guard_returns += 1


func _spawn_guards() -> void:
	_ensure_guards_root()
	for g in _guards:
		if is_instance_valid(g):
			g.queue_free()
	_guards.clear()
	var offsets := [
		Vector3(-0.55, 0.0, 0.15),
		Vector3(0.55, 0.0, 0.15),
	]
	for i in mini(guard_count, offsets.size()):
		var guard := Node3D.new()
		guard.name = "Guard_%d" % (i + 1)
		guard.set_script(GuardScript)
		_guards_root.add_child(guard)
		_build_guard_mesh(guard)
		guard.call("setup", self, offsets[i], guard_damage, attack_interval)
		_guards.append(guard)


func _build_guard_mesh(guard: Node3D) -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.14
	capsule.height = 0.55
	body.mesh = capsule
	body.position = Vector3(0.0, 0.28, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.38, 0.28)
	mat.roughness = 0.85
	body.material_override = mat
	guard.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	head.mesh = sphere
	head.position = Vector3(0.0, 0.62, 0.0)
	head.material_override = mat
	guard.add_child(head)


func _ensure_guards_root() -> void:
	if _guards_root != null and is_instance_valid(_guards_root):
		return
	_guards_root = get_node_or_null("Guards") as Node3D
	if _guards_root == null:
		_guards_root = Node3D.new()
		_guards_root.name = "Guards"
		add_child(_guards_root)


func _ensure_range_origin() -> void:
	if _range_origin != null and is_instance_valid(_range_origin):
		return
	_range_origin = get_node_or_null("RangeOrigin") as Marker3D
	if _range_origin != null:
		return
	_range_origin = Marker3D.new()
	_range_origin.name = "RangeOrigin"
	_range_origin.position = Vector3(0.0, 0.05, 0.0)
	add_child(_range_origin)


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
	cyl.radius = 0.55
	cyl.height = 0.9
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
