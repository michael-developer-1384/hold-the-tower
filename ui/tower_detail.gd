extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchCostScript := preload("res://scripts/meta/research_cost.gd")
const BlueprintResolverScript := preload("res://scripts/meta/blueprint_resolver.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")

var _tower_id: String = "basic_tower"
var _edit_params: Dictionary = {}
var _value_labels: Dictionary = {}
var _status_label: Label
var _rp_label: Label
var _research_cost_label: Label
var _pages: Array = []
var _bp_chip_row: HBoxContainer
var _selected_bp: String = ""
var _def: Resource
var _bp_dialog: AcceptDialog
var _bp_name_edit: LineEdit
var _bp_list: VBoxContainer
var _tab_buttons: Array = []


func _ready() -> void:
	_tower_id = AppRouterScript.pending_tower_id
	if _tower_id.is_empty():
		_tower_id = "basic_tower"
	_edit_params = ProfileManager.get_tower_research_params(_tower_id)
	_selected_bp = ProfileManager.get_active_blueprint_id(_tower_id)
	UiStyleScript.apply_root(self)

	var defs := TowerCatalogScript.create_all()
	_def = TowerCatalogScript.find_by_id(defs, _tower_id)

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

	_rp_label = UiStyleScript.make_rp_badge(ProfileManager.get_research_points())
	UiStyleScript.make_top_bar(
		root,
		str(_def.display_name) if _def else _tower_id,
		func() -> void: AppRouterScript.go_gallery(get_tree(), "towers"),
		[_rp_label]
	)

	var tabs := UiStyleScript.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS", "RESEARCH"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	_tab_buttons = tabs["buttons"]
	root.add_child(tabs["row"])

	_pages.append(_build_overview(root))
	_pages.append(_build_statistics(root))
	_pages.append(_build_research(root))
	_build_blueprint_dialog()
	_show_tab(0)
	_refresh_research_labels()
	_refresh_blueprint_chips()


func _build_overview(root: Control) -> Control:
	var overview := UiStyleScript.make_scroll_panel()
	root.add_child(overview)
	var body := UiStyleScript.scroll_body(overview)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(360, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cols.add_child(left)

	var preview := PreviewScene.instantiate()
	preview.preview_size = Vector2i(340, 280)
	preview.custom_minimum_size = Vector2(340, 280)
	preview.zoom = 2.2
	left.add_child(preview)
	if _def and _def.visual_scene != null:
		preview.call_deferred("set_visual_scene", _def.visual_scene)
	left.add_child(UiStyleScript.make_flat_label("Drag to rotate", 12, true))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	if _def:
		right.add_child(UiStyleScript.make_flat_label(str(_def.display_name), 28))
		right.add_child(UiStyleScript.make_flat_label("%s · %d Gold" % [str(_def.role), int(_def.cost)], 15, true))
		right.add_child(UiStyleScript.make_label(str(_def.long_description), 15))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		for feature in FeatureCatalogScript.resolve_ids(_def.feature_ids):
			chips.add_child(UiStyleScript.make_feature_chip(
				"%s — %s" % [feature.display_name, feature.short_description]
			))
		right.add_child(chips)

		var resolved := BlueprintResolverScript.resolve(_tower_id, {
			"id": "research",
			"params": ProfileManager.get_tower_research_params(_tower_id),
		})
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 4)
		right.add_child(UiStyleScript.make_flat_label("Research stats", 16))
		right.add_child(stats_box)
		for k in resolved.keys():
			if k in ["tower_id", "blueprint_id", "blueprint_name", "cost", "guard_count"]:
				continue
			stats_box.add_child(UiStyleScript.make_flat_label("%s: %s" % [str(k), str(resolved[k])], 14, true))
	return overview


func _build_statistics(root: Control) -> Control:
	var stats := UiStyleScript.make_scroll_panel()
	root.add_child(stats)
	var body := UiStyleScript.scroll_body(stats)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	var life: Dictionary = ProfileManager.get_tower_lifetime(_tower_id)
	var keys: PackedStringArray = _def.stat_metric_keys if _def else PackedStringArray()
	if keys.is_empty():
		keys = PackedStringArray(["times_built", "kills", "damage_dealt"])
	for key in keys:
		var val = life.get(key, 0)
		grid.add_child(UiStyleScript.make_flat_label(
			"%s: %s" % [key.replace("_", " ").capitalize(), str(val)], 15
		))
	return stats


func _build_research(root: Control) -> Control:
	var page := UiStyleScript.make_scroll_panel()
	root.add_child(page)
	var body := UiStyleScript.scroll_body(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	header.add_child(UiStyleScript.make_flat_label("Research values apply to the next match.", 13, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_research_cost_label = UiStyleScript.make_flat_label("", 13)
	header.add_child(_research_cost_label)

	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 8)
	stats_col.custom_minimum_size = Vector2(560, 0)
	stats_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(stats_col)

	for spec in ResearchConfigScript.specs_for(_tower_id):
		var sid := str(spec["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stats_col.add_child(row)
		var name_l := UiStyleScript.make_flat_label(str(spec.get("display_name", sid)), 14)
		name_l.custom_minimum_size = Vector2(160, 0)
		row.add_child(name_l)
		var minus := UiStyleScript.make_compact_button("-", 36, 32)
		minus.pressed.connect(func() -> void: _step_stat(sid, -1))
		row.add_child(minus)
		var val_l := UiStyleScript.make_flat_label("", 14)
		val_l.custom_minimum_size = Vector2(180, 0)
		_value_labels[sid] = val_l
		row.add_child(val_l)
		var plus := UiStyleScript.make_compact_button("+", 36, 32)
		plus.pressed.connect(func() -> void: _step_stat(sid, 1))
		row.add_child(plus)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	var apply := UiStyleScript.make_compact_button("APPLY RESEARCH", 180, 42)
	apply.pressed.connect(_apply_research)
	actions.add_child(apply)
	_status_label = UiStyleScript.make_flat_label("", 13, true)
	actions.add_child(_status_label)

	var bp_header := HBoxContainer.new()
	bp_header.add_theme_constant_override("separation", 8)
	body.add_child(bp_header)
	bp_header.add_child(UiStyleScript.make_flat_label("Blueprints", 16))
	_bp_chip_row = HBoxContainer.new()
	_bp_chip_row.add_theme_constant_override("separation", 6)
	bp_header.add_child(_bp_chip_row)
	var add_bp := UiStyleScript.make_compact_button("+", 40, 36)
	add_bp.tooltip_text = "Manage blueprints"
	add_bp.pressed.connect(func() -> void: _bp_dialog.popup_centered(Vector2i(480, 420)))
	bp_header.add_child(add_bp)
	return page


func _build_blueprint_dialog() -> void:
	_bp_dialog = AcceptDialog.new()
	_bp_dialog.title = "Blueprints"
	_bp_dialog.ok_button_text = "Close"
	_bp_dialog.min_size = Vector2i(480, 420)
	UiStyleScript.style_modal(_bp_dialog)
	add_child(_bp_dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bp_dialog.add_child(box)

	box.add_child(UiStyleScript.make_label(
		"Save the current research draft, or activate a named blueprint into research (RP delta applies).",
		13,
		true
	))
	_bp_name_edit = LineEdit.new()
	_bp_name_edit.placeholder_text = "Blueprint name"
	_bp_name_edit.custom_minimum_size = Vector2(0, 36)
	box.add_child(_bp_name_edit)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	box.add_child(save_row)
	var save_new := UiStyleScript.make_compact_button("Save current", 140, 36)
	save_new.pressed.connect(_save_new_blueprint)
	save_row.add_child(save_new)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	box.add_child(scroll)
	_bp_list = VBoxContainer.new()
	_bp_list.add_theme_constant_override("separation", 6)
	_bp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bp_list)
	_bp_dialog.about_to_popup.connect(_refresh_blueprint_list)


func _step_stat(stat_id: String, dir: int) -> void:
	var spec := ResearchConfigScript.find_spec(_tower_id, stat_id)
	if spec.is_empty():
		return
	var step := float(spec.get("step", 0.1)) * float(dir)
	var cur := float(_edit_params.get(stat_id, spec.get("base", 0.0)))
	var nxt := clampf(cur + step, float(spec["min"]), float(spec["max"]))
	_edit_params[stat_id] = snappedf(nxt, step if step != 0.0 else 0.01)
	_edit_params = ResearchCostScript.clamp_params(_tower_id, _edit_params)
	_refresh_research_labels()


func _refresh_research_labels() -> void:
	_rp_label.text = "RP: %d" % ProfileManager.get_research_points()
	var committed := ProfileManager.get_committed_research_cost(_tower_id)
	var new_cost := ResearchCostScript.total_int(_tower_id, _edit_params)
	var delta := new_cost - committed
	_research_cost_label.text = "Value %d  |  Δ %+d RP" % [new_cost, delta]
	var current := ProfileManager.get_tower_research_params(_tower_id)
	for sid in _value_labels.keys():
		var spec := ResearchConfigScript.find_spec(_tower_id, sid)
		var before := float(current.get(sid, spec.get("base", 0.0)))
		var after := float(_edit_params.get(sid, before))
		var step_cost := absi(
			ResearchCostScript.total_int(_tower_id, _with(sid, after + float(spec.get("step", 0.1))))
			- ResearchCostScript.total_int(_tower_id, _edit_params)
		)
		(_value_labels[sid] as Label).text = "%.2f → %.2f  (~%d)" % [before, after, step_cost]


func _with(stat_id: String, value: float) -> Dictionary:
	var p := _edit_params.duplicate(true)
	p[stat_id] = value
	return ResearchCostScript.clamp_params(_tower_id, p)


func _apply_research() -> void:
	var result: Dictionary = ProfileManager.apply_tower_research(_tower_id, _edit_params)
	if bool(result.get("ok", false)):
		_status_label.text = "Applied (%+.0f RP)" % float(result.get("delta", 0.0))
		_edit_params = ProfileManager.get_tower_research_params(_tower_id)
	else:
		_status_label.text = str(result.get("reason", "Failed"))
	_refresh_research_labels()
	_refresh_blueprint_chips()


func _save_new_blueprint() -> void:
	var result: Dictionary = ProfileManager.create_blueprint(_tower_id, _bp_name_edit.text, _edit_params)
	_status_label.text = "Saved." if bool(result.get("ok", false)) else str(result.get("reason", "Failed"))
	_refresh_blueprint_list()
	_refresh_blueprint_chips()


func _refresh_blueprint_chips() -> void:
	if _bp_chip_row == null:
		return
	for c in _bp_chip_row.get_children():
		c.queue_free()
	for bp in ProfileManager.get_tower_blueprints(_tower_id):
		var id := str(bp.get("id", ""))
		var chip := UiStyleScript.make_compact_button(str(bp.get("display_name", id)), 100, 32)
		if bool(bp.get("active", false)):
			UiStyleScript.style_tab_button(chip, true)
			chip.disabled = false
		chip.pressed.connect(func() -> void:
			var res: Dictionary = ProfileManager.activate_blueprint(_tower_id, id)
			_status_label.text = "Activated." if bool(res.get("ok", false)) else str(res.get("reason", "Failed"))
			_edit_params = ProfileManager.get_tower_research_params(_tower_id)
			_selected_bp = id
			_refresh_research_labels()
			_refresh_blueprint_chips()
		)
		_bp_chip_row.add_child(chip)


func _refresh_blueprint_list() -> void:
	for c in _bp_list.get_children():
		c.queue_free()
	for bp in ProfileManager.get_tower_blueprints(_tower_id):
		var id := str(bp.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_bp_list.add_child(row)
		var label := "%s%s" % [
			str(bp.get("display_name", id)),
			" · active" if bool(bp.get("active", false)) else "",
		]
		var name_l := UiStyleScript.make_flat_label(label, 13)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var load_b := UiStyleScript.make_compact_button("Activate", 80, 30)
		load_b.pressed.connect(func() -> void:
			var res: Dictionary = ProfileManager.activate_blueprint(_tower_id, id)
			_status_label.text = "Activated." if bool(res.get("ok", false)) else str(res.get("reason", "Failed"))
			_edit_params = ProfileManager.get_tower_research_params(_tower_id)
			_selected_bp = id
			_refresh_research_labels()
			_refresh_blueprint_list()
			_refresh_blueprint_chips()
		)
		row.add_child(load_b)
		var over := UiStyleScript.make_compact_button("Overwrite", 90, 30)
		over.pressed.connect(func() -> void:
			ProfileManager.overwrite_blueprint(_tower_id, id, _edit_params)
			_status_label.text = "Overwritten."
			_refresh_blueprint_list()
			_refresh_blueprint_chips()
		)
		row.add_child(over)
		var del := UiStyleScript.make_compact_button("Delete", 70, 30)
		del.pressed.connect(func() -> void:
			ProfileManager.delete_blueprint(_tower_id, id)
			_refresh_blueprint_list()
			_refresh_blueprint_chips()
		)
		row.add_child(del)


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx
