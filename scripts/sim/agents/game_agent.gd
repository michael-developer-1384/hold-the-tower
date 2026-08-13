extends RefCounted

## Base agent. decide() returns action dict or {action, score, breakdown}.

var id: String = "base"
var temperature: float = 0.0 # 0 = always best; higher = noisier
var decision_noise: float = 0.0 # legacy alias for soft random among top


func decide(_ctx: Dictionary) -> Dictionary:
	return {"type": "WAIT"}


func score_action(_action: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {"total": 0.0}


func pick_scored(scored: Array, rng) -> Dictionary:
	## scored: [{action, score, breakdown}, ...]
	if scored.is_empty():
		return {"type": "WAIT"}
	scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var temp: float = temperature
	if temp <= 0.0 and decision_noise <= 0.0:
		return scored[0]
	# Softmax over top-K or 90/7/3 style with temperature.
	if temp <= 0.0:
		var roll: float = float(rng.randf())
		if roll < 0.90:
			return scored[0]
		if roll < 0.97 and scored.size() > 1:
			return scored[1]
		return rng.pick(scored)
	var weights: Array = []
	var sum: float = 0.0
	for item in scored:
		var w: float = exp(float(item.get("score", 0.0)) / maxf(temp, 0.01))
		weights.append(w)
		sum += w
	var r: float = float(rng.randf()) * sum
	var acc: float = 0.0
	for i in scored.size():
		acc += float(weights[i])
		if r <= acc:
			return scored[i]
	return scored[0]


static func profile_temperature(profile: String) -> float:
	match profile:
		"beginner":
			return 2.5
		"casual":
			return 1.2
		"competent":
			return 0.4
		"expert":
			return 0.1
		"optimizer":
			return 0.0
		_:
			return 0.0
