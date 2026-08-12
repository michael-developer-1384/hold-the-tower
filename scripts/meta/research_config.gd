class_name ResearchConfig
extends RefCounted

## Registry of researchable stats keyed by stat_key.


static func get_stat(stat_key: String) -> Dictionary:
	return _registry().get(stat_key, {})


static func specs_for(tower_id: String) -> Array:
	var keys := _keys_for_tower(tower_id)
	var out: Array = []
	for key in keys:
		var spec := get_stat(key)
		if not spec.is_empty():
			out.append(spec)
	return out


static func base_params(tower_id: String) -> Dictionary:
	var out := {}
	for spec in specs_for(tower_id):
		out[str(spec["id"])] = float(spec["base"])
	return out


static func find_spec(tower_id: String, stat_id: String) -> Dictionary:
	for spec in specs_for(tower_id):
		if str(spec["id"]) == stat_id:
			return spec
	return get_stat(stat_id)


static func _keys_for_tower(tower_id: String) -> PackedStringArray:
	match tower_id:
		"basic_tower":
			return PackedStringArray(["damage", "range", "fire_interval", "projectile_speed"])
		"guard_post":
			return PackedStringArray([
				"guard_hp", "guard_damage", "guard_attack_interval", "defense_radius",
				"healing_rate", "healing_delay", "respawn_time"
			])
		_:
			return PackedStringArray()


static func _registry() -> Dictionary:
	return {
		"damage": _stat("damage", "Damage", "Projectile hit damage.", 15.0, 45.0, 25.0, 80.0, false, 0.1, "%.1f"),
		"range": _stat("range", "Range", "Spherical targeting radius.", 3.0, 6.0, 4.0, 70.0, false, 0.02, "%.2f"),
		"fire_interval": _stat("fire_interval", "Fire Interval", "Seconds between shots.", 0.4, 1.2, 0.8, 90.0, true, 0.01, "%.2fs"),
		"projectile_speed": _stat("projectile_speed", "Projectile Speed", "How fast shots travel.", 18.0, 42.0, 28.0, 40.0, false, 0.5, "%.1f"),
		"guard_hp": _stat("guard_hp", "Guard HP", "Max health per guard.", 60.0, 180.0, 100.0, 80.0, false, 1.0, "%.0f"),
		"guard_damage": _stat("guard_damage", "Guard Damage", "Melee damage per hit.", 12.0, 36.0, 20.0, 80.0, false, 0.1, "%.1f"),
		"guard_attack_interval": _stat("guard_attack_interval", "Guard Attack Interval", "Seconds between melee swings.", 0.4, 1.2, 0.8, 90.0, true, 0.01, "%.2fs"),
		"defense_radius": _stat("defense_radius", "Defense Radius", "Floor disc where guards engage.", 1.8, 3.5, 2.5, 70.0, false, 0.02, "%.2f"),
		"healing_rate": _stat("healing_rate", "Healing Rate", "Out-of-combat HP per second.", 5.0, 20.0, 10.0, 50.0, false, 0.1, "%.1f"),
		"healing_delay": _stat("healing_delay", "Healing Delay", "Seconds before OOC heal starts.", 0.5, 4.0, 2.0, 40.0, true, 0.05, "%.2fs"),
		"respawn_time": _stat("respawn_time", "Respawn Time", "Seconds until a fallen guard returns.", 4.0, 12.0, 8.0, 60.0, true, 0.1, "%.1fs"),
	}


static func _stat(
	id: String,
	display_name: String,
	description: String,
	min_v: float,
	max_v: float,
	base: float,
	max_cost: float,
	lower_is_better: bool,
	step: float,
	value_format: String
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"label": display_name,
		"description": description,
		"min": min_v,
		"max": max_v,
		"base": base,
		"max_cost": max_cost,
		"lower_is_better": lower_is_better,
		"direction": "lower" if lower_is_better else "higher",
		"step": step,
		"value_format": value_format,
	}
