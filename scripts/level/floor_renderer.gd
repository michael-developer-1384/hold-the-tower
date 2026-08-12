class_name FloorRenderer
extends RefCounted

## Instantiates walkable path meshes for one floor.


static func render(
	parent: Node3D,
	floor_def: Resource,
	path_mat: StandardMaterial3D
) -> void:
	var path_root := Node3D.new()
	path_root.name = "Path"
	parent.add_child(path_root)

	for plat in floor_def.platforms:
		if not plat.visible:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = plat.id
		var box := BoxMesh.new()
		box.size = plat.size
		mesh_instance.mesh = box
		mesh_instance.transform = plat.transform
		mesh_instance.material_override = path_mat
		mesh_instance.set_meta("mat_kind", "path")
		path_root.add_child(mesh_instance)

	for p in floor_def.path_points:
		var tile := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.92, 0.06, 0.92)
		tile.mesh = box
		tile.material_override = path_mat
		tile.set_meta("mat_kind", "path")
		tile.position = Vector3(p.x, floor_def.elevation + 0.05, p.z)
		path_root.add_child(tile)
