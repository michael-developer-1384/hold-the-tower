extends RefCounted

## Separates HP / speed / damage / spawn / count pressure from tower balance.

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const PathTravelScript := preload("res://scripts/level/path_travel.gd")
const PathBuilder := preload("res://scripts/level/enemy_path_builder.gd")
const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")


static func components(difficulty_id: String) -> Dictionary:
	var entry: Dictionary = DifficultyCatalogScript.find(difficulty_id)
	return {
		"health_multiplier": float(entry.get("health_multiplier", 1.0)),
		"speed_multiplier": float(entry.get("speed_multiplier", 1.0)),
		"damage_multiplier": float(entry.get("damage_multiplier", 1.0)),
		"spawn_rate_multiplier": float(entry.get("spawn_rate_multiplier", 1.0)),
		"enemy_count_multiplier": float(entry.get("enemy_count_multiplier", 1.0)),
		"legacy_multiplier": float(entry.get("multiplier", 1.0)),
	}


static func ranged_pressure_factor(difficulty_id: String) -> float:
	## HP × speed is super-linear for ranged exposure DPS.
	var c := components(difficulty_id)
	return float(c.health_multiplier) * float(c.speed_multiplier)


static func report(difficulty_id: String = "normal", starting_buying_power: int = 300) -> Dictionary:
	var c := components(difficulty_id)
	var level = TestLevelFactoryScript.create_level()
	var meta: Dictionary = PathBuilder.build_with_meta(level)
	var path: PackedVector3Array = meta.get("path", PackedVector3Array())
	var path_len := PathTravelScript.path_length(path)
	var bot = EnemyCatalogScript.get_bot()
	var base_speed := float(bot.base_move_speed) if bot else 2.2
	var move := maxf(base_speed * float(c.speed_multiplier), 0.05)
	var travel := path_len / move
	var reward := int(bot.reward) if bot else 10
	var total_count := 0
	var total_hp := 0.0
	var hp_by_wave: Array = []
	var spawn_duration := 0.0
	var densities: Array = []
	for w in WaveCatalogScript.create_all():
		var count := 0
		var hp := 0.0
		var stagger := 0.0
		var last_interval := 0.0
		var spawned := 0
		for g in w.get("groups", []):
			var n := int(round(float(g.get("count", 0)) * float(c.enemy_count_multiplier)))
			var interval := float(g.get("spawn_interval", 0.8)) / maxf(float(c.spawn_rate_multiplier), 0.0001)
			var abs_hp := float(g.get("absolute_health", 100.0)) * float(c.health_multiplier)
			count += n
			hp += float(n) * abs_hp
			for _i in n:
				if spawned > 0:
					stagger += last_interval
				last_interval = interval
				spawned += 1
		var wave_spawn := stagger
		spawn_duration += wave_spawn
		var dens := float(count) / maxf(wave_spawn, 0.0001)
		densities.append(dens)
		total_count += count
		total_hp += hp
		hp_by_wave.append({"wave": int(w.get("wave_number", 0)), "hp": hp, "count": count, "spawn_duration": wave_spawn})
	densities.sort()
	var avg_dens := 0.0
	var max_dens := 0.0
	for d in densities:
		avg_dens += float(d)
		max_dens = maxf(max_dens, float(d))
	if densities.size() > 0:
		avg_dens /= float(densities.size())
	var window := spawn_duration + travel
	var min_dps := total_hp / maxf(window, 0.0001)
	var economy := reward * total_count
	var wave_pressure := min_dps * ranged_pressure_factor(difficulty_id)
	return {
		"difficulty_id": difficulty_id,
		"components": c,
		"ranged_pressure_factor": ranged_pressure_factor(difficulty_id),
		"total_enemy_count": total_count,
		"total_incoming_hp": total_hp,
		"hp_by_wave": hp_by_wave,
		"spawn_duration": spawn_duration,
		"max_spawn_density": max_dens,
		"average_spawn_density": avg_dens,
		"path_length": path_len,
		"path_travel_time": travel,
		"wave_pressure_score": wave_pressure,
		"whole_run_pressure_score": wave_pressure,
		"theoretical_minimum_sustained_dps": min_dps,
		"economy_from_kills": economy,
		"starting_economy": starting_buying_power,
		"available_spending": starting_buying_power + economy,
		"note": "HP×speed for ranged defense is super-linear vs a single difficulty multiplier.",
	}
