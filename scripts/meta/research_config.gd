class_name ResearchConfig
extends RefCounted

## Per-stat research ranges. direction: "higher" improves upward, "lower" improves downward.


static func specs_for(tower_id: String) -> Array:
	match tower_id:
		"basic_tower":
			return [
				_spec("damage", "Damage", 15.0, 45.0, 25.0, 80.0, "higher", 0.1),
				_spec("range", "Range", 3.0, 6.0, 4.0, 70.0, "higher", 0.02),
				_spec("fire_interval", "Fire Interval", 0.4, 1.2, 0.8, 90.0, "lower", 0.01),
				_spec("projectile_speed", "Projectile Speed", 18.0, 42.0, 28.0, 40.0, "higher", 0.5),
			]
		"guard_post":
			return [
				_spec("guard_hp", "Guard HP", 60.0, 180.0, 100.0, 80.0, "higher", 1.0),
				_spec("guard_damage", "Guard Damage", 12.0, 36.0, 20.0, 80.0, "higher", 0.1),
				_spec("guard_attack_interval", "Guard Attack Interval", 0.4, 1.2, 0.8, 90.0, "lower", 0.01),
				_spec("defense_radius", "Defense Radius", 1.8, 3.5, 2.5, 70.0, "higher", 0.02),
				_spec("healing_rate", "Healing Rate", 5.0, 20.0, 10.0, 50.0, "higher", 0.1),
				_spec("healing_delay", "Healing Delay", 0.5, 4.0, 2.0, 40.0, "lower", 0.05),
				_spec("respawn_time", "Respawn Time", 4.0, 12.0, 8.0, 60.0, "lower", 0.1),
			]
		_:
			return []


static func base_params(tower_id: String) -> Dictionary:
	var out := {}
	for spec in specs_for(tower_id):
		out[str(spec["id"])] = float(spec["base"])
	return out


static func find_spec(tower_id: String, stat_id: String) -> Dictionary:
	for spec in specs_for(tower_id):
		if str(spec["id"]) == stat_id:
			return spec
	return {}


static func _spec(
	id: String,
	label: String,
	min_v: float,
	max_v: float,
	base: float,
	max_cost: float,
	direction: String,
	step: float
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"min": min_v,
		"max": max_v,
		"base": base,
		"max_cost": max_cost,
		"direction": direction,
		"step": step,
	}
