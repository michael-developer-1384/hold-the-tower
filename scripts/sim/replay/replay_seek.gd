extends RefCounted

## Keyframe restore + forward replay. No reverse physics.
## Mid-combat JSON snapshots are not a trusted spawn/combat restore yet.
## Seek always restores the initial snapshot and fast-forwards with the action log.


static func nearest_keyframe(pkg: Dictionary, target: float) -> Dictionary:
	var best := {
		"t": 0.0,
		"snapshot": pkg.get("initial_snapshot", {}),
	}
	if typeof(best.get("snapshot")) != TYPE_DICTIONARY or (best.get("snapshot") as Dictionary).is_empty():
		best["snapshot"] = {}
	for item in pkg.get("keyframes", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var t: float = float(item.get("t", 0.0))
		if t <= target + 0.0001:
			best = item
		else:
			break
	return best


static func apply_seek(sim, pkg: Dictionary, target: float) -> float:
	var snap: Dictionary = pkg.get("initial_snapshot", {})
	if typeof(snap) != TYPE_DICTIONARY or snap.is_empty():
		var kf0: Dictionary = nearest_keyframe(pkg, 0.0)
		snap = kf0.get("snapshot", {})
	if typeof(snap) == TYPE_DICTIONARY and not snap.is_empty():
		load("res://scripts/sim/sim_snapshot.gd").restore(sim, snap)
	_reset_playhead(sim, snap)
	var applied := _actions_already_applied(snap, pkg, 0.0)
	sim.set_replay(pkg.get("action_log", []), -1.0, applied)
	return 0.0


static func apply_seek_keyframe(sim, pkg: Dictionary, target: float) -> float:
	## In-memory clone path. Not used for JSON replay seek until spawn restore is bit-exact.
	var kf: Dictionary = nearest_keyframe(pkg, target)
	var snap: Dictionary = kf.get("snapshot", {})
	var t0 := float(kf.get("t", 0.0))
	if typeof(snap) == TYPE_DICTIONARY and not snap.is_empty():
		load("res://scripts/sim/sim_snapshot.gd").restore(sim, snap)
	var applied := _actions_already_applied(snap, pkg, t0)
	sim.set_replay(pkg.get("action_log", []), -1.0, applied)
	_reset_playhead(sim, snap)
	return t0


static func _reset_playhead(sim, snap: Dictionary) -> void:
	## Seek-from-origin and mid-run rewinds must not keep a later clock or game_over flag.
	if sim.clock != null and sim.clock.has_method("reset"):
		sim.clock.reset()
	var t0: float = 0.0
	if typeof(snap) == TYPE_DICTIONARY:
		t0 = float(snap.get("sim_time", 0.0))
	if sim.clock != null:
		sim.clock.sim_time = t0
		var SimContextScript = load("res://scripts/sim/sim_context.gd")
		SimContextScript.sim_time_ms = t0 * 1000.0
	if sim.has_method("mark_not_finished"):
		sim.mark_not_finished()
	if sim.get("result") != null:
		sim.result = {}
	if sim.game != null:
		sim.game.set("game_over", false)
		sim.game.set("level_complete", false)
		var build = sim.game.get("build_manager")
		if build != null and build.has_method("set_build_enabled"):
			build.call("set_build_enabled", true)
		var selection = sim.game.get("selection_manager")
		if selection != null and selection.has_method("set_interaction_enabled"):
			selection.call("set_interaction_enabled", true)


static func _actions_already_applied(snap: Dictionary, pkg: Dictionary, t0: float) -> int:
	if typeof(snap) == TYPE_DICTIONARY and snap.has("action_log"):
		return (snap.get("action_log", []) as Array).size()
	var replay_log: Array = pkg.get("action_log", [])
	var idx := 0
	while idx < replay_log.size() and float(replay_log[idx].get("time", 0.0)) < t0 - 0.0001:
		idx += 1
	return idx


static func tick_toward(tree: SceneTree, sim, target: float, still_valid: Callable = Callable()) -> void:
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var safety := 0
	while sim.clock != null and sim.clock.sim_time + 0.0001 < target and not sim.is_finished() and safety < 400000:
		if still_valid.is_valid() and not bool(still_valid.call()):
			return
		if sim.has_method("replay_due_actions"):
			sim.replay_due_actions()
		await tree.physics_frame
		if still_valid.is_valid() and not bool(still_valid.call()):
			return
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		safety += 1
