extends CanvasLayer

## Fake in-match chrome for the visual slice. No gameplay wiring.


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.apply_theme(root)
	add_child(root)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 18
	top.offset_bottom = 86
	top.add_theme_constant_override("separation", UiTokens.SPACE_12)
	root.add_child(top)

	top.add_child(_metric_panel("WAVE", "03  /  12"))
	top.add_child(_metric_panel("PHASE", "PRE-MARKET"))
	top.add_child(_metric_panel("BUYING POWER", "$ 12,400"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	top.add_child(_metric_panel("SELECTED", "SENTRY  ·  L1"))

	var bottom := PanelContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_card_panel(bottom)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24
	bottom.offset_bottom = -22
	bottom.offset_top = -92
	bottom.offset_right = 420
	root.add_child(bottom)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	bottom.add_child(col)
	col.add_child(UiStyle.make_section_label("SECTOR  A-7   MAINTENANCE SPINE"))
	col.add_child(UiStyle.make_flat_label("Core approach  ·  three decks  ·  live fire", UiTokens.FONT_CAPTION, true))
	col.add_child(UiStyle.make_flat_label("HODL  1.00     TICK  +0.00", UiTokens.FONT_DATA, false))

	var hint := PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_card_panel(hint)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_right = -24
	hint.offset_bottom = -22
	hint.offset_left = -430
	hint.offset_top = -70
	root.add_child(hint)
	var hint_col := VBoxContainer.new()
	hint_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hint_col)
	hint_col.add_child(UiStyle.make_flat_label("WASD  pan    Q/E  height    SHIFT  fast", UiTokens.FONT_CAPTION, true))
	hint_col.add_child(UiStyle.make_flat_label("RMB  look    WHEEL  zoom    R  reset", UiTokens.FONT_CAPTION, true))


func _metric_panel(title: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_card_panel(p)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(UiStyle.make_section_label(title))
	v.add_child(UiStyle.make_flat_label(value, UiTokens.FONT_SECTION, false))
	return p
