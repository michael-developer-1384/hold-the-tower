extends Control

signal finished

var _skipped: bool = false
var _done: bool = false
var _line: ColorRect
var _label: Label
var _brand: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label = UiStyle.make_flat_label("HODL SYSTEM // %s" % UiTokens.APP_VERSION, UiTokens.FONT_LABEL, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.position = Vector2(-200, -40)
	_label.size = Vector2(400, 24)
	add_child(_label)

	_line = ColorRect.new()
	_line.color = UiTokens.ACCENT
	_line.size = Vector2(0, 2)
	_line.position = Vector2(0, size.y * 0.5)
	add_child(_line)

	_brand = UiStyle.make_flat_label("HODL THE TOWER", UiTokens.FONT_PAGE, false)
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.modulate.a = 0.0
	_brand.set_anchors_preset(Control.PRESET_CENTER)
	_brand.position = Vector2(-220, 10)
	_brand.size = Vector2(440, 36)
	add_child(_brand)

	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_boot()
	_run()


func _input(event: InputEvent) -> void:
	if _skipped:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
			_skip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _line != null:
		_line.position.y = size.y * 0.5


func _run() -> void:
	await get_tree().process_frame
	if _line == null or _brand == null:
		return
	_line.position = Vector2(0, size.y * 0.5)
	var t := create_tween()
	t.tween_property(_line, "size:x", size.x, 0.35)
	t.tween_property(_brand, "modulate:a", 1.0, 0.25)
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		_finish()
	)


func _skip() -> void:
	_skipped = true
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
