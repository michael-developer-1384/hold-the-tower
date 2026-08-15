extends RefCounted

## Keyframe restore + forward replay. No reverse physics.


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
	var kf: Dictionary = nearest_keyframe(pkg, target)
	var snap: Dictionary = kf.get("snapshot", {})
	var t0 := float(kf.get("t", 0.0))
	if typeof(snap) == TYPE_DICTIONARY and not snap.is_empty():
		load("res://scripts/sim/sim_snapshot.gd").restore(sim, snap)
	# Cursor = actions already baked into the snapshot — not "all actions with time <= t0".
	# Time-equality skip drops PLACE at 0.0 when the nearest frame is the empty initial snap.
	var applied := _actions_already_applied(snap, pkg, t0)
	sim.set_replay(pkg.get("action_log", []), -1.0, applied)
	if sim.has_method("mark_not_finished"):
		sim.mark_not_finished()
	return t0


static func _actions_already_applied(snap: Dictionary, pkg: Dictionary, t0: float) -> int:
	if typeof(snap) == TYPE_DICTIONARY and snap.has("action_log"):
		return (snap.get("action_log", []) as Array).size()
	# Legacy snaps without action_log: skip strictly earlier times only (< t0).
	var log: Array = pkg.get("action_log", [])
	var idx := 0
	while idx < log.size() and float(log[idx].get("time", 0.0)) < t0 - 0.0001:
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
