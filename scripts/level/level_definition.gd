class_name LevelDefinition
extends Resource

## Complete level data: floors, connectors, and key gameplay anchors.

@export var level_id: String = ""
@export var floors: Array = []
@export var connectors: Array = []
@export var core_transform: Transform3D = Transform3D.IDENTITY
@export var spawn_transform: Transform3D = Transform3D.IDENTITY


func get_floor_by_id(floor_id: String) -> Resource:
	for floor_def in floors:
		if floor_def.floor_id == floor_id:
			return floor_def
	return null


func get_floor_by_index(index: int) -> Resource:
	for floor_def in floors:
		if floor_def.floor_index == index:
			return floor_def
	return null
