extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const SessionStoreScript := preload("res://scripts/run/session_store.gd")
const SessionSummaryScene := preload("res://ui/components/session_summary.tscn")
const MenuDioramaScript := preload("res://ui/components/menu_diorama_3d.gd")
const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")

@onready var _primary: Button = %PrimaryAction
@onready var _secondary: Button = %SecondaryAction
@onready var _active_host: VBoxContainer = %ActiveSessionHost
@onready var _last_run_host: VBoxContainer = %LastRunHost
@onready var _diorama_host: Control = %DioramaHost

var _restart_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	UiStyle.apply_theme(self)
	_style_actions()
	_bind_actions()
	_bind_diorama()
	_bind_market_summary()
	_bind_session_cards()
	_restart_dialog = _make_confirm("RESTART SAVED RUN?", "This clears the saved checkpoint and starts the run again.")
	_restart_dialog.confirmed.connect(_restart_saved)
	_delete_dialog = _make_confirm("DELETE SAVED RUN?", "This saved session cannot be restored.")
	_delete_dialog.confirmed.connect(func() -> void:
		SessionStoreScript.clear()
		AppRouterScript.go_main_menu(get_tree())
	)
	call_deferred("_focus_primary")


func _style_actions() -> void:
	UiStyle._style_button(_primary, "primary")
	UiStyle._style_button(_secondary, "secondary")
	_primary.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	_secondary.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)


func _bind_actions() -> void:
	var has_session := SessionStoreScript.has_session()
	if has_session:
		_primary.text = "CONTINUE RUN"
		_primary.custom_minimum_size = Vector2(0, 48)
		_primary.pressed.connect(func() -> void:
			if typeof(UiAudio) != TYPE_NIL:
				UiAudio.play_accept()
			AppRouterScript.go_game(get_tree(), true)
		)
		_secondary.visible = true
		_secondary.text = "NEW RUN"
		_secondary.visible = OS.is_debug_build()
		_secondary.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
	else:
		_primary.text = "NEW RUN"
		_primary.custom_minimum_size = Vector2(0, 48)
		_primary.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
		_secondary.visible = false


func _bind_diorama() -> void:
	var diorama := MenuDioramaScript.new()
	diorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	_diorama_host.add_child(diorama)


func _bind_market_summary() -> void:
	if typeof(ProfileManager) == TYPE_NIL:
		return
	ProfileManager.commit_pending_last_run()
	var market: Dictionary = ProfileManager.get_market()
	var panel := PanelContainer.new()
	UiStyle.style_card_panel(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var last_return := 0.0
	var run_candles: Array = market.get("run_candles", [])
	if not run_candles.is_empty():
		last_return = float(run_candles.back().get("session_return", 0.0))
	for metric in [
		["HODL INDEX", "%.2f" % ProfileManager.get_global_hodl_price()],
		["ATH", "%.2f" % ProfileManager.get_global_hodl_ath()],
		["ACCOUNT EQUITY", MoneyDisplayScript.usd_cents(ProfileManager.get_account_balance_cents())],
		["LAST SESSION", "%+.2f%%" % (last_return * 100.0)],
		["NEXT ATH RESEARCH", "%.2f" % ProfileManager.get_next_ath_research_threshold()],
	]:
		var col := VBoxContainer.new()
		col.add_child(UiStyle.make_flat_label(str(metric[0]), 11, true))
		col.add_child(UiStyle.make_flat_label(str(metric[1]), 18))
		row.add_child(col)
	_last_run_host.add_child(panel)


func _bind_session_cards() -> void:
	if SessionStoreScript.has_session():
		var session: Dictionary = SessionStoreScript.load_session()
		var card: Node = SessionSummaryScene.instantiate()
		UiStyle.style_card_panel(card)
		_active_host.add_child(card)
		if card.has_method("setup_session"):
			card.call("setup_session", session)
		var actions: HBoxContainer = card.call("actions_host") as HBoxContainer
		var restart := UiStyle.make_compact_button("RESTART", 100, 34, "secondary")
		restart.visible = OS.is_debug_build()
		restart.pressed.connect(func() -> void:
			_restart_dialog.dialog_text = "%s\n\nThis clears the saved checkpoint and starts the run again." % StatPresentationScript.session_summary_line(session)
			if typeof(UiAudio) != TYPE_NIL:
				UiAudio.play_modal()
			_restart_dialog.popup_centered(Vector2i(480, 200))
		)
		if actions:
			actions.add_child(restart)
		var delete_btn := UiStyle.make_compact_button("DELETE", 100, 34, "danger")
		delete_btn.visible = OS.is_debug_build()
		delete_btn.pressed.connect(func() -> void:
			_delete_dialog.dialog_text = "%s\n\nThis saved session cannot be restored." % StatPresentationScript.session_summary_line(session)
			if typeof(UiAudio) != TYPE_NIL:
				UiAudio.play_modal()
			_delete_dialog.popup_centered(Vector2i(480, 200))
		)
		if actions:
			actions.add_child(delete_btn)

	if typeof(RunManager) == TYPE_NIL:
		return
	var run: Dictionary = RunManager.last_run
	if run.is_empty():
		return
	var last_card: Node = SessionSummaryScene.instantiate()
	UiStyle.style_card_panel(last_card)
	_last_run_host.add_child(last_card)
	if last_card.has_method("setup_last_run"):
		last_card.call("setup_last_run", run)


func _focus_primary() -> void:
	_primary.grab_focus()


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
