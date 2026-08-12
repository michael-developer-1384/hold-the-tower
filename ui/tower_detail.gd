extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchCostScript := preload("res://scripts/meta/research_cost.gd")
const BlueprintResolverScript := preload("res://scripts/meta/blueprint_resolver.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")

var _tower_id: String = "basic_tower"
var _selected_bp: String = ""
var _edit_params: Dictionary = {}
var _name_edit: LineEdit
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _cost_label: Label
var _delta_label: Label
var _status_label: Label
var _overview_label: Label
var _stats_label: Label
var _rp_label: Label
var _bp_buttons: Dictionary = {}
var _pages: Array = []


func _ready() -> void:
	_tower_id = AppRouterScript.pending_tower_id
	if _tower_id.is_empty():
		_tower_id = "basic_tower"
	_selected_bp = ProfileManager.get_active_blueprint_id(_tower_id)
	UiStyleScript.apply_root(self)

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

	var defs := TowerCatalogScript.create_all()
	var def = TowerCatalogScript.find_by_id(defs, _tower_id)
	_rp_label = UiStyleScript.make_rp_badge(ProfileManager.get_research_points())
	UiStyleScript.make_top_bar(
		root,
		str(def.display_name) if def else _tower_id,
		func() -> void: AppRouterScript.go_gallery(get_tree()),
		[_rp_label]
	)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for i in ["OVERVIEW", "STATISTICS", "BLUEPRINTS"]:
		var b := UiStyleScript.make_button(i, 40)
		var idx := tabs.get_child_count()
		b.pressed.connect(func() -> void: _show_tab(idx))
		tabs.add_child(b)

	var overview := UiStyleScript.make_scroll_panel()
	root.add_child(overview)
	_overview_label = UiStyleScript.make_label("", 16)
	UiStyleScript.scroll_body(overview).add_child(_overview_label)
	_pages.append(overview)

	var stats := UiStyleScript.make_scroll_panel()
	root.add_child(stats)
	_stats_label = UiStyleScript.make_label("", 15)
	UiStyleScript.scroll_body(stats).add_child(_stats_label)
	_pages.append(stats)

	var bp_page := UiStyleScript.make_scroll_panel()
	root.add_child(bp_page)
	var bp_root := UiStyleScript.scroll_body(bp_page)
	_pages.append(bp_page)

	var bp_row := HBoxContainer.new()
	bp_row.add_theme_constant_override("separation", 8)
	bp_root.add_child(bp_row)
	for bp in ProfileManager.get_tower_blueprints(_tower_id):
		var id := str(bp.get("id", ""))
		var label := str(bp.get("display_name", id))
		if bool(bp.get("active", false)):
			label += " [ACTIVE]"
		var b := UiStyleScript.make_button(label, 40)
		b.toggle_mode = true
		b.button_pressed = id == _selected_bp
		b.pressed.connect(_select_bp.bind(id))
		_bp_buttons[id] = b
		bp_row.add_child(b)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Blueprint name"
	bp_root.add_child(_name_edit)

	for spec in ResearchConfigScript.specs_for(_tower_id):
		var sid := str(spec["id"])
		var row := VBoxContainer.new()
		bp_root.add_child(row)
		var lab := UiStyleScript.make_flat_label(str(spec["label"]), 14)
		row.add_child(lab)
		_value_labels[sid] = lab
		var slider := HSlider.new()
		slider.min_value = float(spec["min"])
		slider.max_value = float(spec["max"])
		slider.step = float(spec["step"])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 28)
		slider.value_changed.connect(_on_slider.bind(sid))
		row.add_child(slider)
		_sliders[sid] = slider

	_cost_label = UiStyleScript.make_flat_label("", 15)
	bp_root.add_child(_cost_label)
	_delta_label = UiStyleScript.make_flat_label("", 15)
	bp_root.add_child(_delta_label)
	_status_label = UiStyleScript.make_label("", 14, true)
	bp_root.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	bp_root.add_child(actions)
	var save_btn := UiStyleScript.make_button("SAVE")
	save_btn.pressed.connect(_on_save)
	actions.add_child(save_btn)
	var act_btn := UiStyleScript.make_button("ACTIVATE")
	act_btn.pressed.connect(_on_activate)
	actions.add_child(act_btn)
	var reset_btn := UiStyleScript.make_button("RESET BASE")
	reset_btn.pressed.connect(_on_reset_base)
	actions.add_child(reset_btn)

	_load_selected_into_editor()
	_refresh_overview()
	_refresh_stats()
	_show_tab(0)


func _show_tab(idx: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == idx


func _select_bp(id: String) -> void:
	_selected_bp = id
	for k in _bp_buttons.keys():
		(_bp_buttons[k] as Button).button_pressed = str(k) == id
	_load_selected_into_editor()


func _load_selected_into_editor() -> void:
	var bp := ProfileManager.get_blueprint(_tower_id, _selected_bp)
	_name_edit.text = str(bp.get("display_name", "Blueprint"))
	_edit_params = ResearchCostScript.clamp_params(_tower_id, bp.get("params", {}))
	for sid in _sliders.keys():
		var slider: HSlider = _sliders[sid]
		slider.set_value_no_signal(float(_edit_params.get(sid, slider.value)))
		_update_value_label(sid)
	_refresh_cost()


func _on_slider(value: float, sid: String) -> void:
	_edit_params[sid] = value
	_update_value_label(sid)
	_refresh_cost()


func _update_value_label(sid: String) -> void:
	var spec := ResearchConfigScript.find_spec(_tower_id, sid)
	var lab: Label = _value_labels[sid]
	lab.text = "%s: %.2f (base %.2f)" % [
		str(spec.get("label", sid)),
		float(_edit_params.get(sid, 0.0)),
		float(spec.get("base", 0.0)),
	]


func _refresh_cost() -> void:
	var cost := ResearchCostScript.total(_tower_id, _edit_params)
	var committed := ProfileManager.get_committed_research_cost(_tower_id)
	var delta := cost - committed
	_cost_label.text = "Config research cost: %.1f RP" % cost
	_delta_label.text = "Delta vs active: %+.1f RP  |  Free RP: %d" % [
		delta, ProfileManager.get_research_points()
	]
	if _rp_label:
		_rp_label.text = "RP: %d" % ProfileManager.get_research_points()


func _on_save() -> void:
	var result: Dictionary = ProfileManager.save_blueprint(
		_tower_id, _selected_bp, _name_edit.text.strip_edges(), _edit_params
	)
	if bool(result.get("ok", false)):
		_status_label.text = "Saved."
		_reload_bp_buttons()
	else:
		_status_label.text = str(result.get("reason", "Save failed"))
	_refresh_cost()


func _on_activate() -> void:
	var save_res: Dictionary = ProfileManager.save_blueprint(
		_tower_id, _selected_bp, _name_edit.text.strip_edges(), _edit_params
	)
	if not bool(save_res.get("ok", false)):
		_status_label.text = str(save_res.get("reason", "Save failed"))
		return
	var result: Dictionary = ProfileManager.activate_blueprint(_tower_id, _selected_bp)
	if bool(result.get("ok", false)):
		_status_label.text = "Activated. Delta %.1f RP" % float(result.get("delta", 0.0))
		_reload_bp_buttons()
		_refresh_overview()
	else:
		_status_label.text = str(result.get("reason", "Activate failed"))
	_refresh_cost()


func _on_reset_base() -> void:
	_edit_params = ResearchConfigScript.base_params(_tower_id)
	for sid in _sliders.keys():
		(_sliders[sid] as HSlider).set_value_no_signal(float(_edit_params[sid]))
		_update_value_label(sid)
	_refresh_cost()


func _reload_bp_buttons() -> void:
	for bp in ProfileManager.get_tower_blueprints(_tower_id):
		var id := str(bp.get("id", ""))
		if not _bp_buttons.has(id):
			continue
		var label := str(bp.get("display_name", id))
		if bool(bp.get("active", false)):
			label += " [ACTIVE]"
		(_bp_buttons[id] as Button).text = label


func _refresh_overview() -> void:
	var active := ProfileManager.get_active_blueprint(_tower_id)
	var resolved := BlueprintResolverScript.resolve(_tower_id, active)
	var base := BlueprintResolverScript.catalog_base_snapshot(_tower_id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("BASE vs ACTIVE BLUEPRINT")
	lines.append("")
	for k in resolved.keys():
		if k in ["tower_id", "blueprint_id", "blueprint_name", "cost", "guard_count"]:
			continue
		if typeof(resolved[k]) == TYPE_FLOAT or typeof(resolved[k]) == TYPE_INT:
			lines.append("%s: base %s  |  active %s" % [
				k, str(base.get(k, "-")), str(resolved[k])
			])
	lines.append("")
	lines.append("Active: %s (%s)" % [
		str(active.get("display_name", "")), str(active.get("id", ""))
	])
	_overview_label.text = "\n".join(lines)


func _refresh_stats() -> void:
	var life := ProfileManager.get_tower_lifetime(_tower_id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("LIFETIME (ALL BLUEPRINTS)")
	lines.append(_format_stats(life))
	lines.append("")
	lines.append("BY BLUEPRINT")
	for bp in ProfileManager.get_tower_blueprints(_tower_id):
		var id := str(bp.get("id", ""))
		var st := ProfileManager.get_blueprint_stats(_tower_id, id)
		lines.append("--- %s ---" % str(bp.get("display_name", id)))
		lines.append(_format_stats(st))
		lines.append("")
	_stats_label.text = "\n".join(lines)


func _format_stats(st: Dictionary) -> String:
	return "\n".join([
		"Games: %d" % int(st.get("games_used", 0)),
		"Built: %d" % int(st.get("times_built", 0)),
		"Gold invested: %.0f" % float(st.get("gold_invested", 0.0)),
		"Damage: %.0f" % float(st.get("damage_dealt", 0.0)),
		"Kills: %d" % int(st.get("kills", 0)),
		"Hits: %d  Shots: %d" % [int(st.get("hits", 0)), int(st.get("shots", 0))],
		"Overkill: %.0f" % float(st.get("overkill_damage", 0.0)),
		"Same-floor dmg: %.0f  Cross-floor: %.0f" % [
			float(st.get("same_floor_damage", 0.0)), float(st.get("cross_floor_damage", 0.0))
		],
		"Blocked: %d  Block ms: %d" % [
			int(st.get("enemies_blocked", 0)), int(st.get("total_block_time_ms", 0))
		],
		"Guard deaths/respawns: %d / %d" % [
			int(st.get("guards_died", 0)), int(st.get("guards_respawned", 0))
		],
	])
