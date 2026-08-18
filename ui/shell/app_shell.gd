extends Control

## Persistent meta Command Center shell.

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ToastHostScript := preload("res://scripts/app/toast_host.gd")
const TooltipHostScript := preload("res://scripts/app/tooltip_host.gd")
const BootIntroScript := preload("res://ui/shell/boot_intro.gd")

@onready var _status: Label = %StatusLabel
@onready var _page_root: Control = %PageRoot
@onready var _footer: Label = %Footer
@onready var _hint: Label = %HintLabel
@onready var _quit_dialog: ConfirmationDialog = %QuitDialog
@onready var _side_panel: PanelContainer = %SidePanel
@onready var _background: ColorRect = %Background

var _toast: ToastHost
var _tooltip: TooltipHost
var _history: Array[String] = []
var _current_route: String = ""
var _nav_buttons: Dictionary = {}
var _boot_layer: Control


func _ready() -> void:
	AppRouterScript.bind_shell(self)
	UiStyle.apply_theme(self)
	_style_chrome()
	_wire_nav()
	_refresh_dev_nav()
	_wire_dialogs()
	_spawn_overlays()
	_footer.text = UiTokens.BUILD_LABEL
	_refresh_hint()

	var boot_route := AppRouterScript.pending_route_on_boot
	AppRouterScript.pending_route_on_boot = AppRouterScript.ROUTE_MAIN
	if typeof(SettingsManager) != TYPE_NIL and not SettingsManager.boot_already_shown():
		_show_boot(boot_route)
	else:
		navigate(boot_route, false)
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.start_ambient()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_escape()
		get_viewport().set_input_as_handled()


func navigate(route: String, push: bool = true) -> void:
	if route.is_empty():
		route = AppRouterScript.ROUTE_MAIN
	if not AppRouterScript.PAGE_SCENES.has(route):
		push_warning("Unknown route: %s" % route)
		return
	if push and not _current_route.is_empty() and _current_route != route:
		_history.append(_current_route)
	_current_route = route
	_load_page(route)
	_refresh_nav()
	_refresh_status()
	if typeof(UiAudio) != TYPE_NIL and route != AppRouterScript.ROUTE_MAIN:
		UiAudio.play_accept()


func navigate_back() -> bool:
	if _history.is_empty():
		if _current_route != AppRouterScript.ROUTE_MAIN:
			navigate(AppRouterScript.ROUTE_MAIN, false)
			if typeof(UiAudio) != TYPE_NIL:
				UiAudio.play_back()
			return true
		return false
	var prev: String = _history.pop_back()
	_current_route = ""
	navigate(prev, false)
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_back()
	return true


func show_toast(title: String, body: String = "") -> void:
	if _toast:
		_toast.show_toast(title, body)


func tooltip() -> TooltipHost:
	return _tooltip


func set_status_extra(text: String) -> void:
	_refresh_status(text)


func _style_chrome() -> void:
	_background.color = UiTokens.BG
	var side_sb := UiStyle.make_flat_style(UiTokens.BG_ELEVATED, UiTokens.SURFACE_LINE_SOFT, 0, 0)
	side_sb.border_width_right = 1
	side_sb.border_color = UiTokens.SURFACE_LINE_SOFT
	side_sb.content_margin_left = 16
	side_sb.content_margin_right = 16
	side_sb.content_margin_top = 20
	side_sb.content_margin_bottom = 16
	_side_panel.add_theme_stylebox_override("panel", side_sb)

	for btn in [%NavPlay, %NavMarket, %NavProgression, %NavDatabase, %NavDev, %NavSettings, %QuitBtn]:
		UiStyle._style_button(btn, "ghost")
		btn.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
		btn.custom_minimum_size = Vector2(0, 36)


func _wire_nav() -> void:
	_nav_buttons[AppRouterScript.ROUTE_PLAY] = %NavPlay
	_nav_buttons[AppRouterScript.ROUTE_MARKET] = %NavMarket
	_nav_buttons[AppRouterScript.ROUTE_PROGRESSION] = %NavProgression
	_nav_buttons[AppRouterScript.ROUTE_DATABASE] = %NavDatabase
	_nav_buttons[AppRouterScript.ROUTE_SETTINGS] = %NavSettings
	_nav_buttons[AppRouterScript.ROUTE_SIM_LAB] = %NavDev

	# Sidebar replaces (no history push) so ESC does not bounce through rail hops.
	%NavPlay.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_MAIN, false)
	)
	%NavMarket.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_MARKET, false)
	)
	%NavProgression.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_PROGRESSION, false)
	)
	%NavDatabase.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_DATABASE, false)
	)
	%NavSettings.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_SETTINGS, false)
	)
	%NavDev.pressed.connect(func() -> void:
		navigate(AppRouterScript.ROUTE_SIM_LAB, false)
	)
	%QuitBtn.pressed.connect(_confirm_quit)

	if typeof(InputMode) != TYPE_NIL:
		InputMode.mode_changed.connect(func(_m: String) -> void: _refresh_hint())


func _wire_dialogs() -> void:
	_quit_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyle.style_modal(_quit_dialog)
	_quit_dialog.confirmed.connect(func() -> void: AppRouterScript.quit_game(get_tree()))


func _spawn_overlays() -> void:
	_toast = ToastHostScript.new()
	add_child(_toast)
	_tooltip = TooltipHostScript.new()
	add_child(_tooltip)


func _show_boot(after_route: String) -> void:
	_boot_layer = BootIntroScript.new()
	_boot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_boot_layer)
	move_child(_boot_layer, get_child_count() - 1)
	_boot_layer.finished.connect(func() -> void:
		if typeof(SettingsManager) != TYPE_NIL:
			SettingsManager.mark_boot_shown()
		if _boot_layer:
			_boot_layer.queue_free()
			_boot_layer = null
		navigate(after_route, false)
	)


func _load_page(route: String) -> void:
	for c in _page_root.get_children():
		c.queue_free()
	var path: String = AppRouterScript.PAGE_SCENES[route]
	if not ResourceLoader.exists(path):
		var fallback := UiStyle.make_label("Missing page: %s" % path, 16, true)
		_page_root.add_child(fallback)
		return
	var packed: PackedScene = load(path)
	var page := packed.instantiate()
	if page is Control:
		(page as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_root.add_child(page)
	if typeof(UiMotion) != TYPE_NIL and page is CanvasItem:
		UiMotion.tween_page_enter(page as CanvasItem)


func _dev_nav_visible() -> bool:
	if OS.is_debug_build():
		return true
	return typeof(ProfileManager) != TYPE_NIL and ProfileManager.is_debug_hud_enabled()


func _refresh_dev_nav() -> void:
	%NavDev.visible = _dev_nav_visible()


func _refresh_nav() -> void:
	_refresh_dev_nav()
	for route in _nav_buttons.keys():
		var b: Button = _nav_buttons[route]
		var active := false
		if route == AppRouterScript.ROUTE_DATABASE:
			active = _current_route in [AppRouterScript.ROUTE_DATABASE, AppRouterScript.ROUTE_TOWER_DETAIL, AppRouterScript.ROUTE_ENEMY_DETAIL]
		elif route == AppRouterScript.ROUTE_PLAY:
			active = _current_route in [AppRouterScript.ROUTE_PLAY, AppRouterScript.ROUTE_MAIN]
		else:
			active = _current_route == route
		b.add_theme_color_override("font_color", UiTokens.ACCENT if active else UiTokens.MUTED)


func _refresh_status(extra: String = "") -> void:
	if typeof(ProfileManager) == TYPE_NIL:
		_status.text = ""
		return
	var level := ProfileManager.get_player_level()
	var xp := ProfileManager.get_research_xp_total()
	var rp := ProfileManager.get_research_points()
	const ProgressionConfigScript := preload("res://scripts/meta/progression_config.gd")
	var info: Dictionary = ProgressionConfigScript.xp_into_level(xp)
	var xp_txt := "MAX" if bool(info.get("at_cap", false)) else "%d / %d" % [xp, int(info.get("xp_next_total", xp))]
	var base := "LV %d      XP %s      RP %d" % [level, xp_txt, rp]
	if not extra.is_empty():
		base += "      %s" % extra
	_status.text = base


func _refresh_hint() -> void:
	if typeof(InputMode) != TYPE_NIL:
		_hint.text = "%s   %s" % [InputMode.hint_back(), InputMode.hint_select()]
	else:
		_hint.text = "[ESC] BACK   [ENTER] SELECT"


func _handle_escape() -> void:
	if _quit_dialog and _quit_dialog.visible:
		_quit_dialog.hide()
		return
	if not navigate_back():
		if _current_route == AppRouterScript.ROUTE_MAIN:
			_confirm_quit()


func _confirm_quit() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_modal()
	_quit_dialog.popup_centered(Vector2i(420, 180))
