extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")

var _enemy_id: String = "bot"
var _pages: Array = []
var _tab_buttons: Array = []


func _ready() -> void:
	_enemy_id = AppRouterScript.pending_enemy_id
	if _enemy_id.is_empty():
		_enemy_id = "bot"
	UiStyleScript.apply_root(self)

	var defs := EnemyCatalogScript.create_all()
	var def = EnemyCatalogScript.find_by_id(defs, _enemy_id)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	UiStyleScript.make_top_bar(
		root,
		str(def.display_name) if def else _enemy_id,
		func() -> void: AppRouterScript.go_gallery(get_tree(), "enemies")
	)

	var tabs := UiStyleScript.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	_tab_buttons = tabs["buttons"]
	root.add_child(tabs["row"])

	var overview := UiStyleScript.make_scroll_panel()
	root.add_child(overview)
	var ov := UiStyleScript.scroll_body(overview)
	_pages.append(overview)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	ov.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(360, 0)
	cols.add_child(left)

	var preview := PreviewScene.instantiate()
	preview.preview_size = Vector2i(340, 280)
	preview.custom_minimum_size = Vector2(340, 280)
	preview.zoom = 2.2
	left.add_child(preview)
	if def and def.visual_scene != null:
		preview.call_deferred("set_visual_scene", def.visual_scene)
	left.add_child(UiStyleScript.make_flat_label("Drag to rotate", 12, true))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	if def:
		right.add_child(UiStyleScript.make_flat_label(str(def.display_name), 28))
		right.add_child(UiStyleScript.make_flat_label(str(def.role), 15, true))
		right.add_child(UiStyleScript.make_label(str(def.long_description), 15))
		right.add_child(UiStyleScript.make_label(
			"HP %.0f · Speed %.1f · Melee %.0f / %.2fs · Reward %d" % [
				float(def.base_max_health),
				float(def.base_move_speed),
				float(def.base_melee_damage),
				float(def.base_melee_interval),
				int(def.reward),
			],
			14
		))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		for feature in FeatureCatalogScript.resolve_ids(def.feature_ids):
			chips.add_child(UiStyleScript.make_feature_chip(
				"%s — %s" % [feature.display_name, feature.short_description]
			))
		right.add_child(chips)

	var stats := UiStyleScript.make_scroll_panel()
	root.add_child(stats)
	var st := UiStyleScript.scroll_body(stats)
	_pages.append(stats)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	st.add_child(grid)
	var life: Dictionary = ProfileManager.get_enemy_lifetime(_enemy_id)
	var keys: PackedStringArray = def.stat_metric_keys if def else PackedStringArray(["encountered", "killed", "leaks"])
	for key in keys:
		grid.add_child(UiStyleScript.make_flat_label("%s: %s" % [str(key).capitalize(), str(life.get(key, 0))], 15))

	_show_tab(0)


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx
