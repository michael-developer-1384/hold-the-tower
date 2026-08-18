class_name PathExposureCalculator
extends RefCounted

## Exact path length inside a tower range (sphere or floor disc).


static func compute(
	tower_pos: Vector3,
	range_value: float,
	shape: String,
	floor_id: String,
	path: PackedVector3Array,
	segment_floor_ids: PackedStringArray,
	enemy_speed: float = 2.2
) -> Dictionary:
	var empty := _empty()
	if path.size() < 2 or range_value <= 0.0:
		return empty

	var covered_indices: Array[int] = []
	var coverage_by_floor := {}
	var windows: Array = []
	var covered_total := 0.0
	var path_total := 0.0
	var cursor := 0.0
	var entry := -1.0
	var exit_pos := -1.0

	var seg_count := path.size() - 1
	for i in seg_count:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var seg_len := a.distance_to(b)
		path_total += seg_len
		var seg_floor := "unknown"
		if i < segment_floor_ids.size():
			seg_floor = segment_floor_ids[i]
		var skip_floor := shape == "FLOOR_DISC" and floor_id != "" and seg_floor != floor_id
		var hits: Array = []
		if not skip_floor:
			if shape == "FLOOR_DISC":
				hits = segment_disc_xz(a, b, tower_pos, range_value)
			else:
				hits = segment_sphere(a, b, tower_pos, range_value)
		for hit in hits:
			var t0 := float(hit.x)
			var t1 := float(hit.y)
			var length := seg_len * maxf(t1 - t0, 0.0)
			if length <= 0.0000001 and t1 > t0:
				length = 0.0
			if t1 + 0.0000001 < t0:
				continue
			covered_total += length
			if not coverage_by_floor.has(seg_floor):
				coverage_by_floor[seg_floor] = 0.0
			coverage_by_floor[seg_floor] = float(coverage_by_floor[seg_floor]) + length
			var w0 := cursor + seg_len * t0
			var w1 := cursor + seg_len * t1
			if entry < 0.0:
				entry = w0
			exit_pos = w1
			_push_window(windows, w0, w1)
			if covered_indices.is_empty() or covered_indices[covered_indices.size() - 1] != i:
				covered_indices.append(i)
		cursor += seg_len

	var speed := maxf(enemy_speed, 0.0001)
	return {
		"covered_indices": covered_indices,
		"covered_length_total": covered_total,
		"covered_length_by_floor": coverage_by_floor,
		"coverage_by_floor": coverage_by_floor,
		"covered_fraction_of_path": covered_total / maxf(path_total, 0.0001),
		"path_length_total": path_total,
		"windows": windows,
		"entry_position": entry,
		"exit_position": exit_pos,
		"exposure_seconds": covered_total / speed,
		"enemy_speed": speed,
	}


static func exposure_seconds(covered_path_length: float, enemy_speed: float) -> float:
	return covered_path_length / maxf(enemy_speed, 0.0001)


static func segment_sphere(a: Vector3, b: Vector3, center: Vector3, radius: float) -> Array:
	return _segment_ball(a, b, center, radius, false)


static func segment_disc_xz(a: Vector3, b: Vector3, center: Vector3, radius: float) -> Array:
	return _segment_ball(a, b, center, radius, true)


static func _segment_ball(a: Vector3, b: Vector3, center: Vector3, radius: float, xz_only: bool) -> Array:
	var r := maxf(radius, 0.0)
	var av := Vector3(a.x, 0.0, a.z) if xz_only else a
	var bv := Vector3(b.x, 0.0, b.z) if xz_only else b
	var cv := Vector3(center.x, 0.0, center.z) if xz_only else center
	var d := bv - av
	var f := av - cv
	var aa := d.dot(d)
	var rr := r * r
	if aa < 0.0000001:
		if f.length_squared() <= rr + 0.0000001:
			return [Vector2(0.0, 1.0)]
		return []
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - rr
	var disc := bb * bb - 4.0 * aa * cc
	var t0 := 0.0
	var t1 := 1.0
	if disc < -0.0000001:
		if f.length_squared() <= rr and (bv - cv).length_squared() <= rr:
			return [Vector2(0.0, 1.0)]
		return []
	if disc < 0.0:
		disc = 0.0
	var sqrt_d := sqrt(disc)
	var inv := 1.0 / (2.0 * aa)
	t0 = (-bb - sqrt_d) * inv
	t1 = (-bb + sqrt_d) * inv
	if t0 > t1:
		var tmp := t0
		t0 = t1
		t1 = tmp
	if t1 < 0.0 or t0 > 1.0:
		return []
	t0 = clampf(t0, 0.0, 1.0)
	t1 = clampf(t1, 0.0, 1.0)
	if t1 <= t0:
		if minf((av - cv).length_squared(), (bv - cv).length_squared()) <= rr:
			return [Vector2(t0, t1)] if t1 > t0 else []
		return []
	return [Vector2(t0, t1)]


static func _push_window(windows: Array, w0: float, w1: float) -> void:
	if w1 < w0:
		return
	if windows.is_empty():
		windows.append({"t0": w0, "t1": w1})
		return
	var last: Dictionary = windows[windows.size() - 1]
	if w0 <= float(last.get("t1", 0.0)) + 0.0001:
		last["t1"] = maxf(float(last.get("t1", 0.0)), w1)
		windows[windows.size() - 1] = last
	else:
		windows.append({"t0": w0, "t1": w1})


static func _empty() -> Dictionary:
	return {
		"covered_indices": [] as Array[int],
		"covered_length_total": 0.0,
		"covered_length_by_floor": {},
		"coverage_by_floor": {},
		"covered_fraction_of_path": 0.0,
		"path_length_total": 0.0,
		"windows": [],
		"entry_position": -1.0,
		"exit_position": -1.0,
		"exposure_seconds": 0.0,
		"enemy_speed": 0.0,
	}
