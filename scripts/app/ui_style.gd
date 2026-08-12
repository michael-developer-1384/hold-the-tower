class_name UiStyle
extends RefCounted

const BG := Color(0.08, 0.09, 0.11, 1.0)
const PANEL := Color(0.14, 0.16, 0.20, 0.96)
const ACCENT := Color(0.35, 0.72, 0.85, 1.0)
const TEXT := Color(0.92, 0.94, 0.96, 1.0)
const MUTED := Color(0.65, 0.70, 0.76, 1.0)
const DANGER := Color(0.85, 0.35, 0.35, 1.0)
const CARD_LOCKED := Color(0.10, 0.11, 0.13, 0.96)


static func apply_root(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
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


static func make_button(text: String, min_h: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", 18)
	return b


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
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

	var root := Control.new()
	root.custom_minimum_size = size
	wrap.add_child(root)

	match tower_id:
		"basic_tower":
			_draw_basic_preview(root, size)
		"guard_post":
			_draw_guard_preview(root, size)
		_:
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


static func _draw_basic_preview(root: Control, size: Vector2) -> void:
	# Steel turret silhouette inspired by in-game Basic Tower.
	_rect(root, Vector2(size.x * 0.28, size.y * 0.62), Vector2(size.x * 0.44, size.y * 0.18), Color(0.35, 0.38, 0.42))
	_rect(root, Vector2(size.x * 0.38, size.y * 0.30), Vector2(size.x * 0.24, size.y * 0.36), Color(0.45, 0.52, 0.58))
	_rect(root, Vector2(size.x * 0.46, size.y * 0.18), Vector2(size.x * 0.28, size.y * 0.10), Color(0.55, 0.72, 0.82))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.78), Vector2(size.x * 0.64, size.y * 0.06), Color(0.28, 0.30, 0.34))


static func _draw_guard_preview(root: Control, size: Vector2) -> void:
	# Brown post + two guard silhouettes.
	_rect(root, Vector2(size.x * 0.36, size.y * 0.42), Vector2(size.x * 0.28, size.y * 0.36), Color(0.42, 0.30, 0.22))
	_rect(root, Vector2(size.x * 0.32, size.y * 0.34), Vector2(size.x * 0.36, size.y * 0.10), Color(0.55, 0.38, 0.28))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.48), Vector2(size.x * 0.14, size.y * 0.30), Color(0.55, 0.38, 0.28))
	_rect(root, Vector2(size.x * 0.20, size.y * 0.40), Vector2(size.x * 0.10, size.y * 0.10), Color(0.70, 0.50, 0.38))
	_rect(root, Vector2(size.x * 0.68, size.y * 0.48), Vector2(size.x * 0.14, size.y * 0.30), Color(0.55, 0.38, 0.28))
	_rect(root, Vector2(size.x * 0.70, size.y * 0.40), Vector2(size.x * 0.10, size.y * 0.10), Color(0.70, 0.50, 0.38))
	_rect(root, Vector2(size.x * 0.18, size.y * 0.78), Vector2(size.x * 0.64, size.y * 0.06), Color(0.28, 0.30, 0.34))


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
