class_name FloorDefinition
extends Resource

## One horizontal gameplay layer with free origin and elevation.

@export var floor_id: String = ""
@export var floor_index: int = 0
@export var elevation: float = 0.0
@export var origin: Vector3 = Vector3.ZERO
@export var focus_point: Vector3 = Vector3.ZERO
@export var path_points: PackedVector3Array = PackedVector3Array()
@export var platforms: Array = []
@export var build_spots: Array = []


func world_focus_point() -> Vector3:
	if focus_point != Vector3.ZERO:
		return focus_point
	return origin + Vector3(0.0, elevation, 0.0)
