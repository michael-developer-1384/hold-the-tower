class_name RampDefinition
extends Resource

## Shared ramp geometry for visible mesh and enemy path waypoints.

@export var start_position: Vector3 = Vector3.ZERO
@export var end_position: Vector3 = Vector3.ZERO
@export var width: float = 1.0
@export var waypoint_count: int = 6
## Grid cells the ramp occupies, from first step to landing (inclusive).
@export var cells: Array[Vector2i] = []


func get_waypoints() -> PackedVector3Array:
	var points := PackedVector3Array()
	var count: int = maxi(waypoint_count, 2)
	for i in count:
		var t: float = float(i) / float(count - 1)
		points.append(start_position.lerp(end_position, t))
	return points


func horizontal_length() -> float:
	var a := Vector2(start_position.x, start_position.z)
	var b := Vector2(end_position.x, end_position.z)
	return a.distance_to(b)
