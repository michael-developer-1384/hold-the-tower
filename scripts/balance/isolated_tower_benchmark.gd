extends RefCounted

## One tower, one spot, one build wave. Real GameSimulation — no second combat engine.

const Model := preload("res://scripts/balance/combat_value_model.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	load("res://scripts/sim/agents/game_agent.gd")
	var tower_id := str(opts.get("tower_id", "basic_tower"))
	var spot_id := str(opts.get("spot_id", "F1_C"))
	var build_wave := int(opts.get("build_wave", 1))
	var seed := int(opts.get("seed", 7))
	var difficulty_id := str(opts.get("difficulty_id", "normal"))
	var sim_opts := {
		"level_id": str(opts.get("level_id", "vertical_test")),
		"difficulty_id": difficulty_id,
		"seed": seed,
		"config": {"starting_gold": int(opts.get("starting_gold", 1000))},
		"record": str(opts.get("record", "none")),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
	}
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup(sim_opts, tree)
	var policy = load("res://scripts/balance/isolated_policy.gd").new()
	policy.tower_id = tower_id
	policy.spot_id = spot_id
	policy.build_wave = build_wave
	policy.start_waves = bool(opts.get("start_waves", true))
	sim.set_agent(policy)
	await sim.await_ready()
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	var duration := float(opts.get("duration", 0.0))
	if duration > 0.0:
		await SimRunnerScript.run_for_seconds(tree, sim, duration, {
			"time_scale": float(opts.get("time_scale", 40.0)),
			"decide": true,
		})
	else:
		await SimRunnerScript.run_until_finished(tree, sim, {
			"time_scale": float(opts.get("time_scale", 40.0)),
			"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
		})
	var result: Dictionary = sim.finish()
	var action := {
		"tower_id": tower_id,
		"spot_id": spot_id,
		"type": "PLACE_TOWER",
	}
	var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tower_id)
	if def:
		action["cost"] = int(def.cost)
		action["base_cost"] = int(def.cost)
		action["base_range"] = float(def.base_range)
		action["base_damage"] = float(def.base_damage)
		action["base_fire_interval"] = float(def.base_fire_interval)
		action["range_shape"] = str(def.range_shape)
		action["unit_count"] = int(def.unit_count)
		action["role"] = str(def.role)
	var ctx := {
		"build_wave": build_wave,
		"difficulty_id": difficulty_id,
		"path_meta": sim._path_meta() if sim.has_method("_path_meta") else {},
	}
	var analytical: Dictionary = Model.evaluate(action, ctx)
	var tower_row := _tower_row(result, tower_id, spot_id)
	var incoming := float(Model.remaining_hp_from_wave(build_wave, ctx))
	var actual := float(tower_row.get("damage", result.get("total_damage", 0.0)))
	var lava := _lava_metrics(sim)
	var cost := maxf(float(action.get("base_cost", 100)), 1.0)
	var report := {
		"tower_id": tower_id,
		"spot_id": spot_id,
		"floor_id": str(tower_row.get("floor_id", "")),
		"build_wave": build_wave,
		"seed": seed,
		"difficulty_id": difficulty_id,
		"cost": cost,
		"analytical": analytical,
		"actual_damage": actual,
		"incoming_hp": incoming,
		"hp_removed_fraction": actual / maxf(incoming, 0.0001),
		"kills": int(tower_row.get("kills", result.get("enemies_killed", 0))),
		"leaks": int(result.get("enemies_leaked", 0)),
		"core_hp": int(result.get("lives_remaining", 0)),
		"overkill": float(tower_row.get("overkill", 0.0)),
		"target_time": float(tower_row.get("target_time", 0.0)),
		"no_target_time": float(tower_row.get("no_target_time", 0.0)),
		"target_uptime": _uptime(tower_row),
		"block_seconds": float(tower_row.get("total_block_time_ms", 0.0)) / 1000.0,
		"same_floor_damage": float(tower_row.get("same_floor_damage", 0.0)),
		"cross_floor_damage": float(tower_row.get("cross_floor_damage", 0.0)),
		"damage_per_gold": actual / cost,
		"value_per_gold": actual / cost,
		"theoretical_dps": float(analytical.get("theoretical_dps", 0.0)),
		"theoretical_damage": float(analytical.get("theoretical_damage_remaining_run", 0.0)),
		"covered_path_length": float(analytical.get("covered_path_length", 0.0)),
		"exposure_seconds": float(analytical.get("exposure_seconds", 0.0)),
		"lava": lava,
		"won": bool(result.get("won", false)),
		"duration": float(result.get("duration", 0.0)),
	}
	sim.cleanup()
	await tree.process_frame
	return report


static func _tower_row(result: Dictionary, tower_id: String, spot_id: String) -> Dictionary:
	for row in result.get("tower_stats", []):
		if str(row.get("tower_type")) == tower_id and (spot_id.is_empty() or str(row.get("spot_id")) == spot_id):
			return row
	if (result.get("tower_stats", []) as Array).size() > 0:
		return result.get("tower_stats")[0]
	return {}


static func _uptime(row: Dictionary) -> float:
	var t := float(row.get("target_time", 0.0))
	var n := float(row.get("no_target_time", 0.0))
	var s := t + n
	if s <= 0.0:
		return 0.0
	return t / s


static func _lava_metrics(sim) -> Dictionary:
	if sim == null or sim.game == null:
		return {}
	var tl = sim.game.get("tower_level") if sim.game else null
	if tl == null or not tl.has_method("get_lava_system"):
		return {}
	var lava = tl.call("get_lava_system")
	if lava == null or not lava.has_method("field_metrics"):
		return {}
	return lava.call("field_metrics")
