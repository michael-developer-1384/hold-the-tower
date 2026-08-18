extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")

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

@onready var _missing_label: Label = %MissingManagerLabel
@onready var _display_section: PanelContainer = %DisplaySection
@onready var _window_mode: OptionButton = %WindowModeOption
@onready var _resolution: OptionButton = %ResolutionOption
@onready var _vsync: CheckBox = %VSyncCheck
@onready var _ui_scale: OptionButton = %UiScaleOption
@onready var _audio_section: PanelContainer = %AudioSection
@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _ui_audio_slider: HSlider = %UiAudioSlider
@onready var _ui_audio_value: Label = %UiAudioValue
@onready var _mute: CheckBox = %MuteCheck
@onready var _controls_section: PanelContainer = %ControlsSection
@onready var _orbit_slider: HSlider = %OrbitSlider
@onready var _orbit_value: Label = %OrbitValue
@onready var _gamepad_slider: HSlider = %GamepadSlider
@onready var _gamepad_value: Label = %GamepadValue
@onready var _zoom_slider: HSlider = %ZoomSlider
@onready var _zoom_value: Label = %ZoomValue
@onready var _invert_y: CheckBox = %InvertYCheck
@onready var _accessibility_section: PanelContainer = %AccessibilitySection
@onready var _reduced_motion: CheckBox = %ReducedMotionCheck
@onready var _time_machine: CheckBox = %TimeMachineCheck
@onready var _floor_ghosting: CheckBox = %FloorGhostingCheck
@onready var _debug_hud: CheckBox = %DebugHudCheck
@onready var _data_section: PanelContainer = %DataSection
@onready var _reset_progress: Button = %ResetProgressBtn

var _reset_dialog: ConfirmationDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_style_sections()
	if typeof(SettingsManager) == TYPE_NIL:
		_missing_label.visible = true
		_display_section.visible = false
		_audio_section.visible = false
		_controls_section.visible = false
		_accessibility_section.visible = false
		_data_section.visible = typeof(ProfileManager) != TYPE_NIL
		if _data_section.visible:
			_bind_data()
		return
	_bind_display()
	_bind_audio()
	_bind_controls()
	_bind_accessibility()
	_bind_data()


func _style_sections() -> void:
	for panel in [_display_section, _audio_section, _controls_section, _accessibility_section, _data_section]:
		UiStyle.style_card_panel(panel)


func _bind_display() -> void:
	for i in WINDOW_MODES.size():
		_window_mode.add_item(str(WINDOW_MODES[i]["label"]), i)
	var cur_mode := str(SettingsManager.get_value("display", "window_mode", "windowed"))
	for i in WINDOW_MODES.size():
		if str(WINDOW_MODES[i]["id"]) == cur_mode:
			_window_mode.select(i)
			break
	_window_mode.item_selected.connect(func(idx: int) -> void:
		SettingsManager.set_value("display", "window_mode", str(WINDOW_MODES[idx]["id"]))
	)

	for i in RESOLUTIONS.size():
		_resolution.add_item(RESOLUTIONS[i], i)
	var cur_res := str(SettingsManager.get_value("display", "resolution", "1920x1080"))
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == cur_res:
			_resolution.select(i)
			break
	_resolution.item_selected.connect(func(idx: int) -> void:
		SettingsManager.set_value("display", "resolution", RESOLUTIONS[idx])
	)

	_vsync.button_pressed = bool(SettingsManager.get_value("display", "vsync", true))
	_vsync.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("display", "vsync", pressed)
	)

	for i in UI_SCALES.size():
		_ui_scale.add_item(str(UI_SCALES[i]["label"]), i)
	var cur_scale := float(SettingsManager.get_value("display", "ui_scale", 1.0))
	for i in UI_SCALES.size():
		if is_equal_approx(float(UI_SCALES[i]["value"]), cur_scale):
			_ui_scale.select(i)
			break
	_ui_scale.item_selected.connect(func(idx: int) -> void:
		var v := float(UI_SCALES[idx]["value"])
		SettingsManager.set_value("display", "ui_scale", v)
		SettingsManager.set_value("accessibility", "ui_scale", v)
	)


func _bind_audio() -> void:
	_bind_volume_slider(_master_slider, _master_value, "master", 0.75)
	_bind_volume_slider(_music_slider, _music_value, "music", 0.75)
	_bind_volume_slider(_sfx_slider, _sfx_value, "sfx", 0.75)
	_bind_volume_slider(_ui_audio_slider, _ui_audio_value, "ui", 0.75)
	_mute.button_pressed = bool(SettingsManager.get_value("audio", "muted", false))
	_mute.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("audio", "muted", pressed)
	)


func _bind_volume_slider(slider: HSlider, value_label: Label, key: String, default_v: float) -> void:
	slider.value = float(SettingsManager.get_value("audio", key, default_v))
	value_label.text = "%.0f%%" % (slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%.0f%%" % (v * 100.0)
		SettingsManager.set_value("audio", key, v)
	)


func _bind_controls() -> void:
	_bind_sensitivity_slider(_orbit_slider, _orbit_value, "mouse_orbit_sensitivity", 1.0)
	_bind_sensitivity_slider(_gamepad_slider, _gamepad_value, "gamepad_camera_sensitivity", 1.0)
	_bind_sensitivity_slider(_zoom_slider, _zoom_value, "zoom_sensitivity", 1.0)
	_invert_y.button_pressed = bool(SettingsManager.get_value("controls", "invert_y", false))
	_invert_y.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("controls", "invert_y", pressed)
	)


func _bind_sensitivity_slider(slider: HSlider, value_label: Label, key: String, default_v: float) -> void:
	slider.value = float(SettingsManager.get_value("controls", key, default_v))
	value_label.text = "%.2fx" % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%.2fx" % v
		SettingsManager.set_value("controls", key, v)
	)


func _bind_accessibility() -> void:
	_reduced_motion.button_pressed = bool(SettingsManager.get_value("accessibility", "reduced_motion", false))
	_reduced_motion.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("accessibility", "reduced_motion", pressed)
	)
	_time_machine.button_pressed = bool(SettingsManager.get_value("gameplay", "time_machine", true))
	_time_machine.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("gameplay", "time_machine", pressed)
	)
	_floor_ghosting.button_pressed = bool(SettingsManager.get_value("gameplay", "floor_ghosting", false))
	_floor_ghosting.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_value("gameplay", "floor_ghosting", pressed)
	)
	if typeof(ProfileManager) != TYPE_NIL:
		_debug_hud.visible = true
		_debug_hud.button_pressed = ProfileManager.is_debug_hud_enabled()
		_debug_hud.toggled.connect(func(pressed: bool) -> void:
			ProfileManager.set_debug_hud_enabled(pressed)
		)
	else:
		_debug_hud.visible = false


func _bind_data() -> void:
	if typeof(ProfileManager) == TYPE_NIL:
		_data_section.visible = false
		return
	UiStyle._style_button(_reset_progress, "danger")
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "RESET ALL PROGRESS?"
	_reset_dialog.dialog_text = "This deletes every run, tower research, blueprints, and lifetime stats, and restores starting account cash. This cannot be undone."
	_reset_dialog.ok_button_text = "RESET"
	_reset_dialog.cancel_button_text = "CANCEL"
	UiStyle.style_modal(_reset_dialog)
	add_child(_reset_dialog)
	_reset_dialog.confirmed.connect(_reset_all_progress)
	_reset_progress.pressed.connect(func() -> void:
		if typeof(UiAudio) != TYPE_NIL:
			UiAudio.play_modal()
		_reset_dialog.popup_centered(Vector2i(520, 220))
	)


func _reset_all_progress() -> void:
	if typeof(ProfileManager) == TYPE_NIL:
		return
	ProfileManager.reset_profile()
	var shell := AppRouterScript.shell()
	if shell != null and shell.has_method("show_toast"):
		shell.call("show_toast", "Progress reset", "New account. Starting cash. Empty history.")
	AppRouterScript.go_main_menu(get_tree())
