extends Node3D

signal view_changed(view_index: int)

@export var tween_duration: float = 0.3
@export var camera_distance: float = 18.0
@export var camera_height: float = 14.0
@export var ortho_size: float = 12.0
@export var look_target: Vector3 = Vector3(0.0, 3.0, 0.0)

var view_index: int = 0
var _rotating: bool = false
var _camera: Camera3D


func _ready() -> void:
	_camera = $Camera3D
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ortho_size
	_camera.position = Vector3(camera_distance, camera_height, camera_distance)
	_camera.look_at(look_target)
	_camera.current = true
	view_changed.emit(view_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_left"):
		rotate_by(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right"):
		rotate_by(1)
		get_viewport().set_input_as_handled()


## Rotate view by N quarter-turns. Positive = right (E), negative = left (Q).
func rotate_by(steps: int) -> void:
	if steps == 0 or _rotating:
		return
	var dir: int = 1 if steps > 0 else -1
	var count: int = absi(steps)
	_start_rotate(dir, count)


func _start_rotate(dir: int, remaining: int) -> void:
	if remaining <= 0:
		return
	_rotating = true
	view_index = (view_index + dir) % 4
	if view_index < 0:
		view_index += 4
	# Switch cutaway immediately to the target view.
	view_changed.emit(view_index)
	var target_yaw: float = rotation.y + dir * (PI * 0.5)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_yaw, tween_duration)
	tween.finished.connect(func() -> void:
		_rotating = false
		view_changed.emit(view_index)
		if remaining > 1:
			_start_rotate(dir, remaining - 1)
	)
