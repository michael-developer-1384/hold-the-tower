class_name EntityPreview3D
extends Control

## SubViewport preview that only instantiates a visual PackedScene (no gameplay scripts).
## Object is recentered on its AABB so yaw/pitch rotate cleanly around the visual middle.

@export var auto_rotate: bool = true
@export var rotate_speed: float = 0.35
@export var drag_sensitivity: float = 0.01
@export var preview_size: Vector2i = Vector2i(220, 180)
@export var zoom: float = 2.35
@export var render_scale: float = 2.0

var _viewport: SubViewport
var _host: SubViewportContainer
var _pivot: Node3D
var _offset: Node3D
var _camera: Camera3D
var _yaw: float = 0.55
var _pitch: float = 0.22
var _visual: Node3D
var _pending_scene: PackedScene
var _frame_radius: float = 1.0
var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(preview_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	resized.connect(_sync_viewport_size)
	_build_viewport()
	_sync_viewport_size()
	if _pending_scene != null:
		var scene := _pending_scene
		_pending_scene = null
		set_visual_scene(scene)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	if auto_rotate and not _dragging:
		_yaw += rotate_speed * delta
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_last_mouse = mb.position
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var delta := mm.position - _last_mouse
		_last_mouse = mm.position
		_yaw += delta.x * drag_sensitivity
		_pitch = clampf(_pitch + delta.y * drag_sensitivity, -0.2, 0.7)
		accept_event()


func set_visual_scene(scene: PackedScene) -> void:
	if not is_inside_tree() or _viewport == null:
		_pending_scene = scene
		return
	_clear_visual()
	if scene == null:
		return
	_visual = scene.instantiate() as Node3D
	if _visual == null:
		return
	_offset.add_child(_visual)
	# Wait one frame so transforms/meshes are ready, then center.
	call_deferred("_frame_visual")


func clear_preview() -> void:
	_pending_scene = null
	_clear_visual()


func _build_viewport() -> void:
	if _viewport != null:
		return
	_host = SubViewportContainer.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.stretch = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.use_taa = false
	_host.add_child(_viewport)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_viewport.add_child(_pivot)

	_offset = Node3D.new()
	_offset.name = "Offset"
	_pivot.add_child(_offset)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	light.light_energy = 1.25
	_viewport.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, 1.6, 1.8)
	fill.light_energy = 0.65
	_viewport.add_child(fill)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 35.0
	_viewport.add_child(_camera)
	_place_camera()


func _sync_viewport_size() -> void:
	if _viewport == null:
		return
	var display := size
	if display.x < 2.0 or display.y < 2.0:
		display = Vector2(preview_size)
	var scale := maxf(render_scale, 1.0)
	# Prefer crisp downscale over low-res upscale.
	_viewport.size = Vector2i(
		maxi(int(ceil(display.x * scale)), 2),
		maxi(int(ceil(display.y * scale)), 2)
	)


func _clear_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null
	if _offset != null:
		_offset.position = Vector3.ZERO


func _frame_visual() -> void:
	_frame_radius = 1.0
	if _offset != null:
		_offset.position = Vector3.ZERO
	if _visual == null or not is_instance_valid(_visual):
		_place_camera()
		return

	var aabb := _compute_aabb(_visual)
	if aabb.size.length() > 0.001:
		# Shift mesh so its geometric center sits on the pivot (origin).
		_offset.position = -aabb.get_center()
		_frame_radius = maxf(aabb.size.length() * 0.72, 0.75)
	_place_camera()


func _place_camera() -> void:
	if _camera == null:
		return
	var dist := maxf(_frame_radius * zoom, 1.2)
	# Fixed camera; object spins under it around origin (AABB center).
	var cam_pos := Vector3(dist * 0.65, dist * 0.45, dist)
	_camera.look_at_from_position(cam_pos, Vector3.ZERO, Vector3.UP)


func _compute_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xform: Transform3D = item[1]
		if n is Node3D:
			xform = xform * (n as Node3D).transform
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var local := mi.get_aabb()
				for i in 8:
					var corner := xform * local.get_endpoint(i)
					if first:
						result = AABB(corner, Vector3.ZERO)
						first = false
					else:
						result = result.expand(corner)
		for child in n.get_children():
			stack.append([child, xform])
	return result
