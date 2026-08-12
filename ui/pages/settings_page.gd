extends Control

const RESOLUTIONS := [
	"1280x720",
	"1280x800",
	"1600x900",
	"1920x1080",
	"2560x1080",
	"2560x1440",
	"3440x1440",
	"3840x2160",
]

const UI_SCALES := [
	{"label": "80%", "value": 0.8},
	{"label": "90%", "value": 0.9},
	{"label": "100%", "value": 1.0},
	{"label": "110%", "value": 1.1},
	{"label": "125%", "value": 1.25},
	{"label": "150%", "value": 1.5},
]

const WINDOW_MODES := [
	{"id": "windowed", "label": "Windowed"},
	{"id": "borderless", "label": "Borderless"},
	{"id": "exclusive", "label": "Exclusive Fullscreen"},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	root.add_child(UiStyle.make_flat_label("SETTINGS", UiTokens.FONT_PAGE, false))
	root.add_child(UiStyle.make_flat_label("Device preferences. Progression lives in your profile.", UiTokens.FONT_CAPTION, true))

	if typeof(SettingsManager) == TYPE_NIL:
		root.add_child(UiStyle.make_flat_label("SettingsManager autoload missing.", UiTokens.FONT_BODY, true))
		return

	root.add_child(_section_display())
	root.add_child(_section_audio())
	root.add_child(_section_controls())
	root.add_child(_section_accessibility())


func _section_display() -> PanelContainer:
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("DISPLAY"))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	col.add_child(mode_row)
	mode_row.add_child(_field_label("Window mode"))
	var mode_opt := OptionButton.new()
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur_mode := str(SettingsManager.get_value("display", "window_mode", "windowed"))
	var mode_idx := 0
	for i in WINDOW_MODES.size():
		mode_opt.add_item(str(WINDOW_MODES[i]["label"]), i)
		if str(WINDOW_MODES[i]["id"]) == cur_mode:
			mode_idx = i
	mode_opt.select(mode_idx)
	mode_opt.item_selected.connect(func(idx: int) -> void:
		SettingsManager.set_value("display", "window_mode", str(WINDOW_MODES[idx]["id"]))
	)
	mode_row.add_child(mode_opt)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	col.add_child(res_row)
	res_row.add_child(_field_label("Resolution"))
	var res_opt := OptionButton.new()
	res_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur_res := str(SettingsManager.get_value("display", "resolution", "1920x1080"))
	var res_idx := 2
	for i in RESOLUTIONS.size():
		res_opt.add_item(RESOLUTIONS[i], i)
		if RESOLUTIONS[i] == cur_res:
			res_idx = i
	res_opt.select(res_idx)
	res_opt.item_selected.connect(func(idx: int) -> void:
		SettingsManager.set_value("display", "resolution", RESOLUTIONS[idx])
	)
	res_row.add_child(res_opt)

	col.add_child(_checkbox(
		"VSync",
		bool(SettingsManager.get_value("display", "vsync", true)),
		func(pressed: bool) -> void: SettingsManager.set_value("display", "vsync", pressed)
	))

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	col.add_child(scale_row)
	scale_row.add_child(_field_label("UI scale"))
	var scale_opt := OptionButton.new()
	scale_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur_scale := float(SettingsManager.get_value("display", "ui_scale", 1.0))
	var scale_idx := 2
	for i in UI_SCALES.size():
		scale_opt.add_item(str(UI_SCALES[i]["label"]), i)
		if is_equal_approx(float(UI_SCALES[i]["value"]), cur_scale):
			scale_idx = i
	scale_opt.select(scale_idx)
	scale_opt.item_selected.connect(func(idx: int) -> void:
		var v := float(UI_SCALES[idx]["value"])
		SettingsManager.set_value("display", "ui_scale", v)
		SettingsManager.set_value("accessibility", "ui_scale", v)
	)
	scale_row.add_child(scale_opt)
	return panel


func _section_audio() -> PanelContainer:
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("AUDIO"))
	for key: String in ["master", "music", "sfx", "ui"]:
		var label := key.capitalize()
		col.add_child(_slider_row(
			label,
			float(SettingsManager.get_value("audio", key, 0.75)),
			0.0,
			1.0,
			0.01,
			func(v: float) -> void: SettingsManager.set_value("audio", key, v),
			func(v: float) -> String: return "%.0f%%" % (v * 100.0)
		))
	col.add_child(_checkbox(
		"Mute all",
		bool(SettingsManager.get_value("audio", "muted", false)),
		func(pressed: bool) -> void: SettingsManager.set_value("audio", "muted", pressed)
	))
	return panel


func _section_controls() -> PanelContainer:
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("CONTROLS"))
	col.add_child(_slider_row(
		"Mouse orbit sensitivity",
		float(SettingsManager.get_value("controls", "mouse_orbit_sensitivity", 1.0)),
		0.25,
		2.5,
		0.05,
		func(v: float) -> void: SettingsManager.set_value("controls", "mouse_orbit_sensitivity", v),
		func(v: float) -> String: return "%.2fx" % v
	))
	col.add_child(_slider_row(
		"Gamepad camera sensitivity",
		float(SettingsManager.get_value("controls", "gamepad_camera_sensitivity", 1.0)),
		0.25,
		2.5,
		0.05,
		func(v: float) -> void: SettingsManager.set_value("controls", "gamepad_camera_sensitivity", v),
		func(v: float) -> String: return "%.2fx" % v
	))
	col.add_child(_slider_row(
		"Zoom sensitivity",
		float(SettingsManager.get_value("controls", "zoom_sensitivity", 1.0)),
		0.25,
		2.5,
		0.05,
		func(v: float) -> void: SettingsManager.set_value("controls", "zoom_sensitivity", v),
		func(v: float) -> String: return "%.2fx" % v
	))
	col.add_child(_checkbox(
		"Invert Y",
		bool(SettingsManager.get_value("controls", "invert_y", false)),
		func(pressed: bool) -> void: SettingsManager.set_value("controls", "invert_y", pressed)
	))
	return panel


func _section_accessibility() -> PanelContainer:
	var panel := UiStyle.make_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.make_section_label("ACCESSIBILITY"))
	col.add_child(_checkbox(
		"Reduced motion",
		bool(SettingsManager.get_value("accessibility", "reduced_motion", false)),
		func(pressed: bool) -> void: SettingsManager.set_value("accessibility", "reduced_motion", pressed)
	))
	col.add_child(_checkbox(
		"Time Machine",
		bool(SettingsManager.get_value("gameplay", "time_machine", true)),
		func(pressed: bool) -> void: SettingsManager.set_value("gameplay", "time_machine", pressed)
	))
	if typeof(ProfileManager) != TYPE_NIL:
		col.add_child(_checkbox(
			"Debug HUD",
			ProfileManager.is_debug_hud_enabled(),
			func(pressed: bool) -> void: ProfileManager.set_debug_hud_enabled(pressed)
		))
	return panel


func _field_label(text: String) -> Label:
	var l := UiStyle.make_flat_label(text, UiTokens.FONT_BODY, false)
	l.custom_minimum_size = Vector2(220, 0)
	return l


func _checkbox(text: String, initial: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = initial
	cb.toggled.connect(func(pressed: bool) -> void: on_toggle.call(pressed))
	return cb


func _slider_row(
	label: String,
	initial: float,
	min_v: float,
	max_v: float,
	step: float,
	on_change: Callable,
	fmt: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_field_label(label))
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = clampf(initial, min_v, max_v)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 24)
	row.add_child(slider)
	var value_l := UiStyle.make_flat_label(str(fmt.call(slider.value)), UiTokens.FONT_DATA, true)
	value_l.custom_minimum_size = Vector2(72, 0)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_l)
	slider.value_changed.connect(func(v: float) -> void:
		value_l.text = str(fmt.call(v))
		on_change.call(v)
	)
	return row
