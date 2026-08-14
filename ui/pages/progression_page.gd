extends Control

const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const LevelNodeScene := preload("res://ui/components/progression_level_node.tscn")

@onready var _hero_panel: PanelContainer = %HeroPanel
@onready var _lv_metric: VBoxContainer = %LvMetric
@onready var _xp_metric: VBoxContainer = %XpMetric
@onready var _rp_metric: VBoxContainer = %RpMetric
@onready var _capacity_label: Label = %CapacityLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_hint: Label = %XpHint
@onready var _road_scroll: ScrollContainer = %RoadScroll
@onready var _roadmap_host: HBoxContainer = %RoadmapHost
@onready var _benefits_panel: PanelContainer = %BenefitsPanel
@onready var _benefits_host: VBoxContainer = %BenefitsHost
@onready var _next_panel: PanelContainer = %NextPanel
@onready var _next_host: VBoxContainer = %NextHost
@onready var _unlocks_panel: PanelContainer = %UnlocksPanel
@onready var _unlocks_host: VBoxContainer = %TowerUnlocksHost


func _ready() -> void:
	UiStyle.apply_theme(self)
	UiStyle.style_card_panel(_hero_panel)
	UiStyle.style_card_panel(_benefits_panel)
	UiStyle.style_card_panel(_next_panel)
	UiStyle.style_card_panel(_unlocks_panel)
	_bind()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func _bind() -> void:
	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var rp := ProfileManager.get_research_points()
	var xp_info: Dictionary = ProgressionConfigScript.xp_into_level(xp)

	_fill_metric(_lv_metric, "LV", str(level))
	if bool(xp_info.get("at_cap", false)):
		_fill_metric(_xp_metric, "XP", "%d MAX" % xp)
	else:
		_fill_metric(_xp_metric, "XP", "%d / %d" % [xp, int(xp_info.get("xp_next_total", xp))])
	_fill_metric(_rp_metric, "RP", str(rp))

	var sentry := StatPresentationScript.display_tower("basic_tower").to_upper()
	var guard := StatPresentationScript.display_tower("guard_post").to_upper()
	var lava := StatPresentationScript.display_tower("lava_tower").to_upper()
	_capacity_label.text = "%s %d RP  ·  %s %d RP  ·  %s %d RP" % [
		sentry,
		ProgressionConfigScript.tower_capacity("basic_tower", level),
		guard,
		ProgressionConfigScript.tower_capacity("guard_post", level),
		lava,
		ProgressionConfigScript.tower_capacity("lava_tower", level),
	]

	if bool(xp_info.get("at_cap", false)):
		_xp_bar.visible = false
		_xp_hint.visible = false
	else:
		_xp_bar.visible = true
		_xp_hint.visible = true
		_xp_bar.max_value = float(maxi(int(xp_info.get("xp_need", 1)), 1))
		_xp_bar.value = float(int(xp_info.get("xp_in_level", 0)))
		_xp_hint.text = "%d XP to Level %d" % [int(xp_info.get("xp_to_next", 0)), level + 1]

	for c in _roadmap_host.get_children():
		c.queue_free()
	for entry in ProgressionConfigScript.roadmap():
		var node := LevelNodeScene.instantiate()
		_roadmap_host.add_child(node)
		node.setup(entry, level)

	_fill_benefits(level)
	_fill_next(level)
	_fill_unlocks()


func _fill_metric(host: VBoxContainer, title: String, value: String) -> void:
	for c in host.get_children():
		c.queue_free()
	var t := UiStyle.make_flat_label(title, UiTokens.FONT_CAPTION, true)
	var v := UiStyle.make_flat_label(value, UiTokens.FONT_SECTION, false)
	host.add_child(t)
	host.add_child(v)


func _fill_benefits(level: int) -> void:
	for c in _benefits_host.get_children():
		c.queue_free()
	_benefits_host.add_child(UiStyle.make_section_label("CURRENT BENEFITS"))
	var cur := ProgressionConfigScript.unlocks_for_level(level)
	_benefits_host.add_child(UiStyle.make_flat_label(
		"Research cap: %s" % str(cur.get("research_cap_label", "?")),
		UiTokens.FONT_BODY, false
	))
	_benefits_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d RP" % [
			StatPresentationScript.display_tower("basic_tower"),
			int(cur.get("sentry_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))
	_benefits_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d RP" % [
			StatPresentationScript.display_tower("guard_post"),
			int(cur.get("guard_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))
	_benefits_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d RP" % [
			StatPresentationScript.display_tower("lava_tower"),
			int(cur.get("lava_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))


func _fill_next(level: int) -> void:
	for c in _next_host.get_children():
		c.queue_free()
	if level >= ProgressionConfigScript.max_level():
		_next_host.add_child(UiStyle.make_section_label("NEXT LEVEL"))
		_next_host.add_child(UiStyle.make_flat_label("Fully unlocked.", UiTokens.FONT_BODY, true))
		return
	var next_unlock: Dictionary = ProgressionConfigScript.unlocks_for_level(level + 1)
	_next_host.add_child(UiStyle.make_section_label("LEVEL %d UNLOCKS" % (level + 1)))
	_next_host.add_child(UiStyle.make_flat_label(
		"Research cap: %s → %s" % [
			str(next_unlock.get("prev_research_cap_label", "?")),
			str(next_unlock.get("research_cap_label", "?")),
		],
		UiTokens.FONT_BODY, false
	))
	_next_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d → %d RP" % [
			StatPresentationScript.display_tower("basic_tower"),
			int(next_unlock.get("prev_sentry_capacity", 0)),
			int(next_unlock.get("sentry_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))
	_next_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d → %d RP" % [
			StatPresentationScript.display_tower("guard_post"),
			int(next_unlock.get("prev_guard_capacity", 0)),
			int(next_unlock.get("guard_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))
	_next_host.add_child(UiStyle.make_flat_label(
		"%s capacity: %d → %d RP" % [
			StatPresentationScript.display_tower("lava_tower"),
			int(next_unlock.get("prev_lava_capacity", 0)),
			int(next_unlock.get("lava_capacity", 0)),
		],
		UiTokens.FONT_BODY, false
	))
	for p in next_unlock.get("placeholder_unlocks", []):
		_next_host.add_child(UiStyle.make_flat_label(str(p), UiTokens.FONT_CAPTION, true))


func _fill_unlocks() -> void:
	for c in _unlocks_host.get_children():
		c.queue_free()
	for def in TowerCatalogScript.create_all():
		var unlocked := ProfileManager.is_tower_unlocked(str(def.tower_id))
		_unlocks_host.add_child(UiStyle.make_flat_label(
			"%s — %s" % [str(def.display_name), "UNLOCKED" if unlocked else "LOCKED / later"],
			UiTokens.FONT_BODY,
			not unlocked
		))
	_unlocks_host.add_child(UiStyle.make_flat_label(
		"Placeholder unlocks planned at Player Level 6 and 8.",
		UiTokens.FONT_CAPTION,
		true
	))


func _on_resized() -> void:
	# Full HD content area (~1700px): fit all 10 without horizontal scroll.
	var wide := size.x >= 1400.0
	_road_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if wide else ScrollContainer.SCROLL_MODE_AUTO
	)
	_roadmap_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
