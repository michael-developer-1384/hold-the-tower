class_name TestLevelFactory
extends RefCounted

## Builds the current prototype level as a LevelDefinition (no runtime side effects).

const PATH_Y := 0.35
const ELEV_1 := 0.0
const ELEV_2 := 3.0
const ELEV_3 := 6.0

const LevelDef := preload("res://scripts/level/level_definition.gd")
const FloorDef := preload("res://scripts/level/floor_definition.gd")
const PlatformDef := preload("res://scripts/level/platform_definition.gd")
const BuildSpotDef := preload("res://scripts/level/build_spot_definition.gd")
const RampDef := preload("res://scripts/level/ramp_definition.gd")


static func create_level() -> Resource:
	var level = LevelDef.new()
	level.level_id = "test_vertical_platforms"

	var floor_1 = _create_floor_1()
	var floor_2 = _create_floor_2()
	var floor_3 = _create_floor_3()
	level.floors.append(floor_1)
	level.floors.append(floor_2)
	level.floors.append(floor_3)

	level.connectors.append(_create_ramp_1_2())
	level.connectors.append(_create_ramp_2_3())

	var spawn: Vector3 = floor_1.path_points[0]
	level.spawn_transform = Transform3D(Basis.IDENTITY, spawn)
	var core_pos: Vector3 = floor_3.path_points[floor_3.path_points.size() - 1]
	level.core_transform = Transform3D(Basis.IDENTITY, core_pos + Vector3(0.0, 0.35, 0.0))
	return level


static func _create_floor_1() -> Resource:
	var floor_def = FloorDef.new()
	floor_def.floor_id = "floor_1"
	floor_def.floor_index = 0
	floor_def.elevation = ELEV_1
	floor_def.origin = Vector3.ZERO
	floor_def.focus_point = Vector3(0.0, ELEV_1, 0.0)

	# South row W->E, then east edge north to ramp approach at (4, 0).
	var path := PackedVector3Array()
	for x in range(-4, 5):
		path.append(_wp(x, -4, ELEV_1))
	for z in range(-3, 1):
		path.append(_wp(4, z, ELEV_1))
	floor_def.path_points = path

	floor_def.platforms.append(_plat("f1_path_south", Vector3(0, ELEV_1 - 0.1, -4), Vector3(9.0, 0.18, 1.0)))
	floor_def.platforms.append(_plat("f1_path_east", Vector3(4, ELEV_1 - 0.1, -1.5), Vector3(1.0, 0.18, 4.0)))

	# 5 spots, both sides of the south + east path.
	floor_def.build_spots.append(_spot("F1_A", "floor_1", Vector3(-3, ELEV_1 + 0.05, -3))) # north of south path
	floor_def.build_spots.append(_spot("F1_B", "floor_1", Vector3(-1, ELEV_1 + 0.05, -5))) # south of south path
	floor_def.build_spots.append(_spot("F1_C", "floor_1", Vector3(1, ELEV_1 + 0.05, -3))) # north of south path
	floor_def.build_spots.append(_spot("F1_D", "floor_1", Vector3(2, ELEV_1 + 0.05, -5))) # south of south path
	floor_def.build_spots.append(_spot("F1_E", "floor_1", Vector3(5, ELEV_1 + 0.05, -2))) # east of east path
	return floor_def


static func _create_floor_2() -> Resource:
	var floor_def = FloorDef.new()
	floor_def.floor_id = "floor_2"
	floor_def.floor_index = 1
	floor_def.elevation = ELEV_2
	floor_def.origin = Vector3(0.0, ELEV_2, 0.0)
	floor_def.focus_point = Vector3(0.0, ELEV_2, 0.0)

	# Landing (0,0), west, north, east to ramp approach (2, 4).
	var path := PackedVector3Array()
	for x in range(0, -5, -1):
		path.append(_wp(x, 0, ELEV_2))
	for z in range(1, 5):
		path.append(_wp(-4, z, ELEV_2))
	for x in range(-3, 3):
		path.append(_wp(x, 4, ELEV_2))
	floor_def.path_points = path

	floor_def.platforms.append(_plat("f2_landing", Vector3(0, ELEV_2 - 0.08, 0), Vector3(1.2, 0.16, 1.2)))
	floor_def.platforms.append(_plat("f2_west", Vector3(-2, ELEV_2 - 0.08, 0), Vector3(5.0, 0.16, 1.0)))
	floor_def.platforms.append(_plat("f2_north", Vector3(-4, ELEV_2 - 0.08, 2.5), Vector3(1.0, 0.16, 4.0)))
	floor_def.platforms.append(_plat("f2_east_walk", Vector3(-0.5, ELEV_2 - 0.08, 4), Vector3(6.0, 0.16, 1.0)))

	# 5 spots, both sides along west / north / east walkways.
	floor_def.build_spots.append(_spot("F2_A", "floor_2", Vector3(-1, ELEV_2 + 0.05, 1))) # north of west path
	floor_def.build_spots.append(_spot("F2_B", "floor_2", Vector3(-2, ELEV_2 + 0.05, -1))) # south of west path
	floor_def.build_spots.append(_spot("F2_C", "floor_2", Vector3(-5, ELEV_2 + 0.05, 2))) # west of north path
	floor_def.build_spots.append(_spot("F2_D", "floor_2", Vector3(-3, ELEV_2 + 0.05, 3))) # east of north path
	floor_def.build_spots.append(_spot("F2_E", "floor_2", Vector3(0, ELEV_2 + 0.05, 5))) # north of east path
	return floor_def


static func _create_floor_3() -> Resource:
	var floor_def = FloorDef.new()
	floor_def.floor_id = "floor_3"
	floor_def.floor_index = 2
	floor_def.elevation = ELEV_3
	floor_def.origin = Vector3(0.0, ELEV_3, 0.0)
	floor_def.focus_point = Vector3(0.0, ELEV_3, 0.0)

	# Landing (2,0), then rim to SE core (4, -4).
	var path := PackedVector3Array()
	path.append(_wp(2, 0, ELEV_3))
	for x in range(1, -5, -1):
		path.append(_wp(x, 0, ELEV_3))
	for z in range(1, 5):
		path.append(_wp(-4, z, ELEV_3))
	for x in range(-3, 5):
		path.append(_wp(x, 4, ELEV_3))
	for z in range(3, -5, -1):
		path.append(_wp(4, z, ELEV_3))
	floor_def.path_points = path

	floor_def.platforms.append(_plat("f3_landing", Vector3(2, ELEV_3 - 0.08, 0), Vector3(1.2, 0.16, 1.2)))
	floor_def.platforms.append(_plat("f3_south_walk", Vector3(-1, ELEV_3 - 0.08, 0), Vector3(7.0, 0.16, 1.0)))
	floor_def.platforms.append(_plat("f3_west", Vector3(-4, ELEV_3 - 0.08, 2), Vector3(1.0, 0.16, 5.0)))
	floor_def.platforms.append(_plat("f3_north", Vector3(0, ELEV_3 - 0.08, 4), Vector3(9.0, 0.16, 1.0)))
	floor_def.platforms.append(_plat("f3_east", Vector3(4, ELEV_3 - 0.08, 0), Vector3(1.0, 0.16, 9.0)))

	# 5 spots, both sides of the rim path.
	floor_def.build_spots.append(_spot("F3_A", "floor_3", Vector3(-1, ELEV_3 + 0.05, 1))) # north of south path
	floor_def.build_spots.append(_spot("F3_B", "floor_3", Vector3(-2, ELEV_3 + 0.05, -1))) # south of south path
	floor_def.build_spots.append(_spot("F3_C", "floor_3", Vector3(-5, ELEV_3 + 0.05, 2))) # west of west path
	floor_def.build_spots.append(_spot("F3_D", "floor_3", Vector3(1, ELEV_3 + 0.05, 3))) # south of north path
	floor_def.build_spots.append(_spot("F3_E", "floor_3", Vector3(5, ELEV_3 + 0.05, 0))) # east of east path
	return floor_def


static func _create_ramp_1_2() -> Resource:
	# Westbound from east approach: rising cells (3,0)(2,0)(1,0), landing (0,0) path-owned.
	var ramp = RampDef.new()
	ramp.connector_id = "ramp_1_2"
	ramp.from_floor_id = "floor_1"
	ramp.to_floor_id = "floor_2"
	ramp.width = 0.95
	ramp.thickness = 0.12
	var pts := _ramp_points(
		Vector3(3, ELEV_1, 0),
		Vector3(0, ELEV_2, 0),
		3
	)
	ramp.start_transform = Transform3D(Basis.IDENTITY, pts[0])
	ramp.end_transform = Transform3D(Basis.IDENTITY, pts[pts.size() - 1])
	ramp.path_points = pts
	return ramp


static func _create_ramp_2_3() -> Resource:
	# Southbound from north rim: rising cells (2,3)(2,2)(2,1), landing (2,0) path-owned.
	var ramp = RampDef.new()
	ramp.connector_id = "ramp_2_3"
	ramp.from_floor_id = "floor_2"
	ramp.to_floor_id = "floor_3"
	ramp.width = 0.95
	ramp.thickness = 0.12
	var pts := _ramp_points(
		Vector3(2, ELEV_2, 3),
		Vector3(2, ELEV_3, 0),
		3
	)
	ramp.start_transform = Transform3D(Basis.IDENTITY, pts[0])
	ramp.end_transform = Transform3D(Basis.IDENTITY, pts[pts.size() - 1])
	ramp.path_points = pts
	return ramp


## Build evenly spaced ramp waypoints including landing. Mesh skips the last point.
static func _ramp_points(start_xz_elev: Vector3, end_xz_elev: Vector3, rising_steps: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var total := rising_steps + 1 # rising planks + landing
	for i in range(total):
		var t: float = float(i) / float(rising_steps)
		var p := start_xz_elev.lerp(end_xz_elev, t)
		pts.append(Vector3(p.x, p.y + PATH_Y, p.z))
	return pts


static func _wp(x: float, z: float, elev: float) -> Vector3:
	return Vector3(x, elev + PATH_Y, z)


static func _plat(id: String, center: Vector3, size: Vector3) -> Resource:
	var plat = PlatformDef.new()
	plat.id = id
	plat.transform = Transform3D(Basis.IDENTITY, center)
	plat.size = size
	plat.walkable = true
	plat.visible = true
	return plat


static func _spot(id: String, floor_id: String, pos: Vector3) -> Resource:
	var spot = BuildSpotDef.new()
	spot.id = id
	spot.floor_id = floor_id
	spot.transform = Transform3D(Basis.IDENTITY, pos)
	spot.size = Vector2(1.0, 1.0)
	spot.allowed_types = PackedStringArray(["basic"])
	spot.occupied = false
	return spot
