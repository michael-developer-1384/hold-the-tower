extends "res://scripts/sim/agents/game_agent.gd"

## Uniform random among legal actions (baseline).
## WAIT is legal, but when START_WAVE is the only progress action available
## (no affordable place/upgrade), prefer it so runs can finish.


func _init(p_temperature: float = 0.0) -> void:
	id = "random"
	temperature = p_temperature


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	if actions.is_empty():
		return {"type": "WAIT"}
	var progressive: Array = []
	for a in actions:
		var t := str(a.get("type", ""))
		if t != "WAIT":
			progressive.append(a)
	var pool: Array = actions
	# Avoid endless WAIT loops between waves when nothing else is affordable.
	if progressive.size() == 1 and str(progressive[0].get("type")) == "START_WAVE":
		pool = progressive
	elif progressive.size() > 0 and rng != null and rng.randf() < 0.85:
		pool = progressive
	if rng == null:
		return {"action": pool[0], "score": 0.0, "breakdown": {"random": 1.0}}
	var action: Dictionary = rng.pick(pool)
	return {"action": action, "score": 0.0, "breakdown": {"random": 1.0}}
