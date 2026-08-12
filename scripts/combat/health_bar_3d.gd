extends Node3D

## World-space HP bar. Parent faces camera; fill stays left-anchored on the background.

var _bg: MeshInstance3D
var _fill_pivot: Node3D
var _fill: MeshInstance3D
var _fill_mesh: BoxMesh
var _visible_forced: bool = false
var _ratio: float = 1.0

const WIDTH := 0.7
const HEIGHT := 0.07
const DEPTH := 0.02


func _ready() -> void:
	_ensure_meshes()
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Match camera orientation so both child meshes share one billboard frame.
	global_transform.basis = cam.global_transform.basis


func _ensure_meshes() -> void:
	if _bg != null and _fill != null and _fill_mesh != null and _fill_pivot != null:
		return

	if _bg == null:
		_bg = MeshInstance3D.new()
		_bg.name = "HpBg"
		var bg_mesh := BoxMesh.new()
		bg_mesh.size = Vector3(WIDTH, HEIGHT, DEPTH)
		_bg.mesh = bg_mesh
		var bg_mat := StandardMaterial3D.new()
		bg_mat.albedo_color = Color(0.1, 0.1, 0.12, 0.85)
		bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		_bg.material_override = bg_mat
		_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_bg)

	if _fill_pivot == null:
		_fill_pivot = Node3D.new()
		_fill_pivot.name = "HpFillPivot"
		# Left edge of the background bar.
		_fill_pivot.position = Vector3(-WIDTH * 0.5, 0.0, 0.001)
		add_child(_fill_pivot)

	if _fill == null:
		_fill = MeshInstance3D.new()
		_fill.name = "HpFill"
		_fill_mesh = BoxMesh.new()
		_fill_mesh.size = Vector3(WIDTH, HEIGHT, DEPTH + 0.002)
		_fill.mesh = _fill_mesh
		var fill_mat := StandardMaterial3D.new()
		fill_mat.albedo_color = Color(0.25, 0.85, 0.35, 1.0)
		fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		_fill.material_override = fill_mat
		_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fill_pivot.add_child(_fill)

	_apply_ratio()


func set_health(current: float, maximum: float, force_show: bool = false) -> void:
	if maximum <= 0.0:
		return
	_ensure_meshes()
	_ratio = clampf(current / maximum, 0.0, 1.0)
	_visible_forced = force_show
	visible = force_show or _ratio < 0.999
	if not visible:
		return
	_apply_ratio()


func _apply_ratio() -> void:
	if _fill == null or _fill_mesh == null:
		return
	var w := WIDTH * maxf(_ratio, 0.001)
	_fill_mesh.size = Vector3(w, HEIGHT, DEPTH + 0.002)
	# Mesh grows from its center; shift so the left edge stays on the pivot.
	_fill.position = Vector3(w * 0.5, 0.0, 0.0)
	var mat := _fill.material_override as StandardMaterial3D
	if mat == null:
		return
	if _ratio > 0.5:
		mat.albedo_color = Color(0.25, 0.85, 0.35, 1.0)
	elif _ratio > 0.25:
		mat.albedo_color = Color(0.95, 0.75, 0.2, 1.0)
	else:
		mat.albedo_color = Color(0.9, 0.25, 0.2, 1.0)
