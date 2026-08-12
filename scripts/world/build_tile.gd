extends Node3D

## Clickable build slot for future tower placement.

@export var floor_index: int = 0
@export var grid_position: Vector2i = Vector2i.ZERO
var occupied: bool = false


func interact() -> void:
	# Stub for future placement UI.
	pass


func set_occupied(value: bool) -> void:
	occupied = value
