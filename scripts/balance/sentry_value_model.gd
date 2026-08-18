extends RefCounted

## Analytical Sentry value. Upper-bound DPS, no projectile travel / target-loss fudge.

const Model := preload("res://scripts/balance/combat_value_model.gd")


static func theoretical_dps(action: Dictionary) -> float:
	var d: Dictionary = Model.def_payload(action)
	var interval := maxf(float(d.get("base_fire_interval", 0.8)), 0.05)
	var damage := float(d.get("params", {}).get("damage", d.base_damage))
	if action.has("damage"):
		damage = float(action.get("damage"))
	return damage / interval * float(d.unit_count)


static func evaluate(action: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Model.empty_metrics()
	var d: Dictionary = Model.def_payload(action)
	var exp: Dictionary = Model.exposure_for(action, ctx)
	var dps := theoretical_dps(action)
	var exposure := float(exp.get("exposure_seconds", 0.0))
	var covered := float(exp.get("covered_length_total", 0.0))
	var frac := float(exp.get("covered_fraction_of_path", 0.0))
	var hp := Model.enemy_hp(ctx)
	var per_enemy := dps * exposure
	var build_wave := int(ctx.get("build_wave", 1))
	var remaining := Model.remaining_hp_from_wave(build_wave, ctx)
	var uptime := clampf(frac * 1.15, 0.0, 1.0)
	var effective := dps * uptime
	var cost := maxf(float(d.cost), 1.0)
	m["tower_id"] = "basic_tower"
	m["role"] = "Ranged"
	m["cost"] = cost
	m["theoretical_dps"] = dps
	m["effective_dps_estimate"] = effective
	m["covered_path_length"] = covered
	m["exposure_seconds"] = exposure
	m["theoretical_damage_per_enemy"] = per_enemy
	m["theoretical_damage_per_wave"] = per_enemy * 10.0
	m["theoretical_damage_remaining_run"] = minf(remaining, effective * 120.0)
	m["damage_per_gold"] = effective / cost
	m["value_per_gold"] = m["damage_per_gold"]
	m["target_uptime_potential"] = uptime
	m["placement_quality"] = frac
	m["early_build_value"] = remaining / cost
	m["late_build_value"] = Model.remaining_hp_from_wave(5, ctx) / cost
	m["mechanical_score"] = (dps / cost) * 80.0 * (0.35 + frac)
	m["overkill_not_modeled"] = true
	return m
