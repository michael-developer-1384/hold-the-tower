extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")

var _enemy_id: String = "bot"
var _pages: Array = []
var _def: Resource


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_enemy_id = AppRouterScript.pending_enemy_id
	if _enemy_id.is_empty():
		_enemy_id = "bot"
	var defs := EnemyCatalogScript.create_all()
	_def = EnemyCatalogScript.find_by_id(defs, _enemy_id)
	_build()
	_show_tab(0)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var back := UiStyle.make_compact_button("BACK", 90, 34, "ghost")
	back.pressed.connect(func() -> void:
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_back()
		AppRouterScript.go_database(get_tree(), "enemies")
	)
	top.add_child(back)
	var title := UiStyle.make_flat_label(
		str(_def.display_name) if _def else _enemy_id,
		UiTokens.FONT_PAGE,
		false
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	root.add_child(_build_hero())

	var tabs := UiStyle.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	root.add_child(tabs["row"])

	_pages.append(_build_overview(root))
	_pages.append(_build_statistics(root))


func _build_hero() -> PanelContainer:
	var panel := UiStyle.make_panel()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(320, 0)
	cols.add_child(left)

	var preview := PreviewScene.instantiate()
	preview.preview_size = Vector2i(300, 240)
	preview.custom_minimum_size = Vector2(300, 240)
	preview.zoom = 2.2
	left.add_child(preview)
	if _def and _def.visual_scene != null:
		preview.call_deferred("set_visual_scene", _def.visual_scene)
	left.add_child(UiStyle.make_flat_label("Drag to rotate", UiTokens.FONT_CAPTION, true))

	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(identity)
	if _def:
		identity.add_child(UiStyle.make_flat_label(str(_def.display_name), UiTokens.FONT_SECTION, false))
		identity.add_child(UiStyle.make_flat_label(str(_def.role), UiTokens.FONT_CAPTION, true))
		var desc := UiStyle.make_label(str(_def.long_description), UiTokens.FONT_BODY, false)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		identity.add_child(desc)
		identity.add_child(UiStyle.make_flat_label(
			"HP %.0f · Speed %.1f · Melee %.0f / %.2fs · Reward %d" % [
				float(_def.base_max_health),
				float(_def.base_move_speed),
				float(_def.base_melee_damage),
				float(_def.base_melee_interval),
				int(_def.reward),
			],
			UiTokens.FONT_DATA,
			false
		))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		for feature in FeatureCatalogScript.resolve_ids(_def.feature_ids):
			chips.add_child(UiStyle.make_feature_chip(
				"%s — %s" % [feature.display_name, feature.short_description]
			))
		identity.add_child(chips)

	var snap := UiStyle.make_panel()
	snap.custom_minimum_size = Vector2(240, 0)
	cols.add_child(snap)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 4)
	snap.add_child(scol)
	scol.add_child(UiStyle.make_section_label("BASE STATS"))
	if _def:
		scol.add_child(UiStyle.make_stat_row("HP", "%.0f" % float(_def.base_max_health)))
		scol.add_child(UiStyle.make_stat_row("Speed", "%.1f" % float(_def.base_move_speed)))
		scol.add_child(UiStyle.make_stat_row("Melee", "%.0f" % float(_def.base_melee_damage)))
		scol.add_child(UiStyle.make_stat_row("Interval", "%.2fs" % float(_def.base_melee_interval)))
		scol.add_child(UiStyle.make_stat_row("Reward", str(int(_def.reward))))
	return panel


func _build_overview(root: Control) -> Control:
	var overview := UiStyle.make_scroll_panel()
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(overview)
	var body := UiStyle.scroll_body(overview)
	if _def:
		body.add_child(UiStyle.make_section_label("ROLE"))
		body.add_child(UiStyle.make_flat_label(str(_def.role), UiTokens.FONT_BODY, false))
		body.add_child(UiStyle.make_section_label("DESCRIPTION"))
		var long := UiStyle.make_label(str(_def.long_description), UiTokens.FONT_BODY, false)
		long.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(long)
	else:
		body.add_child(UiStyle.make_flat_label("Unknown enemy.", UiTokens.FONT_BODY, true))
	return overview


func _build_statistics(root: Control) -> Control:
	var stats := UiStyle.make_scroll_panel()
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stats)
	var body := UiStyle.scroll_body(stats)
	body.add_child(UiStyle.make_section_label("LIFETIME"))
	var life: Dictionary = ProfileManager.get_enemy_lifetime(_enemy_id)
	var keys: PackedStringArray = _def.stat_metric_keys if _def else PackedStringArray(["encountered", "killed", "leaks"])
	for key in keys:
		body.add_child(UiStyle.make_stat_row(
			str(key).replace("_", " ").capitalize(),
			str(life.get(key, 0))
		))
	return stats


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx
