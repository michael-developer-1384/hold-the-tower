extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

const LEVEL_PLACEHOLDERS := [
	{"id": "ridge_run", "display_name": "Ridge Run", "description": "Open ridge assault (coming soon)"},
	{"id": "core_spire", "display_name": "Core Spire", "description": "Tight vertical climb (coming soon)"},
]

var _selected_level: String = "vertical_test"
var _selected_diff: String = "normal"
var _diff_btn: Button
var _info: Label
var _level_cards: Dictionary = {} # id -> PanelContainer
var _diff_dialog: AcceptDialog
var _diff_choice_row: HBoxContainer
var _diff_choice_buttons: Dictionary = {}


func _ready() -> void:
	UiStyleScript.apply_root(self)
	_selected_level = LevelCatalogScript.default_id()
	_selected_diff = DifficultyCatalogScript.default_id()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_diff_btn = UiStyleScript.make_compact_button(_diff_button_text(), 200, 40)
	_diff_btn.pressed.connect(_open_diff_dialog)
	var lv_rp := UiStyleScript.make_lv_rp_badge(
		ProfileManager.get_player_level(), ProfileManager.get_research_points()
	)
	UiStyleScript.make_top_bar(
		root,
		"PLAY",
		func() -> void: AppRouterScript.go_main_menu(get_tree()),
		[lv_rp, _diff_btn]
	)

	_info = UiStyleScript.make_flat_label("", 14, true)
	root.add_child(_info)

	var scroll_panel := UiStyleScript.make_scroll_panel()
	root.add_child(scroll_panel)
	var body := UiStyleScript.scroll_body(scroll_panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)

	for level in LevelCatalogScript.all():
		grid.add_child(_make_level_card(level, false))
	for ph in LEVEL_PLACEHOLDERS:
		grid.add_child(_make_level_card(ph, true))

	var start_row := HBoxContainer.new()
	root.add_child(start_row)
	var start_btn := UiStyleScript.make_compact_button("START RUN", 200, 52)
	start_btn.pressed.connect(_on_start)
	start_row.add_child(start_btn)

	_build_diff_dialog()
	_refresh_info()
	_refresh_level_selection()


func _diff_button_text() -> String:
	var d := DifficultyCatalogScript.find(_selected_diff)
	return "Difficulty: %s" % str(d.get("display_name", _selected_diff))


func _build_diff_dialog() -> void:
	_diff_dialog = AcceptDialog.new()
	_diff_dialog.title = "Difficulty"
	_diff_dialog.ok_button_text = "Apply"
	_diff_dialog.min_size = Vector2i(560, 320)
	UiStyleScript.style_modal(_diff_dialog)
	add_child(_diff_dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_diff_dialog.add_child(box)

	box.add_child(UiStyleScript.make_label(
		"Enemy HP, speed, and melee scale with difficulty. Core leak damage stays fixed.",
		13,
		true
	))

	_diff_choice_row = HBoxContainer.new()
	_diff_choice_row.add_theme_constant_override("separation", 10)
	box.add_child(_diff_choice_row)

	for d in DifficultyCatalogScript.all():
		var id := str(d["id"])
		var card := Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(120, 110)
		card.text = "%s\n%.2fx\n+%d RP" % [
			d["display_name"],
			float(d["multiplier"]),
			DifficultyCatalogScript.research_reward(id),
		]
		card.add_theme_font_size_override("font_size", 14)
		card.pressed.connect(func() -> void: _select_diff_choice(id))
		_diff_choice_row.add_child(card)
		_diff_choice_buttons[id] = card

	_diff_dialog.confirmed.connect(_on_diff_applied)
	_refresh_diff_choices()


func _select_diff_choice(id: String) -> void:
	_selected_diff = id
	_refresh_diff_choices()


func _refresh_diff_choices() -> void:
	for id in _diff_choice_buttons.keys():
		var b: Button = _diff_choice_buttons[id]
		var active := str(id) == _selected_diff
		b.button_pressed = active
		UiStyleScript.style_tab_button(b, active)
		b.disabled = false
		b.custom_minimum_size = Vector2(120, 110)


func _open_diff_dialog() -> void:
	_refresh_diff_choices()
	_diff_dialog.popup_centered()


func _on_diff_applied() -> void:
	_diff_btn.text = _diff_button_text()
	_refresh_info()


func _make_level_card(level: Dictionary, placeholder: bool) -> Control:
	var lid := str(level["id"])
	var unlocked := false if placeholder else ProfileManager.is_level_unlocked(lid)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 300)
	UiStyleScript.style_card_panel(card, false, placeholder or not unlocked)
	_level_cards[lid] = card

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(cv)

	cv.add_child(UiStyleScript.make_level_preview(lid if not placeholder else "locked", Vector2(220, 140)))
	cv.add_child(UiStyleScript.make_flat_label(str(level["display_name"]), 20))
	var desc := UiStyleScript.make_label(str(level.get("description", "")), 13, true)
	cv.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(spacer)

	if placeholder:
		cv.add_child(UiStyleScript.make_flat_label("Coming soon", 13, true))
		var locked := UiStyleScript.make_button("LOCKED", 40)
		locked.disabled = true
		cv.add_child(locked)
	else:
		var clears: Dictionary = ProfileManager.get_profile().get("level_clears", {})
		var best: Dictionary = ProfileManager.get_profile().get("best_results", {})
		cv.add_child(UiStyleScript.make_flat_label(
			("Unlocked" if unlocked else "Locked")
			+ ("  ·  Clears %d" % int(clears.get(lid, 0)))
			+ ("  ·  Best %s" % str(best.get(lid, "-")) if best.has(lid) else ""),
			12,
			true
		))
		var select := UiStyleScript.make_button("SELECT", 40)
		select.disabled = not unlocked
		if unlocked:
			select.pressed.connect(_select_level.bind(lid))
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb := event as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						_select_level(lid)
			)
		cv.add_child(select)
	return card


func _select_level(lid: String) -> void:
	if not ProfileManager.is_level_unlocked(lid):
		return
	_selected_level = lid
	_refresh_level_selection()


func _refresh_level_selection() -> void:
	for lid in _level_cards.keys():
		var card: PanelContainer = _level_cards[lid]
		var selected := str(lid) == _selected_level
		var placeholder := false
		for ph in LEVEL_PLACEHOLDERS:
			if str(ph["id"]) == str(lid):
				placeholder = true
				break
		var unlocked := false if placeholder else ProfileManager.is_level_unlocked(str(lid))
		UiStyleScript.style_card_panel(card, selected and unlocked, placeholder or not unlocked)
		# Update footer button text if present.
		var cv := card.get_child(0) as VBoxContainer
		if cv == null:
			continue
		var btn := cv.get_child(cv.get_child_count() - 1)
		if btn is Button and not (btn as Button).disabled:
			(btn as Button).text = "SELECTED" if selected else "SELECT"


func _refresh_info() -> void:
	var reward := DifficultyCatalogScript.research_reward(_selected_diff)
	var d := DifficultyCatalogScript.find(_selected_diff)
	_info.text = "Clear reward: +%d Research Points  ·  Enemy scale %.2fx" % [
		reward, float(d.get("multiplier", 1.0))
	]


func _on_start() -> void:
	if not ProfileManager.is_level_unlocked(_selected_level):
		return
	RunManager.configure(_selected_level, _selected_diff)
	AppRouterScript.go_game(get_tree())
