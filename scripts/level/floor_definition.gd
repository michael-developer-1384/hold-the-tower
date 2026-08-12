class_name FloorDefinition
extends Resource

## Data definition for one tower floor. Geometry and gameplay are generated from this.

@export var floor_index: int = 0
@export var height: float = 0.0
## Local path points on this floor (x,z tile centers; y usually 0 relative to floor height).
@export var path_points: PackedVector3Array = PackedVector3Array()
## Local build-tile positions (x, 0, z) relative to floor origin / height.
@export var build_tile_positions: PackedVector3Array = PackedVector3Array()
## Wall side ids present on this floor: "N", "E", "S", "W".
@export var walls: PackedStringArray = PackedStringArray(["N", "E", "S", "W"])
