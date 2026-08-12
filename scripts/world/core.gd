extends Node3D

signal health_changed(current_health: int)
signal destroyed

@export var max_health: int = 20
var health: int = 20


func _ready() -> void:
	health = max_health
	health_changed.emit(health)


func take_hit(amount: int = 1) -> void:
	if health <= 0:
		return
	health = max(health - amount, 0)
	if typeof(GameplayAudio) != TYPE_NIL:
		GameplayAudio.play_global("core_hit")
	health_changed.emit(health)
	if health <= 0:
		destroyed.emit()
