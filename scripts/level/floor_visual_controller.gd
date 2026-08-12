extends Node

## Floor visuals: normal at/below focus; hover / hover-ghost above focus.
## Ghost floors keep casting shadows via SHADOWS_ONLY proxies.

const GHOST_ALPHA := 0.08
const HOVER_GHOST_ALPHA := 0.30
const HOVER_BOOST := 0.18
const SHADOW_PROXY_META := "shadow_proxy"

var focus_floor: int = 0
var hover_floor: int = -1

var _floor_nodes: Array[Node3D] = []
var _floor_heights: PackedFloat32Array = PackedFloat32Array()
var _mats_normal: Dictionary = {}
var _mats_ghost: Dictionary = {}
var _mats_hover: Dictionary = {}
var _mats_hover_ghost: Dictionary = {}
var _entity_ghost_mat: StandardMaterial3D
var _entity_hover_ghost_mat: StandardMaterial3D
var _entity_normal_cache: Dictionary = {}
var _entity_shadow_cache: Dictionary = {}
var _entity_mode_cache: Dictionary = {}


static func mode_for_floor_indices(floor_index: int, focus: int, hover: int) -> String:
	if floor_index == hover and floor_index != focus:
		if floor_index > focus:
			return "hover_ghost"
		return "hover"
	if floor_index > focus:
		return "ghost"
	return "normal"


func setup(
	floor_nodes: Array[Node3D],
	floor_heights: PackedFloat32Array,
	base_materials: Dictionary
) -> void:
	_floor_nodes = floor_nodes
	_floor_heights = floor_heights
	_mats_normal.clear()
	_mats_ghost.clear()
	_mats_hover.clear()
	_mats_hover_ghost.clear()
	for key in base_materials.keys():
		var base: StandardMaterial3D = base_materials[key]
		_mats_normal[key] = base
		_mats_ghost[key] = _make_ghost(base, GHOST_ALPHA, false)
		_mats_hover[key] = _make_tinted(base, 1.0, HOVER_BOOST)
		_mats_hover_ghost[key] = _make_ghost(base, HOVER_GHOST_ALPHA, true)
	_entity_ghost_mat = _make_ghost_color(Color(0.85, 0.85, 0.9), GHOST_ALPHA, false)
	_entity_hover_ghost_mat = _make_ghost_color(Color(0.95, 0.96, 1.0), HOVER_GHOST_ALPHA, true)
	_refresh_floors()


func set_focus_floor(index: int) -> void:
	focus_floor = index
	_refresh_floors()
	_update_entity_visuals()


func set_hover_floor(index: int) -> void:
	if hover_floor == index:
		return
	hover_floor = index
	_refresh_floors()
	_update_entity_visuals()


func _process(_delta: float) -> void:
	_update_entity_visuals()


func _refresh_floors() -> void:
	for i in _floor_nodes.size():
		var floor_node := _floor_nodes[i]
		if not is_instance_valid(floor_node):
			continue
		floor_node.visible = true
		_apply_mode_to_node(floor_node, _mode_for_floor(i))


func _mode_for_floor(floor_index: int) -> String:
	return mode_for_floor_indices(floor_index, focus_floor, hover_floor)


func _apply_mode_to_node(node: Node, mode: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.has_meta(SHADOW_PROXY_META) and bool(mesh_instance.get_meta(SHADOW_PROXY_META)):
			return
		var kind := str(mesh_instance.get_meta("mat_kind", "floor"))
		match mode:
			"ghost":
				if _mats_ghost.has(kind):
					mesh_instance.material_override = _mats_ghost[kind]
				_set_ghost_shadows(mesh_instance, true, kind)
			"hover_ghost":
				if _mats_hover_ghost.has(kind):
					mesh_instance.material_override = _mats_hover_ghost[kind]
				_set_ghost_shadows(mesh_instance, true, kind)
			"hover":
				if _mats_hover.has(kind):
					mesh_instance.material_override = _mats_hover[kind]
				_set_ghost_shadows(mesh_instance, false, kind)
			_:
				if _mats_normal.has(kind):
					mesh_instance.material_override = _mats_normal[kind]
				_set_ghost_shadows(mesh_instance, false, kind)
	for child in node.get_children():
		_apply_mode_to_node(child, mode)


func _set_ghost_shadows(mesh_instance: MeshInstance3D, ghost: bool, kind: String) -> void:
	var proxy := mesh_instance.get_node_or_null("ShadowProxy") as MeshInstance3D
	if ghost:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if proxy == null:
			proxy = MeshInstance3D.new()
			proxy.name = "ShadowProxy"
			proxy.set_meta(SHADOW_PROXY_META, true)
			proxy.mesh = mesh_instance.mesh
			proxy.transform = Transform3D.IDENTITY
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.material_override = _mats_normal.get(kind, mesh_instance.material_override)
			mesh_instance.add_child(proxy)
		else:
			proxy.mesh = mesh_instance.mesh
			proxy.material_override = _mats_normal.get(kind, mesh_instance.material_override)
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.visible = true
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if proxy != null:
			proxy.visible = false
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_tinted(base: StandardMaterial3D, mul: float, boost: float) -> StandardMaterial3D:
	var mat := base.duplicate() as StandardMaterial3D
	var c := mat.albedo_color
	c.r = clampf(c.r * mul + boost, 0.0, 1.0)
	c.g = clampf(c.g * mul + boost, 0.0, 1.0)
	c.b = clampf(c.b * mul + boost, 0.0, 1.0)
	mat.albedo_color = c
	return mat


func _make_ghost(base: StandardMaterial3D, alpha: float, bright: bool) -> StandardMaterial3D:
	var ghost := base.duplicate() as StandardMaterial3D
	var c := ghost.albedo_color
	var mix := 0.55 if bright else 0.45
	c = c.lerp(Color(0.92, 0.94, 0.98), mix)
	if bright:
		c.r = clampf(c.r + 0.08, 0.0, 1.0)
		c.g = clampf(c.g + 0.08, 0.0, 1.0)
		c.b = clampf(c.b + 0.1, 0.0, 1.0)
	c.a = alpha
	ghost.albedo_color = c
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.roughness = 1.0
	ghost.metallic = 0.0
	ghost.disable_receive_shadows = false
	if bright:
		ghost.emission_enabled = true
		ghost.emission = Color(0.55, 0.65, 0.85)
		ghost.emission_energy_multiplier = 0.35
	return ghost


func _make_ghost_color(color: Color, alpha: float, bright: bool) -> StandardMaterial3D:
	var ghost := StandardMaterial3D.new()
	color.a = alpha
	ghost.albedo_color = color
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.roughness = 1.0
	ghost.disable_receive_shadows = false
	if bright:
		ghost.emission_enabled = true
		ghost.emission = Color(0.6, 0.7, 0.95)
		ghost.emission_energy_multiplier = 0.45
	return ghost


func _update_entity_visuals() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if node is Node3D:
			var enemy := node as Node3D
			enemy.visible = true
			_set_entity_mode(enemy, _entity_mode_for(enemy))
	for node in tree.get_nodes_in_group("towers"):
		if node is Node3D:
			var tower := node as Node3D
			tower.visible = true
			_set_entity_mode(tower, _entity_mode_for(tower))
	for node in tree.get_nodes_in_group("cores"):
		if node is Node3D:
			var core := node as Node3D
			core.visible = true
			_set_entity_mode(core, _entity_mode_for(core))


func _entity_mode_for(node: Node3D) -> String:
	var fi := _entity_floor_index(node)
	return mode_for_floor_indices(fi, focus_floor, hover_floor)


func _entity_floor_index(node: Node3D) -> int:
	if node.has_meta("floor_index"):
		return int(node.get_meta("floor_index"))
	if "floor_index" in node:
		return int(node.get("floor_index"))
	return _floor_index_for_y(node.global_position.y)


func _floor_index_for_y(y: float) -> int:
	if _floor_heights.is_empty():
		return 0
	var best: int = 0
	for i in range(1, _floor_heights.size()):
		var mid: float = (_floor_heights[i - 1] + _floor_heights[i]) * 0.5
		if y >= mid:
			best = i
	return best


func _set_entity_mode(root: Node3D, mode: String) -> void:
	_set_meshes_mode_recursive(root, mode)


func _set_meshes_mode_recursive(node: Node, mode: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.name == "ShadowProxy" or (
			mesh_instance.has_meta(SHADOW_PROXY_META) and bool(mesh_instance.get_meta(SHADOW_PROXY_META))
		):
			return
		var id := mesh_instance.get_instance_id()
		var prev: String = str(_entity_mode_cache.get(id, "normal"))
		if mode == "ghost" or mode == "hover_ghost":
			if not _entity_normal_cache.has(id):
				_entity_normal_cache[id] = mesh_instance.material_override
			if not _entity_shadow_cache.has(id):
				_entity_shadow_cache[id] = mesh_instance.cast_shadow
			mesh_instance.material_override = (
				_entity_hover_ghost_mat if mode == "hover_ghost" else _entity_ghost_mat
			)
			_ensure_entity_shadow_proxy(mesh_instance)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_entity_mode_cache[id] = mode
		elif prev != "normal" or _entity_normal_cache.has(id):
			_restore_entity_mesh(mesh_instance)
	for child in node.get_children():
		_set_meshes_mode_recursive(child, mode)


func _restore_entity_mesh(mesh_instance: MeshInstance3D) -> void:
	var id := mesh_instance.get_instance_id()
	if _entity_normal_cache.has(id):
		mesh_instance.material_override = _entity_normal_cache[id]
		_entity_normal_cache.erase(id)
	if _entity_shadow_cache.has(id):
		mesh_instance.cast_shadow = _entity_shadow_cache[id]
		_entity_shadow_cache.erase(id)
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var proxy := mesh_instance.get_node_or_null("ShadowProxy") as MeshInstance3D
	if proxy != null:
		proxy.visible = false
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_entity_mode_cache.erase(id)


func _ensure_entity_shadow_proxy(mesh_instance: MeshInstance3D) -> void:
	var proxy := mesh_instance.get_node_or_null("ShadowProxy") as MeshInstance3D
	var opaque: Material = null
	var id := mesh_instance.get_instance_id()
	if _entity_normal_cache.has(id):
		opaque = _entity_normal_cache[id]
	if proxy == null:
		proxy = MeshInstance3D.new()
		proxy.name = "ShadowProxy"
		proxy.set_meta(SHADOW_PROXY_META, true)
		proxy.mesh = mesh_instance.mesh
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.material_override = opaque
		mesh_instance.add_child(proxy)
	else:
		proxy.mesh = mesh_instance.mesh
		proxy.material_override = opaque
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.visible = true
