class_name EnemyPathBuilder
extends RefCounted

## Builds enemy route + per-waypoint / per-segment floor ownership.


static func build(level: Resource) -> PackedVector3Array:
	return build_with_meta(level)["path"]


static func build_with_meta(level: Resource) -> Dictionary:
	var path := PackedVector3Array()
	var waypoint_floors := PackedStringArray()
	if level == null:
		return {
			"path": path,
			"waypoint_floors": waypoint_floors,
			"segment_floors": PackedStringArray(),
		}

	var sorted_floors: Array = level.floors.duplicate()
	sorted_floors.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)

	for i in sorted_floors.size():
		var floor_def = sorted_floors[i]
		_append_unique(path, waypoint_floors, floor_def.path_points, str(floor_def.floor_id))

		if i >= sorted_floors.size() - 1:
			continue
		var next_floor = sorted_floors[i + 1]
		var connector = _find_connector(level, floor_def.floor_id, next_floor.floor_id)
		if connector == null:
			continue
		# Connector owned by from-floor until last (landing) tagged as to-floor.
		var wps: PackedVector3Array = connector.get_waypoints()
		for wi in wps.size():
			var fid := str(floor_def.floor_id)
			if wi == wps.size() - 1:
				fid = str(next_floor.floor_id)
			_append_one(path, waypoint_floors, wps[wi], fid)

	var segment_floors := PackedStringArray()
	for si in range(maxi(path.size() - 1, 0)):
		segment_floors.append(waypoint_floors[si] if si < waypoint_floors.size() else "unknown")

	return {
		"path": path,
		"waypoint_floors": waypoint_floors,
		"segment_floors": segment_floors,
	}


static func _find_connector(level: Resource, from_id: String, to_id: String) -> Resource:
	for connector in level.connectors:
		if connector.from_floor_id == from_id and connector.to_floor_id == to_id:
			return connector
	return null


static func _append_unique(
	dest: PackedVector3Array,
	floors: PackedStringArray,
	points: PackedVector3Array,
	floor_id: String
) -> void:
	for p in points:
		_append_one(dest, floors, p, floor_id)


static func _append_one(
	dest: PackedVector3Array,
	floors: PackedStringArray,
	p: Vector3,
	floor_id: String
) -> void:
	if dest.is_empty() or not dest[dest.size() - 1].is_equal_approx(p):
		dest.append(p)
		floors.append(floor_id)
