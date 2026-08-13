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
	var Profile = load("res://scripts/sim/agents/player_profile.gd")
	var resolved: Dictionary = Profile.resolve(opts)
	opts["player_profile"] = str(resolved.get("player_profile", "optimizer"))
	opts["temperature"] = float(resolved.get("temperature", 0.0))
	var sim = load("res://scripts/sim/game_simulation.gd").new()
	sim.setup(opts, tree)
	var agent_id := str(opts.get("agent_id", "basic"))
	var temp := float(resolved.get("temperature", 0.0))
	var agent = make_agent(agent_id, temp)
	if agent == null:
		push_error("BatchRunner: failed to create agent '%s'" % agent_id)
		sim.cleanup()
		return {"won": false, "error": "agent_load_failed", "agent_id": agent_id, "seed": int(opts.get("seed", 0))}
	Profile.apply_to_agent(agent, resolved)
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
	result["player_profile"] = str(resolved.get("player_profile", "optimizer"))
	result["temperature"] = temp
	result["frames"] = frames
	if agent != null and agent.has_method("explicit_biases"):
		var am: Dictionary = result.get("agent_metrics", {})
		am["explicit_biases"] = agent.explicit_biases()
		result["agent_metrics"] = am
	var ReplayPackage = load("res://scripts/sim/replay/replay_package.gd")
	var mode: String = ReplayPackage.normalize_mode(str(opts.get("record", ReplayPackage.MODE_NONE)))
	if mode != ReplayPackage.MODE_NONE:
		var pkg: Dictionary = ReplayPackage.build(sim, opts, result)
		var path: String = load("res://scripts/sim/replay/replay_store.gd").save(pkg)
		result["replay_id"] = str(pkg.get("run_id", ""))
		result["replay_path"] = path
		result["replay_storage"] = pkg.get("storage", {})
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
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var agg: Dictionary = metrics.aggregate(results, agent_id)
	agg["level_id"] = str(opts.get("level_id", "vertical_test"))
	agg["difficulty"] = str(opts.get("difficulty_id", "normal"))
	agg["player_profile"] = str(opts.get("player_profile", opts.get("profile", "optimizer")))
	var div: Dictionary = Diversity.summarize(results)
	agg["diversity"] = div
	var report: String = metrics.format_report(agg)
	report += "\n" + Diversity.format_report(div, results.size())
	return {"aggregate": agg, "results": results, "diversity": div, "report": report}
