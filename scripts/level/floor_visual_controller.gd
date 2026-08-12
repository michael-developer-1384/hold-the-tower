extends Node

## Vertical structure stays full-height; only horizontal floor surfaces ghost above focus.
## Walls/pillars cull by camera facing.

const HIDE_DOT := 0.2
const SHOW_DOT := 0.1
const PILLAR_HIDE_DOT := 0.15
const PILLAR_SHOW_DOT := 0.05
const GHOST_ALPHA := 0.08

var focus_floor: int = 0

var _floor_nodes: Array[Node3D] = []
var _floor_heights: PackedFloat32Array = PackedFloat32Array()
var _wall_entries: Array[Dictionary] = []
var _pillar_entries: Array[Dictionary] = []
var _wall_front_state: Dictionary = {}
var _pillar_front_state: Dictionary = {}

var _mats_normal: Dictionary = {}
var _mats_ghost: Dictionary = {}
var _entity_ghost_mat: StandardMaterial3D
var _entity_normal_cache: Dictionary = {}


func setup(
	floor_nodes: Array[Node3D],
	floor_heights: PackedFloat32Array,
	wall_entries: Array[Dictionary],
	pillar_entries: Array[Dictionary],
	base_materials: Dictionary
) -> void:
	_floor_nodes = floor_nodes
	_floor_heights = floor_heights
	_wall_entries = wall_entries
	_pillar_entries = pillar_entries
	_mats_normal.clear()
	_mats_ghost.clear()
	for key in base_materials.keys():
		var base: StandardMaterial3D = base_materials[key]
		_mats_normal[key] = base
		_mats_ghost[key] = _make_ghost(base)
	_entity_ghost_mat = _make_ghost_color(Color(0.85, 0.85, 0.9))
	set_focus_floor(focus_floor)
	_update_structure_culling()


func set_focus_floor(index: int) -> void:
	focus_floor = index
	_apply_horizontal_floor_modes()
	_update_entity_visuals()
	_update_structure_culling()


func notify_camera_moved() -> void:
	_update_structure_culling()


func _process(_delta: float) -> void:
	_update_structure_culling()
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
		# Floor roots stay visible; only materials become ghost above focus.
		floor_node.visible = true
		var ghost := _is_ghost_floor(i)
		_apply_mode_to_node(floor_node, ghost)


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


func _update_structure_culling() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var cam_pos := camera.global_position
	_update_walls(cam_pos)
	_update_pillars(cam_pos)


func _update_walls(cam_pos: Vector3) -> void:
	for entry in _wall_entries:
		var wall: MeshInstance3D = entry.get("mesh")
		if not is_instance_valid(wall):
			continue
		var normal: Vector3 = entry.get("normal", Vector3.FORWARD)
		var to_cam := cam_pos - wall.global_position
		if to_cam.length_squared() < 0.0001:
			continue
		var dot := normal.dot(to_cam.normalized())
		var id := wall.get_instance_id()
		var was_front: bool = bool(_wall_front_state.get(id, false))
		var is_front := was_front
		if was_front:
			if dot < SHOW_DOT:
				is_front = false
		else:
			if dot > HIDE_DOT:
				is_front = true
		_wall_front_state[id] = is_front
		wall.visible = not is_front
		if _mats_normal.has("wall"):
			wall.material_override = _mats_normal["wall"]


func _update_pillars(cam_pos: Vector3) -> void:
	# Hide pillars on the camera-facing corners (same idea as front walls).
	var flat_cam := Vector3(cam_pos.x, 0.0, cam_pos.z)
	if flat_cam.length_squared() < 0.0001:
		return
	flat_cam = flat_cam.normalized()
	for entry in _pillar_entries:
		var pillar: MeshInstance3D = entry.get("mesh")
		if not is_instance_valid(pillar):
			continue
		var outward: Vector3 = entry.get("outward", Vector3.FORWARD)
		var dot := outward.dot(flat_cam)
		var id := pillar.get_instance_id()
		var was_front: bool = bool(_pillar_front_state.get(id, false))
		var is_front := was_front
		if was_front:
			if dot < PILLAR_SHOW_DOT:
				is_front = false
		else:
			if dot > PILLAR_HIDE_DOT:
				is_front = true
		_pillar_front_state[id] = is_front
		pillar.visible = not is_front
		if _mats_normal.has("wall"):
			pillar.material_override = _mats_normal["wall"]
