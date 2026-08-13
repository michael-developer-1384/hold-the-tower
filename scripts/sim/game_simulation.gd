class_name GameSimulation
extends RefCounted

## Headless host around the live gameplay graph (sim_host.tscn).

const HOST_SCENE := "res://scenes/sim/sim_host.tscn"
const SimClockScript := preload("res://scripts/sim/sim_clock.gd")
const SeededRngScript := preload("res://scripts/sim/seeded_rng.gd")
const SimActionsScript := preload("res://scripts/sim/sim_actions.gd")
const SimMetricsScript := preload("res://scripts/sim/sim_metrics.gd")
const PathCoverageCalc := preload("res://scripts/level/path_coverage_calculator.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")

var tree: SceneTree
var root: Node3D
var game: Node
var build_manager: Node
var wave_manager: Node
var telemetry: Node
var clock
var rng
var agent = null
var result: Dictionary = {}
var action_log: Array = []
var agent_metrics: Dictionary = {}
var config: Dictionary = {}
var level_id: String = "vertical_test"
var difficulty_id: String = "normal"
var run_seed: int = 0
var _wall_start_ms: int = 0
var _decision_interval: float = 0.5
var _next_decision_at: float = 0.0
var _last_leak_flag: bool = false
var _finished: bool = false
var _max_sim_seconds: float = 60.0 * 30.0


static func create(opts: Dictionary, scene_tree: SceneTree):
	## Prefer: preload(...).new(); sim.setup(...) — static new() is unreliable via class_name cache.
	var script := load("res://scripts/sim/game_simulation.gd") as GDScript
	var sim = script.new()
	sim.setup(opts, scene_tree)
	return sim


func setup(opts: Dictionary, scene_tree: SceneTree) -> void:
	tree = scene_tree
	level_id = str(opts.get("level_id", "vertical_test"))
	difficulty_id = str(opts.get("difficulty_id", "normal"))
	run_seed = int(opts.get("seed", 1))
	config = opts.get("config", {}).duplicate(true) if typeof(opts.get("config", {})) == TYPE_DICTIONARY else {}
	_decision_interval = float(opts.get("decision_interval", 0.5))
	_max_sim_seconds = float(opts.get("max_sim_seconds", 60.0 * 30.0))

	SimContextScript.begin(run_seed, config)
	clock = SimClockScript.new()
	clock.reset()
	rng = SeededRngScript.new(run_seed)
	SimContextScript.clock = clock
	SimContextScript.rng = rng

	AudioBridgeScript.set_suppressed(true)
	AudioBridgeScript.stop_all()

	if typeof(RunManager) != TYPE_NIL:
		RunManager.configure(level_id, difficulty_id)
		# Default sim loadout: zero research (base catalog stats).
		if bool(opts.get("use_profile_research", false)):
			RunManager.call("_snapshot_research")
		else:
			RunManager.research_snapshot.clear()
			RunManager.research_allocation_snapshot.clear()
			RunManager.active_blueprints.clear()
			RunManager.active_blueprint_names.clear()
			for tid in ["basic_tower", "guard_post"]:
				RunManager.research_allocation_snapshot[tid] = {}
				RunManager.research_snapshot[tid] = {}
				RunManager.active_blueprints[tid] = "research"
				RunManager.active_blueprint_names[tid] = "Research"

	var packed: PackedScene = load(HOST_SCENE)
	root = packed.instantiate() as Node3D
	# Avoid recursive add if somehow already parented.
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	tree.root.add_child(root)
	tree.current_scene = root

	game = root.get_node_or_null("GameManager")
	build_manager = root.get_node_or_null("BuildManager")
	wave_manager = root.get_node_or_null("WaveManager")
	telemetry = root.get_node_or_null("TelemetryManager")

	# Wait one idle frame so GameManager._ready finishes (it awaits process_frame).
	# Caller must pump frames after create before stepping combat.

	agent_metrics = {
		"actions_considered": 0,
		"actions_chosen": 0,
		"action_types": {},
		"score_sum": 0.0,
		"score_count": 0,
		"decisions": [],
	}
	action_log.clear()
	result.clear()
	_finished = false
	_next_decision_at = 0.0
	_wall_start_ms = Time.get_ticks_msec()


func set_agent(p_agent) -> void:
	agent = p_agent


func await_ready() -> void:
	# GameManager awaits one process_frame in _ready.
	await tree.process_frame
	await tree.process_frame


func is_finished() -> bool:
	if _finished:
		return true
	if game == null:
		return true
	return bool(game.get("game_over")) or bool(game.get("level_complete"))


func state() -> Dictionary:
	return SimActionsScript.read_state(game)


func execute(action: Dictionary) -> bool:
	var ok := SimActionsScript.execute(game, action)
	if ok and str(action.get("type", "")) != SimActionsScript.TYPE_WAIT:
		action_log.append({
			"time": clock.sim_time,
			"action": action.duplicate(true),
		})
	return ok


func get_available_actions() -> Array:
	return SimActionsScript.get_available_actions(game)


func step() -> void:
	if is_finished():
		_ensure_result()
		return
	_maybe_decide()
	# Advance one physics tick worth of simulated time tracking.
	clock.step(SimClockScript.STEP)
	# Drive the scene: one physics + process frame as fast as the tree allows.
	# Using time_scale externally; here we just await physics when used from async host.


func run_ticks(count: int) -> void:
	for _i in count:
		if is_finished():
			break
		_maybe_decide()
		clock.step(SimClockScript.STEP)


func run_until(sim_time: float) -> void:
	while clock.sim_time < sim_time and not is_finished():
		_maybe_decide()
		clock.step(SimClockScript.STEP)


func _maybe_decide() -> void:
	if agent == null or game == null:
		return
	if clock.sim_time + 0.0001 < _next_decision_at:
		# Still allow decisions on leak / gold thresholds via agent hooks.
		pass
	var force := false
	var leaks_now := 0
	if telemetry != null:
		leaks_now = int(telemetry.get("enemies_leaked")) if "enemies_leaked" in telemetry else 0
	if leaks_now > 0 and not _last_leak_flag:
		force = true
		_last_leak_flag = true
	elif leaks_now == 0:
		_last_leak_flag = false

	if not force and clock.sim_time + 0.0001 < _next_decision_at:
		return

	var actions := get_available_actions()
	agent_metrics["actions_considered"] = int(agent_metrics["actions_considered"]) + actions.size()
	var ctx := {
		"state": state(),
		"actions": actions,
		"sim_time": clock.sim_time,
		"rng": rng,
		"path_meta": _path_meta(),
		"game": game,
		"simulation": self,
	}
	var decision = agent.decide(ctx)
	var action: Dictionary = {}
	var score := 0.0
	var breakdown: Dictionary = {}
	if typeof(decision) == TYPE_DICTIONARY:
		if decision.has("action"):
			action = decision.get("action", {})
			score = float(decision.get("score", 0.0))
			breakdown = decision.get("breakdown", {})
		else:
			action = decision
	if action.is_empty():
		action = {"type": SimActionsScript.TYPE_WAIT}
	execute(action)
	agent_metrics["actions_chosen"] = int(agent_metrics["actions_chosen"]) + 1
	var atype := str(action.get("type", "WAIT"))
	var hist: Dictionary = agent_metrics["action_types"]
	hist[atype] = int(hist.get(atype, 0)) + 1
	agent_metrics["score_sum"] = float(agent_metrics["score_sum"]) + score
	agent_metrics["score_count"] = int(agent_metrics["score_count"]) + 1
	if not breakdown.is_empty() and (agent_metrics["decisions"] as Array).size() < 64:
		(agent_metrics["decisions"] as Array).append({
			"time": clock.sim_time,
			"action": action.duplicate(true),
			"score": score,
			"breakdown": breakdown.duplicate(true),
		})
	_next_decision_at = clock.sim_time + _decision_interval


func _path_meta() -> Dictionary:
	var tl = game.get("tower_level") if game else null
	if tl != null and tl.has_method("get_path_meta"):
		return tl.call("get_path_meta")
	return {}


func coverage_for_spot(spot_pos: Vector3, range_value: float, shape: String, floor_id: String) -> float:
	var meta := _path_meta()
	var cov := PathCoverageCalc.compute_for_tower(
		spot_pos,
		range_value,
		shape,
		floor_id,
		meta.get("path", PackedVector3Array()),
		meta.get("segment_floors", PackedStringArray())
	)
	var total := 0.0
	for v in cov.get("coverage_by_floor", {}).values():
		total += float(v)
	return total


func clone() -> Dictionary:
	## Lightweight lookahead snapshot (session-shaped + sim extras). Incomplete for bit-exact restore.
	var SessionStoreScript = preload("res://scripts/run/session_store.gd")
	var snap := SessionStoreScript.capture_from_game(game, true)
	snap["sim_time"] = clock.sim_time
	snap["action_log"] = action_log.duplicate(true)
	return snap


func evaluate_action_with_lookahead(action: Dictionary, horizon_seconds: float = 2.5) -> float:
	## V1: heuristic score only — clone/restore not yet bit-complete for live combat.
	## Smart agent uses this hook; returns score from agent.score_action when available.
	if agent != null and agent.has_method("score_action"):
		var scored = agent.score_action(action, {
			"state": state(),
			"actions": get_available_actions(),
			"sim_time": clock.sim_time,
			"rng": rng,
			"path_meta": _path_meta(),
			"game": game,
			"simulation": self,
			"horizon": horizon_seconds,
		})
		if typeof(scored) == TYPE_DICTIONARY:
			return float(scored.get("total", 0.0))
		return float(scored)
	return 0.0


func _ensure_result() -> void:
	if not result.is_empty():
		return
	var wall := maxi(Time.get_ticks_msec() - _wall_start_ms, 1)
	result = SimMetricsScript.build_result(self, wall)


func finish() -> Dictionary:
	_finished = true
	_ensure_result()
	return result


func cleanup() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	game = null
	SimContextScript.end()
	AudioBridgeScript.set_suppressed(false)
