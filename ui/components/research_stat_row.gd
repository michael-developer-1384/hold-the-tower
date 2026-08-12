extends PanelContainer

## Compact research stat card: current/draft, RP slider with locked region, ± buttons.

signal allocation_changed(stat_id: String, invested: int)

const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const UiStyleScript := preload("res://scripts/app/ui_style.gd")

var stat_id: String = ""
var _spec: Dictionary = {}
var _player_level: int = 1
var _committed: int = 0
var _draft: int = 0
var _level_cap: int = 0
var _max_rp: int = 1

var _title: Label
var _current_l: Label
var _draft_l: Label
var _pct_l: Label
var _invest_l: Label
var _track: Control
var _dragging := false


func setup(spec: Dictionary, player_level: int) -> void:
	_spec = spec
	stat_id = str(spec.get("id", ""))
	_player_level = player_level
	_max_rp = maxi(1, int(spec.get("max_investment_rp", 1)))
	_level_cap = ResearchResolverScript.level_cap_for_stat(spec, player_level)
	_build_ui()


func set_values(committed: int, draft: int) -> void:
	_committed = committed
	_draft = clampi(draft, 0, _level_cap)
	_refresh_labels()
	if _track:
		_track.queue_redraw()


func get_draft() -> int:
	return _draft


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.17, 0.98)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_color = Color(0.22, 0.26, 0.32, 1.0)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 112)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var title_txt := str(_spec.get("display_name", stat_id)).to_upper()
	if bool(_spec.get("lower_is_better", false)):
		title_txt += "  ↓"
	_title = UiStyleScript.make_flat_label(title_txt, 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_pct_l = UiStyleScript.make_flat_label("", 12, true)
	head.add_child(_pct_l)

	var vals := HBoxContainer.new()
	vals.add_theme_constant_override("separation", 16)
	col.add_child(vals)
	_current_l = UiStyleScript.make_flat_label("", 15)
	vals.add_child(_current_l)
	vals.add_child(UiStyleScript.make_flat_label("→", 14, true))
	_draft_l = UiStyleScript.make_flat_label("", 15)
	vals.add_child(_draft_l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vals.add_child(spacer)
	_invest_l = UiStyleScript.make_flat_label("", 11, true)
	vals.add_child(_invest_l)

	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 22)
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track.mouse_filter = Control.MOUSE_FILTER_STOP
	_track.draw.connect(_draw_track)
	_track.gui_input.connect(_on_track_input)
	_track.tooltip_text = str(_spec.get("description", ""))
	col.add_child(_track)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	col.add_child(btns)
	for step in [-5, -1]:
		var b := UiStyleScript.make_compact_button("%+d" % step, 40, 28)
		var s: int = int(step)
		b.pressed.connect(func() -> void: _nudge(s))
		btns.add_child(b)
	var mid := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(mid)
	for step2 in [1, 5]:
		var b2 := UiStyleScript.make_compact_button("%+d" % step2, 40, 28)
		var s2: int = int(step2)
		b2.pressed.connect(func() -> void: _nudge(s2))
		btns.add_child(b2)


func _nudge(delta: int) -> void:
	_set_draft(_draft + delta)


func _set_draft(v: int) -> void:
	var nxt := clampi(v, 0, _level_cap)
	if nxt == _draft:
		return
	_draft = nxt
	_refresh_labels()
	_track.queue_redraw()
	allocation_changed.emit(stat_id, _draft)


func _refresh_labels() -> void:
	var cur_v := ResearchResolverScript.value_for(_spec, _committed)
	var draft_v := ResearchResolverScript.value_for(_spec, _draft)
	_current_l.text = "CUR %s" % ResearchResolverScript.format_value(_spec, cur_v)
	_draft_l.text = "DRAFT %s" % ResearchResolverScript.format_value(_spec, draft_v)
	_pct_l.text = ResearchResolverScript.format_delta_label(_spec, cur_v, draft_v)
	_invest_l.text = "%d / %d RP  (max %d)" % [_draft, _level_cap, _max_rp]
	if _level_cap < _max_rp:
		var unlock_lvl := ResearchResolverScript.level_unlock_for_investment(_spec, _level_cap + 1)
		_track.tooltip_text = "%s\nUnlocks more at Player Level %d" % [
			str(_spec.get("description", "")), unlock_lvl
		]


func _draw_track() -> void:
	var r := Rect2(Vector2.ZERO, _track.size)
	if r.size.x < 4.0:
		return
	var pad := 1.0
	var bar := Rect2(pad, r.size.y * 0.3, r.size.x - pad * 2.0, r.size.y * 0.4)
	_track.draw_rect(bar, Color(0.18, 0.20, 0.26), true)
	var avail_w := bar.size.x * (float(_level_cap) / float(_max_rp))
	var filled_w := bar.size.x * (float(_draft) / float(_max_rp))
	_track.draw_rect(Rect2(bar.position, Vector2(avail_w, bar.size.y)), Color(0.25, 0.40, 0.55), true)
	_track.draw_rect(Rect2(bar.position, Vector2(filled_w, bar.size.y)), Color(0.42, 0.78, 0.55), true)
	if _level_cap < _max_rp:
		var lock_x := bar.position.x + avail_w
		_track.draw_rect(
			Rect2(Vector2(lock_x, bar.position.y), Vector2(bar.end.x - lock_x, bar.size.y)),
			Color(0.12, 0.12, 0.14, 0.9),
			true
		)
		_track.draw_line(
			Vector2(lock_x, bar.position.y - 3.0),
			Vector2(lock_x, bar.end.y + 3.0),
			Color(0.92, 0.72, 0.28),
			2.0
		)


func _on_track_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_apply_track_x(mb.position.x)
	elif event is InputEventMouseMotion and _dragging:
		_apply_track_x((event as InputEventMouseMotion).position.x)


func _apply_track_x(x: float) -> void:
	var w := maxf(_track.size.x, 1.0)
	var t := clampf(x / w, 0.0, 1.0)
	var raw := int(round(t * float(_max_rp)))
	_set_draft(raw)
