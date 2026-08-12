extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

const LEVEL_PLACEHOLDERS := [
	{"id": "ridge_run", "display_name": "Ridge Run", "description": "Open ridge assault (coming soon)"},
	{"id": "core_spire", "display_name": "Core Spire", "description": "Tight vertical climb (coming soon)"},
]

var _selected_level: String = "vertical_test"
var _selected_diff: String = "normal"
var _level_list: VBoxContainer
var _preview_host: Control
var _desc_label: Label
var _meta_label: Label
var _diff_buttons: Dictionary = {}
var _reward_label: Label
var _start_btn: Button
var _level_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_selected_level = LevelCatalogScript.default_id()
	_selected_diff = DifficultyCatalogScript.default_id()
	_build()
	_select_level(_selected_level, true)
	_refresh_diff()
	_refresh_start()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	root.add_child(UiStyle.make_flat_label("PLAY SETUP", UiTokens.FONT_PAGE, false))
	root.add_child(UiStyle.make_flat_label("Select a level, review the map, configure the run.", UiTokens.FONT_CAPTION, true))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	cols.add_child(_build_level_browser())
	cols.add_child(_build_preview_column())
	cols.add_child(_build_config_column())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	_start_btn = UiStyle.make_button("START RUN", 48, "primary")
	_start_btn.custom_minimum_size = Vector2(220, 48)
	_start_btn.pressed.connect(_on_start)
	bottom.add_child(_start_btn)


func _build_level_browser() -> PanelContainer:
	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("LEVELS"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_level_list = VBoxContainer.new()
	_level_list.add_theme_constant_override("separation", 8)
	_level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_level_list)

	for level in LevelCatalogScript.all():
		_level_list.add_child(_make_level_row(level, false))
	for ph in LEVEL_PLACEHOLDERS:
		_level_list.add_child(_make_level_row(ph, true))
	return panel


func _make_level_row(level: Dictionary, placeholder: bool) -> Control:
	var lid := str(level["id"])
	var unlocked := false if placeholder else ProfileManager.is_level_unlocked(lid)
	var btn := Button.new()
	btn.toggle_mode = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status := "COMING SOON" if placeholder else ("UNLOCKED" if unlocked else "LOCKED")
	btn.text = "%s\n%s" % [str(level.get("display_name", lid)), status]
	btn.disabled = placeholder or not unlocked
	btn.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	if unlocked and not placeholder:
		btn.pressed.connect(func() -> void: _select_level(lid))
	UiStyle.style_tab_button(btn, false)
	_level_buttons[lid] = btn
	return btn


func _build_preview_column() -> PanelContainer:
	var panel := UiStyle.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("MAP PREVIEW"))
	_preview_host = Control.new()
	_preview_host.custom_minimum_size = Vector2(0, 280)
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_preview_host)
	_desc_label = UiStyle.make_label("", UiTokens.FONT_BODY, false)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_desc_label)
	_meta_label = UiStyle.make_flat_label("", UiTokens.FONT_CAPTION, true)
	col.add_child(_meta_label)
	return panel


func _build_config_column() -> PanelContainer:
	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("RUN CONFIG"))
	col.add_child(UiStyle.make_flat_label("Difficulty", UiTokens.FONT_LABEL, true))
	col.add_child(UiStyle.make_flat_label(
		"Enemy HP, speed, and melee scale. Core leak damage stays fixed.",
		UiTokens.FONT_CAPTION,
		true
	))

	var diffs := VBoxContainer.new()
	diffs.add_theme_constant_override("separation", 8)
	col.add_child(diffs)
	for d in DifficultyCatalogScript.all():
		var id := str(d["id"])
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s  ·  %.2fx  ·  +%d RP" % [
			str(d.get("display_name", id)),
			float(d.get("multiplier", 1.0)),
			DifficultyCatalogScript.research_reward(id),
		]
		b.pressed.connect(func() -> void:
			_selected_diff = id
			_refresh_diff()
		)
		diffs.add_child(b)
		_diff_buttons[id] = b

	col.add_child(UiStyle.make_divider())
	_reward_label = UiStyle.make_flat_label("", UiTokens.FONT_BODY, false)
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_reward_label)
	return panel


func _select_level(lid: String, force: bool = false) -> void:
	if not force and not ProfileManager.is_level_unlocked(lid):
		return
	if _is_placeholder(lid):
		return
	_selected_level = lid
	for id in _level_buttons.keys():
		var b: Button = _level_buttons[id]
		var active := str(id) == _selected_level
		b.button_pressed = active
		UiStyle.style_tab_button(b, active)

	for c in _preview_host.get_children():
		c.queue_free()
	var level := LevelCatalogScript.find(lid)
	if level.is_empty():
		for ph in LEVEL_PLACEHOLDERS:
			if str(ph["id"]) == lid:
				level = ph
				break
	var preview := UiStyle.make_level_preview(lid, Vector2(420, 260))
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_host.add_child(preview)
	_desc_label.text = str(level.get("description", ""))
	var clears: Dictionary = ProfileManager.get_profile().get("level_clears", {})
	var best: Dictionary = ProfileManager.get_profile().get("best_results", {})
	_meta_label.text = "Clears %d%s" % [
		int(clears.get(lid, 0)),
		("  ·  Best %s" % str(best.get(lid, "-"))) if best.has(lid) else "",
	]
	_refresh_start()


func _refresh_diff() -> void:
	for id in _diff_buttons.keys():
		var b: Button = _diff_buttons[id]
		var active := str(id) == _selected_diff
		b.button_pressed = active
		UiStyle.style_tab_button(b, active)
	var d := DifficultyCatalogScript.find(_selected_diff)
	_reward_label.text = "Clear reward: +%d Research Points\nEnemy scale: %.2fx" % [
		DifficultyCatalogScript.research_reward(_selected_diff),
		float(d.get("multiplier", 1.0)),
	]


func _refresh_start() -> void:
	var ok := ProfileManager.is_level_unlocked(_selected_level) and not _is_placeholder(_selected_level)
	_start_btn.disabled = not ok


func _is_placeholder(lid: String) -> bool:
	for ph in LEVEL_PLACEHOLDERS:
		if str(ph["id"]) == lid:
			return true
	return false


func _on_start() -> void:
	if not ProfileManager.is_level_unlocked(_selected_level):
		return
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_accept()
	RunManager.configure(_selected_level, _selected_diff)
	AppRouterScript.go_game(get_tree(), false)
