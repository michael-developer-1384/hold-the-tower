extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


func _ready() -> void:
	UiStyleScript.apply_root(self)
	var root := UiStyleScript.make_content_shell(self, 1200.0)

	var badge := UiStyleScript.make_lv_xp_rp_badge(
		ProfileManager.get_player_level(),
		ProfileManager.get_research_xp_total(),
		ProfileManager.get_research_points()
	)
	UiStyleScript.make_top_bar(
		root,
		"PROGRESSION",
		func() -> void: AppRouterScript.go_main_menu(get_tree()),
		[badge]
	)

	var scroll := UiStyleScript.make_scroll_panel()
	root.add_child(scroll)
	var body := UiStyleScript.scroll_body(scroll)

	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var xp_info: Dictionary = ProgressionConfigScript.xp_into_level(xp)

	var hero := UiStyleScript.make_panel()
	body.add_child(hero)
	var hero_col := VBoxContainer.new()
	hero_col.add_theme_constant_override("separation", 8)
	hero.add_child(hero_col)
	hero_col.add_child(UiStyleScript.make_flat_label("PLAYER LEVEL %d" % level, 28))
	if bool(xp_info.get("at_cap", false)):
		hero_col.add_child(UiStyleScript.make_flat_label("XP %d  (max level)" % xp, 16))
	else:
		var next_total := int(xp_info.get("xp_next_total", xp))
		var to_next := int(xp_info.get("xp_to_next", 0))
		hero_col.add_child(UiStyleScript.make_flat_label("XP %d / %d" % [xp, next_total], 16))
		hero_col.add_child(UiStyleScript.make_flat_label("%d XP to Level %d" % [to_next, level + 1], 14, true))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.show_percentage = false
		bar.max_value = float(maxi(int(xp_info.get("xp_need", 1)), 1))
		bar.value = float(int(xp_info.get("xp_in_level", 0)))
		hero_col.add_child(bar)

	if level < ProgressionConfigScript.max_level():
		var next_unlock: Dictionary = ProgressionConfigScript.unlocks_for_level(level + 1)
		var unlock_panel := UiStyleScript.make_panel()
		body.add_child(unlock_panel)
		var ucol := VBoxContainer.new()
		ucol.add_theme_constant_override("separation", 4)
		unlock_panel.add_child(ucol)
		ucol.add_child(UiStyleScript.make_flat_label("LEVEL %d UNLOCKS" % (level + 1), 18))
		ucol.add_child(UiStyleScript.make_flat_label(
			"Research cap: %s → %s" % [
				str(next_unlock.get("prev_research_cap_label", "?")),
				str(next_unlock.get("research_cap_label", "?")),
			],
			14
		))
		ucol.add_child(UiStyleScript.make_flat_label(
			"Sentry capacity: %d → %d RP" % [
				int(next_unlock.get("prev_sentry_capacity", 0)),
				int(next_unlock.get("sentry_capacity", 0)),
			],
			14
		))
		ucol.add_child(UiStyleScript.make_flat_label(
			"Guard capacity: %d → %d RP" % [
				int(next_unlock.get("prev_guard_capacity", 0)),
				int(next_unlock.get("guard_capacity", 0)),
			],
			14
		))
		for p in next_unlock.get("placeholder_unlocks", []):
			ucol.add_child(UiStyleScript.make_flat_label("• %s" % str(p), 14, true))

	body.add_child(UiStyleScript.make_flat_label("LEVEL ROADMAP", 20))
	for entry in ProgressionConfigScript.roadmap():
		var lvl := int(entry.get("level", 1))
		var card := UiStyleScript.make_panel()
		body.add_child(card)
		var ccol := VBoxContainer.new()
		ccol.add_theme_constant_override("separation", 3)
		card.add_child(ccol)
		var title := "Level %d  ·  %d XP" % [lvl, int(entry.get("xp_required", 0))]
		if lvl == level:
			title += "  ·  CURRENT"
		elif lvl < level:
			title += "  ·  unlocked"
		else:
			title += "  ·  locked"
		ccol.add_child(UiStyleScript.make_flat_label(title, 15))
		ccol.add_child(UiStyleScript.make_flat_label(
			"Research cap %s  ·  Sentry %d RP  ·  Guard %d RP" % [
				str(entry.get("research_cap_label", "?")),
				int(entry.get("sentry_capacity", 0)),
				int(entry.get("guard_capacity", 0)),
			],
			13,
			true
		))
		for p in entry.get("placeholder_unlocks", []):
			ccol.add_child(UiStyleScript.make_flat_label("Unlock: %s" % str(p), 13, true))

	body.add_child(UiStyleScript.make_flat_label("TOWERS", 20))
	var towers_panel := UiStyleScript.make_panel()
	body.add_child(towers_panel)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 4)
	towers_panel.add_child(tcol)
	for def in TowerCatalogScript.create_all():
		var tid := str(def.tower_id)
		var unlocked := ProfileManager.is_tower_unlocked(tid)
		var status := "UNLOCKED" if unlocked else "LOCKED / later"
		tcol.add_child(UiStyleScript.make_flat_label(
			"%s — %s" % [str(def.display_name), status],
			14,
			not unlocked
		))
	tcol.add_child(UiStyleScript.make_flat_label(
		"Placeholder unlocks planned at Player Level 6 and 8.",
		13,
		true
	))
