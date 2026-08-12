class_name UiStyle
extends RefCounted

const BG := Color(0.08, 0.09, 0.11, 1.0)
const PANEL := Color(0.14, 0.16, 0.20, 0.96)
const ACCENT := Color(0.35, 0.72, 0.55, 1.0)
const COST := Color(0.92, 0.62, 0.35, 1.0)
const TEXT := Color(0.92, 0.94, 0.96, 1.0)
const MUTED := Color(0.65, 0.70, 0.76, 1.0)
const DANGER := Color(0.85, 0.35, 0.35, 1.0)
const CARD_LOCKED := Color(0.10, 0.11, 0.13, 0.96)
const THEME := preload("res://ui/theme/hodl_theme.tres")


static func apply_root(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.theme = THEME
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(bg)
	control.move_child(bg, 0)


static func make_title(text: String, size: int = 36) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func make_label(text: String, size: int = 16, muted: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MUTED if muted else TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func make_flat_label(text: String, size: int = 16, muted: bool = false) -> Label:
	var l := make_label(text, size, muted)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func make_rp_badge(points: int) -> Label:
	var l := make_flat_label("RP: %d" % points, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(120, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	return l


static func make_lv_rp_badge(level: int, points: int) -> Label:
	var l := make_flat_label("LV %d   RP %d" % [level, points], 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(160, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	return l


static func make_button(text: String, min_h: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", 18)
	return b


static func make_compact_button(text: String, min_w: float = 120.0, min_h: float = 40.0) -> Button:
	var b := make_button(text, min_h)
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


static func style_tab_button(button: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if active:
		sb.bg_color = Color(0.16, 0.32, 0.24, 1.0)
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
		button.add_theme_color_override("font_color", Color(0.92, 0.98, 0.94, 1.0))
		button.disabled = true
	else:
		sb.bg_color = Color(0.14, 0.16, 0.20, 1.0)
		sb.border_color = Color(0.30, 0.34, 0.40, 1.0)
		sb.set_border_width_all(1)
		button.add_theme_color_override("font_color", MUTED)
		button.disabled = false
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", sb)
	button.add_theme_stylebox_override("disabled", sb)


static func make_tab_row(labels: PackedStringArray, on_select: Callable, active_idx: int = 0) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var buttons: Array = []
	for i in labels.size():
		var b := make_button(labels[i], 40)
		b.custom_minimum_size = Vector2(120, 40)
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_LOCKED if locked else PANEL
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if selected:
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(0.28, 0.34, 0.40, 1.0)
		sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)


static func style_modal(window: Window) -> void:
	window.theme = THEME
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.11, 0.13, 0.17, 0.98)
	panel_sb.border_color = ACCENT
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(10)
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
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	var wrap := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.16, 0.28, 0.22, 1.0)
	csb.set_corner_radius_all(4)
	csb.content_margin_left = 6
	csb.content_margin_right = 6
	csb.content_margin_top = 2
	csb.content_margin_bottom = 2
	wrap.add_theme_stylebox_override("panel", csb)
	wrap.add_child(chip)
	return wrap


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
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return panel


static func scroll_body(panel: PanelContainer) -> VBoxContainer:
	return panel.get_node("Scroll/Body") as VBoxContainer


static func make_top_bar(parent: Control, title: String, back_cb: Callable, extra_right: Array = []) -> HBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.custom_minimum_size = Vector2(0, 48)
	parent.add_child(top)

	var back := make_button("Back", 40)
	back.custom_minimum_size = Vector2(100, 40)
	back.pressed.connect(back_cb)
	top.add_child(back)

	var title_l := make_title(title, 28)
	top.add_child(title_l)

	for node in extra_right:
		if node is Control:
			top.add_child(node)
	return top


static func make_tower_preview(tower_id: String, size: Vector2 = Vector2(160, 110)) -> Control:
	const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
	const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.15, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_bottom = 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = Color(0.25, 0.30, 0.36, 1.0)
	wrap.add_theme_stylebox_override("panel", sb)

	var defs := TowerCatalogScript.create_all()
	var def = TowerCatalogScript.find_by_id(defs, tower_id)
	if def != null and def.visual_scene != null:
		var preview := PreviewScene.instantiate()
		preview.preview_size = Vector2i(int(size.x), int(size.y))
		preview.custom_minimum_size = size
		wrap.add_child(preview)
		preview.call_deferred("set_visual_scene", def.visual_scene)
		return wrap

	var root := Control.new()
	root.custom_minimum_size = size
	wrap.add_child(root)
	_draw_locked_preview(root, size)
	return wrap


static func make_level_preview(level_id: String, size: Vector2 = Vector2(220, 130)) -> Control:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.15, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	wrap.add_theme_stylebox_override("panel", sb)
	var root := Control.new()
	root.custom_minimum_size = size
	wrap.add_child(root)
	match level_id:
		"vertical_test":
			_draw_vertical_level(root, size)
		_:
			_draw_locked_preview(root, size)
	return wrap


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
	# Three stacked floor slabs with a zigzag path cue.
	_rect(root, Vector2(size.x * 0.18, size.y * 0.68), Vector2(size.x * 0.64, size.y * 0.12), Color(0.40, 0.42, 0.46))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.44), Vector2(size.x * 0.64, size.y * 0.12), Color(0.45, 0.48, 0.52))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.20), Vector2(size.x * 0.64, size.y * 0.12), Color(0.50, 0.54, 0.58))
	_rect(root, Vector2(size.x * 0.22, size.y * 0.72), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
	_rect(root, Vector2(size.x * 0.42, size.y * 0.48), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
	_rect(root, Vector2(size.x * 0.60, size.y * 0.24), Vector2(size.x * 0.18, size.y * 0.04), Color(0.95, 0.55, 0.25))
