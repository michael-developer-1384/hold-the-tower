class_name PathCoverageCalculator
extends RefCounted

## Marks path segments covered by sphere (3D) or floor disc (XZ + floor filter).
## Lengths use exact intersection via PathExposureCalculator.

const ExposureCalc := preload("res://scripts/level/path_exposure_calculator.gd")


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
	var exp: Dictionary = ExposureCalc.compute(
		tower_pos,
		range_value,
		shape,
		floor_id,
		path,
		segment_floor_ids
	)
	return {
		"covered_indices": exp.get("covered_indices", []),
		"coverage_by_floor": exp.get("covered_length_by_floor", {}),
	}
