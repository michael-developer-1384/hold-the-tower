extends Node3D

## Runtime host: instantiates a LevelDefinition and wires gameplay anchors.

const CORE_SCENE := preload("res://scenes/world/core.tscn")
const TOWER_SCENE := preload("res://scenes/towers/basic_tower.tscn")
const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const EnemyPathBuilderScript := preload("res://scripts/level/enemy_path_builder.gd")
const FloorRendererScript := preload("res://scripts/level/floor_renderer.gd")
const BuildSpotRendererScript := preload("res://scripts/level/build_spot_renderer.gd")
const ConnectorRendererScript := preload("res://scripts/level/connector_renderer.gd")

var level: Resource
var enemy_path: PackedVector3Array = PackedVector3Array()
var build_spot_count: int = 0

var _core: Node3D
var _enemy_container: Node3D
var _floors_root: Node3D
var _connectors_root: Node3D
var _floor_nodes: Array[Node3D] = []
var _visual: Node

var _path_mat: StandardMaterial3D
var _build_mat: StandardMaterial3D
var _ramp_mat: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_enemy_container = Node3D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)

	_visual = Node.new()
	_visual.name = "FloorVisualController"
	_visual.set_script(load("res://scripts/level/floor_visual_controller.gd"))
	add_child(_visual)

	level = TestLevelFactoryScript.create_level()
	_instantiate_level()
	enemy_path = EnemyPathBuilderScript.build(level)
	_place_core()
	_place_sample_tower()

	_visual.setup(
		_floor_nodes,
		get_floor_heights(),
		{
			"path": _path_mat,
			"build": _build_mat,
			"ramp": _ramp_mat,
		}
	)

	print("Level '%s': %d floors, %d path points, %d build spots" % [
		level.level_id, level.floors.size(), enemy_path.size(), build_spot_count
	])


func get_enemy_path() -> PackedVector3Array:
	return enemy_path


func get_enemy_container() -> Node3D:
	return _enemy_container


func get_core() -> Node3D:
	return _core


func get_floor_count() -> int:
	return level.floors.size() if level else 0


func get_floor_heights() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	if level == null:
		return heights
	var sorted: Array = level.floors.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)
	for floor_def in sorted:
		heights.append(floor_def.world_focus_point().y)
	return heights


func get_focus_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if level == null:
		return points
	var sorted: Array = level.floors.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)
	for floor_def in sorted:
		points.append(floor_def.world_focus_point())
	return points


func set_focus_floor(index: int) -> void:
	if _visual and _visual.has_method("set_focus_floor"):
		_visual.call("set_focus_floor", index)


func _create_materials() -> void:
	_path_mat = _make_mat(Color(0.28, 0.28, 0.30))
	_build_mat = _make_mat(Color(0.62, 0.64, 0.68))
	_ramp_mat = _make_mat(Color(0.55, 0.42, 0.28))


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _instantiate_level() -> void:
	_floors_root = Node3D.new()
	_floors_root.name = "Floors"
	add_child(_floors_root)
	_floor_nodes.clear()

	var sorted: Array = level.floors.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)

	for floor_def in sorted:
		var floor_node := Node3D.new()
		floor_node.name = floor_def.floor_id
		# Platforms store world Y; keep floor node at XZ origin offset only.
		floor_node.position = Vector3(floor_def.origin.x, 0.0, floor_def.origin.z)
		floor_node.set_meta("floor_index", floor_def.floor_index)
		floor_node.set_meta("floor_id", floor_def.floor_id)
		_floors_root.add_child(floor_node)
		_floor_nodes.append(floor_node)

		FloorRendererScript.render(floor_node, floor_def, _path_mat)
		build_spot_count += BuildSpotRendererScript.render(floor_node, floor_def, _build_mat)

	_connectors_root = Node3D.new()
	_connectors_root.name = "Connectors"
	add_child(_connectors_root)
	# Parent each connector under its from-floor so ghosting follows floor focus.
	for connector in level.connectors:
		var from_floor = level.get_floor_by_id(connector.from_floor_id)
		var host: Node3D = _connectors_root
		if from_floor != null:
			for floor_node in _floor_nodes:
				if int(floor_node.get_meta("floor_index", -1)) == from_floor.floor_index:
					host = floor_node
					break
		var list: Array = []
		list.append(connector)
		ConnectorRendererScript.render_all(host, list, _ramp_mat)


func _place_core() -> void:
	_core = CORE_SCENE.instantiate() as Node3D
	_core.name = "Core"
	_core.transform = level.core_transform
	_core.add_to_group("cores")
	add_child(_core)


func _place_sample_tower() -> void:
	var floor_1 = level.get_floor_by_id("floor_1")
	if floor_1 == null or floor_1.build_spots.is_empty():
		return
	var mid: Vector3 = floor_1.path_points[int(floor_1.path_points.size() / 2.0)]
	var best = floor_1.build_spots[0]
	var best_dist := INF
	for spot in floor_1.build_spots:
		var p: Vector3 = spot.transform.origin
		var d := Vector2(p.x, p.z).distance_to(Vector2(mid.x, mid.z))
		if d < best_dist:
			best_dist = d
			best = spot
	var tower := TOWER_SCENE.instantiate() as Node3D
	tower.name = "SampleTower"
	var t: Transform3D = best.transform
	tower.transform = Transform3D(t.basis, t.origin + Vector3(0.0, 0.05, 0.0))
	tower.add_to_group("towers")
	add_child(tower)
	best.occupied = true
