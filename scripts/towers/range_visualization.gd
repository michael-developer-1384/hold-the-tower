extends Node3D

## Shows selected-tower 3D range sphere + covered path overlays.
## Upgrade hover previews extra coverage in a distinct color.

var _sphere: MeshInstance3D
var _preview_sphere: MeshInstance3D
var _coverage_root: Node3D
var _sphere_mat: StandardMaterial3D
var _preview_mat: StandardMaterial3D
var _cover_mat: StandardMaterial3D
var _cover_preview_mat: StandardMaterial3D
var _active_tower: Node3D = null
var _path: PackedVector3Array = PackedVector3Array()
var _segment_floor_ids: PackedStringArray = PackedStringArray()
var _last_coverage: Dictionary = {}
var _preview_enabled: bool = false
var _preview_range: float = 5.5


func _ready() -> void:
	_sphere_mat = _make_sphere_mat(Color(0.35, 0.75, 1.0, 0.08))
	_preview_mat = _make_sphere_mat(Color(0.95, 0.85, 0.25, 0.06))
	_cover_mat = _make_cover_mat(Color(0.35, 0.95, 0.55, 1.0), Color(0.2, 0.7, 0.35, 1.0), 1.4)
	_cover_preview_mat = _make_cover_mat(Color(0.98, 0.82, 0.28, 1.0), Color(0.95, 0.7, 0.15, 1.0), 1.8)

	_sphere = MeshInstance3D.new()
	_sphere.name = "RangeSphere"
	_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	_sphere.mesh = mesh
	_sphere.material_override = _sphere_mat
	_sphere.visible = false
	add_child(_sphere)

	_preview_sphere = MeshInstance3D.new()
	_preview_sphere.name = "UpgradePreviewSphere"
	_preview_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmesh := SphereMesh.new()
	pmesh.radial_segments = 24
	pmesh.rings = 12
	_preview_sphere.mesh = pmesh
	_preview_sphere.material_override = _preview_mat
	_preview_sphere.visible = false
	add_child(_preview_sphere)

	_coverage_root = Node3D.new()
	_coverage_root.name = "CoverageOverlays"
	add_child(_coverage_root)


func setup_path(path: PackedVector3Array, segment_floor_ids: PackedStringArray) -> void:
	_path = path
	_segment_floor_ids = segment_floor_ids


func get_last_coverage() -> Dictionary:
	return _last_coverage


func show_for_tower(tower: Node3D) -> void:
	_active_tower = tower
	if tower == null or not is_instance_valid(tower):
		hide_all()
		return
	_preview_enabled = false
	_update_visuals()


func set_upgrade_preview(enabled: bool, preview_range: float = 5.5) -> void:
	if _active_tower == null or not is_instance_valid(_active_tower):
		_preview_enabled = false
		_preview_sphere.visible = false
		return
	_preview_enabled = enabled
	_preview_range = preview_range
	if enabled:
		_preview_sphere.visible = true
		_preview_sphere.global_position = _active_tower.global_position + Vector3(0.0, 0.4, 0.0)
		_set_sphere_radius(_preview_sphere, preview_range)
	else:
		_preview_sphere.visible = false
	_draw_coverage_state()


func hide_all() -> void:
	_active_tower = null
	_preview_enabled = false
	_sphere.visible = false
	_preview_sphere.visible = false
	_clear_coverage()
	_last_coverage = {}


func refresh() -> void:
	if _active_tower != null and is_instance_valid(_active_tower):
		_update_visuals()


func _update_visuals() -> void:
	var tower := _active_tower
	var rng: float = float(tower.get("attack_range"))
	_sphere.visible = true
	_sphere.global_position = tower.global_position + Vector3(0.0, 0.4, 0.0)
	_set_sphere_radius(_sphere, rng)
	if _preview_enabled:
		_preview_sphere.visible = true
		_preview_sphere.global_position = tower.global_position + Vector3(0.0, 0.4, 0.0)
		_set_sphere_radius(_preview_sphere, _preview_range)
	else:
		_preview_sphere.visible = false

	var calc = load("res://scripts/level/path_coverage_calculator.gd")
	_last_coverage = calc.compute(tower.global_position, rng, _path, _segment_floor_ids)
	_draw_coverage_state()


func _draw_coverage_state() -> void:
	if _active_tower == null or not is_instance_valid(_active_tower):
		_clear_coverage()
		return
	var calc = load("res://scripts/level/path_coverage_calculator.gd")
	var current_rng: float = float(_active_tower.get("attack_range"))
	var current: Dictionary = calc.compute(
		_active_tower.global_position, current_rng, _path, _segment_floor_ids
	)
	_last_coverage = current
	var current_set := {}
	for i in current.get("covered_indices", []):
		current_set[int(i)] = true

	var preview_only: Array = []
	if _preview_enabled:
		var preview: Dictionary = calc.compute(
			_active_tower.global_position, _preview_range, _path, _segment_floor_ids
		)
		for i in preview.get("covered_indices", []):
			var idx: int = int(i)
			if not current_set.has(idx):
				preview_only.append(idx)

	_clear_coverage()
	_draw_segments(current.get("covered_indices", []), _cover_mat, 0.35, 0.08)
	# Slightly thicker / raised gold segments so the upgrade delta reads clearly.
	_draw_segments(preview_only, _cover_preview_mat, 0.42, 0.12, 0.04)


func _draw_segments(
	indices: Array,
	mat: StandardMaterial3D,
	width: float,
	height: float,
	y_lift: float = 0.0
) -> void:
	for i in indices:
		var idx: int = int(i)
		if idx < 0 or idx + 1 >= _path.size():
			continue
		var a: Vector3 = _path[idx]
		var b: Vector3 = _path[idx + 1]
		var mid := (a + b) * 0.5 + Vector3(0.0, y_lift, 0.0)
		var delta := b - a
		var length := delta.length()
		if length < 0.01:
			continue
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, height, length)
		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var z := delta.normalized()
		var x := Vector3.UP.cross(z)
		if x.length_squared() < 0.001:
			x = Vector3.RIGHT.cross(z)
		x = x.normalized()
		var y := z.cross(x).normalized()
		mesh_instance.global_transform = Transform3D(Basis(x, y, z), mid)
		_coverage_root.add_child(mesh_instance)


func _clear_coverage() -> void:
	for child in _coverage_root.get_children():
		child.queue_free()


func _set_sphere_radius(mesh_instance: MeshInstance3D, radius: float) -> void:
	if mesh_instance.mesh is SphereMesh:
		var sm := mesh_instance.mesh as SphereMesh
		sm.radius = radius
		sm.height = radius * 2.0


func _make_sphere_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	return mat


func _make_cover_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
