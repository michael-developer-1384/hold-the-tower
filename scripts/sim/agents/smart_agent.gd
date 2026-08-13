extends "res://scripts/sim/agents/game_agent.gd"

## Optimizer path: mechanical utility + true clone lookahead. No tower-id bonuses.

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const BasicAgentScript := preload("res://scripts/sim/agents/basic_agent.gd")
const ScoreUtil := preload("res://scripts/sim/agents/score_util.gd")

var use_lookahead: bool = true
var lookahead_horizon: float = 3.0
var max_lookahead_candidates: int = 6
var _basic


func _init(p_temperature: float = 0.0) -> void:
	id = "smart"
	temperature = p_temperature
	_basic = BasicAgentScript.new(0.0)
	_basic.include_behavioral = false
	_basic.id = "smart_mechanical"


func explicit_biases() -> Dictionary:
	return {}


func has_explicit_bias_for(_tower_id: String) -> bool:
	return false


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	var sim = ctx.get("simulation", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var scored: Array = []
	for a in actions:
		var s: Dictionary = score_action(a, ctx)
		scored.append({"action": a, "score": float(s.get("total", 0.0)), "breakdown": s})
	if use_lookahead and sim != null and sim.has_method("evaluate_action_with_lookahead"):
		scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
		var n := 0
		for item in scored:
			var a: Dictionary = item.get("action", {})
			if str(a.get("type", "")) == "WAIT":
				continue
			if n >= max_lookahead_candidates:
				break
			var look: float = await sim.evaluate_action_with_lookahead(a, lookahead_horizon)
			var bd: Dictionary = item.get("breakdown", {})
			bd["lookahead"] = ScoreUtil.part(look, ScoreUtil.TYPE_LOOK)
			item["breakdown"] = ScoreUtil.finalize(bd)
			item["score"] = float(item["breakdown"].get("total", 0.0))
			n += 1
	return pick_scored(scored, rng)


func score_action(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var base: Dictionary = _basic.score_action(action, ctx)
	var state: Dictionary = ctx.get("state", {})
	var t := str(action.get("type", ""))
	var wave := int(state.get("current_wave", 1))
	var forecast := _wave_threat(wave)
	base["wave_forecast"] = ScoreUtil.part(forecast * 0.1, ScoreUtil.TYPE_KNOWN)
	if t == "PLACE_TOWER":
		if ScoreUtil.has_feature(action, "3d_targeting"):
			base["cross_floor_coverage"] = ScoreUtil.part(12.0, ScoreUtil.TYPE_MECH)
		if int(state.get("core_hp", 20)) <= 8:
			base["lives_pressure"] = ScoreUtil.part(20.0, ScoreUtil.TYPE_MECH)
	elif t == "START_WAVE":
		if state.get("towers", []).size() == 0:
			base["economy"] = ScoreUtil.part(-40.0, ScoreUtil.TYPE_MECH)
		else:
			base["economy"] = ScoreUtil.part(5.0, ScoreUtil.TYPE_MECH)
	return ScoreUtil.finalize(base)


func _wave_threat(wave_number: int) -> float:
	var w := WaveCatalogScript.get_wave(wave_number)
	if w.is_empty():
		return 0.0
	var threat := 0.0
	for g in w.get("groups", []):
		threat += float(g.get("count", 0)) * float(g.get("absolute_health", 100.0)) * 0.01
	return threat
