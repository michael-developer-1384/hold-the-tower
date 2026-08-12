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
@onready var _tower_panel: PanelContainer = $TowerPanel
@onready var _tower_title: Label = $TowerPanel/Margin/VBox/TitleLabel
@onready var _tower_info: Label = $TowerPanel/Margin/VBox/InfoLabel
@onready var _upgrade_button: Button = $TowerPanel/Margin/VBox/UpgradeButton
@onready var _end_overlay: ColorRect = $EndOverlay
@onready var _end_title: Label = $EndOverlay/Center/VBox/TitleLabel
@onready var _restart_button: Button = $EndOverlay/Center/VBox/RestartButton

var _game: Node
var _build: Node
var _selection: Node
var _range_viz: Node3D
var _wave_running: bool = false
var _ended: bool = false
var _selected_spot: Node = null
var _selected_tower: Node3D = null


func _ready() -> void:
	_build_panel.visible = false
	_tower_panel.visible = false
	_end_overlay.visible = false
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	_build_button.pressed.connect(_on_build_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_upgrade_button.mouse_entered.connect(_on_upgrade_hover_entered)
	_upgrade_button.mouse_exited.connect(_on_upgrade_hover_exited)
	_restart_button.pressed.connect(_on_restart_pressed)
	_start_wave_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_tower_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP


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

	set_gold(int(_game.get("gold")))
	set_core_health(int(_game.get("core_hp")))
	set_enemy_count(int(_game.get("enemies_alive")))
	set_wave(int(_game.get("current_wave")))
	_refresh_build_panel()
	_refresh_tower_panel()
	_refresh_start_button()


func set_core_health(value: int) -> void:
	_core_label.text = "Core: %d" % value


func set_gold(value: int) -> void:
	_gold_label.text = "Gold: %d" % value
	_refresh_build_panel()
	_refresh_tower_panel()


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


func _on_spot_selection_changed(spot: Node) -> void:
	_selected_spot = spot
	_refresh_build_panel()


func _on_tower_selection_changed(tower: Node3D) -> void:
	_selected_tower = tower
	_refresh_tower_panel()


func _on_build_failed(reason: String) -> void:
	_build_info.text = reason


func _on_game_over(_active: bool) -> void:
	_ended = true
	_end_overlay.visible = true
	_end_title.text = "GAME OVER"
	_build_panel.visible = false
	_tower_panel.visible = false
	_refresh_start_button()


func _on_level_complete(_active: bool) -> void:
	_ended = true
	_end_overlay.visible = true
	_end_title.text = "LEVEL COMPLETE"
	_build_panel.visible = false
	_tower_panel.visible = false
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
	var coverage_text := _format_coverage()
	_tower_title.text = "TOWER %s" % str(tower.get("runtime_id"))
	_tower_info.text = "Level: %d\nRange: %.1f\nDamage: %.0f\nShots: %d  Hits: %d\nKills: %d\n%s" % [
		int(tower.get("level")),
		float(tower.get("attack_range")),
		float(tower.get("damage")),
		int(tower.get("shots_fired")),
		int(tower.get("hits")),
		int(tower.get("kills")),
		coverage_text,
	]

	var max_level := 2
	var upgrade_cost := 150
	if _build and _build.has_method("get_basic_tower_def"):
		var def = _build.call("get_basic_tower_def")
		if def:
			max_level = int(def.max_level)
			upgrade_cost = int(def.upgrade_cost)

	if int(tower.get("level")) >= max_level:
		_upgrade_button.text = "MAX LEVEL"
		_upgrade_button.disabled = true
	else:
		_upgrade_button.text = "UPGRADE RANGE\nCost: %d" % upgrade_cost
		var can := false
		if _build and _build.has_method("can_upgrade"):
			can = bool(_build.call("can_upgrade", tower))
		_upgrade_button.disabled = not can


func _format_coverage() -> String:
	if _range_viz == null or not _range_viz.has_method("get_last_coverage"):
		return "Coverage: —"
	var cov: Dictionary = _range_viz.call("get_last_coverage")
	var by_floor: Dictionary = cov.get("coverage_by_floor", {})
	if by_floor.is_empty():
		return "Coverage: none"
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = by_floor.keys()
	keys.sort()
	for key in keys:
		parts.append("%s: %.1f" % [str(key), float(by_floor[key])])
	return "Coverage:\n" + "\n".join(parts)


func _on_start_wave_pressed() -> void:
	if _game and _game.has_method("start_next_wave"):
		_game.call("start_next_wave")


func _on_build_pressed() -> void:
	if _build and _build.has_method("build_selected"):
		_build.call("build_selected")
	_refresh_build_panel()


func _on_upgrade_pressed() -> void:
	if _game and _game.has_method("upgrade_selected_tower"):
		_game.call("upgrade_selected_tower")
	_refresh_tower_panel()


func _on_upgrade_hover_entered() -> void:
	if _ended or _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if int(_selected_tower.get("level")) >= 2:
		return
	var preview_range := 5.5
	if _build and _build.has_method("get_basic_tower_def"):
		var def = _build.call("get_basic_tower_def")
		if def:
			preview_range = float(def.upgraded_range)
	if _range_viz and _range_viz.has_method("set_upgrade_preview"):
		_range_viz.call("set_upgrade_preview", true, preview_range)


func _on_upgrade_hover_exited() -> void:
	if _range_viz and _range_viz.has_method("set_upgrade_preview"):
		_range_viz.call("set_upgrade_preview", false)


func _on_restart_pressed() -> void:
	if _game and _game.has_method("restart"):
		_game.call("restart")
