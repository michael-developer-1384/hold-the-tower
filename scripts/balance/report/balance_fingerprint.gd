extends RefCounted

## Hash of balance-relevant catalog params + analysis overrides.


static func catalog_params() -> Dictionary:
	var TowerCatalogScript = load("res://scripts/towers/tower_catalog.gd")
	var LavaConfigScript = load("res://scripts/world/lava_config.gd")
	var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
	var ResearchConfigScript = load("res://scripts/meta/research_config.gd")
	var towers := {}
	for def in TowerCatalogScript.create_all():
		towers[str(def.tower_id)] = {
			"cost": int(def.cost),
			"base_damage": float(def.base_damage),
			"base_range": float(def.base_range),
			"base_fire_interval": float(def.base_fire_interval),
			"unit_count": int(def.unit_count),
			"research_base": ResearchConfigScript.base_params(str(def.tower_id)),
		}
	return {
		"towers": towers,
		"lava": LavaConfigScript.defaults(),
		"difficulty": DifficultyCatalogScript.all(),
	}


static func compute(overrides: Dictionary = {}) -> String:
	var payload := {"catalog": catalog_params(), "overrides": overrides}
	var raw := JSON.stringify(payload)
	return raw.sha256_text().substr(0, 16)


static func git_commit() -> String:
	var out: Array = []
	var err := OS.execute("git", PackedStringArray(["rev-parse", "--short", "HEAD"]), out, true)
	if err != 0 or out.is_empty():
		return ""
	return str(out[0]).strip_edges()
