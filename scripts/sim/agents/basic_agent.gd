extends "res://scripts/sim/agents/game_agent.gd"

## Human-like heuristic. Behavioral biases are tagged, not hidden.

const ScoreUtil := preload("res://scripts/sim/agents/score_util.gd")

var include_behavioral: bool = true
var weights: Dictionary = {
	"place_coverage": 40.0,
	"place_sentry_bias": 10.0,
	"place_guard_bias": 8.0,
	"upgrade_value": 35.0,
	"start_wave_ready": 25.0,
	"hoard_penalty": 15.0,
	"wait_penalty": -5.0,
	"min_towers_before_wave": 2,
	"idle_gold_start_wave": 80,
}


func _init(p_temperature: float = 0.0, p_weights: Dictionary = {}) -> void:
	id = "basic"
	temperature = p_temperature
	if not p_weights.is_empty():
		for k in p_weights.keys():
			weights[k] = p_weights[k]


func explicit_biases() -> Dictionary:
	if not include_behavioral:
		return {}
	return {
		"basic_tower": float(weights.get("place_sentry_bias", 0.0)),
		"guard_post": float(weights.get("place_guard_bias", 0.0)),
	}


func has_explicit_bias_for(tower_id: String) -> bool:
	return absf(float(explicit_biases().get(tower_id, 0.0))) > 0.01


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var scored: Array = []
	for a in actions:
		var s: Dictionary = score_action(a, ctx)
		scored.append({"action": a, "score": float(s.get("total", 0.0)), "breakdown": s})
	return pick_scored(scored, rng)


func score_action(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var state: Dictionary = ctx.get("state", {})
	var sim = ctx.get("simulation", null)
	var t := str(action.get("type", ""))
	var parts := {}
	match t:
		"PLACE_TOWER":
			var def: Dictionary = ScoreUtil.def_from_action(action)
			var pos := Vector3.ZERO
			var floor_id := ""
			for spot in state.get("free_spots", []):
				if str(spot.get("spot_id")) == str(action.get("spot_id")):
					pos = spot.get("position", Vector3.ZERO)
					floor_id = str(spot.get("floor_id", ""))
					break
			var cov := 0.0
			if sim != null and sim.has_method("coverage_for_spot"):
				cov = float(sim.call("coverage_for_spot", pos, float(def.base_range), str(def.range_shape), floor_id))
			parts["coverage"] = ScoreUtil.part(cov * float(weights.get("place_coverage", 40.0)) * 0.05, ScoreUtil.TYPE_MECH)
			var dps := ScoreUtil.estimated_dps(action)
			var dpg := (dps / maxf(float(def.cost), 1.0)) * 80.0
			parts["dps_per_gold"] = ScoreUtil.part(dpg, ScoreUtil.TYPE_MECH)
			if include_behavioral:
				if str(def.tower_id) == "basic_tower":
					parts["place_sentry_bias"] = ScoreUtil.part(float(weights.get("place_sentry_bias", 10.0)), ScoreUtil.TYPE_BIAS)
				elif str(def.tower_id) == "guard_post":
					var floor_bonus := 12.0 if floor_id == "floor_1" else (6.0 if floor_id == "floor_2" else 2.0)
					parts["place_guard_bias"] = ScoreUtil.part(float(weights.get("place_guard_bias", 8.0)) + floor_bonus, ScoreUtil.TYPE_BIAS)
				if int(state.get("gold", 0)) > 250:
					parts["hoard"] = ScoreUtil.part(float(weights.get("hoard_penalty", 15.0)), ScoreUtil.TYPE_BIAS)
		"UPGRADE_TOWER":
			var bonus := float(action.get("upgrade_range_bonus", 1.5))
			var cost := maxf(float(action.get("cost", 150)), 1.0)
			parts["upgrade_efficiency"] = ScoreUtil.part((bonus / cost) * 2000.0, ScoreUtil.TYPE_MECH)
			if include_behavioral:
				parts["upgrade_habit"] = ScoreUtil.part(float(weights.get("upgrade_value", 35.0)), ScoreUtil.TYPE_BIAS)
				if int(state.get("gold", 0)) >= 250:
					parts["upgrade_extra"] = ScoreUtil.part(10.0, ScoreUtil.TYPE_BIAS)
		"START_WAVE":
			var towers: Array = state.get("towers", [])
			var gold2 := int(state.get("gold", 0))
			var ready := towers.size() >= int(weights.get("min_towers_before_wave", 2))
			var idle_gold := gold2 <= int(weights.get("idle_gold_start_wave", 80))
			if ready or idle_gold or towers.size() >= 4:
				parts["start_wave"] = ScoreUtil.part(float(weights.get("start_wave_ready", 25.0)), ScoreUtil.TYPE_MECH)
			else:
				parts["start_wave"] = ScoreUtil.part(-20.0, ScoreUtil.TYPE_MECH)
		"WAIT":
			parts["wait"] = ScoreUtil.part(float(weights.get("wait_penalty", -5.0)), ScoreUtil.TYPE_BIAS if include_behavioral else ScoreUtil.TYPE_MECH)
			if include_behavioral and not bool(state.get("wave_running", false)) and int(state.get("gold", 0)) >= 100:
				parts["wait_idle"] = ScoreUtil.part(-15.0, ScoreUtil.TYPE_BIAS)
		_:
			parts["unknown"] = ScoreUtil.part(-100.0, ScoreUtil.TYPE_MECH)
	return ScoreUtil.finalize(parts)
