extends CanvasLayer

@onready var _core_label: Label = $Root/VBox/CoreLabel
@onready var _enemy_label: Label = $Root/VBox/EnemyLabel
@onready var _focus_label: Label = $Root/VBox/FocusLabel


func set_core_health(value: int) -> void:
	_core_label.text = "Core: %d" % value


func set_enemy_count(value: int) -> void:
	_enemy_label.text = "Enemies: %d" % value


func set_focus_floor(display_number: int) -> void:
	_focus_label.text = "Focus: Floor %d" % display_number
