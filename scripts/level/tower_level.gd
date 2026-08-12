extends Node3D

const GRID_SIZE := 9
const TILE_SIZE := 1.0
const FLOOR_GAP := 3.0
const FLOOR_COUNT := 3
const HALF := (GRID_SIZE - 1) * 0.5 * TILE_SIZE # 4.0
const RAMP_TILES := 4
const PATH_Y_OFFSET := 0.35

const TILE_VOID := 0
const TILE_FLOOR := 1
const TILE_PATH := 2
const TILE_BUILD := 3
const TILE_RAMP := 4

const BUILD_TILE_SCENE := preload("res://scenes/world/build_tile.tscn")
const CORE_SCENE := preload("res://scenes/world/core.tscn")
const TOWER_SCENE := preload("res://scenes/towers/basic_tower.tscn")
const RampDef := preload("res://scripts/level/ramp_definition.gd")

var floors: Array[FloorDefinition] = []
var enemy_path: PackedVector3Array = PackedVector3Array()
var build_tile_count: int = 0

var _core: Node3D
var _enemy_container: Node3D
var _floors_root: Node3D
var _floor_nodes: Array[Node3D] = []
var _visual: Node

var _path_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
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

	_build_floors_data()
	_generate_geometry()
	_build_full_enemy_path()
	_place_core()
	_place_sample_tower()

	_visual.setup(
		_floor_nodes,
		get_floor_heights(),
		{
			"path": _path_mat,
			"floor": _floor_mat,
			"build": _build_mat,
			"ramp": _ramp_mat,
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


func set_non_walkable_hidden(hidden: bool) -> void:
	for node in get_tree().get_nodes_in_group("non_walkable_surfaces"):
		if node is Node3D:
			(node as Node3D).visible = not hidden


func _create_materials() -> void:
	_path_mat = _make_mat(Color(0.28, 0.28, 0.30))
	_floor_mat = _make_mat(Color(0.42, 0.42, 0.45))
	_build_mat = _make_mat(Color(0.62, 0.64, 0.68))
	_ramp_mat = _make_mat(Color(0.55, 0.42, 0.28))


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
		floors.append(floor_def)

	_layout_floor_0(floors[0])
	_layout_floor_1(floors[1], floors[0])
	_layout_floor_2(floors[2], floors[1])

	for floor_def in floors:
		if floor_def.floor_index == 0:
			_finalize_sparse_build_tiles(floor_def)
		else:
			_finalize_build_tiles(floor_def)


func _layout_floor_0(floor_def: FloorDefinition) -> void:
	# Path: south W->E, then east up to z=4. Ramp continues west as next tiles.
	var path_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		path_cells.append(Vector2i(x, 0))
	for z in range(1, 5):
		path_cells.append(Vector2i(GRID_SIZE - 1, z))

	floor_def.path_points = _cells_to_path(path_cells)
	floor_def.tile_types = _make_base_tiles(0)
	_mark_path_cells(floor_def, path_cells)

	var path_end := Vector2i(GRID_SIZE - 1, 4) # (8,4)
	var ramp_dir := Vector2i(-1, 0)
	floor_def.ramp_to_next = _make_ramp_from_path_end(
		floor_def.height, floors[1].height, path_end, ramp_dir
	)
	_mark_ramp_footprint_from_path_end(floor_def, path_end, ramp_dir)


func _layout_floor_1(floor_def: FloorDefinition, _lower: FloorDefinition) -> void:
	floor_def.tile_types = _make_base_tiles(1)

	var land := Vector2i(GRID_SIZE - 1 - RAMP_TILES, 4) # (4,4)
	_mark_arrival_opening(floor_def, Vector2i(-1, 0), land)

	# Path starts on landing tile, then west / north / east.
	var path_cells: Array[Vector2i] = []
	for x in range(land.x, -1, -1):
		path_cells.append(Vector2i(x, 4))
	for z in range(5, GRID_SIZE):
		path_cells.append(Vector2i(0, z))
	for x in range(1, 7):
		path_cells.append(Vector2i(x, GRID_SIZE - 1))

	floor_def.path_points = _cells_to_path(path_cells)
	_mark_path_cells(floor_def, path_cells)

	var path_end := Vector2i(6, GRID_SIZE - 1) # (6,8)
	var ramp_dir := Vector2i(0, -1)
	floor_def.ramp_to_next = _make_ramp_from_path_end(
		floor_def.height, floors[2].height, path_end, ramp_dir
	)
	_mark_ramp_footprint_from_path_end(floor_def, path_end, ramp_dir)


func _layout_floor_2(floor_def: FloorDefinition, _lower: FloorDefinition) -> void:
	floor_def.tile_types = _make_base_tiles(2)
	floor_def.ramp_to_next = null

	var land := Vector2i(6, GRID_SIZE - 1 - RAMP_TILES) # (6,4)
	_mark_arrival_opening(floor_def, Vector2i(0, -1), land)

	# Long way around the rim to the core at SE (8,0).
	var path_cells: Array[Vector2i] = []
	path_cells.append(land) # landing tile
	for x in range(land.x - 1, -1, -1):
		path_cells.append(Vector2i(x, land.y))
	for z in range(land.y + 1, GRID_SIZE):
		path_cells.append(Vector2i(0, z))
	for x in range(1, GRID_SIZE):
		path_cells.append(Vector2i(x, GRID_SIZE - 1))
	for z in range(GRID_SIZE - 2, -1, -1):
		path_cells.append(Vector2i(GRID_SIZE - 1, z))

	floor_def.path_points = _cells_to_path(path_cells)
	_mark_path_cells(floor_def, path_cells)


func _make_base_tiles(floor_index: int) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	tiles.resize(GRID_SIZE * GRID_SIZE)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var idx := z * GRID_SIZE + x
			if floor_index == 0:
				tiles[idx] = TILE_FLOOR
			else:
				var on_edge := x == 0 or z == 0 or x == GRID_SIZE - 1 or z == GRID_SIZE - 1
				tiles[idx] = TILE_FLOOR if on_edge else TILE_VOID
	return tiles


func _cells_to_path(cells: Array[Vector2i]) -> PackedVector3Array:
	var packed := PackedVector3Array()
	for cell in cells:
		packed.append(_tile_pos(cell.x, cell.y))
	return packed


func _mark_path_cells(floor_def: FloorDefinition, cells: Array[Vector2i]) -> void:
	for cell in cells:
		_set_tile(floor_def, cell.x, cell.y, TILE_PATH)


func _mark_ramp_footprint_from_path_end(
	floor_def: FloorDefinition,
	path_end: Vector2i,
	dir: Vector2i,
	tile_count: int = RAMP_TILES
) -> void:
	# Ramp occupies the next N tiles after the last path tile.
	for i in range(1, tile_count + 1):
		var cell := Vector2i(path_end.x + dir.x * i, path_end.y + dir.y * i)
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
			break
		_set_tile(floor_def, cell.x, cell.y, TILE_RAMP)


func _mark_arrival_opening(
	upper: FloorDefinition,
	dir: Vector2i,
	land_cell: Vector2i,
	tile_count: int = RAMP_TILES
) -> void:
	# Void the cells the ramp passes through; landing remains a normal tile for PATH.
	var path_end := Vector2i(land_cell.x - dir.x * tile_count, land_cell.y - dir.y * tile_count)
	for i in range(1, tile_count):
		var cell := Vector2i(path_end.x + dir.x * i, path_end.y + dir.y * i)
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
			continue
		_set_tile(upper, cell.x, cell.y, TILE_VOID)
	_set_tile(upper, land_cell.x, land_cell.y, TILE_FLOOR)


func _make_ramp_from_path_end(
	from_y: float,
	to_y: float,
	path_end: Vector2i,
	dir: Vector2i,
	tile_count: int = RAMP_TILES
) -> Resource:
	# Start on the next tile beside the last path tile; end on the landing tile above.
	var cells: Array[Vector2i] = []
	for i in range(1, tile_count + 1):
		cells.append(Vector2i(path_end.x + dir.x * i, path_end.y + dir.y * i))
	var first_ramp := cells[0]
	var land := cells[cells.size() - 1]
	var ramp = RampDef.new()
	var start := _tile_pos(first_ramp.x, first_ramp.y)
	var end := _tile_pos(land.x, land.y)
	ramp.start_position = Vector3(start.x, from_y + PATH_Y_OFFSET, start.z)
	ramp.end_position = Vector3(end.x, to_y + PATH_Y_OFFSET, end.z)
	ramp.width = TILE_SIZE * 0.95
	ramp.waypoint_count = 6
	ramp.cells = cells
	return ramp


func _finalize_sparse_build_tiles(floor_def: FloorDefinition) -> void:
	# Lower floor: a few hand-picked spots beside the path, not a full strip.
	var spots: Array[Vector2i] = [
		Vector2i(2, 1),
		Vector2i(5, 1),
		Vector2i(7, 2),
		Vector2i(7, 3),
	]
	var build_positions := PackedVector3Array()
	for cell in spots:
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
			continue
		if _get_tile(floor_def, cell.x, cell.y) != TILE_FLOOR:
			continue
		_set_tile(floor_def, cell.x, cell.y, TILE_BUILD)
		build_positions.append(_tile_pos(cell.x, cell.y))
	floor_def.build_tile_positions = build_positions


func _finalize_build_tiles(floor_def: FloorDefinition) -> void:
	var build_positions := PackedVector3Array()
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if _get_tile(floor_def, x, z) != TILE_PATH:
				continue
			for offset in neighbor_offsets:
				var nx: int = x + offset.x
				var nz: int = z + offset.y
				if nx < 0 or nz < 0 or nx >= GRID_SIZE or nz >= GRID_SIZE:
					continue
				var kind := _get_tile(floor_def, nx, nz)
				if kind != TILE_FLOOR:
					continue
				_set_tile(floor_def, nx, nz, TILE_BUILD)
				build_positions.append(_tile_pos(nx, nz))
	# Deduplicate positions.
	var unique := {}
	var deduped := PackedVector3Array()
	for p in build_positions:
		var k := _key(p)
		if unique.has(k):
			continue
		unique[k] = true
		deduped.append(p)
	floor_def.build_tile_positions = deduped


func _set_tile(floor_def: FloorDefinition, x: int, z: int, kind: int) -> void:
	var idx := z * GRID_SIZE + x
	if idx < 0 or idx >= floor_def.tile_types.size():
		return
	floor_def.tile_types[idx] = kind


func _get_tile(floor_def: FloorDefinition, x: int, z: int) -> int:
	var idx := z * GRID_SIZE + x
	if idx < 0 or idx >= floor_def.tile_types.size():
		return TILE_VOID
	return floor_def.tile_types[idx]


func _tile_pos(gx: int, gz: int) -> Vector3:
	return Vector3((float(gx) - HALF) * TILE_SIZE, 0.0, (float(gz) - HALF) * TILE_SIZE)


func _key(v: Vector3) -> String:
	return "%d,%d" % [roundi(v.x / TILE_SIZE), roundi(v.z / TILE_SIZE)]


func _generate_geometry() -> void:
	_floors_root = Node3D.new()
	_floors_root.name = "Floors"
	add_child(_floors_root)
	_floor_nodes.clear()

	for floor_def in floors:
		var floor_node := Node3D.new()
		floor_node.name = "Floor_%d" % (floor_def.floor_index + 1)
		floor_node.position.y = floor_def.height
		floor_node.set_meta("floor_index", floor_def.floor_index)
		_floors_root.add_child(floor_node)
		_floor_nodes.append(floor_node)

		_add_floor_geometry(floor_node, floor_def)
		_add_path_tiles(floor_node, floor_def)
		_add_build_tiles(floor_node, floor_def)
		if floor_def.ramp_to_next != null:
			_add_ramp(floor_node, floor_def.ramp_to_next)


func _add_floor_geometry(parent: Node3D, floor_def: FloorDefinition) -> void:
	var deck := Node3D.new()
	deck.name = "Deck"
	parent.add_child(deck)
	var non_walkable := Node3D.new()
	non_walkable.name = "NonWalkableSurfaces"
	non_walkable.add_to_group("non_walkable_surfaces")
	deck.add_child(non_walkable)

	var thickness := 0.18 if floor_def.floor_index == 0 else 0.16
	var y := -0.1 if floor_def.floor_index == 0 else -0.08

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var kind := _get_tile(floor_def, x, z)
			if kind == TILE_VOID or kind == TILE_RAMP:
				continue
			var cell := MeshInstance3D.new()
			var cell_box := BoxMesh.new()
			cell_box.size = Vector3(TILE_SIZE * 0.98, thickness, TILE_SIZE * 0.98)
			cell.mesh = cell_box
			cell.material_override = _floor_mat
			cell.set_meta("mat_kind", "floor")
			var pos := _tile_pos(x, z)
			cell.position = Vector3(pos.x, y, pos.z)
			# Structural filler can be toggled off; path/build keep a support deck.
			if kind == TILE_FLOOR:
				non_walkable.add_child(cell)
			else:
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


func _add_ramp(parent: Node3D, ramp: Resource) -> void:
	var ramp_root := Node3D.new()
	ramp_root.name = "Ramp"
	parent.add_child(ramp_root)

	var cells: Array = ramp.get("cells")
	if cells == null or cells.is_empty():
		return

	var start_local := Vector3(
		ramp.start_position.x,
		ramp.start_position.y - parent.position.y,
		ramp.start_position.z
	)
	var end_local := Vector3(
		ramp.end_position.x,
		ramp.end_position.y - parent.position.y,
		ramp.end_position.z
	)
	var delta := end_local - start_local
	var flat := Vector3(delta.x, 0.0, delta.z)
	var flat_len := flat.length()
	if flat_len < 0.001:
		return
	flat /= flat_len

	# One plank segment per grid cell — same XZ centers as path tiles.
	var steps: int = maxi(cells.size() - 1, 1)
	var rise_per_step: float = delta.y / float(steps)
	var seg_len: float = sqrt(TILE_SIZE * TILE_SIZE + rise_per_step * rise_per_step)
	var right := Vector3(-flat.z, 0.0, flat.x)
	var slope_dir := Vector3(flat.x * TILE_SIZE, rise_per_step, flat.z * TILE_SIZE).normalized()
	var normal := right.cross(slope_dir).normalized()
	right = slope_dir.cross(normal).normalized()
	var basis := Basis(right, normal, slope_dir)

	# Last cell is the upper-floor landing — path only, no plank mesh there.
	for i in range(cells.size() - 1):
		var cell: Vector2i = cells[i]
		var xz := _tile_pos(cell.x, cell.y)
		var t: float = float(i) / float(steps)
		var center := Vector3(xz.x, lerpf(start_local.y, end_local.y, t), xz.z)
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(ramp.width, 0.12, seg_len * 0.98)
		mesh_instance.mesh = box
		mesh_instance.material_override = _ramp_mat
		mesh_instance.set_meta("mat_kind", "ramp")
		mesh_instance.transform = Transform3D(basis, center)
		ramp_root.add_child(mesh_instance)


func _build_full_enemy_path() -> void:
	enemy_path = PackedVector3Array()
	for i in floors.size():
		var floor_def := floors[i]
		for p in floor_def.path_points:
			enemy_path.append(Vector3(p.x, floor_def.height + PATH_Y_OFFSET, p.z))

		if floor_def.ramp_to_next != null:
			var waypoints: PackedVector3Array = floor_def.ramp_to_next.call("get_waypoints")
			# First waypoint is the next tile beside the last path tile.
			for w in range(waypoints.size()):
				enemy_path.append(waypoints[w])


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
