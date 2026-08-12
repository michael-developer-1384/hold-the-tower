class_name BuildSpotRenderer
extends RefCounted

## Instantiates pickable BuildSpot runtime nodes from definitions.

const BUILD_SPOT_SCENE := preload("res://scenes/world/build_spot.tscn")


static func render(parent: Node3D, floor_def: Resource) -> Array:
	var root := Node3D.new()
	root.name = "BuildSpots"
	parent.add_child(root)

	var spots: Array = []
	for spot_def in floor_def.build_spots:
		var spot := BUILD_SPOT_SCENE.instantiate() as Node3D
		spot.name = str(spot_def.id)
		spot.transform = spot_def.transform
		if spot.has_method("configure"):
			spot.call(
				"configure",
				str(spot_def.id),
				str(spot_def.floor_id),
				int(floor_def.floor_index),
				spot_def.size if spot_def.size else Vector2.ONE
			)
		if spot_def.occupied and spot.has_method("set_occupied"):
			spot.call("set_occupied", true, null)
		root.add_child(spot)
		spots.append(spot)
	return spots
