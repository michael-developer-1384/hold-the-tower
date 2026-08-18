extends RefCounted

## Meltdown analytical value. Persistent area / ramp — never damage/fire_interval.

const Model := preload("res://scripts/balance/combat_value_model.gd")
const LavaConfigScript := preload("res://scripts/world/lava_config.gd")


static func evaluate(action: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Model.empty_metrics()
	var d: Dictionary = Model.def_payload(action)
	var exp: Dictionary = Model.exposure_for(action, ctx)
	var params: Dictionary = LavaConfigScript.resolve(d.get("params", {}))
	var lava_damage := float(d.lava_damage)
	var pour := float(d.pour_rate)
	var lifetime := float(d.lava_lifetime)
	var flow := float(d.flow_rate)
	var full := float(params.damage_full_mass)
	var fill_rate := pour / full
	var t_full := full / maxf(pour, 0.01)
	var peak_cell := lava_damage
	var expected_cells := 1.0 + clampf(flow * 2.0, 0.0, 3.0)
	if str(Model.spot_floor(action, ctx)) != "floor_1":
		expected_cells += clampf(flow * 1.5, 0.0, 2.0)
	var build_wave := int(ctx.get("build_wave", 1))
	var remaining_time := maxf(30.0, 90.0 - float(build_wave - 1) * 18.0)
	var fill := clampf(fill_rate * remaining_time, 0.0, 1.0)
	var dwell := float(exp.get("exposure_seconds", 0.0))
	var occupancy := clampf(dwell * 0.35, 0.05, 1.0)
	var effective := peak_cell * expected_cells * fill * occupancy
	var cost := maxf(float(d.cost), 1.0)
	var remaining_hp := Model.remaining_hp_from_wave(build_wave, ctx)
	m["tower_id"] = "lava_tower"
	m["role"] = "Area"
	m["cost"] = cost
	m["theoretical_dps"] = peak_cell * expected_cells
	m["effective_dps_estimate"] = effective
	m["covered_path_length"] = float(exp.get("covered_length_total", 0.0))
	m["exposure_seconds"] = dwell
	m["theoretical_damage_per_enemy"] = lava_damage * dwell * fill
	m["theoretical_damage_remaining_run"] = minf(remaining_hp, effective * remaining_time)
	m["damage_per_gold"] = (effective * remaining_time) / cost
	m["value_per_gold"] = m["damage_per_gold"]
	m["target_uptime_potential"] = occupancy
	m["placement_quality"] = float(exp.get("covered_fraction_of_path", 0.0))
	m["lava_damage"] = lava_damage
	m["pour_rate"] = pour
	m["lava_lifetime"] = lifetime
	m["flow_rate"] = flow
	m["damage_full_mass"] = full
	m["cell_mass_capacity"] = float(params.cell_mass_capacity)
	m["flow_start_mass"] = float(params.flow_start_mass)
	m["t_full_single_cell"] = t_full
	m["expected_cells"] = expected_cells
	m["early_build_value"] = Model.remaining_hp_from_wave(1, ctx) / cost
	m["late_build_value"] = Model.remaining_hp_from_wave(5, ctx) / cost
	m["mechanical_score"] = (effective * remaining_time / cost) * 12.0 + float(exp.get("covered_fraction_of_path", 0.0)) * 20.0
	m["uses_fire_interval"] = false
	return m
