class_name LevelCatalog
extends RefCounted

## Known playable levels.


static func all() -> Array:
	return [
		{
			"id": "vertical_test",
			"display_name": "Vertical Test Level",
			"description": "Three-floor vertical prototype path.",
			"scene_path": "res://scenes/main.tscn",
			"legacy_level_id": "test_vertical_platforms",
		},
	]


static func find(level_id: String) -> Dictionary:
	for entry in all():
		if str(entry.get("id", "")) == level_id:
			return entry
	return {}


static func default_id() -> String:
	return "vertical_test"
