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
	sim.set_agent(agent)
	await sim.await_ready()

	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 64
	var speed := float(opts.get("time_scale", 40.0))
	Engine.time_scale = speed
	# Physics delta is (1/60)*time_scale; keep SimClock on the same game-time axis.
	var clock_dt := (1.0 / 60.0) * speed

	var safety_frames := int(opts.get("max_frames", 200000))
	var frames := 0
	while not sim.is_finished() and frames < safety_frames:
		sim._maybe_decide()
		await tree.physics_frame
		if sim.clock:
			sim.clock.step(clock_dt)
		frames += 1
		if sim.clock and sim.clock.sim_time > float(opts.get("max_sim_seconds", 1800.0)):
			break

	Engine.time_scale = 1.0
	var result: Dictionary = sim.finish()
	result["agent_id"] = agent_id
	result["frames"] = frames
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
