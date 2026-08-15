extends "res://scripts/sim/agents/game_agent.gd"

## Random spend baseline.
## While PLACE / UPGRADE is affordable, pick uniformly among those only.
## START_WAVE only when nothing is affordable (so runs still finish).
## WAIT is never chosen while a spend or start is legal.


func _init(p_temperature: float = 0.0) -> void:
	id = "random"
	temperature = p_temperature


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var rng = ctx.get("rng", null)
	if actions.is_empty():
		return {"type": "WAIT"}

	var spend: Array = []
	var start_wave: Array = []
	for a in actions:
		var t := str(a.get("type", ""))
		match t:
			"PLACE_TOWER", "UPGRADE_TOWER":
				spend.append(a)
			"START_WAVE":
				start_wave.append(a)

	var pool: Array = spend
	if pool.is_empty():
		pool = start_wave
	if pool.is_empty():
		return {"action": {"type": "WAIT"}, "score": 0.0, "breakdown": {"random": 1.0, "reason": "idle"}}

	var action: Dictionary
	if rng == null:
		action = pool[0]
	else:
		action = rng.pick(pool)
	return {
		"action": action,
		"score": 0.0,
		"breakdown": {
			"random": 1.0,
			"pool": "spend" if not spend.is_empty() else "start_wave",
			"options": pool.size(),
		},
	}
