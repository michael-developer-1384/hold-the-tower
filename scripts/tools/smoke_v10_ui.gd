extends SceneTree

## Loads v0.13 UI/domain scripts and instantiates key controls headlessly.


func _initialize() -> void:
	var ok := true
	ok = _load_ok("res://ui/components/entity_preview_3d.gd") and ok
	ok = _load_ok("res://ui/components/tower_card.gd") and ok
	ok = _load_ok("res://ui/pages/database_page.gd") and ok
	ok = _load_ok("res://ui/pages/tower_detail_page.gd") and ok
	ok = _load_ok("res://ui/pages/tower_detail_page.tscn") and ok
	ok = _load_ok("res://ui/pages/enemy_detail_page.gd") and ok
	ok = _load_ok("res://ui/pages/progression_page.gd") and ok
	ok = _load_ok("res://ui/pages/main_menu_page.gd") and ok
	ok = _load_ok("res://ui/pages/settings_page.gd") and ok
	ok = _load_ok("res://ui/shell/app_shell.gd") and ok
	ok = _load_ok("res://scripts/app/settings_manager.gd") and ok
	ok = _load_ok("res://ui/components/research_stat_row.gd") and ok
	ok = _load_ok("res://scripts/run/session_store.gd") and ok
	ok = _load_ok("res://scripts/run/timeline_recorder.gd") and ok
	ok = _load_ok("res://ui/theme/hodl_theme.tres") and ok

	var catalog = load("res://scripts/towers/tower_catalog.gd")
	var defs: Array = catalog.create_all()
	var sentry = catalog.find_by_id(defs, "basic_tower")
	var card_script = load("res://ui/components/tower_card.gd")
	var card = card_script.new()
	root.add_child(card)
	card.setup(sentry, card_script.Mode.GALLERY)

	var preview_scene = load("res://ui/components/entity_preview_3d.tscn")
	var preview = preview_scene.instantiate()
	root.add_child(preview)
	preview.set_visual_scene(sentry.visual_scene)
	var kit = load("res://scenes/towers/visuals/kit/sentry_visual_kit.tscn")
	if kit == null:
		push_error("Missing sentry kit visual")
		ok = false
	else:
		preview.set_visual_scene(kit)
	var detail = load("res://ui/pages/tower_detail_page.tscn")
	if detail == null:
		push_error("Failed to load tower_detail_page")
		ok = false
	else:
		root.add_child(detail.instantiate())

	create_timer(0.2).timeout.connect(func() -> void:
		if card.get_child_count() < 1:
			push_error("TowerCard failed to build children")
			ok = false
		if ok:
			print("v0.13 UI smoke: OK")
			quit(0)
		else:
			print("v0.13 UI smoke: FAILED")
			quit(1)
	)


func _load_ok(path: String) -> bool:
	if load(path) == null:
		push_error("Failed to load %s" % path)
		return false
	return true
