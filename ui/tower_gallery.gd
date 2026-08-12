extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const TowerCardScript := preload("res://ui/components/tower_card.gd")

var _mode: String = "towers"
var _grid: GridContainer
var _tab_buttons: Array = []


func _ready() -> void:
	_mode = AppRouterScript.pending_gallery_mode if not AppRouterScript.pending_gallery_mode.is_empty() else "towers"
	UiStyleScript.apply_root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var rp := UiStyleScript.make_lv_rp_badge(
		ProfileManager.get_player_level(), ProfileManager.get_research_points()
	)
	UiStyleScript.make_top_bar(
		root,
		"GALLERY",
		func() -> void: AppRouterScript.go_main_menu(get_tree()),
		[rp]
	)

	var tabs := UiStyleScript.make_tab_row(
		PackedStringArray(["TOWERS", "ENEMIES"]),
		func(idx: int) -> void: _set_mode("towers" if idx == 0 else "enemies"),
		0 if _mode == "towers" else 1
	)
	_tab_buttons = tabs["buttons"]
	root.add_child(tabs["row"])

	var scroll_panel := UiStyleScript.make_scroll_panel()
	root.add_child(scroll_panel)
	var body := UiStyleScript.scroll_body(scroll_panel)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)
	_refresh()


func _set_mode(mode: String) -> void:
	_mode = mode
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	if _mode == "enemies":
		for def in EnemyCatalogScript.create_all():
			var card := TowerCardScript.new()
			card.setup_enemy(def)
			card.card_pressed.connect(func(eid: String) -> void: AppRouterScript.go_enemy_detail(get_tree(), eid))
			_grid.add_child(card)
	else:
		for def in TowerCatalogScript.create_all():
			var card := TowerCardScript.new()
			card.setup(def, TowerCardScript.Mode.GALLERY)
			card.card_pressed.connect(func(tid: String) -> void: AppRouterScript.go_detail(get_tree(), tid))
			_grid.add_child(card)
