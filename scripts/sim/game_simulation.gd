class_name GameSimulation
extends RefCounted

## Headless host around the live gameplay graph (sim_host.tscn).

const HOST_SCENE := "res://scenes/sim/sim_host.tscn"
const WATCH_SCENE := "res://scenes/sim/sim_watch.tscn"
const SimClockScript := preload("res://scripts/sim/sim_clock.gd")
const SeededRngScript := preload("res://scripts/sim/seeded_rng.gd")
const SimActionsScript := preload("res://scripts/sim/sim_actions.gd")
const SimMetricsScript := preload("res://scripts/sim/sim_metrics.gd")
const PathCoverageCalc := preload("res://scripts/level/path_coverage_calculator.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")
const ReplayPackageScript := preload("res://scripts/sim/replay/replay_package.gd")
const KeyframeBufferScript := preload("res://scripts/sim/replay/keyframe_buffer.gd")

var tree: SceneTree
var root: Node3D
var game: Node
var build_manager: Node
var wave_manager: Node
var telemetry: Node
var clock
var rng
var world_rng
var decision_rng
var world_seed: int = 0
var decision_seed: int = 0
var player_profile: String = "optimizer"
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
var _is_clone: bool = false
var _replay_log: Array = []
var _replay_index: int = 0
var lookahead_stats: Dictionary = {
	"clone_ms_sum": 0.0,
	"eval_ms_sum": 0.0,
	"evals": 0,
	"future_seconds": 0.0,
	"last_example": {},
}
var record_mode: String = ReplayPackageScript.MODE_NONE
var setup_opts: Dictionary = {}
var initial_snapshot: Dictionary = {}
var event_log: Array = []
var keyframe_buffer = null
var _event_cursor: int = 0
var _next_decision_id: int = 1
var _using_existing_root: bool = false


static func create(opts: Dictionary, scene_tree: SceneTree):
	## Prefer: preload(...).new(); sim.setup(...) — static new() is unreliable via class_name cache.
	var script := load("res://scripts/sim/game_simulation.gd") as GDScript
	var sim = script.new()
	sim.setup(opts, scene_tree)
	return sim


func setup(opts: Dictionary, scene_tree: SceneTree) -> void:
	tree = scene_tree
	setup_opts = opts.duplicate(true)
	level_id = str(opts.get("level_id", "vertical_test"))
	difficulty_id = str(opts.get("difficulty_id", "normal"))
	run_seed = int(opts.get("seed", 1))
	config = opts.get("config", {}).duplicate(true) if typeof(opts.get("config", {})) == TYPE_DICTIONARY else {}
	_decision_interval = float(opts.get("decision_interval", 0.5))
	_max_sim_seconds = float(opts.get("max_sim_seconds", 60.0 * 30.0))

	_is_clone = bool(opts.get("clone", false))
	record_mode = ReplayPackageScript.MODE_NONE if _is_clone else ReplayPackageScript.normalize_mode(str(opts.get("record", ReplayPackageScript.MODE_NONE)))
	if _is_clone:
		SimContextScript.clone_active = true
	elif not SimContextScript.active:
		SimContextScript.begin(run_seed, config)
		if bool(opts.get("presentation", false)):
			SimContextScript.presentation = true
	elif bool(opts.get("presentation", false)):
		SimContextScript.presentation = true
	clock = SimClockScript.new()
	clock.reset()
	var Profile = load("res://scripts/sim/agents/player_profile.gd")
	world_seed = int(opts.get("world_seed", Profile.mix_seed(run_seed, "world")))
	decision_seed = int(opts.get("decision_seed", Profile.mix_seed(run_seed, "decision")))
	world_rng = SeededRngScript.new(world_seed)
	decision_rng = SeededRngScript.new(decision_seed)
	rng = world_rng
	player_profile = str(Profile.resolve(opts).get("player_profile", "optimizer"))
	if not _is_clone:
		SimContextScript.clock = clock
		SimContextScript.rng = world_rng

	var suppress_audio := not bool(opts.get("presentation", false))
	AudioBridgeScript.set_suppressed(suppress_audio)
	if suppress_audio:
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

	if opts.get("existing_root") != null:
		root = opts.get("existing_root") as Node3D
		_using_existing_root = true
		if tree.current_scene != root:
			tree.current_scene = root
	else:
		var host_path := str(opts.get("host_scene", HOST_SCENE))
		if host_path.is_empty():
			host_path = HOST_SCENE
		var packed: PackedScene = load(host_path)
		root = packed.instantiate() as Node3D
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
		"behavior": {
			"decision_count": 0,
			"best_action_count": 0,
			"rank_sum": 0.0,
			"regret_sum": 0.0,
			"max_decision_regret": 0.0,
			"rank_1": 0,
			"rank_2": 0,
			"rank_3plus": 0,
		},
	}
	action_log.clear()
	event_log.clear()
	initial_snapshot.clear()
	result.clear()
	_finished = false
	_next_decision_at = 0.0
	_event_cursor = 0
	_next_decision_id = 1
	_wall_start_ms = Time.get_ticks_msec()
	if ReplayPackageScript.records_keyframes(record_mode):
		keyframe_buffer = KeyframeBufferScript.new()
		keyframe_buffer.setup(
			func():
				return load("res://scripts/sim/sim_snapshot.gd").capture(self),
			func():
				return clock.sim_time if clock else 0.0,
			2.0
		)
	else:
		keyframe_buffer = null
	if telemetry != null and "write_disk" in telemetry:
		telemetry.write_disk = ReplayPackageScript.records_keyframes(record_mode) and not _is_clone


func set_agent(p_agent) -> void:
	agent = p_agent


func await_ready() -> void:
	# GameManager awaits one process_frame in _ready.
	await tree.process_frame
	await tree.process_frame
	if ReplayPackageScript.records_actions(record_mode) or ReplayPackageScript.records_keyframes(record_mode):
		initial_snapshot = load("res://scripts/sim/sim_snapshot.gd").capture(self)
	if keyframe_buffer != null:
		keyframe_buffer.maybe_capture(true)


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
	var atype := str(action.get("type", ""))
	if ok and atype != SimActionsScript.TYPE_WAIT:
		action_log.append({
			"time": clock.sim_time,
			"action": action.duplicate(true),
		})
		if keyframe_buffer != null and atype in ["PLACE_TOWER", "UPGRADE_TOWER", "START_WAVE"]:
			keyframe_buffer.maybe_capture(true)
	return ok


func get_available_actions() -> Array:
	return SimActionsScript.get_available_actions(game)


func set_replay(replay_actions: Array, from_time: float = -1.0) -> void:
	agent = null
	_replay_log = replay_actions.duplicate(true)
	_replay_index = 0
	if from_time >= 0.0:
		while _replay_index < _replay_log.size():
			if float(_replay_log[_replay_index].get("time", 0.0)) > from_time + 0.0001:
				break
			_replay_index += 1


func replay_due_actions() -> void:
	if _replay_log.is_empty() or clock == null:
		return
	while _replay_index < _replay_log.size():
		var entry: Dictionary = _replay_log[_replay_index]
		if float(entry.get("time", 0.0)) > clock.sim_time + 0.0001:
			break
		var action: Dictionary = entry.get("action", {})
		if action.is_empty() and entry.has("type"):
			action = entry
		# After a keyframe restore, the previous wave may still be a few ticks late.
		# Keep START_WAVE pending instead of consuming a failed start.
		if str(action.get("type", "")) == SimActionsScript.TYPE_START_WAVE:
			if game != null and (bool(game.get("wave_running")) or bool(game.get("game_over")) or bool(game.get("level_complete"))):
				if bool(game.get("wave_running")):
					break
		execute(action)
		_replay_index += 1


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
	if not _replay_log.is_empty():
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
		"rng": decision_rng if decision_rng != null else rng,
		"path_meta": _path_meta(),
		"game": game,
		"simulation": self,
	}
	var decision = await agent.decide(ctx)
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
	var quality: Dictionary = {}
	if typeof(decision) == TYPE_DICTIONARY:
		quality = decision.get("quality", {})
	if quality.is_empty():
		var GameAgent = load("res://scripts/sim/agents/game_agent.gd")
		quality = GameAgent.quality_of(
			{"action": action, "score": score},
			decision.get("considered", []) if typeof(decision) == TYPE_DICTIONARY else []
		)
	_accumulate_behavior(quality)
	var deep := ReplayPackageScript.records_decisions_deep(record_mode)
	var decisions: Array = agent_metrics["decisions"]
	if deep or decisions.size() < 64:
		var entry := {
			"decision_id": _next_decision_id,
			"time": clock.sim_time,
			"action": action.duplicate(true),
			"score": score,
			"breakdown": breakdown.duplicate(true),
			"state_summary": _state_summary(),
			"best_score": float(quality.get("best_score", score)),
			"chosen_score": float(quality.get("chosen_score", score)),
			"score_gap": float(quality.get("score_gap", 0.0)),
			"chosen_rank": int(quality.get("chosen_rank", 1)),
			"option_count": int(quality.get("option_count", 0)),
			"best_action": quality.get("best_action", {}),
		}
		_next_decision_id += 1
		if deep:
			entry["actions_considered"] = _compact_considered(decision.get("considered", []) if typeof(decision) == TYPE_DICTIONARY else [])
			entry["lookahead"] = _chosen_lookahead(action, breakdown)
		decisions.append(entry)
		if ReplayPackageScript.records_keyframes(record_mode):
			_push_event("agent_decision", {
				"decision_id": entry["decision_id"],
				"action": action.duplicate(true),
				"score": score,
				"chosen_rank": entry["chosen_rank"],
				"score_gap": entry["score_gap"],
			})
	_next_decision_at = clock.sim_time + _decision_interval


func _accumulate_behavior(quality: Dictionary) -> void:
	var b: Dictionary = agent_metrics["behavior"]
	b["decision_count"] = int(b.get("decision_count", 0)) + 1
	var rank := int(quality.get("chosen_rank", 1))
	var gap := float(quality.get("score_gap", 0.0))
	b["rank_sum"] = float(b.get("rank_sum", 0.0)) + float(rank)
	b["regret_sum"] = float(b.get("regret_sum", 0.0)) + gap
	b["max_decision_regret"] = maxf(float(b.get("max_decision_regret", 0.0)), gap)
	if rank <= 1:
		b["best_action_count"] = int(b.get("best_action_count", 0)) + 1
		b["rank_1"] = int(b.get("rank_1", 0)) + 1
	elif rank == 2:
		b["rank_2"] = int(b.get("rank_2", 0)) + 1
	else:
		b["rank_3plus"] = int(b.get("rank_3plus", 0)) + 1


func behavior_summary() -> Dictionary:
	var b: Dictionary = agent_metrics.get("behavior", {})
	var n := maxi(int(b.get("decision_count", 0)), 1)
	var count := int(b.get("decision_count", 0))
	return {
		"decision_count": count,
		"best_action_rate": float(b.get("best_action_count", 0)) / float(n) if count > 0 else 1.0,
		"average_chosen_rank": float(b.get("rank_sum", 0.0)) / float(n) if count > 0 else 1.0,
		"average_decision_regret": float(b.get("regret_sum", 0.0)) / float(n) if count > 0 else 0.0,
		"max_decision_regret": float(b.get("max_decision_regret", 0.0)),
		"rank_1_percentage": float(b.get("rank_1", 0)) / float(n) if count > 0 else 1.0,
		"rank_2_percentage": float(b.get("rank_2", 0)) / float(n) if count > 0 else 0.0,
		"rank_3plus_percentage": float(b.get("rank_3plus", 0)) / float(n) if count > 0 else 0.0,
	}


func after_tick() -> void:
	if _is_clone or record_mode == ReplayPackageScript.MODE_NONE:
		return
	_drain_telemetry_events()
	if keyframe_buffer != null:
		keyframe_buffer.maybe_capture(false)


func mark_not_finished() -> void:
	_finished = false
	result.clear()


func _state_summary() -> Dictionary:
	var st := state()
	var leaks := 0
	if telemetry != null and "enemies_leaked" in telemetry:
		leaks = int(telemetry.get("enemies_leaked"))
	return {
		"gold": int(st.get("gold", 0)),
		"core_hp": int(st.get("core_hp", 0)),
		"wave": int(st.get("current_wave", 1)),
		"wave_running": bool(st.get("wave_running", false)),
		"towers": (st.get("towers", []) as Array).size(),
		"enemies": (st.get("enemies", []) as Array).size(),
		"leaks": leaks,
	}


func _compact_considered(raw) -> Array:
	var items: Array = raw if typeof(raw) == TYPE_ARRAY else []
	var places: Array = []
	var keep: Array = []
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = item.get("action", {})
		var action_type: String = str(a.get("type", ""))
		var row: Dictionary = {
			"action": a.duplicate(true) if typeof(a) == TYPE_DICTIONARY else {},
			"score": float(item.get("score", 0.0)),
			"breakdown": (item.get("breakdown", {}) as Dictionary).duplicate(true) if typeof(item.get("breakdown", {})) == TYPE_DICTIONARY else {},
		}
		if action_type == "PLACE_TOWER":
			places.append(row)
		elif action_type in ["UPGRADE_TOWER", "START_WAVE"]:
			keep.append(row)
	places.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	if places.size() > 8:
		places = places.slice(0, 8)
	return places + keep


func _chosen_lookahead(action: Dictionary, breakdown: Dictionary) -> Dictionary:
	var last: Dictionary = lookahead_stats.get("last_example", {})
	var last_action: Dictionary = last.get("action", {})
	if not last_action.is_empty() and str(last_action.get("type")) == str(action.get("type")):
		if str(last_action.get("spot_id", "")) == str(action.get("spot_id", "")) \
			and str(last_action.get("tower_type", "")) == str(action.get("tower_type", "")) \
			and str(last_action.get("runtime_id", "")) == str(action.get("runtime_id", "")):
			return {
				"horizon": last.get("horizon", 0.0),
				"future": last.get("future", {}),
			}
	if breakdown.has("lookahead"):
		return {"score": breakdown.get("lookahead")}
	return {}


func _drain_telemetry_events() -> void:
	if telemetry == null or not ("event_buffer" in telemetry):
		return
	var buf: Array = telemetry.event_buffer
	while _event_cursor < buf.size():
		var payload: Dictionary = buf[_event_cursor]
		_event_cursor += 1
		var name := str(payload.get("event", ""))
		if name.is_empty():
			continue
		_push_event(name, payload)
		if keyframe_buffer != null and name in ["wave_started", "enemy_reached_core", "level_completed", "game_over", "run_ended"]:
			keyframe_buffer.maybe_capture(true)


func _push_event(name: String, payload: Dictionary) -> void:
	if not ReplayPackageScript.records_keyframes(record_mode):
		return
	var compact := {
		"time": clock.sim_time if clock else 0.0,
		"event": name,
	}
	for k in ["wave", "enemy_id", "tower_runtime_id", "spot_id", "decision_id", "score", "result", "core_hp", "gold"]:
		if payload.has(k):
			compact[k] = payload[k]
	if payload.has("action"):
		compact["action"] = payload.get("action")
	event_log.append(compact)


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
	return load("res://scripts/sim/sim_snapshot.gd").capture(self)


func spawn_clone():
	var t0 := Time.get_ticks_msec()
	var snap: Dictionary = clone()
	var saved_scene = tree.current_scene
	_set_processing(root, false)
	var saved_clock = SimContextScript.clock
	var saved_rng = SimContextScript.rng
	var clone_sim = load("res://scripts/sim/game_simulation.gd").new()
	clone_sim.setup({
		"level_id": level_id,
		"difficulty_id": difficulty_id,
		"seed": run_seed,
		"world_seed": world_seed,
		"decision_seed": decision_seed,
		"config": config,
		"clone": true,
		"max_sim_seconds": _max_sim_seconds,
	}, tree)
	await clone_sim.await_ready()
	tree.current_scene = clone_sim.root
	SimContextScript.clock = clone_sim.clock
	SimContextScript.rng = clone_sim.rng
	load("res://scripts/sim/sim_snapshot.gd").restore(clone_sim, snap)
	lookahead_stats["clone_ms_sum"] = float(lookahead_stats["clone_ms_sum"]) + float(Time.get_ticks_msec() - t0)
	clone_sim.set_meta("parent_scene", saved_scene)
	clone_sim.set_meta("parent_clock", saved_clock)
	clone_sim.set_meta("parent_rng", saved_rng)
	clone_sim.set_meta("parent_root", root)
	return clone_sim


func finish_clone(clone_sim) -> void:
	var parent_scene = clone_sim.get_meta("parent_scene", root)
	var parent_clock = clone_sim.get_meta("parent_clock", clock)
	var parent_rng = clone_sim.get_meta("parent_rng", rng)
	var parent_root = clone_sim.get_meta("parent_root", root)
	clone_sim.cleanup()
	tree.current_scene = parent_scene
	SimContextScript.clock = parent_clock
	SimContextScript.rng = parent_rng
	SimContextScript.clone_active = false
	if parent_root != null and is_instance_valid(parent_root):
		_set_processing(parent_root, true)


func evaluate_action_with_lookahead(action: Dictionary, horizon_seconds: float = 3.0) -> float:
	var t0 := Time.get_ticks_msec()
	var clone_sim = await spawn_clone()
	clone_sim.execute(action)
	var SimRunnerScript = load("res://scripts/sim/sim_runner.gd")
	await SimRunnerScript.run_for_seconds(tree, clone_sim, horizon_seconds, {
		"manage_speed": false,
		"decide": false,
	})
	var scored := _score_future_state(clone_sim)
	if lookahead_stats["last_example"].is_empty() or str(action.get("type")) != "WAIT":
		lookahead_stats["last_example"] = {
			"action": action.duplicate(true),
			"future": scored,
			"horizon": horizon_seconds,
		}
	lookahead_stats["evals"] = int(lookahead_stats["evals"]) + 1
	lookahead_stats["future_seconds"] = float(lookahead_stats["future_seconds"]) + horizon_seconds
	lookahead_stats["eval_ms_sum"] = float(lookahead_stats["eval_ms_sum"]) + float(Time.get_ticks_msec() - t0)
	finish_clone(clone_sim)
	return float(scored.get("total", 0.0))


func _score_future_state(clone_sim) -> Dictionary:
	var st: Dictionary = clone_sim.state()
	var lives := float(st.get("core_hp", 0))
	var leaked := 0
	if clone_sim.telemetry != null:
		leaked = int(clone_sim.telemetry.get("enemies_leaked"))
	var enemy_hp := 0.0
	var progress := 0.0
	for e in st.get("enemies", []):
		enemy_hp += float(e.get("health", 0.0))
		progress += float(e.get("path_progress", 0.0))
	var damage := 0.0
	for t in st.get("towers", []):
		damage += float(t.get("damage_dealt", 0.0))
	var gold := float(st.get("gold", 0))
	var parts := {
		"lives": lives * 8.0,
		"leak_prevention": -float(leaked) * 25.0,
		"enemy_pressure": -enemy_hp * 0.08 - progress * 0.4,
		"future_damage": damage * 0.02,
		"economy": gold * 0.05,
	}
	var total := 0.0
	for v in parts.values():
		total += float(v)
	parts["total"] = total
	return parts


func _set_processing(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(enabled)
	node.set_physics_process(enabled)
	for child in node.get_children():
		_set_processing(child, enabled)


func _ensure_result() -> void:
	if not result.is_empty():
		return
	var wall := maxi(Time.get_ticks_msec() - _wall_start_ms, 1)
	result = SimMetricsScript.build_result(self, wall)
	result["player_profile"] = player_profile
	result["world_seed"] = world_seed
	result["decision_seed"] = decision_seed
	result["behavior"] = behavior_summary()
	var am: Dictionary = result.get("agent_metrics", {})
	am["behavior"] = result["behavior"]
	result["agent_metrics"] = am


func finish() -> Dictionary:
	_finished = true
	_drain_telemetry_events()
	if keyframe_buffer != null:
		keyframe_buffer.maybe_capture(true)
	_ensure_result()
	return result


func cleanup() -> void:
	if root != null and is_instance_valid(root) and not _using_existing_root:
		root.queue_free()
	root = null
	game = null
	if _is_clone:
		SimContextScript.clone_active = false
	else:
		SimContextScript.end()
		AudioBridgeScript.set_suppressed(false)
