class_name PlatformDefinition
extends Resource

## Explicit walkable platform patch. Absence = empty space.

@export var id: String = ""
@export var transform: Transform3D = Transform3D.IDENTITY
@export var size: Vector3 = Vector3.ONE
@export var walkable: bool = true
@export var visible: bool = true
