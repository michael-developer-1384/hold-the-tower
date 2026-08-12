extends Control

const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	root.add_child(UiStyle.make_flat_label("PROGRESSION", UiTokens.FONT_PAGE, false))
	root.add_child(UiStyle.make_flat_label("Read-only overview of level, capacity, and unlocks.", UiTokens.FONT_CAPTION, true))

	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var rp := ProfileManager.get_research_points()
	var xp_info: Dictionary = ProgressionConfigScript.xp_into_level(xp)

	var hero := UiStyle.make_panel()
	root.add_child(hero)
	var hero_col := VBoxContainer.new()
	hero_col.add_theme_constant_override("separation", 8)
	hero.add_child(hero_col)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 28)
	hero_col.add_child(hero_row)
	hero_row.add_child(_metric("LV", str(level)))
	if bool(xp_info.get("at_cap", false)):
		hero_row.add_child(_metric("XP", "%d MAX" % xp))
	else:
		hero_row.add_child(_metric("XP", "%d / %d" % [xp, int(xp_info.get("xp_next_total", xp))]))
	hero_row.add_child(_metric("RP", str(rp)))
	hero_row.add_child(_metric(
		"CAPACITY",
		"S%d / G%d" % [
			ProgressionConfigScript.tower_capacity("basic_tower", level),
			ProgressionConfigScript.tower_capacity("guard_post", level),
		]
	))

	if not bool(xp_info.get("at_cap", false)):
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.show_percentage = false
		bar.max_value = float(maxi(int(xp_info.get("xp_need", 1)), 1))
		bar.value = float(int(xp_info.get("xp_in_level", 0)))
		hero_col.add_child(bar)
		hero_col.add_child(UiStyle.make_flat_label(
			"%d XP to Level %d" % [int(xp_info.get("xp_to_next", 0)), level + 1],
			UiTokens.FONT_CAPTION,
			true
		))

	root.add_child(UiStyle.make_section_label("LEVEL ROADMAP"))
	var road_scroll := ScrollContainer.new()
	road_scroll.custom_minimum_size = Vector2(0, 168)
	road_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(road_scroll)
	var road := HBoxContainer.new()
	road.add_theme_constant_override("separation", 10)
	road_scroll.add_child(road)
	for entry in ProgressionConfigScript.roadmap():
		road.add_child(_roadmap_card(entry, level))

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	split.add_child(_benefits_panel(level))
	split.add_child(_next_unlocks_panel(level))

	root.add_child(UiStyle.make_section_label("TOWER UNLOCKS"))
	var towers_panel := UiStyle.make_panel()
	root.add_child(towers_panel)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 6)
	towers_panel.add_child(tcol)
	for def in TowerCatalogScript.create_all():
		var tid := str(def.tower_id)
		var unlocked := ProfileManager.is_tower_unlocked(tid)
		tcol.add_child(UiStyle.make_flat_label(
			"%s — %s" % [str(def.display_name), "UNLOCKED" if unlocked else "LOCKED / later"],
			UiTokens.FONT_BODY,
			not unlocked
		))
	tcol.add_child(UiStyle.make_flat_label(
		"Placeholder unlocks planned at Player Level 6 and 8.",
		UiTokens.FONT_CAPTION,
		true
	))


func _metric(title: String, value: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiStyle.make_flat_label(title, UiTokens.FONT_CAPTION, true))
	col.add_child(UiStyle.make_flat_label(value, UiTokens.FONT_SECTION, false))
	return col


func _roadmap_card(entry: Dictionary, current_level: int) -> PanelContainer:
	var lvl := int(entry.get("level", 1))
	var card := UiStyle.make_panel()
	card.custom_minimum_size = Vector2(168, 140)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var state := "CURRENT" if lvl == current_level else ("unlocked" if lvl < current_level else "locked")
	var title := UiStyle.make_flat_label("LV %d" % lvl, UiTokens.FONT_SECTION, false)
	if lvl == current_level:
		title.add_theme_color_override("font_color", UiTokens.ACCENT)
	col.add_child(title)
	col.add_child(UiStyle.make_flat_label("%d XP · %s" % [int(entry.get("xp_required", 0)), state], UiTokens.FONT_CAPTION, true))
	col.add_child(UiStyle.make_flat_label(
		"Cap %s" % str(entry.get("research_cap_label", "?")),
		UiTokens.FONT_DATA,
		false
	))
	col.add_child(UiStyle.make_flat_label(
		"S %d  G %d" % [int(entry.get("sentry_capacity", 0)), int(entry.get("guard_capacity", 0))],
		UiTokens.FONT_CAPTION,
		true
	))
	for p in entry.get("placeholder_unlocks", []):
		col.add_child(UiStyle.make_flat_label(str(p), UiTokens.FONT_CAPTION, true))
	return card


func _benefits_panel(level: int) -> PanelContainer:
	var panel := UiStyle.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("CURRENT BENEFITS"))
	var cur := ProgressionConfigScript.unlocks_for_level(level)
	col.add_child(UiStyle.make_flat_label("Research cap: %s" % str(cur.get("research_cap_label", "?")), UiTokens.FONT_BODY, false))
	col.add_child(UiStyle.make_flat_label(
		"Sentry capacity: %d RP" % int(cur.get("sentry_capacity", 0)),
		UiTokens.FONT_BODY,
		false
	))
	col.add_child(UiStyle.make_flat_label(
		"Guard capacity: %d RP" % int(cur.get("guard_capacity", 0)),
		UiTokens.FONT_BODY,
		false
	))
	return panel


func _next_unlocks_panel(level: int) -> PanelContainer:
	var panel := UiStyle.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	if level >= ProgressionConfigScript.max_level():
		col.add_child(UiStyle.make_section_label("NEXT LEVEL"))
		col.add_child(UiStyle.make_flat_label("Fully unlocked.", UiTokens.FONT_BODY, true))
		return panel
	var next_unlock: Dictionary = ProgressionConfigScript.unlocks_for_level(level + 1)
	col.add_child(UiStyle.make_section_label("LEVEL %d UNLOCKS" % (level + 1)))
	col.add_child(UiStyle.make_flat_label(
		"Research cap: %s → %s" % [
			str(next_unlock.get("prev_research_cap_label", "?")),
			str(next_unlock.get("research_cap_label", "?")),
		],
		UiTokens.FONT_BODY,
		false
	))
	col.add_child(UiStyle.make_flat_label(
		"Sentry capacity: %d → %d RP" % [
			int(next_unlock.get("prev_sentry_capacity", 0)),
			int(next_unlock.get("sentry_capacity", 0)),
		],
		UiTokens.FONT_BODY,
		false
	))
	col.add_child(UiStyle.make_flat_label(
		"Guard capacity: %d → %d RP" % [
			int(next_unlock.get("prev_guard_capacity", 0)),
			int(next_unlock.get("guard_capacity", 0)),
		],
		UiTokens.FONT_BODY,
		false
	))
	for p in next_unlock.get("placeholder_unlocks", []):
		col.add_child(UiStyle.make_flat_label("• %s" % str(p), UiTokens.FONT_BODY, true))
	return panel
