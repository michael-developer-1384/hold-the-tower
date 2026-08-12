extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")


func _ready() -> void:
	UiStyleScript.apply_root(self)
	var run: Dictionary = RunManager.last_run
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

	var result := str(run.get("result", "unknown"))
	var headline := "LEVEL COMPLETE" if result == "level_complete" else "GAME OVER"
	root.add_child(UiStyleScript.make_title(headline, 34))

	var level := LevelCatalogScript.find(str(run.get("level_id", "")))
	var diff := DifficultyCatalogScript.find(str(run.get("difficulty_id", "normal")))
	root.add_child(UiStyleScript.make_label(
		"%s\n%s — %.2fx" % [
			str(level.get("display_name", run.get("level_id", "?"))),
			str(diff.get("display_name", "?")),
			float(run.get("difficulty_multiplier", 1.0)),
		],
		18
	))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	var overview := UiStyleScript.make_panel()
	body.add_child(overview)
	var ov := UiStyleScript.make_label(_overview_text(run), 15)
	overview.add_child(ov)

	for entry in run.get("tower_type_stats", []):
		var panel := UiStyleScript.make_panel()
		body.add_child(panel)
		panel.add_child(UiStyleScript.make_label(_type_text(entry, run), 14))

	var table_panel := UiStyleScript.make_panel()
	body.add_child(table_panel)
	table_panel.add_child(UiStyleScript.make_label(_table_text(run), 13))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	var retry := UiStyleScript.make_button("RETRY")
	retry.pressed.connect(func() -> void: AppRouterScript.go_game(get_tree()))
	actions.add_child(retry)
	var menu := UiStyleScript.make_button("MAIN MENU")
	menu.pressed.connect(func() -> void:
		RunManager.clear_last_run()
		AppRouterScript.go_main_menu(get_tree())
	)
	actions.add_child(menu)


func _overview_text(run: Dictionary) -> String:
	var secs := float(run.get("duration_ms", 0)) / 1000.0
	return "\n".join([
		"Time: %.1fs" % secs,
		"Core HP: %d" % int(run.get("ending_core_hp", 0)),
		"Enemies killed: %d" % int(run.get("enemies_killed", 0)),
		"Enemies leaked: %d" % int(run.get("enemies_leaked", 0)),
		"Total damage: %.0f" % float(run.get("total_damage", 0.0)),
		"Gold earned: %d" % int(run.get("gold_earned", 0)),
		"Gold spent: %d" % int(run.get("gold_spent", 0)),
		"Research earned: +%d" % int(run.get("research_earned", 0)),
		"Research total: %d" % int(run.get("research_total", ProfileManager.get_research_points())),
	])


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
	lines.append("Built: %d" % int(entry.get("times_built", 0)))
	lines.append("Gold invested: %.0f" % float(entry.get("gold_invested", 0.0)))
	lines.append("Damage: %.0f (%.0f%%)" % [dmg, 100.0 * dmg / total_dmg])
	lines.append("Kills: %d" % int(entry.get("kills", 0)))
	lines.append("Damage / 100 Gold: %.1f" % (dmg / gold * 100.0))
	if tid == "basic_tower":
		lines.append("Hit rate: %.0f%%" % (100.0 * hits / shots))
		lines.append("Combat uptime: %.0f%%" % (100.0 * target_t / combat_span))
		lines.append("Idle / no target: %.0f%%" % (100.0 * idle_t / combat_span))
		lines.append("Cross-floor damage: %.0f (%.0f%%)" % [
			float(entry.get("cross_floor_damage", 0.0)),
			100.0 * float(entry.get("cross_floor_damage", 0.0)) / maxf(dmg, 0.001),
		])
	elif tid == "guard_post":
		var blocks := int(entry.get("enemies_blocked", 0))
		var block_ms := int(entry.get("total_block_time_ms", 0))
		lines.append("Enemies blocked: %d" % blocks)
		lines.append("Total block time: %.1fs" % (float(block_ms) / 1000.0))
		lines.append("Avg block duration: %.2fs" % (
			(float(block_ms) / 1000.0 / float(blocks)) if blocks > 0 else 0.0
		))
		lines.append("Guard deaths: %d" % int(entry.get("guards_died", 0)))
		lines.append("Respawns: %d" % int(entry.get("guards_respawned", 0)))
		lines.append("Damage taken: %.0f" % float(entry.get("guard_damage_taken", 0.0)))
		lines.append("Healing: %.0f" % float(entry.get("guard_healing_done", 0.0)))
		lines.append("Peak simultaneous blocks: %d" % int(entry.get("peak_simultaneous_blocks", 0)))
	lines.append("Blueprint: %s" % str(entry.get("blueprint_id", "?")))
	return "\n".join(lines)


func _table_text(run: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("BUILT TOWERS")
	lines.append("ID | Spot | Type | Damage | Kills | Extra | Gold")
	for t in run.get("towers", []):
		var extra := ""
		if str(t.get("tower_type", "")) == "guard_post":
			extra = "B%d" % int(t.get("enemies_blocked", 0))
		else:
			extra = "X%.0f" % float(t.get("cross_floor_damage", 0.0))
		lines.append("%s | %s | %s | %.0f | %d | %s | %d" % [
			str(t.get("tower_runtime_id", "?")),
			str(t.get("build_spot_id", "?")),
			str(t.get("tower_type", "?")),
			float(t.get("damage_dealt", 0.0)),
			int(t.get("kills", 0)),
			extra,
			int(t.get("gold_invested", 0)),
		])
	return "\n".join(lines)
