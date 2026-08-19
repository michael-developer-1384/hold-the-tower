extends CanvasLayer

## Minimal in-match chrome for the visual slice.


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.apply_theme(root)
	add_child(root)

	var top := PanelContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_sb := UiStyle.make_flat_style(Color(0.05, 0.07, 0.09, 0.55), Color(0.22, 0.28, 0.32, 0.35), UiTokens.RADIUS_MD, 1)
	top_sb.content_margin_top = 8
	top_sb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", top_sb)
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.offset_left = 20
	top.offset_top = 16
	top.offset_right = 430
	top.offset_bottom = 58
	root.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	row.add_child(UiStyle.make_flat_label("WAVE  03 / 12", UiTokens.FONT_CAPTION, false))
	row.add_child(UiStyle.make_flat_label("PRE-MARKET", UiTokens.FONT_CAPTION, true))
	row.add_child(UiStyle.make_flat_label("$ 12,400", UiTokens.FONT_CAPTION, false))

	var sel := PanelContainer.new()
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sel_sb := UiStyle.make_flat_style(Color(0.05, 0.07, 0.09, 0.5), Color(0.22, 0.28, 0.32, 0.3), UiTokens.RADIUS_MD, 1)
	sel_sb.content_margin_top = 8
	sel_sb.content_margin_bottom = 8
	sel.add_theme_stylebox_override("panel", sel_sb)
	sel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sel.offset_right = -20
	sel.offset_top = 16
	sel.offset_left = -210
	sel.offset_bottom = 58
	root.add_child(sel)
	sel.add_child(UiStyle.make_flat_label("SENTRY  L1", UiTokens.FONT_CAPTION, false))

	var hint := PanelContainer.new()
	hint.name = "CamHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_card_panel(hint)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_right = -20
	hint.offset_bottom = -16
	hint.offset_left = -360
	hint.offset_top = -52
	root.add_child(hint)
	hint.add_child(UiStyle.make_flat_label("WASD  ·  QE  ·  RMB  ·  R reset", UiTokens.FONT_CAPTION, true))


func set_capture_mode(on: bool) -> void:
	var hint := get_node_or_null("Root/CamHint")
	if hint:
		hint.visible = not on
