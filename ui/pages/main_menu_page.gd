extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const SessionStoreScript := preload("res://scripts/run/session_store.gd")
const MenuDioramaScript := preload("res://ui/components/menu_diorama_3d.gd")

var _restart_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)

	left.add_child(UiStyle.make_flat_label("HODL THE TOWER", UiTokens.FONT_DISPLAY, false))
	left.add_child(UiStyle.make_flat_label("RIDICULOUSLY SERIOUS TOWER DEFENSE", UiTokens.FONT_LABEL, true))
	left.add_child(UiStyle.make_divider())

	var has_session := SessionStoreScript.has_session()
	if has_session:
		var cont := UiStyle.make_button("CONTINUE RUN", 48, "primary")
		cont.pressed.connect(func() -> void:
			if typeof(UiAudio) != TYPE_NIL:
				UiAudio.play_accept()
			AppRouterScript.go_game(get_tree(), true)
		)
		left.add_child(cont)
		var new_run := UiStyle.make_button("NEW RUN", 40, "secondary")
		new_run.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
		left.add_child(new_run)
	else:
		var new_run2 := UiStyle.make_button("NEW RUN", 48, "primary")
		new_run2.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
		left.add_child(new_run2)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	if has_session:
		left.add_child(_build_session_panel())
	_build_last_run(left)

	var diorama := MenuDioramaScript.new()
	row.add_child(diorama)

	_restart_dialog = _make_confirm("RESTART SAVED RUN?", "This clears the saved checkpoint and starts the run again.")
	_restart_dialog.confirmed.connect(_restart_saved)
	_delete_dialog = _make_confirm("DELETE SAVED RUN?", "This saved session cannot be restored.")
	_delete_dialog.confirmed.connect(func() -> void:
		SessionStoreScript.clear()
		AppRouterScript.go_main_menu(get_tree())
	)


func _build_session_panel() -> PanelContainer:
	var session: Dictionary = SessionStoreScript.load_session()
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("ACTIVE SESSION"))
	var level_id := str(session.get("level_id", "?"))
	var diff := str(session.get("difficulty_id", "?"))
	var wave := int(session.get("current_wave", 1))
	col.add_child(UiStyle.make_flat_label("%s · %s · Wave %d" % [level_id, diff.capitalize(), wave], UiTokens.FONT_BODY, false))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)
	var restart := UiStyle.make_compact_button("RESTART", 100, 34, "secondary")
	restart.pressed.connect(func() -> void:
		_restart_dialog.dialog_text = "%s · %s · Wave %d\n\nThis clears the saved checkpoint and starts the run again." % [
			level_id, diff.capitalize(), wave
		]
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_modal()
		_restart_dialog.popup_centered(Vector2i(480, 200))
	)
	actions.add_child(restart)
	var delete_btn := UiStyle.make_compact_button("DELETE", 100, 34, "danger")
	delete_btn.pressed.connect(func() -> void:
		_delete_dialog.dialog_text = "%s · %s · Wave %d\n\nThis saved session cannot be restored." % [
			level_id, diff.capitalize(), wave
		]
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_modal()
		_delete_dialog.popup_centered(Vector2i(480, 200))
	)
	actions.add_child(delete_btn)
	return panel


func _build_last_run(parent: Control) -> void:
	if typeof(RunManager) == TYPE_NIL:
		return
	var run: Dictionary = RunManager.last_run
	if run.is_empty():
		return
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("LAST RUN"))
	var result := "Victory" if str(run.get("result", "")) == "level_complete" else "Defeat"
	col.add_child(UiStyle.make_flat_label("%s · %s" % [str(run.get("level_id", "?")), result], UiTokens.FONT_BODY, false))
	var rp := int(run.get("research_earned", 0))
	var xp := int(run.get("research_xp_earned", 0))
	if rp > 0 or xp > 0:
		col.add_child(UiStyle.make_flat_label("+%d RP · +%d XP" % [rp, xp], UiTokens.FONT_CAPTION, true))
	parent.add_child(panel)


func _make_confirm(title: String, text: String) -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.title = title
	d.dialog_text = text
	d.ok_button_text = "CONFIRM"
	d.cancel_button_text = "CANCEL"
	UiStyle.style_modal(d)
	add_child(d)
	return d


func _restart_saved() -> void:
	var session: Dictionary = SessionStoreScript.load_session()
	if session.is_empty():
		return
	if typeof(RunManager) != TYPE_NIL:
		RunManager.configure(str(session.get("level_id", "vertical_test")), str(session.get("difficulty_id", "normal")))
	SessionStoreScript.clear()
	AppRouterScript.go_game(get_tree(), false)
