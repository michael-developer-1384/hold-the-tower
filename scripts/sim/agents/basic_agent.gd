extends "res://scripts/sim/agents/game_agent.gd"

## Transparent heuristic agent with configurable weights.

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


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var scored: Array = []
	for a in actions:
		var s := score_action(a, ctx)
		scored.append({"action": a, "score": float(s.get("total", 0.0)), "breakdown": s})
	return pick_scored(scored, rng)


func score_action(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var state: Dictionary = ctx.get("state", {})
	var sim = ctx.get("simulation", null)
	var t := str(action.get("type", ""))
	var breakdown := {}
	var total := 0.0
	match t:
		"PLACE_TOWER":
			var tower_id := str(action.get("tower_id", ""))
			var spot_id := str(action.get("spot_id", ""))
			var pos := Vector3.ZERO
			var floor_id := ""
			for spot in state.get("free_spots", []):
				if str(spot.get("spot_id")) == spot_id:
					pos = spot.get("position", Vector3.ZERO)
					floor_id = str(spot.get("floor_id", ""))
					break
			var range_v := 4.0
			var shape := "SPHERE_3D"
			if tower_id == "guard_post":
				range_v = 2.5
				shape = "FLOOR_DISC"
			var cov := 0.0
			if sim != null and sim.has_method("coverage_for_spot"):
				cov = float(sim.call("coverage_for_spot", pos, range_v, shape, floor_id))
			var cov_score := cov * float(weights.get("place_coverage", 40.0)) * 0.05
			breakdown["coverage"] = cov_score
			total += cov_score
			if tower_id == "basic_tower":
				breakdown["sentry_bias"] = float(weights.get("place_sentry_bias", 10.0))
				total += breakdown["sentry_bias"]
			elif tower_id == "guard_post":
				# Prefer lower floors for guards (path earlier).
				var floor_bonus := 12.0 if floor_id == "floor_1" else (6.0 if floor_id == "floor_2" else 2.0)
				breakdown["guard_bias"] = float(weights.get("place_guard_bias", 8.0)) + floor_bonus
				total += breakdown["guard_bias"]
			var gold := int(state.get("gold", 0))
			if gold > 250:
				breakdown["hoard"] = float(weights.get("hoard_penalty", 15.0))
				total += breakdown["hoard"]
		"UPGRADE_TOWER":
			breakdown["upgrade"] = float(weights.get("upgrade_value", 35.0))
			total += breakdown["upgrade"]
			if int(state.get("gold", 0)) >= 250:
				breakdown["upgrade_extra"] = 10.0
				total += 10.0
		"START_WAVE":
			var towers: Array = state.get("towers", [])
			var gold2 := int(state.get("gold", 0))
			var ready := towers.size() >= int(weights.get("min_towers_before_wave", 2))
			var idle_gold := gold2 <= int(weights.get("idle_gold_start_wave", 80))
			if ready or idle_gold or towers.size() >= 4:
				breakdown["start_wave"] = float(weights.get("start_wave_ready", 25.0))
				total += breakdown["start_wave"]
			else:
				breakdown["start_wave"] = -20.0
				total -= 20.0
		"WAIT":
			breakdown["wait"] = float(weights.get("wait_penalty", -5.0))
			total += breakdown["wait"]
			if not bool(state.get("wave_running", false)) and int(state.get("gold", 0)) >= 100:
				# Prefer acting over waiting when we can place.
				breakdown["wait_idle"] = -15.0
				total -= 15.0
		_:
			total = -100.0
	breakdown["total"] = total
	return breakdown
