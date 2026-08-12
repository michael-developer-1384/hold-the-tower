extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")

const PLACEHOLDERS := [
	{"id": "sniper_nest", "display_name": "Sniper Nest", "description": "Long-range precision (coming soon)"},
	{"id": "mortar_pad", "display_name": "Mortar Pad", "description": "Arc splash support (coming soon)"},
	{"id": "beacon", "display_name": "Signal Beacon", "description": "Utility support (coming soon)"},
]


func _ready() -> void:
	UiStyleScript.apply_root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var rp := UiStyleScript.make_rp_badge(ProfileManager.get_research_points())
	UiStyleScript.make_top_bar(
		root,
		"TOWER GALLERY",
		func() -> void: AppRouterScript.go_main_menu(get_tree()),
		[rp]
	)

	var scroll_panel := UiStyleScript.make_scroll_panel()
	root.add_child(scroll_panel)
	var body := UiStyleScript.scroll_body(scroll_panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)

	var defs: Array = TowerCatalogScript.create_all()
	for def in defs:
		grid.add_child(_make_tower_card({
			"id": str(def.tower_id),
			"display_name": str(def.display_name),
			"description": str(def.description),
			"unlocked": ProfileManager.is_tower_unlocked(str(def.tower_id)),
			"placeholder": false,
		}))

	for ph in PLACEHOLDERS:
		grid.add_child(_make_tower_card({
			"id": str(ph["id"]),
			"display_name": str(ph["display_name"]),
			"description": str(ph["description"]),
			"unlocked": false,
			"placeholder": true,
		}))


func _make_tower_card(data: Dictionary) -> Control:
	var tid := str(data["id"])
	var unlocked := bool(data["unlocked"])
	var placeholder := bool(data.get("placeholder", false))
	var card := UiStyleScript.make_panel()
	card.custom_minimum_size = Vector2(260, 280)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)

	cv.add_child(UiStyleScript.make_tower_preview(tid if not placeholder else "locked"))
	cv.add_child(UiStyleScript.make_flat_label(str(data["display_name"]), 20))
	cv.add_child(UiStyleScript.make_label(str(data["description"]), 13, true))

	if placeholder:
		cv.add_child(UiStyleScript.make_flat_label("Coming soon", 14, true))
		var locked := UiStyleScript.make_button("LOCKED")
		locked.disabled = true
		cv.add_child(locked)
	else:
		var stats: Dictionary = ProfileManager.get_tower_lifetime(tid)
		cv.add_child(UiStyleScript.make_flat_label(
			"Unlocked" if unlocked else "Locked", 13, true
		))
		cv.add_child(UiStyleScript.make_label(
			"Games: %d\nDamage: %d\nKills: %d" % [
				int(stats.get("games_used", 0)),
				int(round(float(stats.get("damage_dealt", 0.0)))),
				int(stats.get("kills", 0)),
			],
			13
		))
		var open := UiStyleScript.make_button("OPEN DETAIL" if unlocked else "LOCKED")
		open.disabled = not unlocked
		if unlocked:
			open.pressed.connect(func() -> void: AppRouterScript.go_detail(get_tree(), tid))
		cv.add_child(open)
	return card
