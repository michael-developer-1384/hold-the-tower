class_name TooltipHost
extends Control

## Delayed, viewport-aware tooltips.

var _panel: PanelContainer
var _title: Label
var _body: Label
var _detail: Label
var _timer: float = -1.0
var _pending: Dictionary = {}
var _visible_tip: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_card_panel(_panel, false, false)
	_panel.custom_minimum_size = Vector2(220, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	_title = UiStyle.make_flat_label("", UiTokens.FONT_LABEL, false)
	_body = UiStyle.make_label("", UiTokens.FONT_CAPTION, true)
	_detail = UiStyle.make_flat_label("", UiTokens.FONT_CAPTION, true)
	_detail.add_theme_color_override("font_color", UiTokens.ACCENT)
	col.add_child(_title)
	col.add_child(_body)
	col.add_child(_detail)
	set_process(true)


func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = -1.0
		_show_now()


func bind_control(control: Control, title: String, body: String, detail: String = "") -> void:
	if control == null:
		return
	control.mouse_entered.connect(func() -> void:
		request(title, body, detail, control.get_global_rect())
	)
	control.mouse_exited.connect(hide_tip)


func request(title: String, body: String, detail: String = "", anchor: Rect2 = Rect2()) -> void:
	_pending = {"title": title, "body": body, "detail": detail, "anchor": anchor}
	_timer = 0.35


func hide_tip() -> void:
	_timer = -1.0
	_panel.visible = false
	_visible_tip = false


func _show_now() -> void:
	_title.text = str(_pending.get("title", "")).to_upper()
	_body.text = str(_pending.get("body", ""))
	var detail := str(_pending.get("detail", ""))
	_detail.text = detail
	_detail.visible = not detail.is_empty()
	_panel.visible = true
	_visible_tip = true
	await get_tree().process_frame
	var anchor: Rect2 = _pending.get("anchor", Rect2())
	var tip_size := _panel.get_combined_minimum_size()
	var pos := Vector2(anchor.position.x, anchor.position.y + anchor.size.y + 8)
	if anchor.size == Vector2.ZERO:
		pos = get_global_mouse_position() + Vector2(16, 16)
	var vp := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - tip_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - tip_size.y - 8.0))
	_panel.global_position = pos
