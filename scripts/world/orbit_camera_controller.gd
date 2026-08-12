extends Node3D

signal focus_changed(floor_index: int)
signal camera_moved

@export var min_pitch_deg: float = 20.0
@export var max_pitch_deg: float = 75.0
@export var min_distance: float = 8.0
@export var max_distance: float = 28.0
@export var orbit_sensitivity: float = 0.008
@export var zoom_step: float = 1.25
@export var pivot_tween_duration: float = 0.35
@export var distance: float = 16.0

var yaw: float = deg_to_rad(45.0)
var pitch: float = deg_to_rad(45.0)
var focus_floor: int = 0

var _floor_count: int = 3
var _focus_points: PackedVector3Array = PackedVector3Array([
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 3.0, 0.0),
	Vector3(0.0, 6.0, 0.0),
])
var _orbiting: bool = false
var _pivot_tween: Tween
var _camera: Camera3D


func _ready() -> void:
	_camera = $Camera3D
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 40.0
	_camera.current = true
	global_position = _point_for(focus_floor)
	_apply_orbit()
	focus_changed.emit(focus_floor)


func setup_floors(floor_count: int, focus_points: PackedVector3Array) -> void:
	_floor_count = max(floor_count, 1)
	if focus_points.size() > 0:
		_focus_points = focus_points
	if focus_floor >= _floor_count:
		focus_floor = 0
	global_position = _point_for(focus_floor)
	_apply_orbit()
	focus_changed.emit(focus_floor)


func is_orbiting() -> bool:
	return _orbiting or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = mb.pressed
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if _orbiting or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_orbiting = true
			var mm := event as InputEventMouseMotion
			yaw -= mm.relative.x * orbit_sensitivity
			pitch = clampf(
				pitch + mm.relative.y * orbit_sensitivity,
				deg_to_rad(min_pitch_deg),
				deg_to_rad(max_pitch_deg)
			)
			_apply_orbit()
			camera_moved.emit()
			get_viewport().set_input_as_handled()
			return
		_orbiting = false

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var digit := _key_to_floor_digit(key.physical_keycode)
		if digit < 0:
			digit = _key_to_floor_digit(key.keycode)
		if digit >= 0:
			set_focus_floor(digit)
			get_viewport().set_input_as_handled()


func _zoom(delta: float) -> void:
	distance = clampf(distance + delta, min_distance, max_distance)
	_apply_orbit()
	camera_moved.emit()


func _key_to_floor_digit(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		KEY_7, KEY_KP_7:
			return 6
		KEY_8, KEY_KP_8:
			return 7
		KEY_9, KEY_KP_9:
			return 8
		_:
			return -1


func set_focus_floor(index: int) -> void:
	if index < 0 or index >= _floor_count:
		return
	var target := _point_for(index)
	if index == focus_floor and global_position.is_equal_approx(target):
		return
	focus_floor = index
	if _pivot_tween and _pivot_tween.is_running():
		_pivot_tween.kill()
	_pivot_tween = create_tween()
	_pivot_tween.set_trans(Tween.TRANS_SINE)
	_pivot_tween.set_ease(Tween.EASE_IN_OUT)
	_pivot_tween.tween_property(self, "global_position", target, pivot_tween_duration)
	_pivot_tween.parallel().tween_method(func(_v: float) -> void:
		_apply_orbit()
		camera_moved.emit()
	, 0.0, 1.0, pivot_tween_duration)
	_pivot_tween.tween_callback(func() -> void:
		_apply_orbit()
		camera_moved.emit()
	)
	focus_changed.emit(focus_floor)


func _point_for(index: int) -> Vector3:
	if index >= 0 and index < _focus_points.size():
		return _focus_points[index]
	return Vector3(0.0, float(index) * 3.0, 0.0)


func _apply_orbit() -> void:
	if _camera == null:
		return
	var cp: float = cos(pitch)
	var offset := Vector3(
		sin(yaw) * cp,
		sin(pitch),
		cos(yaw) * cp
	) * distance
	_camera.position = offset
	_camera.look_at(global_position, Vector3.UP)
