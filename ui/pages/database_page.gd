extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const TowerCardScript := preload("res://ui/components/tower_card.gd")

var _mode: String = "towers"
var _grid: GridContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_mode = AppRouterScript.pending_gallery_mode if not AppRouterScript.pending_gallery_mode.is_empty() else "towers"
	_build()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


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

	root.add_child(UiStyle.make_flat_label("DATABASE", UiTokens.FONT_PAGE, false))
	root.add_child(UiStyle.make_flat_label("Inspect towers and enemies. Research lives on tower detail.", UiTokens.FONT_CAPTION, true))

	var tabs := UiStyle.make_tab_row(
		PackedStringArray(["TOWERS", "ENEMIES"]),
		func(idx: int) -> void: _set_mode("towers" if idx == 0 else "enemies"),
		0 if _mode == "towers" else 1
	)
	root.add_child(tabs["row"])

	var scroll_panel := UiStyle.make_scroll_panel()
	scroll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll_panel)
	var body := UiStyle.scroll_body(scroll_panel)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)
	_refresh()


func _set_mode(mode: String) -> void:
	_mode = mode
	AppRouterScript.pending_gallery_mode = mode
	_refresh()


func _on_resized() -> void:
	if _grid == null:
		return
	var cols := UiStyle.gallery_columns(size.x)
	if _grid.columns != cols:
		_grid.columns = cols


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_grid.columns = UiStyle.gallery_columns(size.x)
	if _mode == "enemies":
		for def in EnemyCatalogScript.create_all():
			var card := TowerCardScript.new()
			card.setup_enemy(def)
			card.card_pressed.connect(func(eid: String) -> void:
				AppRouterScript.go_enemy_detail(get_tree(), eid)
			)
			_grid.add_child(card)
	else:
		for def in TowerCatalogScript.create_all():
			var card := TowerCardScript.new()
			card.setup(def, TowerCardScript.Mode.GALLERY)
			card.card_pressed.connect(func(tid: String) -> void:
				AppRouterScript.go_detail(get_tree(), tid)
			)
			_grid.add_child(card)
