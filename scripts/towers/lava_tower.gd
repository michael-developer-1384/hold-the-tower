extends Node3D

signal tower_clicked(tower: Node3D)
signal tower_hovered(tower: Node3D, hovered: bool)

const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const LavaConfigScript := preload("res://scripts/world/lava_config.gd")

@export var floor_radius: float = 2.5
@export var lava_damage: float = 10.0
@export var pour_rate: float = 1.2
@export var flow_rate: float = 0.45
@export var lava_lifetime: float = 8.0

var runtime_id: String = ""
var tower_type: String = "lava_tower"
var level: int = 1
var floor_id: String = ""
var floor_index: int = 0
var build_spot_id: String = ""
var selected: bool = false
var blueprint_id: String = ""
var resolved_stats: Dictionary = {}
var purchase_price: int = 0
var buying_power_invested: int = 0
# Legacy read-only migration field for old snapshots.
var gold_invested: int = 0

var shots_fired: int = 0
var hits: int = 0
var damage_dealt: float = 0.0
var kills: int = 0
var same_floor_damage: float = 0.0
var cross_floor_damage: float = 0.0
var damage_by_target_floor: Dictionary = {}
var overkill_damage: float = 0.0

var _range_origin: Marker3D
var _pick_body: StaticBody3D
var _spout: Node3D
var _pour_ix: int = 0
var _pour_iz: int = 0
var _pour_ready: bool = false
var _emit_acc: float = 0.0
var _emit_seq: int = 0
var _lava = null


func _ready() -> void:
	add_to_group("towers")
	_ensure_range_origin()
	_ensure_pick_body()
	_spout = get_node_or_null("Visual/Spout") as Node3D


func _physics_process(delta: float) -> void:
	_ensure_pour_target()
	_face_pour()
	var lava = _lava_system()
	if lava == null or not _pour_ready:
		return
	_emit_acc += pour_rate * delta
	while _emit_acc >= 1.0:
		_emit_acc -= 1.0
		_emit_one(lava)


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


func lava_field_metrics() -> Dictionary:
	var lava = _lava_system()
	if lava != null and lava.has_method("field_metrics"):
		return lava.call("field_metrics")
	return {}


func configure_built(
	p_runtime_id: String,
	def: Resource,
	p_floor_id: String,
	p_floor_index: int,
	p_spot_id: String,
	resolved: Dictionary = {}
) -> void:
	runtime_id = p_runtime_id
	tower_type = str(def.tower_id) if def else "lava_tower"
	floor_id = p_floor_id
	floor_index = p_floor_index
	build_spot_id = p_spot_id
	level = 1
	resolved_stats = resolved.duplicate(true) if not resolved.is_empty() else {}
	blueprint_id = str(resolved_stats.get("blueprint_id", ""))
	if resolved_stats.is_empty():
		floor_radius = float(def.base_range) if def else 2.5
		lava_damage = float(def.base_damage) if def else 10.0
		pour_rate = 1.2
		flow_rate = 0.45
		lava_lifetime = 8.0
	else:
		floor_radius = float(resolved_stats.get("range", def.base_range if def else 2.5))
		lava_damage = float(resolved_stats.get("lava_damage", def.base_damage if def else 10.0))
		pour_rate = float(resolved_stats.get("pour_rate", 1.2))
		flow_rate = float(resolved_stats.get("flow_rate", 0.45))
		lava_lifetime = float(resolved_stats.get("lava_lifetime", 8.0))
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)
	_pour_ready = false
	_ensure_pick_body()


func set_selected(value: bool) -> void:
	selected = value
	var base := get_node_or_null("Visual/Base")
	if base:
		base.scale = Vector3.ONE * (1.08 if selected else 1.0)


func get_ui_stat_lines() -> PackedStringArray:
	var StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
	return PackedStringArray([
		"%s  %s" % [StatPresentationScript.label("lava_damage"), StatPresentationScript.format_value("lava_damage", lava_damage)],
		"%s  %s" % [StatPresentationScript.label("pour_rate"), StatPresentationScript.format_value("pour_rate", pour_rate)],
		"%s  %s" % [StatPresentationScript.label("flow_rate"), StatPresentationScript.format_value("flow_rate", flow_rate)],
		"%s  %s" % [StatPresentationScript.label("lava_lifetime"), StatPresentationScript.format_value("lava_lifetime", lava_lifetime)],
	])


func can_in_run_upgrade() -> bool:
	return false


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


func record_overkill(amount: float) -> void:
	if amount > 0.0:
		overkill_damage += amount


func record_kill() -> void:
	kills += 1


func get_fire_cooldown() -> float:
	return 0.0


func set_fire_cooldown(_value: float) -> void:
	pass


func get_emit_acc() -> float:
	return _emit_acc


func set_emit_acc(value: float) -> void:
	_emit_acc = value


func get_emit_seq() -> int:
	return _emit_seq


func set_emit_seq(value: int) -> void:
	_emit_seq = value


func _rand_range(from_v: float, to_v: float) -> float:
	if SimContextScript.rng != null and SimContextScript.rng.has_method("randf_range"):
		return float(SimContextScript.rng.randf_range(from_v, to_v))
	return randf_range(from_v, to_v)


func _ensure_pour_target() -> void:
	if _pour_ready:
		return
	if not is_inside_tree():
		return
	var tl := get_tree().root.find_child("TowerLevel", true, false)
	if tl == null:
		return
	var path: PackedVector3Array = PackedVector3Array()
	var floors: PackedStringArray = PackedStringArray()
	if "enemy_path" in tl:
		path = tl.enemy_path
	if "waypoint_floors" in tl:
		floors = tl.waypoint_floors
	var best_d := INF
	var best := Vector3.ZERO
	var found := false
	for i in path.size():
		if i < floors.size() and str(floors[i]) != floor_id:
			continue
		var p: Vector3 = path[i]
		var d := Vector2(p.x - global_position.x, p.z - global_position.z).length_squared()
		if d < best_d:
			best_d = d
			best = p
			found = true
	if not found:
		return
	_pour_ix = int(round(best.x))
	_pour_iz = int(round(best.z))
	_pour_ready = true


func _emit_one(lava) -> void:
	if lava == null or not lava.has_method("emit_toward"):
		return
	shots_fired += 1
	var origin := global_position + Vector3(0.0, 0.55, 0.0)
	if _spout == null:
		_spout = get_node_or_null("Visual/Spout") as Node3D
	if _spout != null:
		origin = _spout.global_position
	var elev := global_position.y
	if lava.has_method("surface_index"):
		var idx = lava.call("surface_index")
		if idx != null and idx.has_method("support_at"):
			var sup: Dictionary = idx.call("support_at", _pour_ix, _pour_iz, floor_id)
			elev = float(sup.get("elevation", elev))
	var stats := {
		"lava_damage": lava_damage,
		"flow_rate": flow_rate,
		"lava_lifetime": lava_lifetime,
		"cell_mass_capacity": float(resolved_stats.get("cell_mass_capacity", LavaConfigScript.CELL_MASS_CAPACITY)),
		"damage_full_mass": float(resolved_stats.get("damage_full_mass", LavaConfigScript.DAMAGE_FULL_MASS)),
		"damage_threshold_mass": float(resolved_stats.get("damage_threshold_mass", LavaConfigScript.DAMAGE_THRESHOLD_MASS)),
		"flow_start_mass": float(resolved_stats.get("flow_start_mass", LavaConfigScript.FLOW_START_MASS)),
	}
	var phase := _emit_seq % 4
	_emit_seq += 1
	if phase < 2:
		stats["stick_ix"] = _pour_ix
		stats["stick_iz"] = _pour_iz
		var land_aim := Vector3(
			float(_pour_ix) + _rand_range(-0.40, 0.40),
			elev + 0.28,
			float(_pour_iz) + _rand_range(-0.40, 0.40)
		)
		stats["splat_x"] = land_aim.x
		stats["splat_z"] = land_aim.z
		lava.call("emit_toward", origin, land_aim, 1.0, runtime_id, stats)
		return
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0)]
	if lava.has_method("slip_dirs"):
		dirs = lava.call("slip_dirs", _pour_ix, _pour_iz, floor_id)
	if dirs.is_empty():
		dirs = [Vector2i(1, 0), Vector2i(-1, 0)]
	var d: Vector2i = dirs[mini(phase - 2, dirs.size() - 1)]
	stats["skip_floor"] = floor_id
	var along := Vector2(float(-d.y), float(d.x))
	var slip_aim := Vector3(
		float(_pour_ix) + float(d.x) * _rand_range(0.55, 1.20) + along.x * _rand_range(-0.50, 0.50),
		elev - 0.04,
		float(_pour_iz) + float(d.y) * _rand_range(0.55, 1.20) + along.y * _rand_range(-0.50, 0.50)
	)
	lava.call("emit_toward", origin, slip_aim, 1.0, runtime_id, stats)


func _face_pour() -> void:
	if not _pour_ready:
		return
	var aim := Vector3(float(_pour_ix), global_position.y, float(_pour_iz))
	if _spout == null:
		_spout = get_node_or_null("Visual/Spout") as Node3D
	var yaw_node := _spout if _spout != null else get_node_or_null("Visual") as Node3D
	if yaw_node == null:
		return
	if yaw_node.global_position.distance_to(aim) < 0.05:
		return
	aim.y = yaw_node.global_position.y
	yaw_node.look_at(aim, Vector3.UP)


func _lava_system():
	if _lava != null and is_instance_valid(_lava):
		return _lava
	if not is_inside_tree():
		return null
	var tl := get_tree().root.find_child("TowerLevel", true, false)
	if tl != null and tl.has_method("get_lava_system"):
		_lava = tl.call("get_lava_system")
		return _lava
	_lava = get_tree().root.find_child("LavaSystem", true, false)
	return _lava


func _ensure_range_origin() -> void:
	if _range_origin != null and is_instance_valid(_range_origin):
		return
	_range_origin = get_node_or_null("RangeOrigin") as Marker3D
	if _range_origin != null:
		return
	_range_origin = Marker3D.new()
	_range_origin.name = "RangeOrigin"
	_range_origin.position = Vector3(0.0, 0.35, 0.0)
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
