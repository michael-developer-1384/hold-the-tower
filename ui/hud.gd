extends CanvasLayer

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

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


func _ready() -> void:
	_show_debug = ProfileManager.is_debug_hud_enabled() if typeof(ProfileManager) != TYPE_NIL else false
	_build_ui()
	_apply_debug_visibility()


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

	_build_options_dialog()


func _build_options_dialog() -> void:
	_options_dialog = AcceptDialog.new()
	_options_dialog.title = "Options"
	_options_dialog.ok_button_text = "Close"
	_options_dialog.dialog_text = "Match settings"
	add_child(_options_dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)
	_options_dialog.add_child(box)

	_debug_check = CheckBox.new()
	_debug_check.text = "Show debug HUD"
	_debug_check.button_pressed = _show_debug
	_debug_check.toggled.connect(_on_debug_toggled)
	box.add_child(_debug_check)

	var leave := UiStyleScript.make_button("Leave run", 44)
	leave.pressed.connect(_on_leave_run)
	box.add_child(leave)


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
	for def in _tower_defs:
		_gallery_row.add_child(_make_gallery_card(def))


func _make_gallery_card(def: Resource) -> Control:
	var tid := str(def.tower_id)
	var unlocked := true
	if typeof(ProfileManager) != TYPE_NIL:
		unlocked = ProfileManager.is_tower_unlocked(tid)
	var can := false
	if unlocked and _build and _build.has_method("can_build"):
		can = bool(_build.call("can_build", def))

	# Compact horizontal card: preview | info | build — fits the fixed dock height.
	var card := UiStyleScript.make_panel()
	card.custom_minimum_size = Vector2(280, 84)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	row.add_child(UiStyleScript.make_tower_preview(tid, Vector2(96, 64)))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(UiStyleScript.make_flat_label(str(def.display_name), 15))
	info.add_child(UiStyleScript.make_flat_label("%d Gold" % int(def.cost), 13, true))

	var btn := UiStyleScript.make_button("BUILD" if unlocked else "LOCKED", 40)
	btn.custom_minimum_size = Vector2(96, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = (not unlocked) or (not can)
	if unlocked:
		btn.pressed.connect(func() -> void:
			if _build and _build.has_method("build_selected"):
				_build.call("build_selected", def)
			_refresh_gallery()
		)
	row.add_child(btn)
	return card


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
	var display := _display_name_for(tower_type)
	_tower_title.text = "%s  ·  Lv %d" % [display, int(tower.get("level"))]

	if tower_type == "guard_post":
		var alive := int(tower.call("get_alive_guard_count")) if tower.has_method("get_alive_guard_count") else 0
		var capacity := int(tower.get("guard_count")) if "guard_count" in tower else 2
		var hp_text := str(tower.call("get_guard_hp_summary")) if tower.has_method("get_guard_hp_summary") else "--"
		var respawn_eta := float(tower.call("get_next_respawn_eta")) if tower.has_method("get_next_respawn_eta") else 0.0
		var lines := [
			"Guards %d / %d" % [alive, capacity],
			"HP %s" % hp_text,
			"Damage %.0f" % (float(tower.get("guard_damage")) if "guard_damage" in tower else 20.0),
			"Attack %.1fs" % (float(tower.get("attack_interval")) if "attack_interval" in tower else 0.8),
			"Radius %.1f" % (float(tower.call("get_range_value")) if tower.has_method("get_range_value") else 2.5),
		]
		if respawn_eta > 0.0:
			lines.append("Respawning %.0fs" % ceil(respawn_eta))
		_tower_info.text = "\n".join(lines)
		_upgrade_button.text = "NO UPGRADES"
		_upgrade_button.disabled = true
		return

	var range_val := float(tower.call("get_range_value")) if tower.has_method("get_range_value") else float(tower.get("attack_range"))
	_tower_info.text = "\n".join([
		"Range %.1f" % range_val,
		"Damage %.0f" % float(tower.get("damage")),
		"Fire %.2fs" % float(tower.get("fire_interval")),
	])

	var max_level := 2
	var upgrade_cost := 150
	var basic := _def_by_id("basic_tower")
	if basic:
		max_level = int(basic.max_level)
		upgrade_cost = int(basic.upgrade_cost)

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
	if _debug_check:
		_debug_check.button_pressed = _show_debug
	_options_dialog.popup_centered()


func _on_debug_toggled(pressed: bool) -> void:
	_show_debug = pressed
	if typeof(ProfileManager) != TYPE_NIL:
		ProfileManager.set_debug_hud_enabled(pressed)
	_apply_debug_visibility()


func _on_leave_run() -> void:
	_options_dialog.hide()
	AppRouterScript.go_main_menu(get_tree())


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
