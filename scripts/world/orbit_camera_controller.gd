extends Node3D

signal focus_changed(floor_index: int)
signal camera_moved

@export var min_pitch_deg: float = 15.0
@export var max_pitch_deg: float = 75.0
@export var min_distance: float = 8.0
@export var max_distance: float = 40.0
@export var orbit_sensitivity: float = 0.008
@export var zoom_step: float = 1.25
@export var distance: float = 24.0

var yaw: float = deg_to_rad(90.0)
var pitch: float = deg_to_rad(30.0)
var focus_floor: int = 0

var _floor_count: int = 3
var _focus_points: PackedVector3Array = PackedVector3Array([
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 3.0, 0.0),
	Vector3(0.0, 6.0, 0.0),
])
var _map_center: Vector3 = Vector3(0.0, 3.0, 0.0)
var _orbiting: bool = false
var _camera: Camera3D
var _intro_tween: Tween


func _ready() -> void:
	_camera = $Camera3D
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 40.0
	_camera.current = true
	_map_center = _compute_map_center()
	global_position = _map_center
	_apply_orbit()
	focus_changed.emit(focus_floor)
	_apply_control_settings()
	if typeof(SettingsManager) != TYPE_NIL and not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func setup_floors(floor_count: int, focus_points: PackedVector3Array) -> void:
	_floor_count = max(floor_count, 1)
	if focus_points.size() > 0:
		_focus_points = focus_points
	if focus_floor >= _floor_count:
		focus_floor = 0
	_map_center = _compute_map_center()
	global_position = _map_center
	_apply_orbit()
	focus_changed.emit(focus_floor)


func setup_opening_view(
	spawn: Vector3,
	ahead: Vector3,
	radius: float = 8.0,
	path: PackedVector3Array = PackedVector3Array(),
	animate: bool = true
) -> void:
	var lane := _first_lane(spawn, ahead, path)
	var dir: Vector3 = lane["dir"]
	var corner: Vector3 = lane["corner"]
	var spawn_pt: Vector3 = lane["spawn"]
	var look_at_pt: Vector3 = spawn_pt.lerp(corner, 0.38)
	var lane_yaw := atan2(dir.x, dir.z)
	var overview_pitch := deg_to_rad(45.0)
	var lane_pitch := deg_to_rad(30.0)
	var overview_dist := _fit_distance_at(radius, overview_pitch)
	var lane_dist := clampf(spawn_pt.distance_to(corner) * 1.2, 11.0, 16.5)

	_kill_intro()
	yaw = lane_yaw
	_map_center = _compute_map_center()

	if not animate or _skip_intro():
		pitch = lane_pitch
		distance = lane_dist
		global_position = look_at_pt
		_apply_orbit()
		camera_moved.emit()
		return

	pitch = overview_pitch
	distance = overview_dist
	global_position = _map_center
	_apply_orbit()
	camera_moved.emit()

	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.set_trans(Tween.TRANS_CUBIC)
	_intro_tween.set_ease(Tween.EASE_IN_OUT)
	var dur := 1.85
	_intro_tween.tween_property(self, "pitch", lane_pitch, dur)
	_intro_tween.tween_property(self, "distance", lane_dist, dur)
	_intro_tween.tween_property(self, "global_position", look_at_pt, dur)
	_intro_tween.tween_method(_tick_intro, 0.0, 1.0, dur)


func _tick_intro(_t: float) -> void:
	_apply_orbit()
	camera_moved.emit()


func _kill_intro() -> void:
	if _intro_tween != null and is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_tween = null


func _skip_intro() -> bool:
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	if SimContextScript != null and SimContextScript.skip_presentation():
		return true
	if typeof(SettingsManager) != TYPE_NIL and SettingsManager.reduced_motion():
		return true
	return false


func _first_lane(spawn: Vector3, ahead: Vector3, path: PackedVector3Array) -> Dictionary:
	var spawn_pt := spawn
	var dir := ahead - spawn
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(1.0, 0.0, 0.0)
	dir = dir.normalized()
	var corner := spawn_pt + dir * 6.0
	if path.size() >= 2:
		spawn_pt = path[0]
		var first := path[1] - path[0]
		first.y = 0.0
		if first.length_squared() > 0.0001:
			dir = first.normalized()
		corner = path[path.size() - 1]
		for i in range(1, path.size() - 1):
			var a: Vector3 = path[i] - path[i - 1]
			var b: Vector3 = path[i + 1] - path[i]
			a.y = 0.0
			b.y = 0.0
			if a.length_squared() < 0.01 or b.length_squared() < 0.01:
				continue
			a = a.normalized()
			b = b.normalized()
			if a.dot(b) < 0.72:
				corner = path[i]
				dir = a
				break
	return {"spawn": spawn_pt, "dir": dir, "corner": corner}


func _fit_distance(radius: float) -> float:
	return _fit_distance_at(radius, pitch)


func _fit_distance_at(radius: float, at_pitch: float) -> float:
	var r := maxf(radius, 6.0)
	var fov := 40.0
	if _camera != null:
		fov = _camera.fov
	var half := tan(deg_to_rad(fov) * 0.5)
	var horiz := maxf(cos(at_pitch), 0.35)
	var fitted := (r * 1.35) / maxf(half * horiz, 0.08)
	return clampf(fitted, 18.0, 34.0)


func is_orbiting() -> bool:
	return _orbiting or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = mb.pressed
			if mb.pressed:
				_kill_intro()
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_kill_intro()
			_zoom(-zoom_step)
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_kill_intro()
			_zoom(zoom_step)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if _orbiting or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_orbiting = true
			_kill_intro()
			var mm := event as InputEventMouseMotion
			var sens := _mouse_orbit_sens()
			var y_sign := -1.0 if _invert_y() else 1.0
			yaw -= mm.relative.x * sens
			pitch = clampf(
				pitch + mm.relative.y * sens * y_sign,
				deg_to_rad(min_pitch_deg),
				deg_to_rad(max_pitch_deg)
			)
			_apply_orbit()
			camera_moved.emit()
			get_viewport().set_input_as_handled()
			return
		_orbiting = false

	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) < 0.2:
			return
		var gsens := _gamepad_camera_sens()
		var y_sign2 := -1.0 if _invert_y() else 1.0
		if jm.axis == JOY_AXIS_RIGHT_X:
			_kill_intro()
			yaw -= jm.axis_value * gsens * 0.05
			_apply_orbit()
			camera_moved.emit()
		elif jm.axis == JOY_AXIS_RIGHT_Y:
			_kill_intro()
			pitch = clampf(
				pitch + jm.axis_value * gsens * 0.05 * y_sign2,
				deg_to_rad(min_pitch_deg),
				deg_to_rad(max_pitch_deg)
			)
			_apply_orbit()
			camera_moved.emit()

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var digit := _key_to_floor_digit(key.physical_keycode)
		if digit < 0:
			digit = _key_to_floor_digit(key.keycode)
		if digit >= 0:
			set_focus_floor(digit)
			get_viewport().set_input_as_handled()


func _zoom(delta: float) -> void:
	distance = clampf(distance + delta * _zoom_sens(), min_distance, max_distance)
	_apply_orbit()
	camera_moved.emit()


func _apply_control_settings() -> void:
	pass


func _on_settings_changed(section: String) -> void:
	if section == "controls":
		_apply_control_settings()


func _mouse_orbit_sens() -> float:
	var m := 1.0
	if typeof(SettingsManager) != TYPE_NIL:
		m = float(SettingsManager.get_value("controls", "mouse_orbit_sensitivity", 1.0))
	return orbit_sensitivity * m


func _gamepad_camera_sens() -> float:
	var m := 1.0
	if typeof(SettingsManager) != TYPE_NIL:
		m = float(SettingsManager.get_value("controls", "gamepad_camera_sensitivity", 1.0))
	return m


func _zoom_sens() -> float:
	if typeof(SettingsManager) != TYPE_NIL:
		return float(SettingsManager.get_value("controls", "zoom_sensitivity", 1.0))
	return 1.0


func _invert_y() -> bool:
	if typeof(SettingsManager) != TYPE_NIL:
		return bool(SettingsManager.get_value("controls", "invert_y", false))
	return false


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
	if index == focus_floor:
		return
	_kill_intro()
	focus_floor = index
	# Pivot stays fixed at map center; floor focus only drives visuals/HUD.
	global_position = _map_center
	_apply_orbit()
	focus_changed.emit(focus_floor)


func _compute_map_center() -> Vector3:
	if _focus_points.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for p in _focus_points:
		sum += p
	return sum / float(_focus_points.size())


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
