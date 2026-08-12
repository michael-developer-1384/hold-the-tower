class_name PathCoverageCalculator
extends RefCounted

## Marks whole path segments covered by sphere (3D) or floor disc (XZ + floor filter).


static func compute(
	tower_pos: Vector3,
	attack_range: float,
	path: PackedVector3Array,
	segment_floor_ids: PackedStringArray
) -> Dictionary:
	return compute_for_tower(
		tower_pos,
		attack_range,
		"SPHERE_3D",
		"",
		path,
		segment_floor_ids
	)


static func compute_for_tower(
	tower_pos: Vector3,
	range_value: float,
	shape: String,
	floor_id: String,
	path: PackedVector3Array,
	segment_floor_ids: PackedStringArray
) -> Dictionary:
	var covered_indices: Array[int] = []
	var coverage_by_floor := {}
	if path.size() < 2:
		return {"covered_indices": covered_indices, "coverage_by_floor": coverage_by_floor}

	var seg_count := path.size() - 1
	for i in seg_count:
		var seg_floor := "unknown"
		if i < segment_floor_ids.size():
			seg_floor = segment_floor_ids[i]
		if shape == "FLOOR_DISC" and floor_id != "" and seg_floor != floor_id:
			continue
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var dist: float
		if shape == "FLOOR_DISC":
			dist = _point_segment_distance_xz(tower_pos, a, b)
		else:
			dist = _point_segment_distance(tower_pos, a, b)
		if dist > range_value:
			continue
		covered_indices.append(i)
		var length := a.distance_to(b)
		if not coverage_by_floor.has(seg_floor):
			coverage_by_floor[seg_floor] = 0.0
		coverage_by_floor[seg_floor] = float(coverage_by_floor[seg_floor]) + length

	return {"covered_indices": covered_indices, "coverage_by_floor": coverage_by_floor}


static func _point_segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest := a + ab * t
	return p.distance_to(closest)


static func _point_segment_distance_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return p2.distance_to(a2)
	var t := clampf((p2 - a2).dot(ab) / len_sq, 0.0, 1.0)
	var closest := a2 + ab * t
	return p2.distance_to(closest)
