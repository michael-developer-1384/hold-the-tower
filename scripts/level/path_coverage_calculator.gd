class_name PathCoverageCalculator
extends RefCounted

## Marks whole path segments covered if closest 3D distance to tower <= range.


static func compute(
	tower_pos: Vector3,
	attack_range: float,
	path: PackedVector3Array,
	segment_floor_ids: PackedStringArray
) -> Dictionary:
	var covered_indices: Array[int] = []
	var coverage_by_floor := {}
	if path.size() < 2:
		return {"covered_indices": covered_indices, "coverage_by_floor": coverage_by_floor}

	var seg_count := path.size() - 1
	for i in seg_count:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var dist := _point_segment_distance(tower_pos, a, b)
		if dist > attack_range:
			continue
		covered_indices.append(i)
		var floor_id := "unknown"
		if i < segment_floor_ids.size():
			floor_id = segment_floor_ids[i]
		var length := a.distance_to(b)
		if not coverage_by_floor.has(floor_id):
			coverage_by_floor[floor_id] = 0.0
		coverage_by_floor[floor_id] = float(coverage_by_floor[floor_id]) + length

	return {"covered_indices": covered_indices, "coverage_by_floor": coverage_by_floor}


static func _point_segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest := a + ab * t
	return p.distance_to(closest)
