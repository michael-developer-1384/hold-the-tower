extends RefCounted

## Shared combat-value metrics. No combat stepping.

const ExposureCalc := preload("res://scripts/level/path_exposure_calculator.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const PathBuilder := preload("res://scripts/level/enemy_path_builder.gd")
const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const PathTravelScript := preload("res://scripts/level/path_travel.gd")


static func empty_metrics() -> Dictionary:
	return {
		"tower_id": "",
		"role": "",
		"cost": 0.0,
		"theoretical_dps": 0.0,
		"effective_dps_estimate": 0.0,
		"covered_path_length": 0.0,
		"exposure_seconds": 0.0,
		"theoretical_damage_per_enemy": 0.0,
		"theoretical_damage_per_wave": 0.0,
		"theoretical_damage_remaining_run": 0.0,
		"damage_per_gold": 0.0,
		"value_per_gold": 0.0,
		"target_uptime_potential": 0.0,
		"placement_quality": 0.0,
		"early_build_value": 0.0,
		"late_build_value": 0.0,
		"mechanical_score": 0.0,
	}


static func evaluate(action: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var tower_id := str(action.get("tower_id", ""))
	match tower_id:
		"guard_post":
			return load("res://scripts/balance/guard_value_model.gd").evaluate(action, ctx)
		"lava_tower":
			return load("res://scripts/balance/meltdown_value_model.gd").evaluate(action, ctx)
		_:
			return load("res://scripts/balance/sentry_value_model.gd").evaluate(action, ctx)


static func theoretical_dps(action: Dictionary) -> float:
	return float(evaluate(action, {}).get("theoretical_dps", 0.0))


static func mechanical_score(action: Dictionary, ctx: Dictionary = {}) -> float:
	return float(evaluate(action, ctx).get("mechanical_score", 0.0))


static func def_payload(action: Dictionary) -> Dictionary:
	var tower_id := str(action.get("tower_id", "basic_tower"))
	var catalog_def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tower_id)
	var params: Dictionary = ResearchConfigScript.base_params(tower_id)
	for k in params.keys():
		if action.has(k):
			params[k] = action[k]
	return {
		"tower_id": tower_id,
		"cost": float(action.get("base_cost", action.get("cost", catalog_def.cost if catalog_def else 100))),
		"base_range": float(action.get("base_range", catalog_def.base_range if catalog_def else 4.0)),
		"base_damage": float(action.get("base_damage", catalog_def.base_damage if catalog_def else 25.0)),
		"base_fire_interval": float(action.get("base_fire_interval", catalog_def.base_fire_interval if catalog_def else 0.8)),
		"range_shape": str(action.get("range_shape", catalog_def.range_shape if catalog_def else "SPHERE_3D")),
		"unit_count": int(action.get("unit_count", catalog_def.unit_count if catalog_def else 1)),
		"role": str(action.get("role", catalog_def.role if catalog_def else "")),
		"params": params,
		"lava_damage": float(action.get("lava_damage", params.get("lava_damage", 10.0))),
		"pour_rate": float(action.get("pour_rate", params.get("pour_rate", 1.2))),
		"flow_rate": float(action.get("flow_rate", params.get("flow_rate", 0.45))),
		"lava_lifetime": float(action.get("lava_lifetime", params.get("lava_lifetime", 8.0))),
		"guard_damage": float(action.get("guard_damage", params.get("guard_damage", 20.0))),
		"guard_attack_interval": float(action.get("guard_attack_interval", params.get("guard_attack_interval", 0.8))),
		"guard_hp": float(action.get("guard_hp", params.get("guard_hp", 100.0))),
		"respawn_time": float(action.get("respawn_time", params.get("respawn_time", 8.0))),
		"healing_rate": float(action.get("healing_rate", params.get("healing_rate", 10.0))),
		"defense_radius": float(action.get("defense_radius", params.get("defense_radius", action.get("base_range", 2.5)))),
	}


static func path_meta_from_ctx(ctx: Dictionary) -> Dictionary:
	if ctx.has("path_meta") and typeof(ctx.get("path_meta")) == TYPE_DICTIONARY:
		var meta: Dictionary = ctx.get("path_meta")
		if meta.has("path"):
			return meta
	var sim = ctx.get("simulation", null)
	if sim != null and sim.has_method("_path_meta"):
		return sim.call("_path_meta")
	var level = TestLevelFactoryScript.create_level()
	return PathBuilder.build_with_meta(level)


static func exposure_for(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var d := def_payload(action)
	var pos := spot_position(action, ctx)
	var floor_id := spot_floor(action, ctx)
	var meta := path_meta_from_ctx(ctx)
	var speed := enemy_speed(ctx)
	var range_value := float(d.base_range)
	if str(d.tower_id) == "guard_post" or str(d.tower_id) == "lava_tower":
		range_value = float(d.get("defense_radius", d.base_range))
	if str(d.tower_id) == "lava_tower":
		range_value = float(d.base_range)
	return ExposureCalc.compute(
		pos,
		range_value,
		str(d.range_shape),
		floor_id,
		meta.get("path", PackedVector3Array()),
		meta.get("segment_floors", PackedStringArray()),
		speed
	)


static func spot_position(action: Dictionary, ctx: Dictionary) -> Vector3:
	if action.has("position"):
		return action.get("position")
	var state: Dictionary = ctx.get("state", {})
	for spot in state.get("free_spots", []):
		if str(spot.get("spot_id")) == str(action.get("spot_id")):
			return spot.get("position", Vector3.ZERO)
	var spots := level_spots()
	for s in spots:
		if str(s.get("spot_id")) == str(action.get("spot_id")):
			return s.get("position", Vector3.ZERO)
	return Vector3.ZERO


static func spot_floor(action: Dictionary, ctx: Dictionary) -> String:
	var state: Dictionary = ctx.get("state", {})
	for spot in state.get("free_spots", []):
		if str(spot.get("spot_id")) == str(action.get("spot_id")):
			return str(spot.get("floor_id", ""))
	for s in level_spots():
		if str(s.get("spot_id")) == str(action.get("spot_id")):
			return str(s.get("floor_id", ""))
	return ""


static func level_spots() -> Array:
	var level = TestLevelFactoryScript.create_level()
	var out: Array = []
	for floor_def in level.floors:
		for spot in floor_def.build_spots:
			out.append({
				"spot_id": str(spot.id),
				"floor_id": str(floor_def.floor_id),
				"position": spot.transform.origin,
			})
	return out


static func enemy_speed(ctx: Dictionary = {}) -> float:
	if ctx.has("enemy_speed"):
		return maxf(float(ctx.get("enemy_speed")), 0.0001)
	return maxf(PathTravelScript.enemy_base_speed("bot") * PathTravelScript.difficulty_speed_mult(), 0.0001)


static func enemy_hp(ctx: Dictionary = {}) -> float:
	if ctx.has("enemy_hp"):
		return float(ctx.get("enemy_hp"))
	var def = EnemyCatalogScript.get_bot()
	var hp := float(def.base_max_health) if def else 100.0
	var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
	var diff_id := str(ctx.get("difficulty_id", "normal"))
	var entry: Dictionary = DifficultyCatalogScript.find(diff_id)
	return hp * float(entry.get("health_multiplier", 1.0))


static func remaining_hp_from_wave(build_wave: int, ctx: Dictionary = {}) -> float:
	var WaveCatalogScript = load("res://scripts/waves/wave_catalog.gd")
	var hp := 0.0
	var start := maxi(build_wave, 1)
	for w in WaveCatalogScript.create_all():
		if int(w.get("wave_number", 0)) < start:
			continue
		for g in w.get("groups", []):
			hp += float(g.get("count", 0)) * float(g.get("absolute_health", 100.0))
	var DifficultyCatalogScript = load("res://scripts/meta/difficulty_catalog.gd")
	var entry: Dictionary = DifficultyCatalogScript.find(str(ctx.get("difficulty_id", "normal")))
	return hp * float(entry.get("health_multiplier", 1.0))
