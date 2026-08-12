class_name DifficultyCatalog
extends RefCounted

const BASE_RP_REWARD := 50.0


static func all() -> Array:
	return [
		{"id": "easy", "display_name": "Easy", "multiplier": 0.80},
		{"id": "normal", "display_name": "Normal", "multiplier": 1.00},
		{"id": "hard", "display_name": "Hard", "multiplier": 1.25},
		{"id": "brutal", "display_name": "Brutal", "multiplier": 1.50},
	]


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
