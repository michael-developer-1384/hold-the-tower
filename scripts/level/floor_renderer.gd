class_name FloorRenderer
extends RefCounted

## Instantiates walkable path meshes + input-only path pickers.


static func render(
	parent: Node3D,
	floor_def: Resource,
	path_mat: StandardMaterial3D,
	include_pickers: bool = true
) -> Array:
	var path_root := Node3D.new()
	path_root.name = "Path"
	parent.add_child(path_root)

	var pickers: Array = []
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

		if include_pickers:
			var picker := _make_path_picker(
				str(plat.id) + "_picker",
				plat.transform,
				plat.size,
				str(floor_def.floor_id),
				int(floor_def.floor_index)
			)
			path_root.add_child(picker)
			pickers.append(picker)

	for p in floor_def.path_points:
		var tile := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.92, 0.06, 0.92)
		tile.mesh = box
		tile.material_override = path_mat
		tile.set_meta("mat_kind", "path")
		tile.position = Vector3(p.x, floor_def.elevation + 0.05, p.z)
		path_root.add_child(tile)

	return pickers


static func _make_path_picker(
	picker_name: String,
	xform: Transform3D,
	size: Vector3,
	floor_id: String,
	floor_index: int
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_script(load("res://scripts/world/path_picker.gd"))
	body.name = picker_name
	body.collision_layer = 8
	body.collision_mask = 0
	body.input_ray_pickable = true
	body.transform = xform
	body.set_meta("floor_id", floor_id)
	body.set_meta("floor_index", floor_index)
	body.set_meta("pick_kind", "path")
	body.add_to_group("path_pickers")

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(size.x, 0.5), maxf(size.y, 0.2), maxf(size.z, 0.5))
	shape.shape = box
	body.add_child(shape)
	return body
