extends Node

## Tracks mouse vs gamepad without disabling either.

signal mode_changed(mode: String)

enum Mode { MOUSE, GAMEPAD }

var mode: Mode = Mode.MOUSE
var _gamepad_seen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_set_mode(Mode.MOUSE)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.35:
			return
		_gamepad_seen = true
		_set_mode(Mode.GAMEPAD)


func is_gamepad() -> bool:
	return mode == Mode.GAMEPAD


func hint_back() -> String:
	return "[B] BACK" if is_gamepad() else "[ESC] BACK"


func hint_select() -> String:
	return "[A] SELECT" if is_gamepad() else "[ENTER] SELECT"


func _set_mode(m: Mode) -> void:
	if mode == m:
		return
	mode = m
	mode_changed.emit("gamepad" if m == Mode.GAMEPAD else "mouse")


func _ensure_actions() -> void:
	_bind("ui_up", [KEY_W, KEY_UP])
	_bind("ui_down", [KEY_S, KEY_DOWN])
	_bind("ui_left", [KEY_A, KEY_LEFT])
	_bind("ui_right", [KEY_D, KEY_RIGHT])
	_bind("ui_accept", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	_bind("ui_cancel", [KEY_ESCAPE])
	_add_joy("ui_accept", JOY_BUTTON_A)
	_add_joy("ui_cancel", JOY_BUTTON_B)
	_add_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	if not InputMap.has_action("hodl_tab_next"):
		InputMap.add_action("hodl_tab_next")
		var e := InputEventKey.new()
		e.keycode = KEY_TAB
		InputMap.action_add_event("hodl_tab_next", e)
	if not InputMap.has_action("hodl_tab_prev"):
		InputMap.add_action("hodl_tab_prev")
		var e2 := InputEventKey.new()
		e2.keycode = KEY_TAB
		e2.shift_pressed = true
		InputMap.action_add_event("hodl_tab_prev", e2)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.keycode = k as Key
		var exists := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey and (existing as InputEventKey).keycode == (k as Key):
				exists = true
				break
		if not exists:
			InputMap.action_add_event(action, e)


func _add_joy(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button:
			return
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _add_joy_axis(action: String, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = axis_value
	InputMap.action_add_event(action, e)
