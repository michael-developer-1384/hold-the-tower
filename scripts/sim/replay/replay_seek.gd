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
	sim.set_replay(pkg.get("action_log", []), t0)
	if sim.has_method("mark_not_finished"):
		sim.mark_not_finished()
	return t0


static func tick_toward(tree: SceneTree, sim, target: float) -> void:
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	var safety := 0
	while sim.clock != null and sim.clock.sim_time + 0.0001 < target and not sim.is_finished() and safety < 400000:
		if sim.has_method("replay_due_actions"):
			sim.replay_due_actions()
		await tree.physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
		safety += 1
