extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const TimelineRecorderScript := preload("res://scripts/run/timeline_recorder.gd")

var _tm_info: Label
var _tm_slider: HSlider
var _snaps: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()


func _build() -> void:
	var run: Dictionary = RunManager.last_run if typeof(RunManager) != TYPE_NIL else {}
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	root.add_child(UiStyle.make_flat_label("AFTER ACTION REPORT", UiTokens.FONT_PAGE, false))

	var result := str(run.get("result", "unknown"))
	var headline := "LEVEL COMPLETE" if result == "level_complete" else "GAME OVER"
	var level := LevelCatalogScript.find(str(run.get("level_id", "")))
	var diff := DifficultyCatalogScript.find(str(run.get("difficulty_id", "normal")))
	root.add_child(UiStyle.make_flat_label(
		"%s  ·  %s  ·  %s (%.2fx)" % [
			headline,
			str(level.get("display_name", run.get("level_id", "?"))),
			str(diff.get("display_name", "?")),
			float(run.get("difficulty_multiplier", 1.0)),
		],
		UiTokens.FONT_BODY,
		true
	))

	root.add_child(_summary_strip(run))
	root.add_child(_build_timeline_panel())

	var scroll := UiStyle.make_scroll_panel()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := UiStyle.scroll_body(scroll)

	if result == "level_complete":
		body.add_child(_research_panel(run))

	_add_tower_tables(body, run)
	_add_enemy_tables(body, run)
	_add_built_towers_table(body, run)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var retry := UiStyle.make_button("RETRY", 44, "secondary")
	retry.custom_minimum_size = Vector2(160, 44)
	retry.pressed.connect(func() -> void:
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_accept()
		AppRouterScript.go_game(get_tree(), false)
	)
	actions.add_child(retry)
	var menu := UiStyle.make_button("MAIN MENU", 44, "primary")
	menu.custom_minimum_size = Vector2(180, 44)
	menu.pressed.connect(func() -> void:
		if typeof(RunManager) != TYPE_NIL:
			RunManager.clear_last_run()
		AppRouterScript.go_main_menu(get_tree())
	)
	actions.add_child(menu)


func _summary_strip(run: Dictionary) -> PanelContainer:
	var panel := UiStyle.make_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var secs := float(run.get("duration_ms", 0)) / 1000.0
	row.add_child(_metric("TIME", "%.1fs" % secs))
	row.add_child(_metric("CORE", str(int(run.get("ending_core_hp", 0)))))
	row.add_child(_metric("KILLS", str(int(run.get("enemies_killed", 0)))))
	row.add_child(_metric("LEAKS", str(int(run.get("enemies_leaked", 0)))))
	row.add_child(_metric("DAMAGE", "%.0f" % float(run.get("total_damage", 0.0))))
	row.add_child(_metric("GOLD +/−", "%d / %d" % [int(run.get("gold_earned", 0)), int(run.get("gold_spent", 0))]))
	row.add_child(_metric("RP", "+%d" % int(run.get("research_earned", 0))))
	return panel


func _metric(title: String, value: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiStyle.make_flat_label(title, UiTokens.FONT_CAPTION, true))
	col.add_child(UiStyle.make_flat_label(value, UiTokens.FONT_SECTION, false))
	return col


func _build_timeline_panel() -> PanelContainer:
	var dump: Dictionary = TimelineRecorderScript.load_last_dump()
	_snaps = dump.get("snapshots", [])
	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(0, 140)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("TIME MACHINE"))
	if _snaps.is_empty():
		col.add_child(UiStyle.make_flat_label("No timeline dump for this run.", UiTokens.FONT_BODY, true))
		return panel
	_tm_info = UiStyle.make_flat_label("", UiTokens.FONT_DATA, false)
	col.add_child(_tm_info)
	_tm_slider = HSlider.new()
	_tm_slider.min_value = 0
	_tm_slider.max_value = _snaps.size() - 1
	_tm_slider.step = 1
	_tm_slider.value = _snaps.size() - 1
	_tm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tm_slider.custom_minimum_size = Vector2(0, 28)
	col.add_child(_tm_slider)
	_tm_slider.value_changed.connect(_on_tm_scrub)
	_on_tm_scrub(_tm_slider.value)
	col.add_child(UiStyle.make_flat_label(
		"Inspect-only scrubber. Live resume from rewound state is not available on this screen.",
		UiTokens.FONT_CAPTION,
		true
	))
	return panel


func _on_tm_scrub(v: float) -> void:
	var idx := int(v)
	if idx < 0 or idx >= _snaps.size() or _tm_info == null:
		return
	var snap: Dictionary = _snaps[idx]
	_tm_info.text = "t=%.1fs · gold %d · core %d · enemies %d · towers %d" % [
		float(snap.get("t", 0.0)),
		int(snap.get("gold", 0)),
		int(snap.get("core_hp", 0)),
		(snap.get("enemies", []) as Array).size(),
		(snap.get("towers", []) as Array).size(),
	]


func _research_panel(run: Dictionary) -> PanelContainer:
	var panel := UiStyle.make_panel()
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
	var panel := UiStyle.make_panel()
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
	var panel := UiStyle.make_panel()
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UiStyle.make_flat_label("Type | Encountered | Killed | Leaks | Damage taken", UiTokens.FONT_CAPTION, true))
	for entry in stats:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		col.add_child(UiStyle.make_flat_label("%s | %s | %s | %s | %s" % [
			str(e.get("enemy_type", e.get("id", "?"))),
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
	var panel := UiStyle.make_panel()
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	col.add_child(UiStyle.make_flat_label("ID | Spot | Type | Damage | Kills | Extra | Gold", UiTokens.FONT_CAPTION, true))
	for t in towers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = t
		var extra := ""
		if str(row.get("tower_type", "")) == "guard_post":
			extra = "B%d" % int(row.get("enemies_blocked", 0))
		else:
			extra = "X%.0f" % float(row.get("cross_floor_damage", 0.0))
		col.add_child(UiStyle.make_flat_label("%s | %s | %s | %.0f | %d | %s | %d" % [
			str(row.get("tower_runtime_id", "?")),
			str(row.get("build_spot_id", "?")),
			str(row.get("tower_type", "?")),
			float(row.get("damage_dealt", 0.0)),
			int(row.get("kills", 0)),
			extra,
			int(row.get("gold_invested", 0)),
		], UiTokens.FONT_DATA, false))


func _type_text(entry: Dictionary, run: Dictionary) -> String:
	var tid := str(entry.get("tower_type", "?"))
	var total_dmg := maxf(float(run.get("total_damage", 0.0)), 0.001)
	var dmg := float(entry.get("damage_dealt", 0.0))
	var gold := maxf(float(entry.get("gold_invested", 0.0)), 1.0)
	var shots := maxf(float(entry.get("shots", 0)), 0.001)
	var hits := float(entry.get("hits", 0))
	var target_t := float(entry.get("target_time", 0.0))
	var idle_t := float(entry.get("no_target_time", 0.0))
	var combat_span := maxf(target_t + idle_t, 0.001)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(tid.to_upper())
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
	lines.append("Blueprint: %s" % str(entry.get("blueprint_id", "?")))
	return "\n".join(lines)
