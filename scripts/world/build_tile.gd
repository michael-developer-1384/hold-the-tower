extends Node3D

## Visual / interaction stub for a fixed BuildSpotDefinition.

@export var floor_index: int = 0
@export var spot_id: String = ""
@export var floor_id: String = ""
var occupied: bool = false


func interact() -> void:
	# Stub for future placement UI.
	pass


func set_occupied(value: bool) -> void:
	occupied = value
