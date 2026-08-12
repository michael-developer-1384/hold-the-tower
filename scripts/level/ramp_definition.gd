class_name RampDefinition
extends ConnectorDefinition

## Ramp connector: geometry and enemy waypoints from start/end + path points.

@export var width: float = 0.95
@export var thickness: float = 0.12


func get_waypoints() -> PackedVector3Array:
	if path_points.size() >= 2:
		return path_points
	return super.get_waypoints()
