extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const SessionStoreScript := preload("res://scripts/run/session_store.gd")


func _ready() -> void:
	UiStyleScript.apply_root(self)
	var root := UiStyleScript.make_content_shell(self, 520.0, 28.0)

	var panel := UiStyleScript.make_panel()
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	vbox.add_child(UiStyleScript.make_title("HODL THE TOWER", 40))
	vbox.add_child(UiStyleScript.make_label("Ridiculously serious tower defense.", 14, true))

	var badge := UiStyleScript.make_lv_xp_rp_badge(
		ProfileManager.get_player_level(),
		ProfileManager.get_research_xp_total(),
		ProfileManager.get_research_points()
	)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(badge)

	if SessionStoreScript.has_session():
		var session: Dictionary = SessionStoreScript.load_session()
		vbox.add_child(UiStyleScript.make_flat_label(
			"Saved run: %s · %s · Wave %d" % [
				str(session.get("level_id", "?")),
				str(session.get("difficulty_id", "?")),
				int(session.get("current_wave", 1)),
			],
			13,
			true
		))
		var cont := UiStyleScript.make_button("CONTINUE RUN")
		cont.pressed.connect(func() -> void: AppRouterScript.go_game(get_tree(), true))
		vbox.add_child(cont)
		var restart_saved := UiStyleScript.make_button("RESTART SAVED RUN")
		restart_saved.pressed.connect(_restart_saved)
		vbox.add_child(restart_saved)
		var delete_saved := UiStyleScript.make_button("DELETE SAVED RUN")
		delete_saved.pressed.connect(func() -> void:
			SessionStoreScript.clear()
			AppRouterScript.go_main_menu(get_tree())
		)
		vbox.add_child(delete_saved)

	var play_btn := UiStyleScript.make_button("NEW RUN")
	play_btn.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
	vbox.add_child(play_btn)

	var prog_btn := UiStyleScript.make_button("PROGRESSION")
	prog_btn.pressed.connect(func() -> void: AppRouterScript.go_progression(get_tree()))
	vbox.add_child(prog_btn)

	var gallery_btn := UiStyleScript.make_button("GALLERY")
	gallery_btn.pressed.connect(func() -> void: AppRouterScript.go_gallery(get_tree()))
	vbox.add_child(gallery_btn)

	var quit_btn := UiStyleScript.make_button("QUIT")
	quit_btn.pressed.connect(func() -> void: AppRouterScript.quit_game(get_tree()))
	vbox.add_child(quit_btn)


func _restart_saved() -> void:
	var session: Dictionary = SessionStoreScript.load_session()
	if session.is_empty():
		return
	if typeof(RunManager) != TYPE_NIL:
		RunManager.configure(str(session.get("level_id", "vertical_test")), str(session.get("difficulty_id", "normal")))
	SessionStoreScript.clear()
	AppRouterScript.go_game(get_tree(), false)
