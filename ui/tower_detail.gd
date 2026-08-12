extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const BlueprintResolverScript := preload("res://scripts/meta/blueprint_resolver.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")
const ResearchStatRowScript := preload("res://ui/components/research_stat_row.gd")

var _tower_id: String = "basic_tower"
var _edit_alloc: Dictionary = {}
var _status_label: Label
var _lv_rp_label: Label
var _pages: Array = []
var _selected_bp: String = ""
var _def: Resource
var _bp_name_edit: LineEdit
var _bp_list: VBoxContainer

var _hdr_level: Label
var _hdr_xp: Label
var _hdr_rp: Label
var _hdr_current: Label
var _hdr_draft: Label
var _hdr_capacity: Label
var _hdr_change: Label
var _hdr_next: Label
var _apply_btn: Button
var _reset_btn: Button
var _stat_rows: Dictionary = {}
var _xp_bar: ProgressBar


func _ready() -> void:
	_tower_id = AppRouterScript.pending_tower_id
	if _tower_id.is_empty():
		_tower_id = "basic_tower"
	_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
	_selected_bp = ProfileManager.get_active_blueprint_id(_tower_id)
	UiStyleScript.apply_root(self)

	var defs := TowerCatalogScript.create_all()
	_def = TowerCatalogScript.find_by_id(defs, _tower_id)

	var root := UiStyleScript.make_content_shell(self, 1240.0)

	_lv_rp_label = UiStyleScript.make_lv_xp_rp_badge(
		ProfileManager.get_player_level(),
		ProfileManager.get_research_xp_total(),
		ProfileManager.get_research_points()
	)
	UiStyleScript.make_top_bar(
		root,
		str(_def.display_name) if _def else _tower_id,
		func() -> void: AppRouterScript.go_gallery(get_tree(), "towers"),
		[_lv_rp_label]
	)

	var tabs := UiStyleScript.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS", "RESEARCH"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	root.add_child(tabs["row"])

	_pages.append(_build_overview(root))
	_pages.append(_build_statistics(root))
	_pages.append(_build_research(root))
	_show_tab(0)
	_refresh_research_ui()


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
	left.custom_minimum_size = Vector2(340, 0)
	cols.add_child(left)

	var preview := PreviewScene.instantiate()
	preview.preview_size = Vector2i(320, 260)
	preview.custom_minimum_size = Vector2(320, 260)
	preview.zoom = 2.2
	left.add_child(preview)
	if _def and _def.visual_scene != null:
		preview.call_deferred("set_visual_scene", _def.visual_scene)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	if _def:
		right.add_child(UiStyleScript.make_flat_label(str(_def.display_name), 26))
		right.add_child(UiStyleScript.make_flat_label("%s · %d Gold" % [str(_def.role), int(_def.cost)], 14, true))
		right.add_child(UiStyleScript.make_label(str(_def.long_description), 14))
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
			"allocations": ProfileManager.get_tower_research_allocations(_tower_id),
		})
		right.add_child(UiStyleScript.make_flat_label("Research stats", 15))
		for k in resolved.keys():
			if k in ["tower_id", "blueprint_id", "blueprint_name", "cost", "guard_count", "allocations"]:
				continue
			right.add_child(UiStyleScript.make_flat_label("%s: %s" % [str(k), str(resolved[k])], 13, true))
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
		grid.add_child(UiStyleScript.make_flat_label(
			"%s: %s" % [key.replace("_", " ").capitalize(), str(life.get(key, 0))], 15
		))
	return stats


func _build_research(root: Control) -> Control:
	var page := HBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	root.add_child(page)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.7
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	page.add_child(left)

	var scroll := UiStyleScript.make_scroll_panel()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var body := UiStyleScript.scroll_body(scroll)
	body.add_theme_constant_override("separation", 8)

	var level := ProfileManager.get_player_level()
	var committed := ProfileManager.get_tower_research_allocations(_tower_id)
	for spec in ResearchConfigScript.specs_for(_tower_id):
		var sid := str(spec["id"])
		var row = ResearchStatRowScript.new()
		body.add_child(row)
		row.setup(spec, level)
		row.set_values(int(committed.get(sid, 0)), int(_edit_alloc.get(sid, 0)))
		row.allocation_changed.connect(_on_row_changed)
		_stat_rows[sid] = row

	_build_saved_configs(body)

	var right := UiStyleScript.make_panel()
	right.custom_minimum_size = Vector2(360, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(right)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", 6)
	right.add_child(hcol)

	var tower_name := str(_def.display_name) if _def else _tower_id
	hcol.add_child(UiStyleScript.make_flat_label("%s RESEARCH" % tower_name.to_upper(), 18))
	_hdr_level = UiStyleScript.make_flat_label("", 20)
	hcol.add_child(_hdr_level)
	_hdr_xp = UiStyleScript.make_flat_label("", 13)
	hcol.add_child(_hdr_xp)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 14)
	_xp_bar.show_percentage = false
	hcol.add_child(_xp_bar)
	_hdr_rp = UiStyleScript.make_flat_label("", 14)
	hcol.add_child(_hdr_rp)
	_hdr_current = UiStyleScript.make_flat_label("", 13)
	hcol.add_child(_hdr_current)
	_hdr_draft = UiStyleScript.make_flat_label("", 13)
	hcol.add_child(_hdr_draft)
	_hdr_capacity = UiStyleScript.make_flat_label("", 14)
	hcol.add_child(_hdr_capacity)
	_hdr_change = UiStyleScript.make_flat_label("", 14)
	hcol.add_child(_hdr_change)
	_hdr_next = UiStyleScript.make_flat_label("", 12, true)
	hcol.add_child(_hdr_next)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(spacer)

	_reset_btn = UiStyleScript.make_compact_button("RESET DRAFT", 0, 42)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn.pressed.connect(_reset_draft)
	hcol.add_child(_reset_btn)
	_apply_btn = UiStyleScript.make_compact_button("APPLY", 0, 46)
	_apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn.pressed.connect(_apply_research)
	hcol.add_child(_apply_btn)
	_status_label = UiStyleScript.make_flat_label("", 12, true)
	hcol.add_child(_status_label)

	return page


func _build_saved_configs(body: Control) -> void:
	body.add_child(UiStyleScript.make_flat_label("SAVED CONFIGURATIONS", 14))
	body.add_child(UiStyleScript.make_flat_label(
		"Optional named saves. Research works without them.", 11, true
	))
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	body.add_child(save_row)
	_bp_name_edit = LineEdit.new()
	_bp_name_edit.placeholder_text = "Name"
	_bp_name_edit.custom_minimum_size = Vector2(160, 32)
	save_row.add_child(_bp_name_edit)
	var save_btn := UiStyleScript.make_compact_button("SAVE CURRENT", 130, 32)
	save_btn.pressed.connect(_save_new_blueprint)
	save_row.add_child(save_btn)
	_bp_list = VBoxContainer.new()
	_bp_list.add_theme_constant_override("separation", 4)
	body.add_child(_bp_list)


func _on_row_changed(stat_id: String, invested: int) -> void:
	_edit_alloc[stat_id] = invested
	_refresh_research_ui()


func _reset_draft() -> void:
	_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
	_refresh_research_ui()
	_status_label.text = "Draft reset."


func _refresh_research_ui() -> void:
	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var rp := ProfileManager.get_research_points()
	_lv_rp_label.text = "LV %d  XP %s  RP %d" % [
		level,
		_xp_badge_text(xp),
		rp,
	]

	_hdr_level.text = "PLAYER LEVEL %d" % level
	var xp_info: Dictionary = ProgressionConfigScript.xp_into_level(xp)
	if bool(xp_info.get("at_cap", false)):
		_hdr_xp.text = "XP  %d  (max level)" % xp
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
	else:
		var need := int(xp_info.get("xp_need", 1))
		var into := int(xp_info.get("xp_in_level", 0))
		var next_total := int(xp_info.get("xp_next_total", xp + 1))
		_hdr_xp.text = "XP  %d / %d" % [xp, next_total]
		_xp_bar.max_value = float(maxi(need, 1))
		_xp_bar.value = float(into)
	_hdr_rp.text = "RP available  %d" % rp

	var committed := ProfileManager.get_tower_research_allocations(_tower_id)
	var cur_total := ResearchResolverScript.total_invested(committed)
	var draft := ResearchResolverScript.clamp_allocations(_tower_id, _edit_alloc, level)
	_edit_alloc = draft
	var draft_total := ResearchResolverScript.total_invested(draft)
	var capacity := ResearchResolverScript.tower_capacity(_tower_id, level)
	var excess := ResearchResolverScript.capacity_excess(_tower_id, draft, level)
	var delta := draft_total - cur_total

	_hdr_current.text = "Current invested  %d RP" % cur_total
	_hdr_draft.text = "Draft invested  %d RP" % draft_total
	if excess > 0:
		_hdr_capacity.text = "Capacity  %d / %d  (exceeded by %d)" % [draft_total, capacity, excess]
		_hdr_capacity.add_theme_color_override("font_color", UiStyleScript.DANGER)
	else:
		_hdr_capacity.text = "Capacity  %d / %d" % [draft_total, capacity]
		_hdr_capacity.add_theme_color_override("font_color", UiStyleScript.TEXT)

	if delta > 0:
		_hdr_change.text = "Change  +%d RP" % delta
		_apply_btn.text = "APPLY %d RP" % delta
	elif delta < 0:
		_hdr_change.text = "Change  %d RP refund" % delta
		_apply_btn.text = "APPLY & REFUND %d RP" % (-delta)
	else:
		_hdr_change.text = "Change  0 RP"
		_apply_btn.text = "APPLY"

	if level < ProgressionConfigScript.max_level():
		var nxt: Dictionary = ProgressionConfigScript.unlocks_for_level(level + 1)
		_hdr_next.text = "Next level capacity → %d RP  ·  cap %s" % [
			ProgressionConfigScript.tower_capacity(_tower_id, level + 1),
			str(nxt.get("research_cap_label", "?")),
		]
	else:
		_hdr_next.text = "Fully unlocked"

	var can_apply := delta != 0 and excess == 0 and (delta <= 0 or rp >= delta)
	_apply_btn.disabled = not can_apply
	_reset_btn.disabled = ResearchResolverScript.allocations_equal(draft, committed, _tower_id)

	for sid in _stat_rows.keys():
		var row = _stat_rows[sid]
		row.set_values(int(committed.get(sid, 0)), int(draft.get(sid, 0)))

	_refresh_blueprint_list()


func _xp_badge_text(xp: int) -> String:
	var info: Dictionary = ProgressionConfigScript.xp_into_level(xp)
	if bool(info.get("at_cap", false)):
		return "MAX"
	return "%d/%d" % [xp, int(info.get("xp_next_total", xp))]


func _apply_research() -> void:
	var result: Dictionary = ProfileManager.apply_tower_research_allocations(_tower_id, _edit_alloc)
	if bool(result.get("ok", false)):
		_status_label.text = "Applied (%+d RP)" % int(result.get("delta", 0))
		_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
	else:
		_status_label.text = str(result.get("reason", "Failed"))
	_refresh_research_ui()


func _save_new_blueprint() -> void:
	var result: Dictionary = ProfileManager.create_blueprint(_tower_id, _bp_name_edit.text, _edit_alloc)
	_status_label.text = "Saved." if bool(result.get("ok", false)) else str(result.get("reason", "Failed"))
	_refresh_blueprint_list()


func _refresh_blueprint_list() -> void:
	if _bp_list == null:
		return
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
		var name_l := UiStyleScript.make_flat_label(label, 12)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var load_b := UiStyleScript.make_compact_button("LOAD", 64, 28)
		load_b.pressed.connect(func() -> void:
			var res: Dictionary = ProfileManager.activate_blueprint(_tower_id, id)
			_status_label.text = "Loaded." if bool(res.get("ok", false)) else str(res.get("reason", "Failed"))
			_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
			_selected_bp = id
			_refresh_research_ui()
		)
		row.add_child(load_b)
		var over := UiStyleScript.make_compact_button("OVER", 64, 28)
		over.pressed.connect(func() -> void:
			ProfileManager.overwrite_blueprint(_tower_id, id, _edit_alloc)
			_status_label.text = "Overwritten."
			_refresh_blueprint_list()
		)
		row.add_child(over)
		var del := UiStyleScript.make_compact_button("…", 36, 28)
		del.tooltip_text = "Delete"
		del.pressed.connect(func() -> void:
			ProfileManager.delete_blueprint(_tower_id, id)
			_refresh_blueprint_list()
		)
		row.add_child(del)


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx
	if idx == 2:
		_refresh_research_ui()
