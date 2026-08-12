class_name BuildSpotRenderer
extends RefCounted

## Instantiates build-spot visuals from BuildSpotDefinition transforms.

const BUILD_TILE_SCENE := preload("res://scenes/world/build_tile.tscn")


static func render(
	parent: Node3D,
	floor_def: Resource,
	build_mat: StandardMaterial3D
) -> int:
	var root := Node3D.new()
	root.name = "BuildSpots"
	parent.add_child(root)

	var count := 0
	for spot in floor_def.build_spots:
		var tile := BUILD_TILE_SCENE.instantiate() as Node3D
		tile.name = spot.id
		tile.transform = spot.transform
		tile.set("floor_index", floor_def.floor_index)
		tile.set("spot_id", spot.id)
		tile.set("floor_id", spot.floor_id)
		tile.set("occupied", spot.occupied)
		for mesh_instance in _find_meshes(tile):
			mesh_instance.set_meta("mat_kind", "build")
			if mesh_instance.name == "Mesh":
				mesh_instance.material_override = build_mat
				if mesh_instance.mesh is BoxMesh:
					var box := mesh_instance.mesh as BoxMesh
					box.size = Vector3(spot.size.x * 0.95, 0.06, spot.size.y * 0.95)
		root.add_child(tile)
		count += 1
	return count


static func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result
