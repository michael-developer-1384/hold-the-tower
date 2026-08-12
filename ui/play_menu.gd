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
var _level_cards: Dictionary = {}
var _diff_dialog: AcceptDialog
var _diff_option: OptionButton


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

	_diff_btn = UiStyleScript.make_button(_diff_button_text(), 40)
	_diff_btn.custom_minimum_size = Vector2(180, 40)
	_diff_btn.pressed.connect(_open_diff_dialog)
	UiStyleScript.make_top_bar(
		root,
		"PLAY",
		func() -> void: AppRouterScript.go_main_menu(get_tree()),
		[_diff_btn]
	)

	_info = UiStyleScript.make_flat_label("", 15, true)
	root.add_child(_info)

	var scroll_panel := UiStyleScript.make_scroll_panel()
	root.add_child(scroll_panel)
	var body := UiStyleScript.scroll_body(scroll_panel)
	body.add_child(UiStyleScript.make_flat_label("LEVEL SELECT", 14, true))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)

	for level in LevelCatalogScript.all():
		grid.add_child(_make_level_card(level, false))
	for ph in LEVEL_PLACEHOLDERS:
		grid.add_child(_make_level_card(ph, true))

	var start_btn := UiStyleScript.make_button("START RUN", 56)
	start_btn.pressed.connect(_on_start)
	root.add_child(start_btn)

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
	_diff_dialog.dialog_autowrap = true
	_diff_dialog.dialog_text = "Enemy HP, speed, and melee scale with difficulty. Core leak damage stays fixed."
	add_child(_diff_dialog)

	_diff_option = OptionButton.new()
	_diff_option.custom_minimum_size = Vector2(320, 40)
	var idx := 0
	for d in DifficultyCatalogScript.all():
		var id := str(d["id"])
		_diff_option.add_item("%s  (%.2fx)  — clear +%d RP" % [
			d["display_name"], d["multiplier"], DifficultyCatalogScript.research_reward(id)
		], idx)
		_diff_option.set_item_metadata(idx, id)
		if id == _selected_diff:
			_diff_option.select(idx)
		idx += 1
	_diff_dialog.add_child(_diff_option)
	_diff_dialog.confirmed.connect(_on_diff_applied)


func _open_diff_dialog() -> void:
	for i in _diff_option.item_count:
		if str(_diff_option.get_item_metadata(i)) == _selected_diff:
			_diff_option.select(i)
			break
	_diff_dialog.popup_centered()


func _on_diff_applied() -> void:
	var i := _diff_option.selected
	_selected_diff = str(_diff_option.get_item_metadata(i))
	_diff_btn.text = _diff_button_text()
	_refresh_info()


func _make_level_card(level: Dictionary, placeholder: bool) -> Control:
	var lid := str(level["id"])
	var unlocked := false if placeholder else ProfileManager.is_level_unlocked(lid)
	var card := UiStyleScript.make_panel()
	card.custom_minimum_size = Vector2(280, 280)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)

	cv.add_child(UiStyleScript.make_level_preview(lid if not placeholder else "locked"))
	cv.add_child(UiStyleScript.make_flat_label(str(level["display_name"]), 20))
	cv.add_child(UiStyleScript.make_label(str(level.get("description", "")), 13, true))

	if placeholder:
		cv.add_child(UiStyleScript.make_flat_label("Coming soon", 14, true))
		var locked := UiStyleScript.make_button("LOCKED")
		locked.disabled = true
		cv.add_child(locked)
	else:
		var clears: Dictionary = ProfileManager.get_profile().get("level_clears", {})
		var best: Dictionary = ProfileManager.get_profile().get("best_results", {})
		cv.add_child(UiStyleScript.make_flat_label(
			("Unlocked" if unlocked else "Locked")
			+ ("  |  Clears: %d" % int(clears.get(lid, 0)))
			+ ("  |  Best: %s" % str(best.get(lid, "-")) if best.has(lid) else ""),
			13,
			true
		))
		var select := UiStyleScript.make_button("SELECTED" if lid == _selected_level else "SELECT")
		select.disabled = not unlocked
		select.toggle_mode = true
		select.button_pressed = lid == _selected_level
		select.pressed.connect(_select_level.bind(lid))
		_level_cards[lid] = select
		cv.add_child(select)
	return card


func _select_level(lid: String) -> void:
	if not ProfileManager.is_level_unlocked(lid):
		return
	_selected_level = lid
	_refresh_level_selection()


func _refresh_level_selection() -> void:
	for lid in _level_cards.keys():
		var b: Button = _level_cards[lid]
		var selected := str(lid) == _selected_level
		b.button_pressed = selected
		b.text = "SELECTED" if selected else "SELECT"


func _refresh_info() -> void:
	var reward := DifficultyCatalogScript.research_reward(_selected_diff)
	var d := DifficultyCatalogScript.find(_selected_diff)
	_info.text = "Clear reward on this difficulty: +%d Research Points (%.2fx enemies)" % [
		reward, float(d.get("multiplier", 1.0))
	]


func _on_start() -> void:
	if not ProfileManager.is_level_unlocked(_selected_level):
		return
	RunManager.configure(_selected_level, _selected_diff)
	AppRouterScript.go_game(get_tree())
