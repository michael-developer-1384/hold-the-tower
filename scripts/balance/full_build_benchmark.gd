extends RefCounted

## Replay a frozen action log. Source is tagged; no live agent during the measured run.

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
	var log: Array = result.get("action_log", [])
	sim.cleanup()
	await tree.process_frame
	return {"action_log": log, "seed": int(opts.get("seed", 7)), "result": result}


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var source := str(opts.get("source", "FIXTURE"))
	if log.is_empty() and str(opts.get("fixture_id", "scripted")) == "scripted":
		var rec: Dictionary = await record_scripted(tree, opts)
		log = rec.get("action_log", [])
		source = "FIXTURE"
	var replay_opts := opts.duplicate(true)
	replay_opts["action_log"] = log
	var result: Dictionary = await CF.replay(tree, replay_opts)
	return compact(result, {
		"fixture_id": str(opts.get("fixture_id", "scripted")),
		"role": str(opts.get("role", "COMPETENT")),
		"source": source,
		"seed": int(opts.get("seed", 7)),
	})


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
		"outcome": _outcome(result),
	}


static func _outcome(result: Dictionary) -> String:
	if not bool(result.get("won", false)):
		return "LOSS"
	if int(result.get("enemies_leaked", 0)) > 0:
		return "WIN_WITH_LEAKS"
	return "WIN_CLEAN"
