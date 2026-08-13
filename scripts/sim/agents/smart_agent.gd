extends "res://scripts/sim/agents/game_agent.gd"

## Extensible scored agent. Lookahead hook via simulation.evaluate_action_with_lookahead.

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const BasicAgentScript := preload("res://scripts/sim/agents/basic_agent.gd")

var use_lookahead: bool = true
var lookahead_horizon: float = 2.5
var _basic


func _init(p_temperature: float = 0.0) -> void:
	id = "smart"
	temperature = p_temperature
	_basic = BasicAgentScript.new(0.0)


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	var sim = ctx.get("simulation", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var scored: Array = []
	for a in actions:
		var s: Dictionary = score_action(a, ctx)
		var total: float = float(s.get("total", 0.0))
		if use_lookahead and sim != null and str(a.get("type", "")) != "WAIT":
			# Architecture hook: currently reuses heuristic (clone not combat-complete).
			var look: float = float(sim.call("evaluate_action_with_lookahead", a, lookahead_horizon))
			s["lookahead"] = look * 0.15
			total += float(s["lookahead"])
			s["total"] = total
		scored.append({"action": a, "score": total, "breakdown": s})
	return pick_scored(scored, rng)


func score_action(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var base: Dictionary = _basic.score_action(action, ctx)
	var state: Dictionary = ctx.get("state", {})
	var t := str(action.get("type", ""))
	var total: float = float(base.get("total", 0.0))

	# Expected remaining pressure from known wave catalog (public info).
	var wave := int(state.get("current_wave", 1))
	var forecast := _wave_threat(wave)
	base["wave_forecast"] = forecast * 0.1

	if t == "PLACE_TOWER":
		var tower_id := str(action.get("tower_id", ""))
		var cost := float(action.get("cost", 100))
		var dps_est := 25.0 / 0.8 if tower_id == "basic_tower" else 20.0 / 0.8 * 2.0
		var dps_per_gold := (dps_est / maxf(cost, 1.0)) * 120.0
		base["dps_per_gold"] = dps_per_gold
		total += dps_per_gold
		if tower_id == "basic_tower":
			# Cross-floor value of sphere targeting.
			base["cross_floor"] = 18.0
			total += 18.0
		if int(state.get("core_hp", 20)) <= 8:
			base["lives_pressure"] = 20.0
			total += 20.0
		total += float(base["wave_forecast"])
	elif t == "UPGRADE_TOWER":
		base["dps_per_gold"] = 22.0
		total += 22.0
	elif t == "START_WAVE":
		if state.get("towers", []).size() == 0:
			base["economy"] = -40.0
			total -= 40.0
		else:
			base["economy"] = 5.0
			total += 5.0
	elif t == "WAIT":
		total += float(base["wave_forecast"]) * -0.2

	base["total"] = total
	return base


func _wave_threat(wave_number: int) -> float:
	var w := WaveCatalogScript.get_wave(wave_number)
	if w.is_empty():
		return 0.0
	var threat := 0.0
	for g in w.get("groups", []):
		threat += float(g.get("count", 0)) * float(g.get("absolute_health", 100.0)) * 0.01
	return threat
