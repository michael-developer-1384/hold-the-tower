class_name ConnectorRenderer
extends RefCounted

## Renders connectors (currently ramps) from definition path points.


static func render_all(
	parent: Node3D,
	connectors: Array,
	ramp_mat: StandardMaterial3D
) -> void:
	for connector in connectors:
		if connector == null:
			continue
		if not connector.has_method("get_waypoints"):
			continue
		if not ("width" in connector):
			continue
		_render_ramp(parent, connector, ramp_mat)


static func _render_ramp(parent: Node3D, ramp: Resource, ramp_mat: StandardMaterial3D) -> void:
	var waypoints: PackedVector3Array = ramp.call("get_waypoints")
	# Need start + at least one rising point + landing.
	if waypoints.size() < 2:
		return

	var ramp_root := Node3D.new()
	ramp_root.name = str(ramp.get("connector_id"))
	parent.add_child(ramp_root)

	var width: float = float(ramp.get("width"))
	var thickness: float = float(ramp.get("thickness"))

	var start: Vector3 = waypoints[0]
	var end: Vector3 = waypoints[waypoints.size() - 1]
	var delta: Vector3 = end - start
	var flat := Vector3(delta.x, 0.0, delta.z)
	var flat_len: float = flat.length()
	if flat_len < 0.001:
		return
	flat /= flat_len

	# Last waypoint is the upper landing (path-owned) — no plank there.
	var steps: int = maxi(waypoints.size() - 1, 1)
	var rise_per_step: float = delta.y / float(steps)
	var step_xz: float = flat_len / float(steps)
	var seg_len: float = sqrt(step_xz * step_xz + rise_per_step * rise_per_step)

	var slope_dir := Vector3(flat.x * step_xz, rise_per_step, flat.z * step_xz).normalized()
	var right := Vector3(-flat.z, 0.0, flat.x)
	var normal: Vector3 = right.cross(slope_dir).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	right = slope_dir.cross(normal).normalized()
	var basis := Basis(right, normal, slope_dir)

	for i in range(steps):
		var center: Vector3 = waypoints[i]
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, thickness, seg_len * 0.98)
		mesh_instance.mesh = box
		mesh_instance.material_override = ramp_mat
		mesh_instance.set_meta("mat_kind", "ramp")
		mesh_instance.transform = Transform3D(basis, center)
		ramp_root.add_child(mesh_instance)
