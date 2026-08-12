extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const TowerCardScript := preload("res://ui/components/tower_card.gd")

@onready var _tab_row_host: HBoxContainer = %TabRowHost
@onready var _scroll_panel: PanelContainer = %ScrollPanel
@onready var _grid: GridContainer = %GridHost

var _mode: String = "towers"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	UiStyle.style_card_panel(_scroll_panel)
	_mode = AppRouterScript.pending_gallery_mode if not AppRouterScript.pending_gallery_mode.is_empty() else "towers"
	_setup_tabs()
	_refresh()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func _setup_tabs() -> void:
	for c in _tab_row_host.get_children():
		c.queue_free()
	var tabs := UiStyle.make_tab_row(
		PackedStringArray(["TOWERS", "ENEMIES"]),
		func(idx: int) -> void: _set_mode("towers" if idx == 0 else "enemies"),
		0 if _mode == "towers" else 1
	)
	_tab_row_host.add_child(tabs["row"])


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
