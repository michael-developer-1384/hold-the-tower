extends StaticBody3D

signal path_hovered(picker: Node, hovered: bool)
signal path_clicked(picker: Node)


func _ready() -> void:
	mouse_entered.connect(func() -> void: path_hovered.emit(self, true))
	mouse_exited.connect(func() -> void: path_hovered.emit(self, false))
	input_event.connect(_on_input_event)


func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				return
			path_clicked.emit(self)
			get_viewport().set_input_as_handled()
