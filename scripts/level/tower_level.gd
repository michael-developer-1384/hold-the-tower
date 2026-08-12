extends Node3D

const GRID_SIZE := 9
const TILE_SIZE := 1.0
const FLOOR_GAP := 3.0
const FLOOR_COUNT := 3
const HALF := (GRID_SIZE - 1) * 0.5 * TILE_SIZE # 4.0

const TILE_VOID := 0
const TILE_FLOOR := 1
const TILE_PATH := 2
const TILE_BUILD := 3
const TILE_STAIR := 4

const BUILD_TILE_SCENE := preload("res://scenes/world/build_tile.tscn")
const CORE_SCENE := preload("res://scenes/world/core.tscn")
const TOWER_SCENE := preload("res://scenes/towers/basic_tower.tscn")

var floors: Array[FloorDefinition] = []
var enemy_path: PackedVector3Array = PackedVector3Array()
var build_tile_count: int = 0

var _core: Node3D
var _enemy_container: Node3D
var _floors_root: Node3D
var _floor_nodes: Array[Node3D] = []
var _wall_entries: Array[Dictionary] = []
var _pillar_entries: Array[Dictionary] = []
var _visual: Node

var _path_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _build_mat: StandardMaterial3D
var _stair_mat: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_enemy_container = Node3D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)

	_visual = Node.new()
	_visual.name = "FloorVisualController"
	_visual.set_script(load("res://scripts/level/floor_visual_controller.gd"))
	add_child(_visual)

	_build_floors_data()
	_generate_geometry()
	_build_full_enemy_path()
	_place_core()
	_place_sample_tower()

	var heights := get_floor_heights()
	_visual.setup(
		_floor_nodes,
		heights,
		_wall_entries,
		_pillar_entries,
		{
			"path": _path_mat,
			"floor": _floor_mat,
			"wall": _wall_mat,
			"build": _build_mat,
			"stair": _stair_mat,
		}
	)

	print("Generated %d floors" % floors.size())
	print("Generated enemy path with %d points" % enemy_path.size())
	print("Generated %d build tiles" % build_tile_count)


func get_enemy_path() -> PackedVector3Array:
	return enemy_path


func get_enemy_container() -> Node3D:
	return _enemy_container


func get_core() -> Node3D:
	return _core


func get_floor_count() -> int:
	return floors.size()


func get_floor_heights() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	for floor_def in floors:
		heights.append(floor_def.height)
	return heights


func set_focus_floor(index: int) -> void:
	if _visual and _visual.has_method("set_focus_floor"):
		_visual.call("set_focus_floor", index)


func notify_camera_moved() -> void:
	if _visual and _visual.has_method("notify_camera_moved"):
		_visual.call("notify_camera_moved")


func _create_materials() -> void:
	_path_mat = _make_mat(Color(0.28, 0.28, 0.30))
	_floor_mat = _make_mat(Color(0.42, 0.42, 0.45))
	_wall_mat = _make_mat(Color(0.35, 0.36, 0.40))
	_build_mat = _make_mat(Color(0.62, 0.64, 0.68))
	_stair_mat = _make_mat(Color(0.48, 0.40, 0.32))


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _build_floors_data() -> void:
	floors.clear()
	for i in FLOOR_COUNT:
		var floor_def := FloorDefinition.new()
		floor_def.floor_index = i
		floor_def.height = float(i) * FLOOR_GAP
		floor_def.walls = PackedStringArray(["N", "E", "S", "W"])
		_fill_floor_layout(floor_def, i)
		floors.append(floor_def)


func _fill_floor_layout(floor_def: FloorDefinition, floor_index: int) -> void:
	var local_path: Array[Vector3] = []
	match floor_index % 3:
		0:
			for x in range(GRID_SIZE):
				local_path.append(_tile_pos(x, 0))
			for z in range(1, GRID_SIZE):
				local_path.append(_tile_pos(GRID_SIZE - 1, z))
			for x in range(GRID_SIZE - 2, -1, -1):
				local_path.append(_tile_pos(x, GRID_SIZE - 1))
		1:
			for z in range(GRID_SIZE - 1, -1, -1):
				local_path.append(_tile_pos(0, z))
			for x in range(1, GRID_SIZE):
				local_path.append(_tile_pos(x, 0))
			for z in range(1, GRID_SIZE):
				local_path.append(_tile_pos(GRID_SIZE - 1, z))
		_:
			for x in range(GRID_SIZE - 1, -1, -1):
				local_path.append(_tile_pos(x, GRID_SIZE - 1))
			for z in range(GRID_SIZE - 2, -1, -1):
				local_path.append(_tile_pos(0, z))
			for x in range(1, GRID_SIZE):
				local_path.append(_tile_pos(x, 0))

	var packed := PackedVector3Array()
	for p in local_path:
		packed.append(p)
	floor_def.path_points = packed

	var path_set := {}
	for p in local_path:
		path_set[_key(p)] = true

	var build_set := {}
	var build_positions := PackedVector3Array()
	var neighbor_offsets: Array[Vector3] = [
		Vector3(TILE_SIZE, 0, 0),
		Vector3(-TILE_SIZE, 0, 0),
		Vector3(0, 0, TILE_SIZE),
		Vector3(0, 0, -TILE_SIZE),
	]
	for p in local_path:
		for offset in neighbor_offsets:
			var candidate: Vector3 = p + offset
			if not _in_grid(candidate):
				continue
			if path_set.has(_key(candidate)):
				continue
			if candidate.length_squared() > p.length_squared():
				continue
			var k: String = _key(candidate)
			if build_set.has(k):
				continue
			build_set[k] = true
			build_positions.append(candidate)

	floor_def.build_tile_positions = build_positions
	floor_def.tile_types = _build_tile_map(floor_index, path_set, build_set)


func _build_tile_map(floor_index: int, path_set: Dictionary, build_set: Dictionary) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	tiles.resize(GRID_SIZE * GRID_SIZE)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var idx := z * GRID_SIZE + x
			var pos := _tile_pos(x, z)
			var key := _key(pos)
			var on_edge := x == 0 or z == 0 or x == GRID_SIZE - 1 or z == GRID_SIZE - 1
			if path_set.has(key):
				tiles[idx] = TILE_PATH
			elif build_set.has(key):
				tiles[idx] = TILE_BUILD
			elif floor_index == 0:
				tiles[idx] = TILE_FLOOR
			elif on_edge:
				tiles[idx] = TILE_FLOOR
			else:
				tiles[idx] = TILE_VOID
	# Mark stair support cell at path end for upper floors.
	if floor_index < FLOOR_COUNT - 1:
		# Path end already TILE_PATH; keep as path. Optional STAIR flag unused visually.
		pass
	return tiles


func _tile_pos(gx: int, gz: int) -> Vector3:
	return Vector3((float(gx) - HALF) * TILE_SIZE, 0.0, (float(gz) - HALF) * TILE_SIZE)


func _key(v: Vector3) -> String:
	return "%d,%d" % [roundi(v.x / TILE_SIZE), roundi(v.z / TILE_SIZE)]


func _in_grid(v: Vector3) -> bool:
	var gx := roundi(v.x / TILE_SIZE + HALF)
	var gz := roundi(v.z / TILE_SIZE + HALF)
	return gx >= 0 and gx < GRID_SIZE and gz >= 0 and gz < GRID_SIZE


func _generate_geometry() -> void:
	_floors_root = Node3D.new()
	_floors_root.name = "Floors"
	add_child(_floors_root)
	_floor_nodes.clear()
	_wall_entries.clear()
	_pillar_entries.clear()

	# Full-height vertical structure (independent of floor focus).
	_add_full_height_walls()
	_add_full_height_pillars()

	for floor_def in floors:
		var floor_node := Node3D.new()
		floor_node.name = "Floor_%d" % (floor_def.floor_index + 1)
		floor_node.position.y = floor_def.height
		floor_node.set_meta("floor_index", floor_def.floor_index)
		_floors_root.add_child(floor_node)
		_floor_nodes.append(floor_node)

		# Only horizontal gameplay surfaces live under floor nodes.
		_add_floor_geometry(floor_node, floor_def)
		_add_path_tiles(floor_node, floor_def)
		_add_build_tiles(floor_node, floor_def)
		if floor_def.floor_index < FLOOR_COUNT - 1:
			_add_stairs(floor_node, floor_def)


func _tower_structure_height() -> float:
	return (FLOOR_COUNT - 1) * FLOOR_GAP + 2.2


func _add_full_height_walls() -> void:
	var walls_root := Node3D.new()
	walls_root.name = "StructureWalls"
	add_child(walls_root)
	var wall_height := _tower_structure_height()
	var length := GRID_SIZE * TILE_SIZE + 0.3
	var thickness := 0.18
	var y := wall_height * 0.5
	var edge := HALF + 0.55
	var specs := {
		"N": {"pos": Vector3(0, y, edge), "size": Vector3(length, wall_height, thickness), "normal": Vector3(0, 0, 1)},
		"S": {"pos": Vector3(0, y, -edge), "size": Vector3(length, wall_height, thickness), "normal": Vector3(0, 0, -1)},
		"E": {"pos": Vector3(edge, y, 0), "size": Vector3(thickness, wall_height, length), "normal": Vector3(1, 0, 0)},
		"W": {"pos": Vector3(-edge, y, 0), "size": Vector3(thickness, wall_height, length), "normal": Vector3(-1, 0, 0)},
	}
	for side in specs.keys():
		var spec: Dictionary = specs[side]
		var wall := MeshInstance3D.new()
		wall.name = "Wall_%s" % str(side)
		var box := BoxMesh.new()
		box.size = spec["size"]
		wall.mesh = box
		wall.material_override = _wall_mat
		wall.set_meta("mat_kind", "wall")
		wall.position = spec["pos"]
		walls_root.add_child(wall)
		_wall_entries.append({
			"mesh": wall,
			"normal": spec["normal"],
		})


func _add_full_height_pillars() -> void:
	var pillar_root := Node3D.new()
	pillar_root.name = "StructurePillars"
	add_child(pillar_root)
	var height := _tower_structure_height()
	var extent := HALF + 0.55
	var y := height * 0.5
	for corner in [
		Vector3(extent, y, extent),
		Vector3(-extent, y, extent),
		Vector3(extent, y, -extent),
		Vector3(-extent, y, -extent),
	]:
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, height, 0.35)
		mesh_instance.mesh = box
		mesh_instance.material_override = _wall_mat
		mesh_instance.set_meta("mat_kind", "wall")
		mesh_instance.position = corner
		pillar_root.add_child(mesh_instance)
		# Outward radial direction in XZ for camera-facing cull.
		var outward := Vector3(corner.x, 0.0, corner.z).normalized()
		_pillar_entries.append({
			"mesh": mesh_instance,
			"outward": outward,
		})


func _add_floor_geometry(parent: Node3D, floor_def: FloorDefinition) -> void:
	var deck := Node3D.new()
	deck.name = "Deck"
	parent.add_child(deck)

	if floor_def.floor_index == 0:
		# Closed base plate for floor 1.
		var slab := MeshInstance3D.new()
		slab.name = "Slab"
		var box := BoxMesh.new()
		var size := GRID_SIZE * TILE_SIZE + 0.2
		box.size = Vector3(size, 0.2, size)
		slab.mesh = box
		slab.material_override = _floor_mat
		slab.set_meta("mat_kind", "floor")
		slab.position = Vector3(0.0, -0.1, 0.0)
		deck.add_child(slab)
		return

	# Upper floors: only non-VOID tiles as structural deck (open shaft in center).
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var idx := z * GRID_SIZE + x
			var kind: int = TILE_VOID
			if idx < floor_def.tile_types.size():
				kind = floor_def.tile_types[idx]
			if kind == TILE_VOID:
				continue
			var cell := MeshInstance3D.new()
			var cell_box := BoxMesh.new()
			cell_box.size = Vector3(TILE_SIZE * 0.98, 0.16, TILE_SIZE * 0.98)
			cell.mesh = cell_box
			cell.material_override = _floor_mat
			cell.set_meta("mat_kind", "floor")
			var pos := _tile_pos(x, z)
			cell.position = Vector3(pos.x, -0.08, pos.z)
			deck.add_child(cell)


func _add_path_tiles(parent: Node3D, floor_def: FloorDefinition) -> void:
	var path_root := Node3D.new()
	path_root.name = "Path"
	parent.add_child(path_root)
	for p in floor_def.path_points:
		var tile := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(TILE_SIZE * 0.95, 0.08, TILE_SIZE * 0.95)
		tile.mesh = box
		tile.material_override = _path_mat
		tile.set_meta("mat_kind", "path")
		tile.position = Vector3(p.x, 0.05, p.z)
		path_root.add_child(tile)


func _add_build_tiles(parent: Node3D, floor_def: FloorDefinition) -> void:
	var build_root := Node3D.new()
	build_root.name = "BuildTiles"
	parent.add_child(build_root)
	for p in floor_def.build_tile_positions:
		var tile := BUILD_TILE_SCENE.instantiate() as Node3D
		tile.position = Vector3(p.x, 0.05, p.z)
		tile.set("floor_index", floor_def.floor_index)
		for mesh_instance in _find_meshes(tile):
			mesh_instance.set_meta("mat_kind", "build")
			if mesh_instance.name == "Mesh":
				mesh_instance.material_override = _build_mat
		build_root.add_child(tile)
		build_tile_count += 1


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result


func _add_stairs(parent: Node3D, floor_def: FloorDefinition) -> void:
	if floor_def.path_points.is_empty():
		return
	var start := floor_def.path_points[floor_def.path_points.size() - 1]
	var stairs_root := Node3D.new()
	stairs_root.name = "Stairs"
	parent.add_child(stairs_root)

	var inward := Vector3(-start.x, 0.0, -start.z)
	if inward.length_squared() < 0.001:
		inward = Vector3(TILE_SIZE, 0.0, 0.0)
	inward = inward.normalized()

	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var step := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(TILE_SIZE * 0.85, 0.14, TILE_SIZE * 0.55)
		step.mesh = box
		step.material_override = _stair_mat
		step.set_meta("mat_kind", "stair")
		step.position = Vector3(start.x, 0.08 + t * (FLOOR_GAP - 0.2), start.z)
		step.position += inward * (0.35 * t)
		stairs_root.add_child(step)


func _build_full_enemy_path() -> void:
	enemy_path = PackedVector3Array()
	for i in floors.size():
		var floor_def := floors[i]
		for p in floor_def.path_points:
			enemy_path.append(Vector3(p.x, floor_def.height + 0.35, p.z))

		if i < floors.size() - 1:
			var end := floor_def.path_points[floor_def.path_points.size() - 1]
			var next_def := floors[i + 1]
			var next_start := next_def.path_points[0]
			var inward := Vector3(-end.x, 0.0, -end.z)
			if inward.length_squared() < 0.001:
				inward = Vector3(TILE_SIZE, 0.0, 0.0)
			inward = inward.normalized()
			var steps := 8
			for s in range(1, steps + 1):
				var t := float(s) / float(steps)
				var pos := end.lerp(Vector3(next_start.x, 0.0, next_start.z), t)
				pos += inward * (0.35 * sin(t * PI))
				var y := lerpf(floor_def.height, next_def.height, t) + 0.35
				enemy_path.append(Vector3(pos.x, y, pos.z))


func _place_core() -> void:
	var top := floors[floors.size() - 1]
	if top.path_points.is_empty():
		return
	var end := top.path_points[top.path_points.size() - 1]
	_core = CORE_SCENE.instantiate() as Node3D
	_core.name = "Core"
	_core.position = Vector3(end.x, top.height + 0.7, end.z)
	_core.add_to_group("cores")
	add_child(_core)


func _place_sample_tower() -> void:
	var floor0 := floors[0]
	if floor0.build_tile_positions.is_empty():
		return
	var best := floor0.build_tile_positions[0]
	var mid_path := floor0.path_points[int(floor0.path_points.size() / 2.0)]
	var best_dist := INF
	for p in floor0.build_tile_positions:
		var d := Vector2(p.x, p.z).distance_to(Vector2(mid_path.x, mid_path.z))
		if d < best_dist:
			best_dist = d
			best = p
	var tower := TOWER_SCENE.instantiate() as Node3D
	tower.name = "SampleTower"
	tower.position = Vector3(best.x, floor0.height + 0.1, best.z)
	tower.add_to_group("towers")
	add_child(tower)
