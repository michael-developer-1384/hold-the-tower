extends RefCounted

## Base agent. decide() returns action dict or {action, score, breakdown}.

var id: String = "base"
var player_profile: String = "optimizer"
var temperature: float = 0.0 # 0 = always best; relative-softmax scale otherwise
var consider_band: float = 0.0 # options worse than best by more than this get weight 0
var decision_noise: float = 0.0 # legacy alias for soft random among top


func decide(_ctx: Dictionary) -> Dictionary:
	return {"type": "WAIT"}


func score_action(_action: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {"total": 0.0}


func explicit_biases() -> Dictionary:
	return {}


func has_explicit_bias_for(_tower_id: String) -> bool:
	return false


func pick_scored(scored: Array, rng) -> Dictionary:
	## scored: [{action, score, breakdown}, ...]
	if scored.is_empty():
		return {"type": "WAIT"}
	scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var temp: float = temperature
	var chosen: Dictionary = scored[0]
	if temp <= 0.0 and decision_noise <= 0.0:
		return _with_considered(chosen, scored)
	# Legacy 90/7/3 only when T=0 and decision_noise > 0.
	if temp <= 0.0:
		var roll: float = float(rng.randf()) if rng != null else 0.0
		if roll < 0.90:
			chosen = scored[0]
		elif roll < 0.97 and scored.size() > 1:
			chosen = scored[1]
		elif rng != null:
			chosen = rng.pick(scored)
		return _with_considered(chosen, scored)
	var best: float = float(scored[0].get("score", 0.0))
	var band: float = consider_band
	if band <= 0.0:
		band = 1.0e9
	var weights: Array = []
	var sum: float = 0.0
	for item in scored:
		var rel: float = float(item.get("score", 0.0)) - best
		var w: float = 0.0
		if rel + band >= -0.0001:
			w = exp(rel / maxf(temp, 0.01))
		weights.append(w)
		sum += w
	if sum <= 0.0:
		return _with_considered(scored[0], scored)
	var r: float = (float(rng.randf()) if rng != null else 0.0) * sum
	var acc: float = 0.0
	for i in scored.size():
		acc += float(weights[i])
		if r <= acc:
			return _with_considered(scored[i], scored)
	return _with_considered(scored[0], scored)


func _with_considered(chosen: Dictionary, scored: Array) -> Dictionary:
	var out: Dictionary = chosen.duplicate(true)
	out["considered"] = scored
	out["quality"] = quality_of(chosen, scored)
	return out


static func quality_of(chosen: Dictionary, scored: Array) -> Dictionary:
	if scored.is_empty():
		return {
			"best_score": 0.0,
			"chosen_score": 0.0,
			"score_gap": 0.0,
			"chosen_rank": 1,
			"option_count": 0,
		}
	var ordered: Array = scored.duplicate()
	ordered.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var best_s: float = float(ordered[0].get("score", 0.0))
	var chosen_s: float = float(chosen.get("score", 0.0))
	var rank: int = 1
	for i in ordered.size():
		if _same_action(ordered[i].get("action", ordered[i]), chosen.get("action", chosen)):
			rank = i + 1
			chosen_s = float(ordered[i].get("score", chosen_s))
			break
	return {
		"best_score": best_s,
		"chosen_score": chosen_s,
		"score_gap": best_s - chosen_s,
		"chosen_rank": rank,
		"option_count": ordered.size(),
		"best_action": ordered[0].get("action", {}),
	}


static func _same_action(a, b) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return false
	if str(a.get("type", "")) != str(b.get("type", "")):
		return false
	if str(a.get("spot_id", "")) != str(b.get("spot_id", "")):
		return false
	if str(a.get("tower_type", a.get("tower_id", ""))) != str(b.get("tower_type", b.get("tower_id", ""))):
		return false
	if str(a.get("runtime_id", "")) != str(b.get("runtime_id", "")):
		return false
	return true


static func profile_temperature(profile: String) -> float:
	var Profile = load("res://scripts/sim/agents/player_profile.gd")
	return float(Profile.temperature_of(profile))
