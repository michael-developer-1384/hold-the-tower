class_name ResearchConfig
extends RefCounted

## Registry of researchable stats keyed by stat_key (investment model).


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


static func zero_allocations(tower_id: String) -> Dictionary:
	var out := {}
	for spec in specs_for(tower_id):
		out[str(spec["id"])] = 0
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
		"lava_tower":
			return PackedStringArray(["lava_damage", "pour_rate", "flow_rate", "lava_lifetime"])
		_:
			return PackedStringArray()


static func _registry() -> Dictionary:
	return {
		"damage": _stat("damage", "Damage", "Projectile hit damage.", 25.0, 45.0, 240, false, "%.1f"),
		"range": _stat("range", "Range", "Spherical targeting radius.", 4.0, 6.0, 280, false, "%.2f"),
		"fire_interval": _stat("fire_interval", "Fire Interval", "Seconds between shots.", 0.80, 0.40, 300, true, "%.2fs"),
		"projectile_speed": _stat("projectile_speed", "Projectile Speed", "How fast shots travel.", 28.0, 42.0, 140, false, "%.1f"),
		"guard_hp": _stat("guard_hp", "Guard HP", "Max health per guard.", 100.0, 180.0, 220, false, "%.0f"),
		"guard_damage": _stat("guard_damage", "Guard Damage", "Melee damage per hit.", 20.0, 36.0, 240, false, "%.1f"),
		"guard_attack_interval": _stat(
			"guard_attack_interval", "Guard Attack Interval", "Seconds between melee swings.",
			0.80, 0.40, 300, true, "%.2fs"
		),
		"defense_radius": _stat("defense_radius", "Defense Radius", "Floor disc where guards engage.", 2.5, 3.5, 260, false, "%.2f"),
		"healing_rate": _stat("healing_rate", "Healing Rate", "Out-of-combat HP per second.", 10.0, 20.0, 140, false, "%.1f"),
		"healing_delay": _stat("healing_delay", "Healing Delay", "Seconds before OOC heal starts.", 2.0, 0.5, 120, true, "%.2fs"),
		"respawn_time": _stat("respawn_time", "Respawn Time", "Seconds until a fallen guard returns.", 8.0, 4.0, 260, true, "%.1fs"),
		"lava_damage": _stat("lava_damage", "Lava Damage", "Burn per second on a full puddle cell (100 drops).", 10.0, 16.0, 220, false, "%.1f"),
		"pour_rate": _stat("pour_rate", "Pour Rate", "Drops poured onto the path per second.", 1.2, 2.0, 160, false, "%.1f"),
		"flow_rate": _stat("flow_rate", "Flow Rate", "How quickly puddles spread and drip.", 0.45, 0.80, 140, false, "%.2f"),
		"lava_lifetime": _stat("lava_lifetime", "Lava Lifetime", "Idle seconds before a puddle fades. 0 = stays forever.", 0.0, 20.0, 160, false, "%.1fs"),
	}


static func _stat(
	id: String,
	display_name: String,
	description: String,
	base: float,
	best: float,
	max_investment_rp: int,
	lower_is_better: bool,
	value_format: String
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"label": display_name,
		"description": description,
		"base": base,
		"best": best,
		"max_investment_rp": max_investment_rp,
		"lower_is_better": lower_is_better,
		"direction": "lower" if lower_is_better else "higher",
		"value_format": value_format,
	}
