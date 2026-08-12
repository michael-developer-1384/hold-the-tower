class_name WaveCatalog
extends RefCounted

## Recreates prior 5-wave balance as bot-only groups.


static func create_all() -> Array:
	return [
		_wave(1, 10, 100.0),
		_wave(2, 12, 110.0),
		_wave(3, 14, 120.0),
		_wave(4, 16, 135.0),
		_wave(5, 20, 150.0),
	]


static func get_wave(wave_number: int) -> Dictionary:
	for w in create_all():
		if int(w.get("wave_number", 0)) == wave_number:
			return w
	return {}


static func wave_count() -> int:
	return create_all().size()


static func _wave(wave_number: int, count: int, absolute_health: float) -> Dictionary:
	return {
		"wave_number": wave_number,
		"groups": [
			{
				"enemy_id": "bot",
				"count": count,
				"health_multiplier": 1.0,
				"speed_multiplier": 1.0,
				"spawn_interval": 0.8,
				"absolute_health": absolute_health,
			}
		],
	}
