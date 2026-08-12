class_name ToastHost
extends Control

## Lightweight desktop toasts (top-right).

var _box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var align := HBoxContainer.new()
	align.set_anchors_preset(Control.PRESET_FULL_RECT)
	align.alignment = BoxContainer.ALIGNMENT_END
	align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(align)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size = Vector2(280, 0)
	align.add_child(_box)


func show_toast(title: String, body: String = "", duration: float = 2.4) -> void:
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel, true, false)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	col.add_child(UiStyle.make_flat_label(title.to_upper(), UiTokens.FONT_LABEL, false))
	if not body.is_empty():
		col.add_child(UiStyle.make_flat_label(body, UiTokens.FONT_CAPTION, true))
	_box.add_child(panel)
	panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, UiMotion.modal_sec() if typeof(UiMotion) != TYPE_NIL else 0.15)
	t.tween_interval(duration)
	t.tween_property(panel, "modulate:a", 0.0, 0.15)
	t.tween_callback(panel.queue_free)
