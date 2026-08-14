extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const TimelineRecorderScript := preload("res://scripts/run/timeline_recorder.gd")

@onready var _headline: Label = %HeadlineLabel
@onready var _summary_panel: PanelContainer = %SummaryPanel
@onready var _summary_host: HBoxContainer = %SummaryHost
@onready var _timeline_panel: PanelContainer = %TimelinePanel
@onready var _tm_info: Label = %TimelineInfo
@onready var _tm_slider: HSlider = %TimelineSlider
@onready var _tables_panel: PanelContainer = %TablesPanel
@onready var _tables_host: VBoxContainer = %TablesHost
@onready var _retry_btn: Button = %RetryBtn
@onready var _menu_btn: Button = %MainMenuBtn

var _snaps: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	UiStyle.style_card_panel(_summary_panel)
	UiStyle.style_card_panel(_timeline_panel)
	UiStyle.style_card_panel(_tables_panel)
	_bind_run()
	_bind_timeline()
	_retry_btn.pressed.connect(_on_retry)
	_menu_btn.pressed.connect(_on_main_menu)
	_retry_btn.grab_focus()


func _bind_run() -> void:
	var run: Dictionary = RunManager.last_run if typeof(RunManager) != TYPE_NIL else {}
	var result := str(run.get("result", "unknown"))
	var headline := "LEVEL COMPLETE" if result == "level_complete" else "GAME OVER"
	var level := StatPresentationScript.display_level(str(run.get("level_id", "?")))
	var diff := StatPresentationScript.display_difficulty(str(run.get("difficulty_id", "normal")))
	_headline.text = "%s  ·  %s  ·  %s" % [headline, level, diff]
	_fill_summary(run)
	_fill_tables(run, result)


func _fill_summary(run: Dictionary) -> void:
	for c in _summary_host.get_children():
		c.queue_free()
	var secs := float(run.get("duration_ms", 0)) / 1000.0
	_summary_host.add_child(_metric("TIME", "%.1fs" % secs))
	_summary_host.add_child(_metric("CORE", str(int(run.get("ending_core_hp", 0)))))
	_summary_host.add_child(_metric("KILLS", str(int(run.get("enemies_killed", 0)))))
	_summary_host.add_child(_metric("LEAKS", str(int(run.get("enemies_leaked", 0)))))
	_summary_host.add_child(_metric("DAMAGE", "%.0f" % float(run.get("total_damage", 0.0))))
	_summary_host.add_child(_metric("GOLD +/−", "%d / %d" % [int(run.get("gold_earned", 0)), int(run.get("gold_spent", 0))]))
	_summary_host.add_child(_metric("RP", "+%d" % int(run.get("research_earned", 0))))


func _metric(title: String, value: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiStyle.make_flat_label(title, UiTokens.FONT_CAPTION, true))
	col.add_child(UiStyle.make_flat_label(value, UiTokens.FONT_SECTION, false))
	return col


func _bind_timeline() -> void:
	var dump: Dictionary = TimelineRecorderScript.load_last_dump()
	_snaps = dump.get("snapshots", [])
	if _snaps.is_empty():
		_tm_info.text = "No timeline dump for this run."
		_tm_slider.visible = false
		return
	_tm_slider.min_value = 0
	_tm_slider.max_value = _snaps.size() - 1
	_tm_slider.step = 1
	_tm_slider.value = _snaps.size() - 1
	_tm_slider.value_changed.connect(_on_tm_scrub)
	_on_tm_scrub(_tm_slider.value)


func _on_tm_scrub(v: float) -> void:
	var idx := int(v)
	if idx < 0 or idx >= _snaps.size():
		return
	var snap: Dictionary = _snaps[idx]
	_tm_info.text = "t=%.1fs · gold %d · core %d · enemies %d · towers %d" % [
		float(snap.get("t", 0.0)),
		int(snap.get("gold", 0)),
		int(snap.get("core_hp", 0)),
		(snap.get("enemies", []) as Array).size(),
		(snap.get("towers", []) as Array).size(),
	]


func _fill_tables(run: Dictionary, result: String) -> void:
	for c in _tables_host.get_children():
		c.queue_free()
	if result == "level_complete":
		_tables_host.add_child(_research_panel(run))
	_add_tower_tables(_tables_host, run)
	_add_enemy_tables(_tables_host, run)
	_add_built_towers_table(_tables_host, run)


func _research_panel(run: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("RESEARCH"))
	var earned := int(run.get("research_earned", 0))
	var xp_earned := int(run.get("research_xp_earned", earned))
	var lvl_start := int(run.get("player_level_start", 1))
	var lvl_end := int(run.get("player_level_end", ProfileManager.get_player_level()))
	var xp_end := int(run.get("research_xp_total_end", ProfileManager.get_research_xp_total()))
	var xp_info: Dictionary = ProgressionConfigScript.xp_into_level(xp_end)
	col.add_child(UiStyle.make_flat_label("+%d RP  ·  +%d XP" % [earned, xp_earned], UiTokens.FONT_BODY, false))
	col.add_child(UiStyle.make_flat_label("PLAYER LEVEL %d" % lvl_end, UiTokens.FONT_BODY, false))
	if bool(xp_info.get("at_cap", false)):
		col.add_child(UiStyle.make_flat_label("%d XP (max level)" % xp_end, UiTokens.FONT_CAPTION, true))
	else:
		col.add_child(UiStyle.make_flat_label(
			"%d / %d XP  ·  %d to next" % [
				xp_end,
				int(xp_info.get("xp_next_total", xp_end)),
				int(xp_info.get("xp_to_next", 0)),
			],
			UiTokens.FONT_CAPTION,
			true
		))
	if lvl_end > lvl_start:
		col.add_child(UiStyle.make_flat_label(
			"LEVEL UP %d → %d  ·  Cap %s → %s" % [
				lvl_start,
				lvl_end,
				ProgressionConfigScript.fraction_label(lvl_start),
				ProgressionConfigScript.fraction_label(lvl_end),
			],
			UiTokens.FONT_BODY,
			false
		))
	return panel


func _add_tower_tables(body: Control, run: Dictionary) -> void:
	var stats: Array = run.get("tower_type_stats", [])
	if stats.is_empty():
		return
	body.add_child(UiStyle.make_section_label("TOWER PERFORMANCE"))
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel)
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	for entry in stats:
		col.add_child(UiStyle.make_flat_label(_type_text(entry, run), UiTokens.FONT_DATA, false))


func _add_enemy_tables(body: Control, run: Dictionary) -> void:
	var stats: Array = run.get("enemy_type_stats", [])
	if stats.is_empty():
		return
	body.add_child(UiStyle.make_section_label("ENEMY PERFORMANCE"))
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel)
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UiStyle.make_flat_label("Type | Encountered | Killed | Leaks | Damage taken", UiTokens.FONT_CAPTION, true))
	for entry in stats:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var enemy_id := str(e.get("enemy_id", e.get("enemy_type", e.get("id", "?"))))
		col.add_child(UiStyle.make_flat_label("%s | %s | %s | %s | %s" % [
			StatPresentationScript.display_enemy(enemy_id),
			str(e.get("encountered", e.get("spawned", "-"))),
			str(e.get("killed", "-")),
			str(e.get("leaks", e.get("leaked", "-"))),
			str(e.get("damage_taken", e.get("damage", "-"))),
		], UiTokens.FONT_DATA, false))


func _add_built_towers_table(body: Control, run: Dictionary) -> void:
	var towers: Array = run.get("towers", [])
	if towers.is_empty():
		return
	body.add_child(UiStyle.make_section_label("BUILT TOWERS"))
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel)
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	col.add_child(UiStyle.make_flat_label("Tower | Spot | Damage | Kills | Extra | Gold", UiTokens.FONT_CAPTION, true))
	var spot_index := 0
	for t in towers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = t
		spot_index += 1
		var tower_type := str(row.get("tower_type", "?"))
		var extra := ""
		if tower_type == "guard_post":
			extra = "Blocked %d" % int(row.get("enemies_blocked", 0))
		else:
			extra = "Cross-floor %s" % StatPresentationScript.format_value(
				"damage_dealt",
				float(row.get("cross_floor_damage", 0.0))
			)
		col.add_child(UiStyle.make_flat_label("%s | Spot %d | %.0f | %d | %s | %d" % [
			StatPresentationScript.display_tower(tower_type),
			spot_index,
			float(row.get("damage_dealt", 0.0)),
			int(row.get("kills", 0)),
			extra,
			int(row.get("gold_invested", 0)),
		], UiTokens.FONT_DATA, false))


func _type_text(entry: Dictionary, run: Dictionary) -> String:
	var tid := str(entry.get("tower_type", "?"))
	var display_name := StatPresentationScript.display_tower(tid)
	var total_dmg := maxf(float(run.get("total_damage", 0.0)), 0.001)
	var dmg := float(entry.get("damage_dealt", 0.0))
	var gold := maxf(float(entry.get("gold_invested", 0.0)), 1.0)
	var shots := maxf(float(entry.get("shots", 0)), 0.001)
	var hits := float(entry.get("hits", 0))
	var target_t := float(entry.get("target_time", 0.0))
	var idle_t := float(entry.get("no_target_time", 0.0))
	var combat_span := maxf(target_t + idle_t, 0.001)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(display_name.to_upper())
	lines.append("Built %d  ·  Gold %.0f  ·  Damage %.0f (%.0f%%)  ·  Kills %d  ·  Dmg/100g %.1f" % [
		int(entry.get("times_built", 0)),
		float(entry.get("gold_invested", 0.0)),
		dmg,
		100.0 * dmg / total_dmg,
		int(entry.get("kills", 0)),
		dmg / gold * 100.0,
	])
	if tid == "basic_tower":
		lines.append("Hit %.0f%%  ·  Uptime %.0f%%  ·  Idle %.0f%%  ·  Cross-floor %.0f (%.0f%%)" % [
			100.0 * hits / shots,
			100.0 * target_t / combat_span,
			100.0 * idle_t / combat_span,
			float(entry.get("cross_floor_damage", 0.0)),
			100.0 * float(entry.get("cross_floor_damage", 0.0)) / maxf(dmg, 0.001),
		])
	elif tid == "guard_post":
		var blocks := int(entry.get("enemies_blocked", 0))
		var block_ms := int(entry.get("total_block_time_ms", 0))
		lines.append("Blocked %d  ·  Block time %.1fs  ·  Deaths %d  ·  Respawns %d" % [
			blocks,
			float(block_ms) / 1000.0,
			int(entry.get("guards_died", 0)),
			int(entry.get("guards_respawned", 0)),
		])
	elif tid == "lava_tower":
		lines.append("Cross-floor %.0f (%.0f%%)" % [
			float(entry.get("cross_floor_damage", 0.0)),
			100.0 * float(entry.get("cross_floor_damage", 0.0)) / maxf(dmg, 0.001),
		])
	var bp_id := str(entry.get("blueprint_id", ""))
	var bp_name := str(entry.get("blueprint_name", ""))
	lines.append("Blueprint: %s" % StatPresentationScript.display_blueprint(bp_id, bp_name))
	return "\n".join(lines)


func _on_retry() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_accept()
	AppRouterScript.go_game(get_tree(), false)


func _on_main_menu() -> void:
	if typeof(RunManager) != TYPE_NIL:
		RunManager.clear_last_run()
	AppRouterScript.go_main_menu(get_tree())
