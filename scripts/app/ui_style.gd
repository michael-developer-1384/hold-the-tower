class_name UiStyle
extends RefCounted

## Design-system helpers. Prefer scene components for layout; use these for tokens, styles, and dense data UI.

const THEME := preload("res://ui/theme/hodl_theme.tres")

const BG := UiTokens.BG
const PANEL := UiTokens.PANEL
const ACCENT := UiTokens.ACCENT
const COST := UiTokens.COST
const TEXT := UiTokens.TEXT
const MUTED := UiTokens.MUTED
const DANGER := UiTokens.DANGER
const CARD_LOCKED := UiTokens.CARD_LOCKED
const WARNING := UiTokens.WARNING


static func apply_theme(control: Control) -> void:
	control.theme = THEME


static func apply_root(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	apply_theme(control)
	if control.get_node_or_null("Bg") != null:
		return
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(bg)
	control.move_child(bg, 0)


static func make_flat_style(bg: Color, border: Color = UiTokens.SURFACE_LINE, radius: int = UiTokens.RADIUS_MD, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func focus_style() -> StyleBoxFlat:
	var sb := make_flat_style(Color(0, 0, 0, 0), UiTokens.FOCUS_RING, UiTokens.RADIUS_MD, 2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func label(text: String, role: String = "body", muted: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var font_size := UiTokens.FONT_BODY
	match role:
		"display":
			font_size = UiTokens.FONT_DISPLAY
		"page":
			font_size = UiTokens.FONT_PAGE
		"section":
			font_size = UiTokens.FONT_SECTION
		"label":
			font_size = UiTokens.FONT_LABEL
		"data":
			font_size = UiTokens.FONT_DATA
		"caption":
			font_size = UiTokens.FONT_CAPTION
		_:
			font_size = UiTokens.FONT_BODY
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", MUTED if muted else TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func make_title(text: String, size: int = 36) -> Label:
	var l := label(text, "page")
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func make_label(text: String, size: int = 16, muted: bool = false) -> Label:
	var l := label(text, "body", muted)
	l.add_theme_font_size_override("font_size", size)
	return l


static func make_flat_label(text: String, size: int = 16, muted: bool = false) -> Label:
	var l := make_label(text, size, muted)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func make_data_label(text: String, size: int = UiTokens.FONT_DATA) -> Label:
	var l := make_flat_label(text, size, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func make_section_label(text: String) -> Label:
	var l := make_flat_label(text.to_upper(), UiTokens.FONT_LABEL, true)
	return l


static func make_lv_xp_rp_badge(level: int, xp: int, points: int) -> Label:
	const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
	var info: Dictionary = ProgressionConfigScript.xp_into_level(xp)
	var xp_txt := "MAX" if bool(info.get("at_cap", false)) else "%d / %d" % [int(info.get("xp_in_level", 0)), int(info.get("xp_need", 0))]
	if bool(info.get("at_cap", false)):
		xp_txt = "MAX"
	else:
		xp_txt = "%d / %d" % [xp, int(info.get("xp_next_total", xp))]
	var l := make_flat_label("LV %d    XP %s    RP %d" % [level, xp_txt, points], UiTokens.FONT_BODY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	return l


static func make_content_host(parent: Control, max_width: float = UiTokens.CONTENT_MAX_WIDTH, margin: float = float(UiTokens.SPACE_24)) -> VBoxContainer:
	var outer := MarginContainer.new()
	outer.name = "ContentMargin"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", int(margin))
	outer.add_theme_constant_override("margin_right", int(margin))
	outer.add_theme_constant_override("margin_top", int(margin))
	outer.add_theme_constant_override("margin_bottom", int(margin))
	parent.add_child(outer)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(row)

	var left := Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	row.add_child(left)

	var col := VBoxContainer.new()
	col.name = "Content"
	col.add_theme_constant_override("separation", UiTokens.SPACE_12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1000.0
	col.custom_maximum_size = Vector2(maxf(640.0, max_width), -1.0)
	row.add_child(col)

	var right := Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	row.add_child(right)
	return col


## Legacy alias — prefer make_content_host with desktop widths.
static func make_content_shell(parent: Control, max_width: float = UiTokens.CONTENT_MAX_WIDTH, margin: float = 24.0) -> VBoxContainer:
	return make_content_host(parent, max_width, margin)


static func make_button(text: String, min_h: float = 40.0, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	_style_button(b, kind)
	return b


static func make_compact_button(text: String, min_w: float = 120.0, min_h: float = 36.0, kind: String = "secondary") -> Button:
	var b := make_button(text, min_h, kind)
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


static func _style_button(button: Button, kind: String) -> void:
	var bg := Color(0.16, 0.19, 0.24, 1.0)
	var border := UiTokens.SURFACE_LINE
	var hover_bg := Color(0.20, 0.24, 0.30, 1.0)
	match kind:
		"primary":
			bg = UiTokens.ACCENT_SOFT
			border = ACCENT
			hover_bg = Color(0.20, 0.38, 0.28, 1.0)
		"danger":
			bg = Color(0.28, 0.12, 0.12, 1.0)
			border = DANGER
			hover_bg = Color(0.36, 0.16, 0.16, 1.0)
		"ghost":
			bg = Color(0, 0, 0, 0)
			border = Color(0, 0, 0, 0)
			hover_bg = Color(1, 1, 1, 0.04)
		_:
			pass
	var normal := make_flat_style(bg, border, UiTokens.RADIUS_MD, 1 if kind != "ghost" else 0)
	var hover := make_flat_style(hover_bg, ACCENT if kind != "danger" else DANGER, UiTokens.RADIUS_MD, 1)
	var pressed := make_flat_style(bg.darkened(0.08), border, UiTokens.RADIUS_MD, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus_style())


static func style_tab_button(button: Button, active: bool) -> void:
	var sb := make_flat_style(
		UiTokens.ACCENT_SOFT if active else Color(0.12, 0.14, 0.18, 1.0),
		ACCENT if active else UiTokens.SURFACE_LINE,
		UiTokens.RADIUS_MD,
		2 if active else 1
	)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	button.add_theme_color_override("font_color", TEXT if active else MUTED)
	button.disabled = active
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", sb)
	button.add_theme_stylebox_override("disabled", sb)
	button.add_theme_stylebox_override("focus", focus_style())


static func make_tab_row(labels: PackedStringArray, on_select: Callable, active_idx: int = 0) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_8)
	var buttons: Array = []
	for i in labels.size():
		var b := make_button(labels[i], 36, "ghost")
		b.custom_minimum_size = Vector2(110, 36)
		var idx := i
		b.pressed.connect(func() -> void:
			for j in buttons.size():
				style_tab_button(buttons[j], j == idx)
			on_select.call(idx)
		)
		style_tab_button(b, i == active_idx)
		row.add_child(b)
		buttons.append(b)
	return {"row": row, "buttons": buttons}


static func style_card_panel(panel: PanelContainer, selected: bool = false, locked: bool = false) -> void:
	var sb := make_flat_style(
		CARD_LOCKED if locked else PANEL,
		ACCENT if selected else UiTokens.SURFACE_LINE,
		UiTokens.RADIUS_MD,
		2 if selected else 1
	)
	panel.add_theme_stylebox_override("panel", sb)


static func style_modal(window: Window) -> void:
	window.theme = THEME
	var panel_sb := make_flat_style(Color(0.11, 0.13, 0.17, 0.98), ACCENT, UiTokens.RADIUS_LG, 2)
	panel_sb.content_margin_left = 18
	panel_sb.content_margin_right = 18
	panel_sb.content_margin_top = 14
	panel_sb.content_margin_bottom = 14
	window.add_theme_stylebox_override("embedded_border", panel_sb)
	window.add_theme_stylebox_override("panel", panel_sb)
	window.add_theme_color_override("title_color", TEXT)


static func make_feature_chip(text: String) -> PanelContainer:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	chip.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	var chip_wrap := PanelContainer.new()
	var csb := make_flat_style(UiTokens.ACCENT_SOFT, Color(0, 0, 0, 0), UiTokens.RADIUS_SM, 0)
	csb.content_margin_left = 6
	csb.content_margin_right = 6
	csb.content_margin_top = 2
	csb.content_margin_bottom = 2
	chip_wrap.add_theme_stylebox_override("panel", csb)
	chip_wrap.add_child(chip)
	return chip_wrap


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	style_card_panel(p, false, false)
	return p


static func make_scroll_panel() -> PanelContainer:
	var panel := make_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTokens.SPACE_12)
	scroll.add_child(body)
	return panel


static func scroll_body(panel: PanelContainer) -> VBoxContainer:
	return panel.get_node("Scroll/Body") as VBoxContainer


static func make_stat_row(name: String, value: String, delta: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_12)
	var n := make_flat_label(name, UiTokens.FONT_BODY, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v := make_data_label(value)
	v.custom_minimum_size = Vector2(100, 0)
	row.add_child(v)
	if not delta.is_empty():
		var d := make_flat_label(delta, UiTokens.FONT_CAPTION, false)
		d.add_theme_color_override("font_color", ACCENT)
		d.custom_minimum_size = Vector2(80, 0)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(d)
	return row


static func make_divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = UiTokens.SURFACE_LINE_SOFT
	d.custom_minimum_size = Vector2(0, 1)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


static func make_top_bar(parent: Control, title: String, back_cb: Callable, extra_right: Array = []) -> HBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTokens.SPACE_12)
	top.custom_minimum_size = Vector2(0, 48)
	parent.add_child(top)
	var back := make_button("BACK", 36, "secondary")
	back.custom_minimum_size = Vector2(100, 36)
	back.pressed.connect(back_cb)
	top.add_child(back)
	var title_l := make_title(title, UiTokens.FONT_PAGE)
	top.add_child(title_l)
	for node in extra_right:
		if node is Control:
			top.add_child(node)
	return top


static func make_level_preview(level_id: String, preview_size: Vector2 = Vector2(320, 200)) -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = preview_size
	style_card_panel(preview)
	var root := Control.new()
	root.custom_minimum_size = preview_size
	preview.add_child(root)
	match level_id:
		"vertical_test":
			_draw_vertical_level(root, preview_size)
		_:
			_draw_locked_preview(root, preview_size)
	return preview


static func gallery_columns(available_width: float) -> int:
	if available_width >= 2200.0:
		return 6
	if available_width >= 1700.0:
		return 5
	if available_width >= 1400.0:
		return 4
	if available_width >= 1100.0:
		return 3
	return 2


static func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	parent.add_child(r)


static func _draw_locked_preview(root: Control, size: Vector2) -> void:
	_rect(root, Vector2(size.x * 0.15, size.y * 0.20), Vector2(size.x * 0.70, size.y * 0.55), Color(0.18, 0.20, 0.24))
	var q := Label.new()
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 42)
	q.add_theme_color_override("font_color", Color(0.45, 0.50, 0.56))
	q.position = Vector2(0, size.y * 0.18)
	q.size = Vector2(size.x, size.y * 0.5)
	root.add_child(q)


static func _draw_vertical_level(root: Control, size: Vector2) -> void:
	_rect(root, Vector2(size.x * 0.18, size.y * 0.68), Vector2(size.x * 0.64, size.y * 0.12), Color(0.40, 0.42, 0.46))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.44), Vector2(size.x * 0.64, size.y * 0.12), Color(0.45, 0.48, 0.52))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.20), Vector2(size.x * 0.64, size.y * 0.12), Color(0.50, 0.54, 0.58))
	_rect(root, Vector2(size.x * 0.22, size.y * 0.72), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
	_rect(root, Vector2(size.x * 0.42, size.y * 0.48), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
	_rect(root, Vector2(size.x * 0.60, size.y * 0.24), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
