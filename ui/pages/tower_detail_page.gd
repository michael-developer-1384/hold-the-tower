extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const BlueprintResolverScript := preload("res://scripts/meta/blueprint_resolver.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const ResearchStatRowScript := preload("res://ui/components/research_stat_row.gd")
const StatTableRowScene := preload("res://ui/components/stat_table_row.tscn")

@onready var _back_btn: Button = %BackBtn
@onready var _title_label: Label = %TitleLabel
@onready var _hero_panel: PanelContainer = %HeroPanel
@onready var _preview: Control = %PreviewHost
@onready var _display_name: Label = %DisplayNameLabel
@onready var _role_cost: Label = %RoleCostLabel
@onready var _desc: Label = %DescLabel
@onready var _chips_host: HFlowContainer = %ChipsHost
@onready var _snapshot_panel: PanelContainer = %SnapshotPanel
@onready var _snapshot_col: VBoxContainer = %SnapshotCol
@onready var _tab_row_host: HBoxContainer = %TabRowHost
@onready var _tab_overview: PanelContainer = %TabOverview
@onready var _role_label: Label = %RoleLabel
@onready var _overview_desc: Label = %OverviewDescLabel
@onready var _tab_statistics: PanelContainer = %TabStatistics
@onready var _lifetime_host: VBoxContainer = %LifetimeHost
@onready var _tab_research: HBoxContainer = %TabResearch
@onready var _allocations_host: VBoxContainer = %AllocationsHost
@onready var _bp_name_edit: LineEdit = %BpNameEdit
@onready var _save_btn: Button = %SaveCurrentBtn
@onready var _bp_list: VBoxContainer = %BpListHost
@onready var _research_scroll_panel: PanelContainer = %ResearchScrollPanel
@onready var _research_right: PanelContainer = %ResearchRight
@onready var _research_title: Label = %ResearchTitleLabel
@onready var _hdr_level: Label = %HdrLevel
@onready var _hdr_xp: Label = %HdrXp
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _hdr_rp: Label = %HdrRp
@onready var _hdr_current: Label = %HdrCurrent
@onready var _hdr_draft: Label = %HdrDraft
@onready var _hdr_capacity: Label = %HdrCapacity
@onready var _hdr_change: Label = %HdrChange
@onready var _hdr_next: Label = %HdrNext
@onready var _reset_btn: Button = %ResetBtn
@onready var _apply_btn: Button = %ApplyBtn
@onready var _status_label: Label = %StatusLabel

var _tower_id: String = "basic_tower"
var _edit_alloc: Dictionary = {}
var _pages: Array = []
var _selected_bp: String = ""
var _def: Resource
var _stat_rows: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_style_panels()
	_tower_id = AppRouterScript.pending_tower_id
	if _tower_id.is_empty():
		_tower_id = "basic_tower"
	_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
	_selected_bp = ProfileManager.get_active_blueprint_id(_tower_id)
	var defs := TowerCatalogScript.create_all()
	_def = TowerCatalogScript.find_by_id(defs, _tower_id)
	_bind_static()
	_setup_tabs()
	_build_research_rows()
	_connect_signals()
	_show_tab(0)
	_refresh_research_ui()
	_back_btn.grab_focus()


func _style_panels() -> void:
	UiStyle.style_card_panel(_hero_panel)
	UiStyle.style_card_panel(_snapshot_panel)
	UiStyle.style_card_panel(_tab_overview)
	UiStyle.style_card_panel(_tab_statistics)
	UiStyle.style_card_panel(_research_scroll_panel)
	UiStyle.style_card_panel(_research_right)


func _bind_static() -> void:
	var name_text := str(_def.display_name) if _def else _tower_id
	_title_label.text = name_text
	_display_name.text = name_text
	if _def:
		_role_cost.text = "%s · %s" % [str(_def.role), MoneyDisplay.usd(int(_def.cost))]
		_desc.text = str(_def.long_description)
		_role_label.text = str(_def.role)
		_overview_desc.text = str(_def.long_description)
		_research_title.text = "%s RESEARCH" % name_text.to_upper()
		if _def.visual_scene != null:
			_preview.call_deferred("set_visual_scene", _def.visual_scene)
		_preview.preview_size = Vector2i(280, 220)
		_preview.custom_minimum_size = Vector2(280, 220)
		_preview.zoom = 2.2
		for feature in FeatureCatalogScript.resolve_ids(_def.feature_ids):
			_chips_host.add_child(UiStyle.make_feature_chip(
				"%s — %s" % [feature.display_name, feature.short_description]
			))
	_fill_lifetime_stats()
	_fill_build_snapshot()


func _setup_tabs() -> void:
	_pages = [_tab_overview, _tab_statistics, _tab_research]
	var tabs := UiStyle.make_tab_row(
		PackedStringArray(["OVERVIEW", "STATISTICS", "RESEARCH"]),
		func(idx: int) -> void: _show_tab(idx),
		0
	)
	_tab_row_host.add_child(tabs["row"])


func _connect_signals() -> void:
	_back_btn.pressed.connect(_on_back)
	_reset_btn.pressed.connect(_reset_draft)
	_apply_btn.pressed.connect(_apply_research)
	_save_btn.pressed.connect(_save_new_blueprint)


func _on_back() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_back()
	AppRouterScript.back()


func _fill_build_snapshot() -> void:
	for c in _snapshot_col.get_children():
		if str(c.name) == "BuildSnapshotHeader":
			continue
		c.queue_free()
	var resolved := BlueprintResolverScript.resolve(_tower_id, {
		"id": "research",
		"allocations": ProfileManager.get_tower_research_allocations(_tower_id),
	})
	for k in resolved.keys():
		if k in ["tower_id", "blueprint_id", "blueprint_name", "allocations"]:
			continue
		var raw = resolved[k]
		if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			continue
		var row := StatTableRowScene.instantiate()
		row.setup_stat(str(k), float(raw))
		_snapshot_col.add_child(row)


func _fill_lifetime_stats() -> void:
	for c in _lifetime_host.get_children():
		c.queue_free()
	var life: Dictionary = ProfileManager.get_tower_lifetime(_tower_id)
	var keys: PackedStringArray = _def.stat_metric_keys if _def else PackedStringArray()
	if keys.is_empty():
		keys = PackedStringArray(["times_built", "kills", "damage_dealt"])
	for key in keys:
		var row := StatTableRowScene.instantiate()
		row.setup_stat(str(key), float(life.get(key, 0)))
		_lifetime_host.add_child(row)


func _build_research_rows() -> void:
	for c in _allocations_host.get_children():
		c.queue_free()
	_stat_rows.clear()
	var level := ProfileManager.get_player_level()
	var committed := ProfileManager.get_tower_research_allocations(_tower_id)
	for spec in ResearchConfigScript.specs_for(_tower_id):
		var sid := str(spec["id"])
		var row = ResearchStatRowScript.new()
		row.custom_minimum_size = Vector2(0, 96)
		_allocations_host.add_child(row)
		row.setup(spec, level)
		row.set_values(int(committed.get(sid, 0)), int(_edit_alloc.get(sid, 0)))
		row.allocation_changed.connect(_on_row_changed)
		_stat_rows[sid] = row


func _on_row_changed(stat_id: String, invested: int) -> void:
	_edit_alloc[stat_id] = invested
	_refresh_research_ui()


func _reset_draft() -> void:
	_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
	_refresh_research_ui()
	_status_label.text = "Draft reset."
	_toast("Draft reset", "Research draft restored to committed values.")


func _refresh_research_ui() -> void:
	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var rp := ProfileManager.get_research_points()

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
		_hdr_capacity.add_theme_color_override("font_color", UiTokens.DANGER)
	else:
		_hdr_capacity.text = "Capacity  %d / %d" % [draft_total, capacity]
		_hdr_capacity.add_theme_color_override("font_color", UiTokens.TEXT)

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
	_fill_build_snapshot()
	var shell := AppRouterScript.shell()
	if shell != null and shell.has_method("set_status_extra"):
		shell.call("set_status_extra", "Cap %d/%d" % [draft_total, capacity])


func _apply_research() -> void:
	var result: Dictionary = ProfileManager.apply_tower_research_allocations(_tower_id, _edit_alloc)
	if bool(result.get("ok", false)):
		_status_label.text = "Applied (%+d RP)" % int(result.get("delta", 0))
		_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
		_toast(
			"RESEARCH APPLIED",
			"%s · %+d RP" % [StatPresentationScript.display_tower(_tower_id), int(result.get("delta", 0))]
		)
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_research()
	else:
		_status_label.text = str(result.get("reason", "Failed"))
		_toast("RESEARCH FAILED", str(result.get("reason", "Failed")))
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_error()
	_refresh_research_ui()


func _save_new_blueprint() -> void:
	var result: Dictionary = ProfileManager.create_blueprint(_tower_id, _bp_name_edit.text, _edit_alloc)
	if bool(result.get("ok", false)):
		_status_label.text = "Saved."
		_toast("Blueprint saved", _bp_name_edit.text)
	else:
		_status_label.text = str(result.get("reason", "Failed"))
		_toast("Save failed", str(result.get("reason", "Failed")))
	_refresh_blueprint_list()


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
		var name_l := UiStyle.make_flat_label(label, UiTokens.FONT_CAPTION, false)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var load_b := UiStyle.make_compact_button("LOAD", 64, 28, "secondary")
		load_b.pressed.connect(func() -> void:
			var res: Dictionary = ProfileManager.activate_blueprint(_tower_id, id)
			_status_label.text = "Loaded." if bool(res.get("ok", false)) else str(res.get("reason", "Failed"))
			_edit_alloc = ProfileManager.get_tower_research_allocations(_tower_id)
			_selected_bp = id
			_refresh_research_ui()
		)
		row.add_child(load_b)
		var over := UiStyle.make_compact_button("OVER", 64, 28, "ghost")
		over.pressed.connect(func() -> void:
			ProfileManager.overwrite_blueprint(_tower_id, id, _edit_alloc)
			_status_label.text = "Overwritten."
			_refresh_blueprint_list()
		)
		row.add_child(over)
		var del := UiStyle.make_compact_button("…", 36, 28, "ghost")
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


func _toast(title: String, body: String = "") -> void:
	var shell := AppRouterScript.shell()
	if shell != null and shell.has_method("show_toast"):
		shell.call("show_toast", title, body)
