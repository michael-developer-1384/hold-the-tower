class_name BuildSpotDefinition
extends Resource

## Fixed tower placement slot. Position is free in 3D (not grid-bound).

@export var id: String = ""
@export var floor_id: String = ""
@export var transform: Transform3D = Transform3D.IDENTITY
@export var size: Vector2 = Vector2.ONE
@export var allowed_types: PackedStringArray = PackedStringArray()
@export var occupied: bool = false
