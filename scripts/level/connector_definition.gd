class_name ConnectorDefinition
extends Resource

## Link between two floors. Ramp is the only concrete type for now.

@export var connector_id: String = ""
@export var from_floor_id: String = ""
@export var to_floor_id: String = ""
@export var start_transform: Transform3D = Transform3D.IDENTITY
@export var end_transform: Transform3D = Transform3D.IDENTITY
@export var path_points: PackedVector3Array = PackedVector3Array()


func get_waypoints() -> PackedVector3Array:
	if path_points.size() >= 2:
		return path_points
	var points := PackedVector3Array()
	points.append(start_transform.origin)
	points.append(end_transform.origin)
	return points
