extends RefCounted

## Record and measure competent / optimizer full builds. Fixture remains for fidelity.

const CF := preload("res://scripts/balance/counterfactual_runner.gd")
const Policy := preload("res://scripts/sim/fidelity/scripted_policy.gd")

const ROLES := ["BEGINNER", "CASUAL", "COMPETENT", "EXPERT", "OPTIMIZER", "PLAYER_REPLAY"]


static func record_scripted(tree: SceneTree, opts: Dictionary = {}) -> Dictionary:
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup({
		"level_id": str(opts.get("level_id", "vertical_test")),
		"difficulty_id": str(opts.get("difficulty_id", "normal")),
		"seed": int(opts.get("seed", 7)),
		"config": opts.get("config", {"starting_gold": 1000}),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 180.0)),
		"record": "none",
	}, tree)
	await sim.await_ready()
	for action in Policy.opening_actions():
		sim.execute(action)
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(tree, sim, {
		"time_scale": float(opts.get("time_scale", 40.0)),
		"decide": false,
		"max_sim_seconds": float(opts.get("max_sim_seconds", 180.0)),
	})
	var result: Dictionary = sim.finish()
	var replay_log: Array = result.get("action_log", [])
	sim.cleanup()
	await tree.process_frame
	return {"action_log": replay_log, "seed": int(opts.get("seed", 7)), "result": result}


static func record_agent(tree: SceneTree, opts: Dictionary = {}) -> Dictionary:
	var role := str(opts.get("role", "COMPETENT"))
	var AgentScript = load("res://scripts/balance/agents/build_search_agent.gd")
	var agent = AgentScript.new(role)
	if opts.has("lookahead"):
		agent.use_lookahead = bool(opts.get("lookahead"))
		if agent.use_lookahead:
			agent.max_lookahead_candidates = 2
			agent.lookahead_horizon = 2.0
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup({
		"level_id": str(opts.get("level_id", "vertical_test")),
		"difficulty_id": str(opts.get("difficulty_id", "normal")),
		"seed": int(opts.get("seed", 7)),
		"config": opts.get("config", {"starting_gold": 1000}),
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
		"record": "none",
	}, tree)
	sim.set_agent(agent)
	await sim.await_ready()
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_until_finished(tree, sim, {
		"time_scale": float(opts.get("time_scale", 40.0)),
		"decide": true,
		"max_sim_seconds": float(opts.get("max_sim_seconds", 240.0)),
	})
	var result: Dictionary = sim.finish()
	var replay_log: Array = result.get("action_log", [])
	var legal := _all_places_legal(replay_log)
	sim.cleanup()
	await tree.process_frame
	return {
		"action_log": replay_log,
		"seed": int(opts.get("seed", 7)),
		"result": result,
		"legal_actions": legal,
		"role": role,
		"source": "AGENT_SEARCH",
	}


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var source := str(opts.get("source", "FIXTURE"))
	if log_empty(replay_log) and str(opts.get("fixture_id", "")) == "scripted":
		var rec: Dictionary = await record_scripted(tree, opts)
		replay_log = rec.get("action_log", [])
		source = "FIXTURE"
	var replay_opts := opts.duplicate(true)
	replay_opts["action_log"] = replay_log
	var result: Dictionary = await CF.replay(tree, replay_opts)
	return compact(result, {
		"fixture_id": str(opts.get("fixture_id", "")),
		"role": str(opts.get("role", "COMPETENT")),
		"source": source,
		"seed": int(opts.get("seed", 7)),
		"action_log": replay_log,
		"legal_actions": bool(opts.get("legal_actions", true)),
	})


static func log_empty(replay_log: Array) -> bool:
	return replay_log.is_empty()


static func compact(result: Dictionary, meta: Dictionary) -> Dictionary:
	return {
		"fixture_id": str(meta.get("fixture_id", "")),
		"role": str(meta.get("role", "")),
		"source": str(meta.get("source", "FIXTURE")),
		"seed": int(meta.get("seed", 0)),
		"won": bool(result.get("won", false)),
		"leaks": int(result.get("enemies_leaked", 0)),
		"core_hp": int(result.get("lives_remaining", 0)),
		"duration": float(result.get("duration", 0.0)),
		"total_damage": float(result.get("total_damage", 0.0)),
		"enemies_killed": int(result.get("enemies_killed", 0)),
		"outcome": outcome_of(result),
		"legal_actions": bool(meta.get("legal_actions", true)),
		"towers_placed": int(result.get("towers_placed", 0)),
	}


static func outcome_of(result: Dictionary) -> String:
	if not bool(result.get("won", false)):
		return "LOSS"
	if int(result.get("enemies_leaked", 0)) > 0:
		return "WIN_WITH_LEAKS"
	return "WIN_CLEAN"


static func _outcome(result: Dictionary) -> String:
	return outcome_of(result)


static func _all_places_legal(replay_log: Array) -> bool:
	for entry in replay_log:
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		var t := str(action.get("type", ""))
		if t == "PLACE_TOWER":
			if str(action.get("tower_id", "")).is_empty() or str(action.get("spot_id", "")).is_empty():
				return false
	return true
