class_name EnemyPathBuilder
extends RefCounted

## Builds a linear enemy route: floor path, connector, next floor, ...


static func build(level: Resource) -> PackedVector3Array:
	var path := PackedVector3Array()
	if level == null:
		return path

	var sorted_floors: Array = level.floors.duplicate()
	sorted_floors.sort_custom(func(a, b) -> bool:
		return a.floor_index < b.floor_index
	)

	for i in sorted_floors.size():
		var floor_def = sorted_floors[i]
		_append_unique(path, floor_def.path_points)

		if i >= sorted_floors.size() - 1:
			continue
		var next_floor = sorted_floors[i + 1]
		var connector = _find_connector(level, floor_def.floor_id, next_floor.floor_id)
		if connector == null:
			continue
		_append_unique(path, connector.get_waypoints())

	return path


static func _find_connector(level: Resource, from_id: String, to_id: String) -> Resource:
	for connector in level.connectors:
		if connector.from_floor_id == from_id and connector.to_floor_id == to_id:
			return connector
	return null


static func _append_unique(dest: PackedVector3Array, points: PackedVector3Array) -> void:
	for p in points:
		if dest.is_empty() or not dest[dest.size() - 1].is_equal_approx(p):
			dest.append(p)
