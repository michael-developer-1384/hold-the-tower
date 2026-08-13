extends RefCounted

## Fast-sim host: more 1/60 ticks per wall-second, never a fatter gameplay step.

const GAMEPLAY_HZ := 60
const STEP := 1.0 / 60.0
const DEFAULT_SPEED := 40.0

static var _stack: Array = []


static func capture_engine() -> Dictionary:
	return {
		"time_scale": Engine.time_scale,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"max_physics_steps_per_frame": Engine.max_physics_steps_per_frame,
		"max_fps": Engine.max_fps,
	}


static func apply_engine(state: Dictionary) -> void:
	Engine.time_scale = float(state.get("time_scale", 1.0))
	Engine.physics_ticks_per_second = int(state.get("physics_ticks_per_second", GAMEPLAY_HZ))
	Engine.max_physics_steps_per_frame = int(state.get("max_physics_steps_per_frame", 8))
	Engine.max_fps = int(state.get("max_fps", 0))


static func apply_speed(speed: float) -> void:
	_stack.append(capture_engine())
	var n: float = maxf(speed, 0.01)
	Engine.max_fps = 0
	Engine.time_scale = n
	Engine.physics_ticks_per_second = int(round(float(GAMEPLAY_HZ) * n))
	Engine.max_physics_steps_per_frame = maxi(64, int(ceil(n)) + 8)


static func restore() -> void:
	if _stack.is_empty():
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = GAMEPLAY_HZ
		Engine.max_physics_steps_per_frame = 8
		return
	apply_engine(_stack.pop_back())


static func clock_dt() -> float:
	return STEP


static func run_until_finished(tree: SceneTree, sim, opts: Dictionary) -> int:
	var manage := bool(opts.get("manage_speed", true))
	if manage:
		apply_speed(float(opts.get("time_scale", DEFAULT_SPEED)))
	var safety_frames := int(opts.get("max_frames", 400000))
	var frames := 0
	var max_sim := float(opts.get("max_sim_seconds", 1800.0))
	while not sim.is_finished() and frames < safety_frames:
		if sim.has_method("_maybe_decide"):
			await sim._maybe_decide()
		if sim.has_method("replay_due_actions"):
			sim.replay_due_actions()
		await tree.physics_frame
		if sim.clock:
			sim.clock.step(STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		frames += 1
		if sim.clock and sim.clock.sim_time > max_sim:
			break
	if manage:
		restore()
	return frames


static func run_for_seconds(tree: SceneTree, sim, seconds: float, opts: Dictionary = {}) -> int:
	var manage := bool(opts.get("manage_speed", true))
	if manage:
		apply_speed(float(opts.get("time_scale", DEFAULT_SPEED)))
	var target: float = float(sim.clock.sim_time) + seconds
	var frames := 0
	var safety := int(opts.get("max_frames", 400000))
	while not sim.is_finished() and sim.clock.sim_time + 0.0001 < target and frames < safety:
		if bool(opts.get("decide", true)) and sim.has_method("_maybe_decide"):
			await sim._maybe_decide()
		if sim.has_method("replay_due_actions"):
			sim.replay_due_actions()
		await tree.physics_frame
		if sim.clock:
			sim.clock.step(STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		frames += 1
	if manage:
		restore()
	return frames
