class_name WaveSpawnGroup
extends Resource

@export var enemy_id: String = "bot"
@export var count: int = 10
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var spawn_interval: float = 0.8
@export var absolute_health: float = -1.0


func to_dict() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"count": count,
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"spawn_interval": spawn_interval,
		"absolute_health": absolute_health,
	}
