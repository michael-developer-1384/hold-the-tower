extends RefCounted

## Guard value: melee DPS plus blocking utility / potential extra exposure.

const Model := preload("res://scripts/balance/combat_value_model.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")


static func theoretical_melee_dps(action: Dictionary) -> float:
	var d: Dictionary = Model.def_payload(action)
	var interval := maxf(float(d.get("guard_attack_interval", 0.8)), 0.05)
	var damage := float(d.get("guard_damage", d.base_damage))
	return damage / interval * float(d.unit_count)


static func evaluate(action: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Model.empty_metrics()
	var d: Dictionary = Model.def_payload(action)
	var exp: Dictionary = Model.exposure_for(action, ctx)
	var melee := theoretical_melee_dps(action)
	var units := float(d.unit_count)
	var hp := float(d.guard_hp)
	var enemy := EnemyCatalogScript.get_bot()
	var e_dps := 12.0 / 0.85
	if enemy != null:
		e_dps = float(enemy.base_melee_damage) / maxf(float(enemy.base_melee_interval), 0.05)
	var time_to_kill_guard := hp / maxf(e_dps, 0.01)
	var respawn := float(d.respawn_time)
	var cycle := time_to_kill_guard + respawn
	var alive_uptime := time_to_kill_guard / maxf(cycle, 0.01)
	var block_seconds := units * time_to_kill_guard
	var extra_exposure := block_seconds
	var cost := maxf(float(d.cost), 1.0)
	var covered := float(exp.get("covered_length_total", 0.0))
	var frac := float(exp.get("covered_fraction_of_path", 0.0))
	var chokepoint := clampf(frac * 4.0, 0.0, 1.0)
	var effective := melee * alive_uptime * chokepoint
	var remaining := Model.remaining_hp_from_wave(int(ctx.get("build_wave", 1)), ctx)
	m["tower_id"] = "guard_post"
	m["role"] = "Melee"
	m["cost"] = cost
	m["theoretical_dps"] = melee
	m["theoretical_melee_dps"] = melee
	m["effective_dps_estimate"] = effective
	m["covered_path_length"] = covered
	m["exposure_seconds"] = float(exp.get("exposure_seconds", 0.0))
	m["theoretical_damage_per_enemy"] = melee * float(exp.get("exposure_seconds", 0.0)) * alive_uptime
	m["theoretical_damage_remaining_run"] = minf(remaining, effective * 120.0)
	m["damage_per_gold"] = effective / cost
	m["value_per_gold"] = (effective + extra_exposure * 8.0) / cost
	m["target_uptime_potential"] = alive_uptime
	m["placement_quality"] = chokepoint
	m["expected_block_capacity"] = units
	m["block_seconds"] = block_seconds
	m["guard_alive_uptime"] = alive_uptime
	m["respawn_downtime"] = 1.0 - alive_uptime
	m["healing_contribution"] = float(d.healing_rate) * units * alive_uptime
	m["potential_extra_exposure"] = extra_exposure
	m["mechanical_score"] = ((melee / cost) * 50.0 + extra_exposure * chokepoint * 2.5)
	m["early_build_value"] = m["value_per_gold"]
	m["late_build_value"] = m["value_per_gold"] * 0.85
	return m
