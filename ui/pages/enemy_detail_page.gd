extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const StatTableRowScene := preload("res://ui/components/stat_table_row.tscn")

@onready var _back_btn: Button = %BackBtn
@onready var _title_label: Label = %TitleLabel
@onready var _hero_panel: PanelContainer = %HeroPanel
@onready var _preview: Control = %PreviewHost
@onready var _display_name: Label = %DisplayNameLabel
@onready var _role: Label = %RoleLabel
@onready var _desc: Label = %DescLabel
@onready var _combat_summary: Label = %CombatSummaryLabel
@onready var _chips_host: HFlowContainer = %ChipsHost
@onready var _snapshot_panel: PanelContainer = %SnapshotPanel
@onready var _base_stats_host: VBoxContainer = %BaseStatsHost
@onready var _tab_row_host: HBoxContainer = %TabRowHost
@onready var _tab_overview: PanelContainer = %TabOverview
@onready var _overview_role: Label = %OverviewRoleLabel
@onready var _overview_desc: Label = %OverviewDescLabel
@onready var _unknown_label: Label = %UnknownLabel
@onready var _tab_statistics: PanelContainer = %TabStatistics
@onready var _lifetime_host: VBoxContainer = %LifetimeHost

var _enemy_id: String = "bot"
var _pages: Array = []
var _def: Resource


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	UiStyle.style_card_panel(_hero_panel)
	UiStyle.style_card_panel(_snapshot_panel)
	UiStyle.style_card_panel(_tab_overview)
	UiStyle.style_card_panel(_tab_statistics)
	_enemy_id = AppRouterScript.pending_enemy_id
	if _enemy_id.is_empty():
		_enemy_id = "bot"
	var defs := EnemyCatalogScript.create_all()
	_def = EnemyCatalogScript.find_by_id(defs, _enemy_id)
	_bind_static()
	_setup_tabs()
	_back_btn.pressed.connect(_on_back)
	_show_tab(0)
	_back_btn.grab_focus()


func _bind_static() -> void:
	var name_text := str(_def.display_name) if _def else _enemy_id
	_title_label.text = name_text
	_display_name.text = name_text
	if _def:
		_role.text = str(_def.role)
		_desc.text = str(_def.long_description)
		_overview_role.text = str(_def.role)
		_overview_desc.text = str(_def.long_description)
		_unknown_label.visible = false
		_combat_summary.text = "%s · %s · %s · %s · %s" % [
			StatPresentationScript.format_value("base_max_health", float(_def.base_max_health)),
			StatPresentationScript.format_value("base_move_speed", float(_def.base_move_speed)),
			StatPresentationScript.format_value("base_melee_damage", float(_def.base_melee_damage)),
			StatPresentationScript.format_value("base_melee_interval", float(_def.base_melee_interval)),
			StatPresentationScript.format_value("reward", float(_def.reward)),
		]
		if _def.visual_scene != null:
			_preview.call_deferred("set_visual_scene", _def.visual_scene)
		_preview.preview_size = Vector2i(300, 240)
		_preview.custom_minimum_size = Vector2(300, 240)
		_preview.zoom = 1.5
		for feature in FeatureCatalogScript.resolve_ids(_def.feature_ids):
			_chips_host.add_child(UiStyle.make_feature_chip(
				"%s — %s" % [feature.display_name, feature.short_description]
			))
		_fill_base_stats()
	else:
		_unknown_label.visible = true
	_fill_lifetime_stats()


func _fill_base_stats() -> void:
	for c in _base_stats_host.get_children():
		c.queue_free()
	if _def == null:
		return
	var keys: PackedStringArray = PackedStringArray([
		"base_max_health",
		"base_move_speed",
		"base_melee_damage",
		"base_melee_interval",
		"reward",
	])
	for key in keys:
		var row := StatTableRowScene.instantiate()
		row.setup_stat(key, _enemy_stat_value(key))
		_base_stats_host.add_child(row)


func _enemy_stat_value(key: String) -> float:
	match key:
		"base_max_health":
			return float(_def.base_max_health)
		"base_move_speed":
			return float(_def.base_move_speed)
		"base_melee_damage":
			return float(_def.base_melee_damage)
		"base_melee_interval":
			return float(_def.base_melee_interval)
		"reward":
			return float(_def.reward)
		_:
			return 0.0


func _fill_lifetime_stats() -> void:
	for c in _lifetime_host.get_children():
		c.queue_free()
	var life: Dictionary = ProfileManager.get_enemy_lifetime(_enemy_id)
	var keys: PackedStringArray = _def.stat_metric_keys if _def else PackedStringArray(["encountered", "killed", "leaks"])
	for key in keys:
		var row := StatTableRowScene.instantiate()
		row.setup_stat(str(key), float(life.get(key, 0)))
		_lifetime_host.add_child(row)


func _setup_tabs() -> void:
	_pages = [_tab_overview, _tab_statistics]
	var tabs := UiStyle.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	_tab_row_host.add_child(tabs["row"])


func _on_back() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_back()
	AppRouterScript.back()


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx
