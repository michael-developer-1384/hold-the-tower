extends Node

## Ghosts horizontal floor surfaces and entities above the focused floor.

const GHOST_ALPHA := 0.08

var focus_floor: int = 0

var _floor_nodes: Array[Node3D] = []
var _floor_heights: PackedFloat32Array = PackedFloat32Array()
var _mats_normal: Dictionary = {}
var _mats_ghost: Dictionary = {}
var _entity_ghost_mat: StandardMaterial3D
var _entity_normal_cache: Dictionary = {}


func setup(
	floor_nodes: Array[Node3D],
	floor_heights: PackedFloat32Array,
	base_materials: Dictionary
) -> void:
	_floor_nodes = floor_nodes
	_floor_heights = floor_heights
	_mats_normal.clear()
	_mats_ghost.clear()
	for key in base_materials.keys():
		var base: StandardMaterial3D = base_materials[key]
		_mats_normal[key] = base
		_mats_ghost[key] = _make_ghost(base)
	_entity_ghost_mat = _make_ghost_color(Color(0.85, 0.85, 0.9))
	set_focus_floor(focus_floor)


func set_focus_floor(index: int) -> void:
	focus_floor = index
	_apply_horizontal_floor_modes()
	_update_entity_visuals()


func _process(_delta: float) -> void:
	_update_entity_visuals()


func _make_ghost(base: StandardMaterial3D) -> StandardMaterial3D:
	var ghost := base.duplicate() as StandardMaterial3D
	var c := ghost.albedo_color
	c = c.lerp(Color(0.88, 0.9, 0.94), 0.45)
	c.a = GHOST_ALPHA
	ghost.albedo_color = c
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.roughness = 1.0
	ghost.metallic = 0.0
	return ghost


func _make_ghost_color(color: Color) -> StandardMaterial3D:
	var ghost := StandardMaterial3D.new()
	color.a = GHOST_ALPHA
	ghost.albedo_color = color
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.roughness = 1.0
	return ghost


func _is_ghost_floor(floor_index: int) -> bool:
	return floor_index > focus_floor


func _apply_horizontal_floor_modes() -> void:
	for i in _floor_nodes.size():
		var floor_node := _floor_nodes[i]
		if not is_instance_valid(floor_node):
			continue
		floor_node.visible = true
		_apply_mode_to_node(floor_node, _is_ghost_floor(i))


func _apply_mode_to_node(node: Node, ghost: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var kind := str(mesh_instance.get_meta("mat_kind", "floor"))
		if ghost and _mats_ghost.has(kind):
			mesh_instance.material_override = _mats_ghost[kind]
		elif _mats_normal.has(kind):
			mesh_instance.material_override = _mats_normal[kind]
	for child in node.get_children():
		_apply_mode_to_node(child, ghost)


func _update_entity_visuals() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if node is Node3D:
			var enemy := node as Node3D
			enemy.visible = true
			_set_entity_ghost(enemy, _entity_above_focus(enemy))
	for node in tree.get_nodes_in_group("towers"):
		if node is Node3D:
			var tower := node as Node3D
			tower.visible = true
			_set_entity_ghost(tower, _entity_above_focus(tower))
	for node in tree.get_nodes_in_group("cores"):
		if node is Node3D:
			var core := node as Node3D
			core.visible = true
			_set_entity_ghost(core, _entity_above_focus(core))


func _entity_above_focus(node: Node3D) -> bool:
	return _floor_index_for_y(node.global_position.y) > focus_floor


func _floor_index_for_y(y: float) -> int:
	if _floor_heights.is_empty():
		return 0
	var best: int = 0
	for i in range(1, _floor_heights.size()):
		var mid: float = (_floor_heights[i - 1] + _floor_heights[i]) * 0.5
		if y >= mid:
			best = i
	return best


func _set_entity_ghost(root: Node3D, ghost: bool) -> void:
	_set_meshes_ghost_recursive(root, ghost)


func _set_meshes_ghost_recursive(node: Node, ghost: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var id := mesh_instance.get_instance_id()
		if ghost:
			if not _entity_normal_cache.has(id):
				_entity_normal_cache[id] = mesh_instance.material_override
			mesh_instance.material_override = _entity_ghost_mat
		else:
			if _entity_normal_cache.has(id):
				mesh_instance.material_override = _entity_normal_cache[id]
				_entity_normal_cache.erase(id)
	for child in node.get_children():
		_set_meshes_ghost_recursive(child, ghost)
