extends "res://scripts/sim/agents/game_agent.gd"

## Places exactly one tower at a spot before a given wave, then starts remaining waves.

var tower_id: String = "basic_tower"
var spot_id: String = "F1_C"
var build_wave: int = 1
var start_waves: bool = true
var placed: bool = false


func _init() -> void:
	id = "isolated"
	temperature = 0.0


func decide(ctx: Dictionary) -> Dictionary:
	var actions: Array = ctx.get("actions", [])
	var state: Dictionary = ctx.get("state", {})
	if bool(state.get("game_over")) or bool(state.get("level_complete")):
		return {"type": "WAIT"}
	var started := int(state.get("waves_started", 0))
	if not placed:
		if started < build_wave - 1:
			return _start_or_wait(actions, state)
		var place := _find_place(actions)
		if not place.is_empty():
			placed = true
			return place
		if started < build_wave - 1:
			return _start_or_wait(actions, state)
	if start_waves:
		return _start_or_wait(actions, state)
	return {"type": "WAIT"}


func _find_place(actions: Array) -> Dictionary:
	for a in actions:
		if str(a.get("type", "")) != "PLACE_TOWER":
			continue
		if str(a.get("tower_id", "")) != tower_id:
			continue
		if str(a.get("spot_id", "")) != spot_id:
			continue
		return a
	return {}


func _start_or_wait(actions: Array, state: Dictionary) -> Dictionary:
	if bool(state.get("can_start_wave", false)):
		for a in actions:
			if str(a.get("type", "")) == "START_WAVE":
				return a
	return {"type": "WAIT"}
