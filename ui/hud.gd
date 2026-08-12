extends CanvasLayer

@onready var _core_label: Label = $Root/VBox/CoreLabel
@onready var _gold_label: Label = $Root/VBox/GoldLabel
@onready var _wave_label: Label = $Root/VBox/WaveLabel
@onready var _enemy_label: Label = $Root/VBox/EnemyLabel
@onready var _focus_label: Label = $Root/VBox/FocusLabel
@onready var _start_wave_button: Button = $StartWaveButton
@onready var _build_panel: PanelContainer = $BuildPanel
@onready var _build_title: Label = $BuildPanel/Margin/VBox/TitleLabel
@onready var _build_info: Label = $BuildPanel/Margin/VBox/InfoLabel
@onready var _build_button: Button = $BuildPanel/Margin/VBox/BuildButton
@onready var _end_overlay: ColorRect = $EndOverlay
@onready var _end_title: Label = $EndOverlay/Center/VBox/TitleLabel
@onready var _restart_button: Button = $EndOverlay/Center/VBox/RestartButton

var _game: Node
var _build: Node
var _wave_running: bool = false
var _ended: bool = false
var _selected_spot: Node = null


func _ready() -> void:
	_build_panel.visible = false
	_end_overlay.visible = false
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	_build_button.pressed.connect(_on_build_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_start_wave_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP


func bind_game(game_manager: Node, build_manager: Node) -> void:
	_game = game_manager
	_build = build_manager

	_game.gold_changed.connect(set_gold)
	_game.core_hp_changed.connect(set_core_health)
	_game.enemies_alive_changed.connect(set_enemy_count)
	_game.wave_changed.connect(set_wave)
	_game.wave_state_changed.connect(_on_wave_state_changed)
	_game.game_over_changed.connect(_on_game_over)
	_game.level_complete_changed.connect(_on_level_complete)

	if _build and _build.has_signal("selection_changed"):
		_build.selection_changed.connect(_on_selection_changed)
	if _build and _build.has_signal("build_failed"):
		_build.build_failed.connect(_on_build_failed)

	set_gold(int(_game.get("gold")))
	set_core_health(int(_game.get("core_hp")))
	set_enemy_count(int(_game.get("enemies_alive")))
	set_wave(int(_game.get("current_wave")))
	_refresh_build_panel()
	_refresh_start_button()


func set_core_health(value: int) -> void:
	_core_label.text = "Core: %d" % value


func set_gold(value: int) -> void:
	_gold_label.text = "Gold: %d" % value
	_refresh_build_panel()


func set_enemy_count(value: int) -> void:
	_enemy_label.text = "Enemies: %d" % value


func set_wave(value: int) -> void:
	if _wave_running:
		_wave_label.text = "Wave: %d" % value
	else:
		_wave_label.text = "Wave: %d ready" % value
	_refresh_start_button()


func set_focus_floor(display_number: int) -> void:
	_focus_label.text = "Focus: Floor %d" % display_number


func _on_wave_state_changed(running: bool) -> void:
	_wave_running = running
	if _game:
		if running:
			_wave_label.text = "Wave: %d" % int(_game.get("active_wave"))
		else:
			_wave_label.text = "Wave: %d ready" % int(_game.get("current_wave"))
	_refresh_start_button()


func _on_selection_changed(spot: Node) -> void:
	_selected_spot = spot
	_refresh_build_panel()


func _on_build_failed(reason: String) -> void:
	_build_info.text = reason


func _on_game_over(_active: bool) -> void:
	_ended = true
	_end_overlay.visible = true
	_end_title.text = "GAME OVER"
	_build_panel.visible = false
	_refresh_start_button()


func _on_level_complete(_active: bool) -> void:
	_ended = true
	_end_overlay.visible = true
	_end_title.text = "LEVEL COMPLETE"
	_build_panel.visible = false
	_refresh_start_button()


func _refresh_start_button() -> void:
	_start_wave_button.disabled = _ended or _wave_running
	_start_wave_button.visible = not _ended


func _refresh_build_panel() -> void:
	var free_selected := (
		_selected_spot != null
		and is_instance_valid(_selected_spot)
		and not bool(_selected_spot.get("occupied"))
		and not _ended
	)
	_build_panel.visible = free_selected
	if not free_selected:
		return
	var cost := 100
	var name_text := "Basic Tower"
	if _build and _build.has_method("get_basic_tower_def"):
		var def = _build.call("get_basic_tower_def")
		if def:
			cost = int(def.cost)
			name_text = str(def.display_name)
	_build_title.text = "BUILD"
	_build_info.text = "%s\nCost: %d" % [name_text, cost]
	var can := false
	if _build and _build.has_method("can_build"):
		can = bool(_build.call("can_build"))
	_build_button.disabled = not can


func _on_start_wave_pressed() -> void:
	if _game and _game.has_method("start_next_wave"):
		_game.call("start_next_wave")


func _on_build_pressed() -> void:
	if _build and _build.has_method("build_selected"):
		_build.call("build_selected")
	_refresh_build_panel()


func _on_restart_pressed() -> void:
	if _game and _game.has_method("restart"):
		_game.call("restart")
