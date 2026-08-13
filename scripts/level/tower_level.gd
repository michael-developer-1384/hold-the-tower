extends Node3D

## Runtime host: instantiates a LevelDefinition and wires gameplay anchors.

const CORE_SCENE := preload("res://scenes/world/core.tscn")
const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const EnemyPathBuilderScript := preload("res://scripts/level/enemy_path_builder.gd")
const FloorRendererScript := preload("res://scripts/level/floor_renderer.gd")
const BuildSpotRendererScript := preload("res://scripts/level/build_spot_renderer.gd")
const ConnectorRendererScript := preload("res://scripts/level/connector_renderer.gd")

var level: Resource
var enemy_path: PackedVector3Array = PackedVector3Array()
var waypoint_floors: PackedStringArray = PackedStringArray()
var segment_floors: PackedStringArray = PackedStringArray()
var floor_index_by_id: Dictionary = {}
var build_spot_count: int = 0
var build_spots: Array = []
var path_pickers: Array = []

var _core: Node3D
var _enemy_container: Node3D
var _floors_root: Node3D
var _connectors_root: Node3D
var _towers_root: Node3D
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

	_towers_root = Node3D.new()
	_towers_root.name = "Towers"
	add_child(_towers_root)

	_visual = Node.new()
	_visual.name = "FloorVisualController"
	_visual.set_script(load("res://scripts/level/floor_visual_controller.gd"))
	add_child(_visual)

	level = TestLevelFactoryScript.create_level()
	_instantiate_level()
	var meta: Dictionary = EnemyPathBuilderScript.build_with_meta(level)
	enemy_path = meta["path"]
	waypoint_floors = meta["waypoint_floors"]
	segment_floors = meta["segment_floors"]
	for floor_def in level.floors:
		floor_index_by_id[str(floor_def.floor_id)] = int(floor_def.floor_index)
	_place_core()

	_visual.setup(
		_floor_nodes,
		get_floor_heights(),
		{
			"path": _path_mat,
			"build": _build_mat,
			"ramp": _ramp_mat,
		}
	)

	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	if SimContextScript == null or SimContextScript.allow_prints():
		print("Level '%s': %d floors, %d path points, %d build spots" % [
			level.level_id, level.floors.size(), enemy_path.size(), build_spot_count
		])


func get_enemy_path() -> PackedVector3Array:
	return enemy_path


func get_path_meta() -> Dictionary:
	return {
		"path": enemy_path,
		"waypoint_floors": waypoint_floors,
		"segment_floors": segment_floors,
		"floor_index_by_id": floor_index_by_id,
	}


func get_enemy_container() -> Node3D:
	return _enemy_container


func get_towers_root() -> Node3D:
	return _towers_root


func get_build_spots() -> Array:
	return build_spots


func get_path_pickers() -> Array:
	return path_pickers


func get_visual_controller() -> Node:
	return _visual


func get_core() -> Node3D:
	return _core


func get_floor_count() -> int:
	return level.floors.size() if level else 0


func get_level_id() -> String:
	return str(level.level_id) if level else "unknown"


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


func set_hover_floor(index: int) -> void:
	if _visual and _visual.has_method("set_hover_floor"):
		_visual.call("set_hover_floor", index)


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
	build_spots.clear()
	path_pickers.clear()

	var sorted: Array = level.floors.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)

	for floor_def in sorted:
		var floor_node := Node3D.new()
		floor_node.name = floor_def.floor_id
		floor_node.position = Vector3(floor_def.origin.x, 0.0, floor_def.origin.z)
		floor_node.set_meta("floor_index", floor_def.floor_index)
		floor_node.set_meta("floor_id", floor_def.floor_id)
		_floors_root.add_child(floor_node)
		_floor_nodes.append(floor_node)

		var pickers: Array = FloorRendererScript.render(floor_node, floor_def, _path_mat)
		path_pickers.append_array(pickers)
		var floor_spots: Array = BuildSpotRendererScript.render(floor_node, floor_def)
		build_spots.append_array(floor_spots)
		build_spot_count += floor_spots.size()

	_connectors_root = Node3D.new()
	_connectors_root.name = "Connectors"
	add_child(_connectors_root)
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
