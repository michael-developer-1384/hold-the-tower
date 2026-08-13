extends RefCounted

static func make_agent(agent_id: String, temperature: float = 0.0):
	# Load base first so path-extends resolve under --script (no class_name cache).
	load("res://scripts/sim/agents/game_agent.gd")
	match agent_id:
		"random":
			return load("res://scripts/sim/agents/random_agent.gd").new(temperature)
		"basic":
			return load("res://scripts/sim/agents/basic_agent.gd").new(temperature)
		"smart":
			return load("res://scripts/sim/agents/smart_agent.gd").new(temperature)
		_:
			return load("res://scripts/sim/agents/basic_agent.gd").new(temperature)


static func run_one(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup(opts, tree)
	var agent_id := str(opts.get("agent_id", "basic"))
	var temp := float(opts.get("temperature", 0.0))
	var agent = make_agent(agent_id, temp)
	if agent == null:
		push_error("BatchRunner: failed to create agent '%s'" % agent_id)
		sim.cleanup()
		return {"won": false, "error": "agent_load_failed", "agent_id": agent_id, "seed": int(opts.get("seed", 0))}
	if "use_lookahead" in agent:
		agent.use_lookahead = bool(opts.get("lookahead", false))
	sim.set_agent(agent)
	await sim.await_ready()

	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	if not opts.has("time_scale"):
		opts["time_scale"] = SimRunnerScript.DEFAULT_SPEED
	var frames: int = await SimRunnerScript.run_until_finished(tree, sim, opts)
	var result: Dictionary = sim.finish()
	result["agent_id"] = agent_id
	result["frames"] = frames
	if agent != null and agent.has_method("explicit_biases"):
		var am: Dictionary = result.get("agent_metrics", {})
		am["explicit_biases"] = agent.explicit_biases()
		result["agent_metrics"] = am
	sim.cleanup()
	await tree.process_frame
	return result


static func run_batch(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var runs := int(opts.get("runs", 10))
	var base_seed := int(opts.get("seed", 1))
	var agent_id := str(opts.get("agent_id", "basic"))
	var results: Array = []
	for i in runs:
		var one := opts.duplicate(true)
		one["seed"] = base_seed + i
		one["agent_id"] = agent_id
		var r: Dictionary = await run_one(tree, one)
		results.append(r)
		print("Run %d/%d seed=%d won=%s waves=%s lives=%s speed=%.0fx" % [
			i + 1, runs, int(r.get("seed", 0)), str(r.get("won")), str(r.get("waves_reached")),
			str(r.get("lives_remaining")), float(r.get("sim_speed", 0.0))
		])
	var metrics = load("res://scripts/sim/sim_metrics.gd")
	var agg: Dictionary = metrics.aggregate(results, agent_id)
	agg["level_id"] = str(opts.get("level_id", "vertical_test"))
	agg["difficulty"] = str(opts.get("difficulty_id", "normal"))
	return {"aggregate": agg, "results": results, "report": metrics.format_report(agg)}
