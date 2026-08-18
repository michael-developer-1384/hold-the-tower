class_name DifficultyCatalog
extends RefCounted

const BASE_RP_REWARD := 50.0


static func all() -> Array:
	return [
		_preset("easy", "Easy", 0.80),
		_preset("normal", "Normal", 1.00),
		_preset("hard", "Hard", 1.25),
		_preset("brutal", "Brutal", 1.50),
	]


static func _preset(id: String, display_name: String, multiplier: float) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"multiplier": multiplier,
		"health_multiplier": multiplier,
		"speed_multiplier": multiplier,
		"damage_multiplier": multiplier,
		"spawn_rate_multiplier": 1.00,
		"enemy_count_multiplier": 1.00,
	}


static func find(difficulty_id: String) -> Dictionary:
	for entry in all():
		if str(entry.get("id", "")) == difficulty_id:
			return entry
	return find("normal")


static func default_id() -> String:
	return "normal"


static func research_reward(difficulty_id: String) -> int:
	var entry := find(difficulty_id)
	var m := float(entry.get("multiplier", 1.0))
	return int(ceili(BASE_RP_REWARD * m))


static func component(difficulty_id: String, key: String, fallback_multiplier: float = 1.0) -> float:
	var entry := find(difficulty_id)
	if entry.has(key):
		return float(entry[key])
	return float(entry.get("multiplier", fallback_multiplier))
