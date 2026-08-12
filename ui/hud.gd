extends CanvasLayer

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const TowerCardScript := preload("res://ui/components/tower_card.gd")
const SessionStoreScript := preload("res://scripts/run/session_store.gd")
const TimelineRecorderScript := preload("res://scripts/run/timeline_recorder.gd")

var _game: Node
var _build: Node
var _selection: Node
var _range_viz: Node3D
var _wave_running: bool = false
var _ended: bool = false
var _selected_spot: Node = null
var _selected_tower: Node3D = null
var _tower_defs: Array = []
var _show_debug: bool = false
var _focus_display: int = 1

var _core_label: Label
var _gold_label: Label
var _wave_label: Label
var _enemy_label: Label
var _diff_label: Label
var _start_wave_button: Button
var _options_button: Button

var _gallery_panel: PanelContainer
var _gallery_row: HBoxContainer
var _gallery_status: Label

var _tower_panel: PanelContainer
var _tower_title: Label
var _tower_info: Label
var _upgrade_button: Button

var _debug_panel: PanelContainer
var _debug_label: Label

var _options_dialog: AcceptDialog
var _debug_check: CheckBox
var _ui_tick: float = 0.0
var _timeline_slider: HSlider
var _timeline_label: Label
var _tm_panel: PanelContainer
var _tm_resume_btn: Button
var _tm_live_btn: Button
var _paused_by_menu: bool = false
var _dimmer: ColorRect
var _exit_ns_dialog: ConfirmationDialog
var _restart_dialog: ConfirmationDialog
var _tm_confirm: ConfirmationDialog
var _tm_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show_debug = ProfileManager.is_debug_hud_enabled() if typeof(ProfileManager) != TYPE_NIL else false
	_tm_enabled = SettingsManager.time_machine_enabled() if typeof(SettingsManager) != TYPE_NIL else true
	_build_ui()
	_apply_debug_visibility()
	_refresh_tm_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event.is_action_pressed("ui_cancel"):
		if _tm_confirm and _tm_confirm.visible:
			_tm_confirm.hide()
		elif _exit_ns_dialog and _exit_ns_dialog.visible:
			_exit_ns_dialog.hide()
		elif _restart_dialog and _restart_dialog.visible:
			_restart_dialog.hide()
		elif _options_dialog and _options_dialog.visible:
			_on_resume()
		else:
			_open_options()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _ended:
		return
	_ui_tick += delta
	if _ui_tick < 0.25:
		return
	_ui_tick = 0.0
	if _tower_panel != null and _tower_panel.visible and _selected_tower != null and is_instance_valid(_selected_tower):
		if str(_selected_tower.get("tower_type")) == "guard_post":
			_refresh_tower_panel()
	if _show_debug:
		_refresh_debug()
	if _tm_enabled and _game != null and not bool(_game.get("timeline_previewing")):
		_refresh_timeline_slider()


func bind_game(
	game_manager: Node,
	build_manager: Node,
	selection_manager: Node = null,
	range_viz: Node3D = null
) -> void:
	_game = game_manager
	_build = build_manager
	_selection = selection_manager
	_range_viz = range_viz
	_cache_defs()

	_game.gold_changed.connect(set_gold)
	_game.core_hp_changed.connect(set_core_health)
	_game.enemies_alive_changed.connect(set_enemy_count)
	_game.wave_changed.connect(set_wave)
	_game.wave_state_changed.connect(_on_wave_state_changed)
	_game.game_over_changed.connect(_on_game_over)
	_game.level_complete_changed.connect(_on_level_complete)

	if _selection and _selection.has_signal("spot_selection_changed"):
		_selection.spot_selection_changed.connect(_on_spot_selection_changed)
	if _selection and _selection.has_signal("tower_selection_changed"):
		_selection.tower_selection_changed.connect(_on_tower_selection_changed)
	if _build and _build.has_signal("build_failed"):
		_build.build_failed.connect(_on_build_failed)

	_refresh_diff_chip()
	set_gold(int(_game.get("gold")))
	set_core_health(int(_game.get("core_hp")))
	set_enemy_count(int(_game.get("enemies_alive")))
	set_wave(int(_game.get("current_wave")))
	_refresh_gallery()
	_refresh_tower_panel()
	_refresh_start_button()
	_refresh_debug()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top status bar
	var top_wrap := MarginContainer.new()
	top_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_wrap.offset_bottom = 72
	top_wrap.add_theme_constant_override("margin_left", 16)
	top_wrap.add_theme_constant_override("margin_right", 16)
	top_wrap.add_theme_constant_override("margin_top", 12)
	top_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_wrap)

	var status_panel := UiStyleScript.make_panel()
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	top_wrap.add_child(status_panel)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 18)
	status_panel.add_child(status_row)

	_core_label = UiStyleScript.make_flat_label("Core 20", 18)
	_gold_label = UiStyleScript.make_flat_label("Gold 300", 18)
	_wave_label = UiStyleScript.make_flat_label("Wave 1 / 5", 18)
	_enemy_label = UiStyleScript.make_flat_label("Enemies 0", 18)
	_diff_label = UiStyleScript.make_flat_label("Normal", 16, true)
	for l in [_core_label, _gold_label, _wave_label, _enemy_label, _diff_label]:
		status_row.add_child(l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(spacer)

	_start_wave_button = UiStyleScript.make_button("START WAVE", 40)
	_start_wave_button.custom_minimum_size = Vector2(150, 40)
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	status_row.add_child(_start_wave_button)

	_options_button = UiStyleScript.make_button("Options", 40)
	_options_button.custom_minimum_size = Vector2(110, 40)
	_options_button.pressed.connect(_open_options)
	status_row.add_child(_options_button)

	# Selected tower panel (left, sits above the build dock)
	_tower_panel = UiStyleScript.make_panel()
	_tower_panel.visible = false
	_tower_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tower_panel.offset_left = 16
	_tower_panel.offset_top = -310
	_tower_panel.offset_right = 292
	_tower_panel.offset_bottom = -140
	_tower_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_tower_panel)
	var tower_box := VBoxContainer.new()
	tower_box.add_theme_constant_override("separation", 6)
	_tower_panel.add_child(tower_box)
	_tower_title = UiStyleScript.make_flat_label("Tower", 18)
	tower_box.add_child(_tower_title)
	_tower_info = UiStyleScript.make_label("", 14)
	tower_box.add_child(_tower_info)
	_upgrade_button = UiStyleScript.make_button("UPGRADE", 40)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_upgrade_button.mouse_entered.connect(_on_upgrade_hover_entered)
	_upgrade_button.mouse_exited.connect(_on_upgrade_hover_exited)
	tower_box.add_child(_upgrade_button)

	# Compact build dock along the full bottom edge (fixed height, no clipping)
	_gallery_panel = UiStyleScript.make_panel()
	_gallery_panel.visible = false
	var dock_sb := StyleBoxFlat.new()
	dock_sb.bg_color = UiStyleScript.PANEL
	dock_sb.corner_radius_top_left = 10
	dock_sb.corner_radius_top_right = 10
	dock_sb.corner_radius_bottom_left = 10
	dock_sb.corner_radius_bottom_right = 10
	dock_sb.content_margin_left = 12
	dock_sb.content_margin_right = 12
	dock_sb.content_margin_top = 8
	dock_sb.content_margin_bottom = 8
	_gallery_panel.add_theme_stylebox_override("panel", dock_sb)
	_gallery_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_gallery_panel.anchor_top = 1.0
	_gallery_panel.anchor_bottom = 1.0
	_gallery_panel.offset_left = 16
	_gallery_panel.offset_right = -16
	_gallery_panel.offset_top = -128
	_gallery_panel.offset_bottom = -12
	_gallery_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_gallery_panel)

	var gallery_box := VBoxContainer.new()
	gallery_box.add_theme_constant_override("separation", 6)
	gallery_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gallery_panel.add_child(gallery_box)

	var gallery_header := HBoxContainer.new()
	gallery_header.custom_minimum_size = Vector2(0, 22)
	gallery_box.add_child(gallery_header)
	gallery_header.add_child(UiStyleScript.make_flat_label("BUILD", 16))
	var gspacer := Control.new()
	gspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_header.add_child(gspacer)
	_gallery_status = UiStyleScript.make_flat_label("", 13, true)
	gallery_header.add_child(_gallery_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 88)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	gallery_box.add_child(scroll)
	_gallery_row = HBoxContainer.new()
	_gallery_row.add_theme_constant_override("separation", 10)
	_gallery_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(_gallery_row)

	# Debug overlay (top-left under status)
	_debug_panel = UiStyleScript.make_panel()
	_debug_panel.visible = false
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_panel.offset_left = 16
	_debug_panel.offset_top = 88
	_debug_panel.offset_right = 360
	_debug_panel.offset_bottom = 320
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_debug_panel)
	var debug_box := VBoxContainer.new()
	_debug_panel.add_child(debug_box)
	debug_box.add_child(UiStyleScript.make_flat_label("DEBUG", 14, true))
	_debug_label = UiStyleScript.make_label("", 13, true)
	debug_box.add_child(_debug_label)

	_build_tm_bar(root)
	_build_options_dialog()
	_build_confirm_dialogs()


func _build_tm_bar(root: Control) -> void:
	_tm_panel = UiStyleScript.make_panel()
	_tm_panel.visible = false
	_tm_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_tm_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tm_panel.offset_left = 120
	_tm_panel.offset_right = -120
	_tm_panel.offset_top = -210
	_tm_panel.offset_bottom = -140
	_tm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_tm_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_tm_panel.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)
	header.add_child(UiStyleScript.make_flat_label("TIME MACHINE", 14))
	_timeline_label = UiStyleScript.make_flat_label("No snapshots yet", 12, true)
	_timeline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_timeline_label)
	_timeline_slider = HSlider.new()
	_timeline_slider.min_value = 0
	_timeline_slider.max_value = 0
	_timeline_slider.step = 1
	_timeline_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	_timeline_slider.value_changed.connect(_on_timeline_scrub)
	col.add_child(_timeline_slider)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)
	_tm_resume_btn = UiStyleScript.make_compact_button("RESUME HERE", 140, 32, "primary")
	_tm_resume_btn.pressed.connect(_on_tm_resume_here)
	actions.add_child(_tm_resume_btn)
	_tm_live_btn = UiStyleScript.make_compact_button("RETURN TO LIVE", 150, 32, "secondary")
	_tm_live_btn.pressed.connect(_on_tm_return_live)
	actions.add_child(_tm_live_btn)


func _build_options_dialog() -> void:
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.02, 0.03, 0.04, 0.72)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.visible = false
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dimmer)

	_options_dialog = AcceptDialog.new()
	_options_dialog.title = "PAUSED"
	_options_dialog.ok_button_text = "RESUME"
	_options_dialog.min_size = Vector2i(420, 420)
	_options_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyleScript.style_modal(_options_dialog)
	add_child(_options_dialog)
	_options_dialog.confirmed.connect(_on_resume)
	_options_dialog.close_requested.connect(_on_resume)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360, 0)
	_options_dialog.add_child(box)

	box.add_child(UiStyleScript.make_flat_label("COMMAND PAUSE", 18))
	box.add_child(UiStyleScript.make_label("Gameplay stays visible behind this overlay.", 13, true))

	var check_wrap := PanelContainer.new()
	UiStyleScript.style_card_panel(check_wrap, false, false)
	box.add_child(check_wrap)
	_debug_check = CheckBox.new()
	_debug_check.text = "Show debug HUD"
	_debug_check.button_pressed = _show_debug
	_debug_check.toggled.connect(_on_debug_toggled)
	check_wrap.add_child(_debug_check)

	var resume := UiStyleScript.make_compact_button("RESUME", 0, 42, "primary")
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.pressed.connect(_on_resume)
	box.add_child(resume)
	var restart := UiStyleScript.make_compact_button("RESTART RUN", 0, 42, "secondary")
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(func() -> void:
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_modal()
		_restart_dialog.popup_centered(Vector2i(460, 180))
	)
	box.add_child(restart)
	var save_exit := UiStyleScript.make_compact_button("SAVE & EXIT", 0, 42, "secondary")
	save_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_exit.pressed.connect(_on_save_exit)
	box.add_child(save_exit)
	var settings := UiStyleScript.make_compact_button("SETTINGS", 0, 42, "ghost")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(_on_open_settings_from_pause)
	box.add_child(settings)
	var exit_ns := UiStyleScript.make_compact_button("EXIT WITHOUT SAVING", 0, 42, "danger")
	exit_ns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_ns.pressed.connect(func() -> void:
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_modal()
		_exit_ns_dialog.popup_centered(Vector2i(460, 180))
	)
	box.add_child(exit_ns)


func _build_confirm_dialogs() -> void:
	_restart_dialog = ConfirmationDialog.new()
	_restart_dialog.title = "RESTART RUN?"
	_restart_dialog.dialog_text = "Restart this run from the beginning?\nThe current checkpoint will be cleared."
	_restart_dialog.ok_button_text = "RESTART"
	_restart_dialog.cancel_button_text = "CANCEL"
	_restart_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyleScript.style_modal(_restart_dialog)
	add_child(_restart_dialog)
	_restart_dialog.confirmed.connect(_on_restart_run)

	_exit_ns_dialog = ConfirmationDialog.new()
	_exit_ns_dialog.title = "EXIT WITHOUT SAVING?"
	_exit_ns_dialog.dialog_text = "Leave without saving?\nThe active session checkpoint will be deleted."
	_exit_ns_dialog.ok_button_text = "EXIT"
	_exit_ns_dialog.cancel_button_text = "CANCEL"
	_exit_ns_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyleScript.style_modal(_exit_ns_dialog)
	add_child(_exit_ns_dialog)
	_exit_ns_dialog.confirmed.connect(_on_exit_without_saving)

	_tm_confirm = ConfirmationDialog.new()
	_tm_confirm.title = "RESUME HERE?"
	_tm_confirm.dialog_text = "Resume from this point and overwrite everything after it?"
	_tm_confirm.ok_button_text = "RESUME HERE"
	_tm_confirm.cancel_button_text = "CANCEL"
	_tm_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyleScript.style_modal(_tm_confirm)
	add_child(_tm_confirm)
	_tm_confirm.confirmed.connect(func() -> void:
		if _game and _game.has_method("commit_timeline_resume"):
			_game.call("commit_timeline_resume", int(_timeline_slider.value))
		_refresh_timeline_slider()
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_accept()
	)


func _cache_defs() -> void:
	_tower_defs.clear()
	if _build and _build.has_method("get_tower_defs"):
		_tower_defs = _build.call("get_tower_defs")


func set_core_health(value: int) -> void:
	_core_label.text = "Core %d" % value


func set_gold(value: int) -> void:
	_gold_label.text = "Gold %d" % value
	_refresh_gallery()
	_refresh_tower_panel()


func set_enemy_count(value: int) -> void:
	_enemy_label.text = "Enemies %d" % value
	_refresh_debug()


func set_wave(_value: int) -> void:
	_refresh_wave_label()
	_refresh_start_button()
	_refresh_debug()


func set_focus_floor(display_number: int) -> void:
	_focus_display = display_number
	_refresh_debug()


func _wave_total() -> int:
	if _game == null:
		return 5
	var wm = _game.get("wave_manager")
	if wm != null and is_instance_valid(wm) and wm.has_method("get_wave_count"):
		return int(wm.call("get_wave_count"))
	return 5


func _refresh_wave_label() -> void:
	if _game == null or _wave_label == null:
		return
	var total := _wave_total()
	if _wave_running:
		_wave_label.text = "Wave %d / %d" % [int(_game.get("active_wave")), total]
	else:
		_wave_label.text = "Wave %d / %d" % [int(_game.get("current_wave")), total]


func _refresh_diff_chip() -> void:
	if _diff_label == null:
		return
	var id := "normal"
	if typeof(RunManager) != TYPE_NIL:
		id = str(RunManager.difficulty_id)
	var d := DifficultyCatalogScript.find(id)
	_diff_label.text = str(d.get("display_name", id))


func _on_wave_state_changed(running: bool) -> void:
	_wave_running = running
	_refresh_wave_label()
	_refresh_start_button()
	_refresh_debug()


func _on_spot_selection_changed(spot: Node) -> void:
	_selected_spot = spot
	_refresh_gallery()


func _on_tower_selection_changed(tower: Node3D) -> void:
	_selected_tower = tower
	_refresh_tower_panel()
	_refresh_debug()


func _on_build_failed(reason: String) -> void:
	if _gallery_status:
		_gallery_status.text = reason


func _on_game_over(_active: bool) -> void:
	_ended = true
	_gallery_panel.visible = false
	_tower_panel.visible = false
	_refresh_start_button()


func _on_level_complete(_active: bool) -> void:
	_ended = true
	_gallery_panel.visible = false
	_tower_panel.visible = false
	_refresh_start_button()


func _refresh_start_button() -> void:
	if _start_wave_button == null:
		return
	_start_wave_button.disabled = _ended or _wave_running
	_start_wave_button.visible = not _ended


func _refresh_gallery() -> void:
	var free_selected := (
		_selected_spot != null
		and is_instance_valid(_selected_spot)
		and not bool(_selected_spot.get("occupied"))
		and not _ended
	)
	_gallery_panel.visible = free_selected
	if not free_selected:
		return
	_gallery_status.text = ""
	for child in _gallery_row.get_children():
		child.queue_free()
	var defs: Array = TowerCatalogScript.unlocked_buildable(_tower_defs)
	for def in defs:
		var can := false
		if _build and _build.has_method("can_build"):
			can = bool(_build.call("can_build", def))
		var card := TowerCardScript.new()
		card.setup(def, TowerCardScript.Mode.BUILD, can)
		card.build_pressed.connect(func(tid: String) -> void:
			var d = _def_by_id(tid)
			if d != null and _build and _build.has_method("build_selected"):
				_build.call("build_selected", d)
			_refresh_gallery()
		)
		_gallery_row.add_child(card)


func _refresh_tower_panel() -> void:
	var active := (
		_selected_tower != null
		and is_instance_valid(_selected_tower)
		and not _ended
	)
	_tower_panel.visible = active
	if not active:
		if _range_viz and _range_viz.has_method("set_upgrade_preview"):
			_range_viz.call("set_upgrade_preview", false)
		return

	var tower := _selected_tower
	var tower_type := str(tower.get("tower_type"))
	var def = _def_by_id(tower_type)
	var display := _display_name_for(tower_type)
	_tower_title.text = "%s  ·  Lv %d" % [display, int(tower.get("level"))]

	if tower.has_method("get_ui_stat_lines"):
		_tower_info.text = "\n".join(tower.call("get_ui_stat_lines"))
	else:
		_tower_info.text = display

	var can_upgrade := bool(def.can_in_run_upgrade) if def else false
	if tower.has_method("can_in_run_upgrade"):
		can_upgrade = can_upgrade and bool(tower.call("can_in_run_upgrade"))
	if not can_upgrade:
		_upgrade_button.text = "NO UPGRADES"
		_upgrade_button.disabled = true
		return

	var max_level := int(def.max_level) if def else 2
	var upgrade_cost := int(def.upgrade_cost) if def else 150
	if int(tower.get("level")) >= max_level:
		_upgrade_button.text = "MAX LEVEL"
		_upgrade_button.disabled = true
	else:
		_upgrade_button.text = "UPGRADE RANGE  ·  %d" % upgrade_cost
		var can := false
		if _build and _build.has_method("can_upgrade"):
			can = bool(_build.call("can_upgrade", tower))
		_upgrade_button.disabled = not can


func _display_name_for(tower_type: String) -> String:
	var def = _def_by_id(tower_type)
	if def:
		return str(def.display_name)
	return tower_type.capitalize()


func _def_by_id(tower_id: String) -> Resource:
	for def in _tower_defs:
		if str(def.tower_id) == tower_id:
			return def
	return null


func _refresh_debug() -> void:
	if _debug_label == null:
		return
	var wave_state := "running" if _wave_running else "ready"
	var lines: PackedStringArray = PackedStringArray([
		"Focus floor: %d" % _focus_display,
		"Wave state: %s" % wave_state,
		"",
		"1 / 2 / 3 — Select floor",
		"MMB + Mouse — Orbit",
		"Mouse wheel — Zoom",
		"LMB — Select spot / tower / path",
		"Hover — Preview floor",
	])
	if _selected_tower != null and is_instance_valid(_selected_tower):
		var t := _selected_tower
		lines.append("")
		lines.append("Selected: %s" % str(t.get("runtime_id")))
		lines.append("Type: %s" % str(t.get("tower_type")))
		if "blueprint_id" in t:
			lines.append("Blueprint: %s" % str(t.get("blueprint_id")))
		lines.append("Shots %d  Hits %d  Kills %d" % [
			int(t.get("shots_fired")) if "shots_fired" in t else 0,
			int(t.get("hits")) if "hits" in t else 0,
			int(t.get("kills")) if "kills" in t else 0,
		])
		if str(t.get("tower_type")) == "guard_post":
			lines.append("Blocked %d  Block ms %d" % [
				int(t.get("enemies_blocked")) if "enemies_blocked" in t else 0,
				int(t.get("total_block_time_ms")) if "total_block_time_ms" in t else 0,
			])
		lines.append(_format_coverage())
	_debug_label.text = "\n".join(lines)


func _format_coverage() -> String:
	if _range_viz == null or not _range_viz.has_method("get_last_coverage"):
		return "Coverage: —"
	var cov: Dictionary = _range_viz.call("get_last_coverage")
	var by_floor: Dictionary = cov.get("coverage_by_floor", {})
	if by_floor.is_empty():
		return "Floor coverage: none"
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = by_floor.keys()
	keys.sort()
	for key in keys:
		parts.append("%s: %.1f" % [str(key), float(by_floor[key])])
	return "Floor coverage: " + ", ".join(parts)


func _apply_debug_visibility() -> void:
	if _debug_panel:
		_debug_panel.visible = _show_debug
	_refresh_debug()


func _open_options() -> void:
	if _ended:
		return
	if _debug_check:
		_debug_check.button_pressed = _show_debug
	_paused_by_menu = true
	get_tree().paused = true
	if _dimmer:
		_dimmer.visible = true
	if _game and _game.has_method("save_session_checkpoint"):
		_game.call("save_session_checkpoint")
	_refresh_timeline_slider()
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_modal()
	_options_dialog.popup_centered()


func _on_resume() -> void:
	_options_dialog.hide()
	if _dimmer:
		_dimmer.visible = false
	# Keep paused if Time Machine is previewing.
	if _game and bool(_game.get("timeline_previewing")):
		_paused_by_menu = false
		return
	if _paused_by_menu:
		get_tree().paused = false
		_paused_by_menu = false


func _on_restart_run() -> void:
	_options_dialog.hide()
	if _dimmer:
		_dimmer.visible = false
	get_tree().paused = false
	_paused_by_menu = false
	if _game and _game.has_method("restart"):
		_game.call("restart")
	else:
		AppRouterScript.go_game(get_tree(), false)


func _on_save_exit() -> void:
	_options_dialog.hide()
	if _dimmer:
		_dimmer.visible = false
	if _game and _game.has_method("save_session_checkpoint"):
		_game.call("save_session_checkpoint")
	get_tree().paused = false
	_paused_by_menu = false
	AppRouterScript.go_main_menu(get_tree())


func _on_exit_without_saving() -> void:
	_options_dialog.hide()
	if _dimmer:
		_dimmer.visible = false
	SessionStoreScript.clear()
	get_tree().paused = false
	_paused_by_menu = false
	AppRouterScript.go_main_menu(get_tree())


func _on_open_settings_from_pause() -> void:
	if _game and _game.has_method("save_session_checkpoint"):
		_game.call("save_session_checkpoint")
	_options_dialog.hide()
	if _dimmer:
		_dimmer.visible = false
	get_tree().paused = false
	_paused_by_menu = false
	AppRouterScript.go_settings(get_tree())


func _on_debug_toggled(pressed: bool) -> void:
	_show_debug = pressed
	if typeof(ProfileManager) != TYPE_NIL:
		ProfileManager.set_debug_hud_enabled(pressed)
	_apply_debug_visibility()


func _refresh_tm_visibility() -> void:
	_tm_enabled = SettingsManager.time_machine_enabled() if typeof(SettingsManager) != TYPE_NIL else true
	if _tm_panel:
		_tm_panel.visible = _tm_enabled and not _ended
	_refresh_timeline_slider()


func _refresh_timeline_slider() -> void:
	if _timeline_slider == null:
		return
	var rec = _game.get("timeline_recorder") if _game else null
	var count := 0
	if rec != null and rec.has_method("snapshot_count"):
		count = int(rec.call("snapshot_count"))
	_timeline_slider.max_value = maxi(count - 1, 0)
	_timeline_slider.editable = count > 0 and _tm_enabled
	var previewing := _game != null and bool(_game.get("timeline_previewing"))
	if _tm_resume_btn:
		_tm_resume_btn.disabled = not previewing
	if _tm_live_btn:
		_tm_live_btn.disabled = not previewing
	if count <= 0:
		_timeline_label.text = "Recording… no snapshots yet"
	elif previewing:
		_timeline_label.text = "PREVIEW  %d / %d — choose Resume Here or Return to Live" % [int(_timeline_slider.value) + 1, count]
	else:
		_timeline_label.text = "Snapshots: %d — scrub to preview, then commit" % count


func _on_timeline_scrub(value: float) -> void:
	if not _tm_enabled or _game == null:
		return
	if _game.has_method("preview_timeline_snapshot"):
		_game.call("preview_timeline_snapshot", int(value))
	var rec = _game.get("timeline_recorder")
	if rec == null or not rec.has_method("get_snapshot"):
		return
	var snap: Dictionary = rec.call("get_snapshot", int(value))
	if snap.is_empty():
		return
	_timeline_label.text = "PREVIEW t=%.1fs  gold=%d  core=%d  enemies=%d  towers=%d" % [
		float(snap.get("t", 0.0)),
		int(snap.get("gold", 0)),
		int(snap.get("core_hp", 0)),
		(snap.get("enemies", []) as Array).size(),
		(snap.get("towers", []) as Array).size(),
	]
	if _tm_resume_btn:
		_tm_resume_btn.disabled = false
	if _tm_live_btn:
		_tm_live_btn.disabled = false
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_focus()


func _on_tm_resume_here() -> void:
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_modal()
	_tm_confirm.popup_centered(Vector2i(480, 180))


func _on_tm_return_live() -> void:
	if _game and _game.has_method("cancel_timeline_preview"):
		_game.call("cancel_timeline_preview")
	_refresh_timeline_slider()
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.play_back()


func _on_start_wave_pressed() -> void:
	if _game and _game.has_method("start_next_wave"):
		_game.call("start_next_wave")


func _on_upgrade_pressed() -> void:
	if _game and _game.has_method("upgrade_selected_tower"):
		_game.call("upgrade_selected_tower")
	_refresh_tower_panel()
	_refresh_debug()


func _on_upgrade_hover_entered() -> void:
	if _ended or _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if str(_selected_tower.get("tower_type")) != "basic_tower":
		return
	if int(_selected_tower.get("level")) >= 2:
		return
	var current := float(_selected_tower.call("get_range_value")) if _selected_tower.has_method("get_range_value") else float(_selected_tower.get("attack_range"))
	var bonus := 1.5
	if _build and _build.has_method("get_upgrade_range_bonus"):
		bonus = float(_build.call("get_upgrade_range_bonus"))
	var basic := _def_by_id("basic_tower")
	if basic and "upgrade_range_bonus" in basic:
		bonus = float(basic.upgrade_range_bonus)
	if _range_viz and _range_viz.has_method("set_upgrade_preview"):
		_range_viz.call("set_upgrade_preview", true, current + bonus)


func _on_upgrade_hover_exited() -> void:
	if _range_viz and _range_viz.has_method("set_upgrade_preview"):
		_range_viz.call("set_upgrade_preview", false)
