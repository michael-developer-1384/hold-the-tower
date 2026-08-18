extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const MarketConfigScript := preload("res://scripts/market/market_config.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")
const StatTableRowScene := preload("res://ui/components/stat_table_row.tscn")
const LevelPreviewScene := preload("res://ui/components/level_preview_3d.tscn")
const LevelCardScene := preload("res://ui/components/level_selection_card.tscn")

const LEVEL_PLACEHOLDERS := [
	{"id": "ridge_run", "display_name": "Ridge Run", "description": "Open ridge assault (coming soon)"},
	{"id": "core_spire", "display_name": "Core Spire", "description": "Tight vertical climb (coming soon)"},
]

@onready var _level_list: VBoxContainer = %LevelListHost
@onready var _preview_host: Control = %PreviewHost
@onready var _desc_label: Label = %DescLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _diff_list: VBoxContainer = %DiffListHost
@onready var _modifier_host: VBoxContainer = %ModifierHost
@onready var _reward_label: Label = %RewardLabel
@onready var _start_btn: Button = %StartRun
@onready var _level_browser: PanelContainer = %LevelBrowser
@onready var _preview_column: PanelContainer = %PreviewColumn
@onready var _config_column: PanelContainer = %ConfigColumn

var _selected_level: String = "vertical_test"
var _selected_diff: String = "normal"
var _diff_buttons: Dictionary = {}
var _level_buttons: Dictionary = {}
var _preview: Node


func _ready() -> void:
	UiStyle.apply_theme(self)
	_style_panels()
	_style_start()
	_selected_level = LevelCatalogScript.default_id()
	_selected_diff = DifficultyCatalogScript.default_id()
	_build_level_list()
	_build_diff_list()
	_setup_preview()
	_select_level(_selected_level, true)
	_refresh_diff()
	_refresh_start()
	_start_btn.pressed.connect(_on_start)
	call_deferred("_focus_start")


func _style_panels() -> void:
	for panel in [_level_browser, _preview_column, _config_column]:
		UiStyle.style_card_panel(panel)


func _style_start() -> void:
	UiStyle._style_button(_start_btn, "primary")
	_start_btn.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)


func _build_level_list() -> void:
	for level in LevelCatalogScript.all():
		_level_list.add_child(_make_level_row(level, false))
	for ph in LEVEL_PLACEHOLDERS:
		_level_list.add_child(_make_level_row(ph, true))


func _make_level_row(level: Dictionary, placeholder: bool) -> Control:
	var lid := str(level["id"])
	var unlocked := false if placeholder else ProfileManager.is_level_unlocked(lid)
	var card := LevelCardScene.instantiate()
	card.setup(level, placeholder, unlocked)
	if unlocked and not placeholder:
		card.level_selected.connect(func(id: String) -> void: _select_level(id))
	_level_buttons[lid] = card
	return card


func _build_diff_list() -> void:
	for d in DifficultyCatalogScript.all():
		var id := str(d["id"])
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = StatPresentationScript.display_difficulty(id)
		b.pressed.connect(func() -> void:
			_selected_diff = id
			_refresh_diff()
		)
		_diff_list.add_child(b)
		_diff_buttons[id] = b


func _setup_preview() -> void:
	if ResourceLoader.exists("res://ui/components/level_preview_3d.tscn"):
		_preview = LevelPreviewScene.instantiate()
	else:
		const LevelPreviewScript := preload("res://ui/components/level_preview_3d.gd")
		_preview = LevelPreviewScript.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_host.add_child(_preview)


func _select_level(lid: String, force: bool = false) -> void:
	if not force and not ProfileManager.is_level_unlocked(lid):
		return
	if _is_placeholder(lid):
		return
	_selected_level = lid
	for id in _level_buttons.keys():
		var b = _level_buttons[id]
		var active := str(id) == _selected_level
		if b.has_method("set_active"):
			b.call("set_active", active)
		else:
			b.button_pressed = active
			UiStyle.style_tab_button(b, active)

	var level := LevelCatalogScript.find(lid)
	if level.is_empty():
		for ph in LEVEL_PLACEHOLDERS:
			if str(ph["id"]) == lid:
				level = ph
				break

	if _preview.has_method("show_level"):
		_preview.call("show_level", lid)
	elif _preview.has_method("show_locked"):
		_preview.call("show_locked")

	_desc_label.text = str(level.get("description", ""))
	var clears: Dictionary = ProfileManager.get_profile().get("level_clears", {})
	var best: Dictionary = ProfileManager.get_profile().get("best_results", {})
	var best_txt := ""
	if best.has(lid):
		var best_id := str(best.get(lid, ""))
		best_txt = "  ·  Best %s" % StatPresentationScript.display_difficulty(best_id)
	_meta_label.text = "Clears %d%s" % [int(clears.get(lid, 0)), best_txt]
	_refresh_start()


func _refresh_diff() -> void:
	for id in _diff_buttons.keys():
		var b: Button = _diff_buttons[id]
		var active := str(id) == _selected_diff
		b.button_pressed = active
		UiStyle.style_tab_button(b, active)

	for c in _modifier_host.get_children():
		c.queue_free()
	for row in StatPresentationScript.format_difficulty_modifiers(_selected_diff):
		var stat_row := StatTableRowScene.instantiate()
		_modifier_host.add_child(stat_row)
		stat_row.setup(str(row.get("label", "")), str(row.get("value", "")))

	for item in [
		["Risk Notional", MoneyDisplayScript.usd_cents(MarketConfigScript.risk_notional_cents(_selected_diff))],
		["Exposure", "1.0x"],
		["Starting Buying Power", MoneyDisplayScript.usd(MarketConfigScript.STARTING_BUYING_POWER)],
	]:
		var exposure_row := StatTableRowScene.instantiate()
		_modifier_host.add_child(exposure_row)
		exposure_row.setup(str(item[0]), str(item[1]))

	_reward_label.text = "Portfolio P/L = Risk Notional × Session Return. Research is earned by pushing HODL to a new ATH."


func _refresh_start() -> void:
	var ok := ProfileManager.is_level_unlocked(_selected_level) and not _is_placeholder(_selected_level)
	_start_btn.disabled = not ok


func _is_placeholder(lid: String) -> bool:
	for ph in LEVEL_PLACEHOLDERS:
		if str(ph["id"]) == lid:
			return true
	return false


func _focus_start() -> void:
	if not _start_btn.disabled:
		_start_btn.grab_focus()


func _on_start() -> void:
	if not ProfileManager.is_level_unlocked(_selected_level):
		return
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_accept()
	RunManager.configure(_selected_level, _selected_diff)
	AppRouterScript.go_game(get_tree(), false)
