extends CanvasLayer

signal non_walkable_hidden_changed(hidden: bool)

const OPTION_HIDE_NON_WALKABLE := 0

@onready var _core_label: Label = $Root/VBox/CoreLabel
@onready var _enemy_label: Label = $Root/VBox/EnemyLabel
@onready var _focus_label: Label = $Root/VBox/FocusLabel
@onready var _options_menu: MenuButton = $OptionsRoot/OptionsMenu


func _ready() -> void:
	var popup := _options_menu.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.add_check_item("Hide non-walkable surfaces", OPTION_HIDE_NON_WALKABLE)
	popup.set_item_checked(OPTION_HIDE_NON_WALKABLE, false)
	popup.id_pressed.connect(_on_options_pressed)


func set_core_health(value: int) -> void:
	_core_label.text = "Core: %d" % value


func set_enemy_count(value: int) -> void:
	_enemy_label.text = "Enemies: %d" % value


func set_focus_floor(display_number: int) -> void:
	_focus_label.text = "Focus: Floor %d" % display_number


func _on_options_pressed(id: int) -> void:
	if id != OPTION_HIDE_NON_WALKABLE:
		return
	var popup := _options_menu.get_popup()
	var hide_surfaces := not popup.is_item_checked(OPTION_HIDE_NON_WALKABLE)
	popup.set_item_checked(OPTION_HIDE_NON_WALKABLE, hide_surfaces)
	non_walkable_hidden_changed.emit(hide_surfaces)
