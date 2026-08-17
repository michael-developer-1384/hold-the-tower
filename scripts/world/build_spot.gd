@tool
extends StaticBody3D

## Runtime build spot: pickable marker backed by BuildSpotDefinition data.

signal spot_clicked(spot: Node)
signal spot_hovered(spot: Node, hovered: bool)

@export var floor_index: int = 0
@export var spot_id: String = ""
@export var floor_id: String = ""

var occupied: bool = false
var tower_instance: Node3D = null
var selected: bool = false

var _hovering: bool = false
var _interactive: bool = true
var _marker: MeshInstance3D
var _collision: CollisionShape3D
var _mat: StandardMaterial3D
var _base_y: float = 0.02


func _ready() -> void:
	_ensure_visuals()
	_apply_visual_state()
	if Engine.is_editor_hint():
		return
	add_to_group("build_spots")
	collision_layer = 2
	collision_mask = 0
	input_ray_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_strip_generated_visuals()


func configure(p_spot_id: String, p_floor_id: String, p_floor_index: int, size: Vector2) -> void:
	spot_id = p_spot_id
	floor_id = p_floor_id
	floor_index = p_floor_index
	_ensure_visuals()
	if _marker and _marker.mesh is BoxMesh:
		(_marker.mesh as BoxMesh).size = Vector3(size.x * 0.85, 0.04, size.y * 0.85)
	if _collision and _collision.shape is BoxShape3D:
		(_collision.shape as BoxShape3D).size = Vector3(size.x * 0.9, 0.12, size.y * 0.9)
	_apply_visual_state()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	input_ray_pickable = enabled and not occupied
	if _collision:
		_collision.disabled = not enabled
	if not enabled:
		_hovering = false
		if selected:
			set_selected(false)
	_apply_visual_state()


func set_selected(value: bool) -> void:
	selected = value
	_apply_visual_state()


func set_occupied(value: bool, tower: Node3D = null) -> void:
	occupied = value
	tower_instance = tower
	if occupied:
		selected = false
		_hovering = false
		input_ray_pickable = false
	else:
		input_ray_pickable = _interactive
	_apply_visual_state()


func _ensure_visuals() -> void:
	_marker = get_node_or_null("Marker") as MeshInstance3D
	_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _marker == null:
		_marker = MeshInstance3D.new()
		_marker.name = "Marker"
		_marker.set_meta("procedural_level", true)
		var box := BoxMesh.new()
		box.size = Vector3(0.85, 0.04, 0.85)
		_marker.mesh = box
		_marker.position = Vector3(0.0, _base_y, 0.0)
		add_child(_marker)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "CollisionShape3D"
		_collision.set_meta("procedural_level", true)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 0.12, 0.9)
		_collision.shape = shape
		_collision.position = Vector3(0.0, 0.06, 0.0)
		add_child(_collision)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.roughness = 0.9
		_marker.material_override = _mat
		_marker.set_meta("mat_kind", "build")


func _apply_visual_state() -> void:
	if _marker == null or _mat == null:
		return
	if occupied:
		_marker.visible = true
		_mat.albedo_color = Color(0.42, 0.44, 0.48, 0.92)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_marker.position.y = _base_y
		_marker.scale = Vector3.ONE
		return
	_marker.visible = true
	var y := _base_y
	var scale_mul := 1.0
	if selected:
		_mat.albedo_color = Color(0.95, 0.85, 0.35, 1.0)
		y = _base_y + 0.04
		scale_mul = 1.08
	elif _hovering and _interactive:
		_mat.albedo_color = Color(0.85, 0.88, 0.95, 1.0)
		y = _base_y + 0.03
		scale_mul = 1.05
	else:
		_mat.albedo_color = Color(0.55, 0.58, 0.62, 0.85)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		y = _base_y
		scale_mul = 1.0
	if not selected and not (_hovering and _interactive):
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_marker.position.y = y
	_marker.scale = Vector3(scale_mul, 1.0, scale_mul)


func _strip_generated_visuals() -> void:
	var to_free: Array[Node] = []
	for child in get_children():
		if child.has_meta("procedural_level"):
			to_free.append(child)
	for child in to_free:
		child.free()
	_marker = null
	_collision = null
	_mat = null


func _on_mouse_entered() -> void:
	if not _interactive or occupied:
		return
	_hovering = true
	_apply_visual_state()
	spot_hovered.emit(self, true)


func _on_mouse_exited() -> void:
	_hovering = false
	_apply_visual_state()
	spot_hovered.emit(self, false)


func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not _interactive or occupied:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				return
			spot_clicked.emit(self)
			get_viewport().set_input_as_handled()
