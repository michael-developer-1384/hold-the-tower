extends Control

## Persistent meta Command Center shell.

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const ToastHostScript := preload("res://scripts/app/toast_host.gd")
const TooltipHostScript := preload("res://scripts/app/tooltip_host.gd")
const BootIntroScript := preload("res://ui/shell/boot_intro.gd")

var _sidebar: VBoxContainer
var _status: Label
var _content_host: Control
var _page_root: Control
var _toast: ToastHost
var _tooltip: TooltipHost
var _footer: Label
var _hint: Label
var _history: Array[String] = []
var _current_route: String = ""
var _nav_buttons: Dictionary = {}
var _quit_dialog: ConfirmationDialog
var _boot_layer: Control


func _ready() -> void:
	AppRouterScript.bind_shell(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build_chrome()
	_build_dialogs()
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


func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = UiTokens.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size = Vector2(UiTokens.SIDEBAR_WIDTH, 0)
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_constant_override("separation", UiTokens.SPACE_8)
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(UiTokens.SIDEBAR_WIDTH, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_sb := UiStyle.make_flat_style(UiTokens.BG_ELEVATED, UiTokens.SURFACE_LINE_SOFT, 0, 0)
	side_sb.border_width_right = 1
	side_sb.border_color = UiTokens.SURFACE_LINE_SOFT
	side_sb.content_margin_left = 16
	side_sb.content_margin_right = 16
	side_sb.content_margin_top = 20
	side_sb.content_margin_bottom = 16
	side_panel.add_theme_stylebox_override("panel", side_sb)
	side_panel.add_child(_sidebar)
	root.add_child(side_panel)

	var brand := UiStyle.make_flat_label("HODL THE TOWER", UiTokens.FONT_SECTION, false)
	brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar.add_child(brand)
	_sidebar.add_child(UiStyle.make_flat_label("COMMAND CENTER", UiTokens.FONT_CAPTION, true))
	_sidebar.add_child(UiStyle.make_divider())

	_add_nav("PLAY", AppRouterScript.ROUTE_PLAY)
	_add_nav("PROGRESSION", AppRouterScript.ROUTE_PROGRESSION)
	_add_nav("DATABASE", AppRouterScript.ROUTE_DATABASE)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(spacer)

	_add_nav("SETTINGS", AppRouterScript.ROUTE_SETTINGS)
	var quit_btn := UiStyle.make_button("QUIT", 36, "ghost")
	quit_btn.pressed.connect(_confirm_quit)
	_sidebar.add_child(quit_btn)

	var main_col := VBoxContainer.new()
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 0)
	root.add_child(main_col)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 48)
	top.add_theme_constant_override("separation", 16)
	var top_wrap := MarginContainer.new()
	top_wrap.add_theme_constant_override("margin_left", 20)
	top_wrap.add_theme_constant_override("margin_right", 20)
	top_wrap.add_theme_constant_override("margin_top", 10)
	top_wrap.add_theme_constant_override("margin_bottom", 6)
	top_wrap.add_child(top)
	main_col.add_child(top_wrap)

	_status = UiStyle.make_flat_label("", UiTokens.FONT_BODY, false)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	_hint = UiStyle.make_flat_label("", UiTokens.FONT_CAPTION, true)
	top.add_child(_hint)
	_refresh_hint()

	_content_host = Control.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_child(_content_host)

	_page_root = Control.new()
	_page_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_host.add_child(_page_root)

	var foot_wrap := MarginContainer.new()
	foot_wrap.add_theme_constant_override("margin_left", 20)
	foot_wrap.add_theme_constant_override("margin_right", 20)
	foot_wrap.add_theme_constant_override("margin_bottom", 8)
	_footer = UiStyle.make_flat_label(UiTokens.BUILD_LABEL, UiTokens.FONT_CAPTION, true)
	foot_wrap.add_child(_footer)
	main_col.add_child(foot_wrap)

	_toast = ToastHostScript.new()
	add_child(_toast)
	_tooltip = TooltipHostScript.new()
	add_child(_tooltip)

	if typeof(InputMode) != TYPE_NIL:
		InputMode.mode_changed.connect(func(_m: String) -> void: _refresh_hint())


func _add_nav(text: String, route: String) -> void:
	var b := UiStyle.make_button(text, 36, "ghost")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		if route == AppRouterScript.ROUTE_PLAY:
			navigate(AppRouterScript.ROUTE_MAIN, true)
			return
		navigate(route, true)
	)
	_sidebar.add_child(b)
	_nav_buttons[route] = b


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


func _refresh_nav() -> void:
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


func _build_dialogs() -> void:
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "QUIT GAME"
	_quit_dialog.dialog_text = "Leave HODL THE TOWER?"
	_quit_dialog.ok_button_text = "QUIT"
	_quit_dialog.cancel_button_text = "CANCEL"
	_quit_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyle.style_modal(_quit_dialog)
	add_child(_quit_dialog)
	_quit_dialog.confirmed.connect(func() -> void: AppRouterScript.quit_game(get_tree()))


func _confirm_quit() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_modal()
	_quit_dialog.popup_centered(Vector2i(420, 180))
