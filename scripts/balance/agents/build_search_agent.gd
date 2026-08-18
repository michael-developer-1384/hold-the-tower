extends "res://scripts/sim/agents/game_agent.gd"

## Bounded beam over legal SimActions. Competent = heuristic; optimizer = lookahead.

const BasicAgentScript := preload("res://scripts/sim/agents/basic_agent.gd")
const ScoreUtil := preload("res://scripts/sim/agents/score_util.gd")

var role: String = "COMPETENT"
var beam_width: int = 2
var use_lookahead: bool = false
var max_lookahead_candidates: int = 4
var lookahead_horizon: float = 3.0
var _basic


func _init(p_role: String = "COMPETENT") -> void:
	role = p_role
	id = "build_search_competent" if p_role == "COMPETENT" else "build_search_optimizer"
	temperature = 0.0
	if p_role == "OPTIMIZER":
		beam_width = 4
		use_lookahead = true
		max_lookahead_candidates = 4
	else:
		beam_width = 2
		use_lookahead = false
	_basic = BasicAgentScript.new(0.0)
	_basic.include_behavioral = p_role == "COMPETENT"
	_basic.id = id + "_heuristic"


func explicit_biases() -> Dictionary:
	return _basic.explicit_biases() if _basic else {}


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	var sim = ctx.get("simulation", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var scored: Array = []
	for a in actions:
		if not _is_legal(a, ctx):
			continue
		var s: Dictionary = score_action(a, ctx)
		scored.append({"action": a, "score": float(s.get("total", 0.0)), "breakdown": s})
	if scored.is_empty():
		return {"type": "WAIT"}
	scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var width := mini(beam_width, scored.size())
	if use_lookahead and sim != null and sim.has_method("evaluate_action_with_lookahead"):
		var n := 0
		for i in width:
			var item: Dictionary = scored[i]
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
		scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return pick_scored(scored, rng)


func score_action(action: Dictionary, ctx: Dictionary) -> Dictionary:
	return _basic.score_action(action, ctx)


func _is_legal(action: Dictionary, ctx: Dictionary) -> bool:
	var t := str(action.get("type", ""))
	if t == "WAIT" or t == "START_WAVE":
		return true
	var state: Dictionary = ctx.get("state", {})
	if t == "PLACE_TOWER":
		var sid := str(action.get("spot_id", ""))
		if sid.is_empty():
			return false
		var gold := int(state.get("gold", 0))
		var cost := int(action.get("cost", 0))
		if cost > 0 and gold < cost:
			return false
		for spot in state.get("free_spots", []):
			if str(spot.get("spot_id")) == sid:
				return true
		return false
	if t == "UPGRADE_TOWER":
		return str(action.get("runtime_id", "")) != ""
	return true
