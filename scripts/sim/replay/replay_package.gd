extends RefCounted

const SCHEMA_VERSION := 1
const MODE_NONE := "none"
const MODE_SUMMARY := "summary"
const MODE_REPLAY := "replay"
const MODE_DEEP := "deep"


static func normalize_mode(raw: String) -> String:
	match str(raw).to_lower():
		MODE_SUMMARY, MODE_REPLAY, MODE_DEEP:
			return str(raw).to_lower()
		_:
			return MODE_NONE


static func records_keyframes(mode: String) -> bool:
	return mode in [MODE_REPLAY, MODE_DEEP]


static func records_decisions_deep(mode: String) -> bool:
	return mode == MODE_DEEP


static func records_actions(mode: String) -> bool:
	return mode != MODE_NONE


static func build(sim, opts: Dictionary, result: Dictionary) -> Dictionary:
	var mode := normalize_mode(str(opts.get("record", MODE_NONE)))
	var run_id := "run_%s_%d_%d" % [
		str(opts.get("agent_id", "basic")),
		int(opts.get("seed", sim.run_seed if sim else 0)),
		int(Time.get_unix_time_from_system()),
	]
	var pkg := {
		"schema_version": SCHEMA_VERSION,
		"run_id": run_id,
		"created_at": Time.get_datetime_string_from_system(true, true),
		"level_id": str(opts.get("level_id", sim.level_id if sim else "")),
		"difficulty_id": str(opts.get("difficulty_id", sim.difficulty_id if sim else "")),
		"seed": int(opts.get("seed", sim.run_seed if sim else 0)),
		"world_seed": int(opts.get("world_seed", sim.world_seed if sim else 0)),
		"decision_seed": int(opts.get("decision_seed", sim.decision_seed if sim else 0)),
		"agent_id": str(opts.get("agent_id", "")),
		"player_profile": str(opts.get("player_profile", sim.player_profile if sim else "optimizer")),
		"agent_config": {
			"temperature": float(opts.get("temperature", 0.0)),
			"lookahead": bool(opts.get("lookahead", false)),
			"player_profile": str(opts.get("player_profile", sim.player_profile if sim else "optimizer")),
		},
		"simulation_config": {
			"time_scale": float(opts.get("time_scale", 40.0)),
			"record": mode,
			"config": opts.get("config", {}),
		},
		"initial_snapshot": {},
		"action_log": [],
		"agent_decisions": [],
		"event_log": [],
		"keyframes": [],
		"final_result": result.duplicate(true),
		"metrics": {
			"won": result.get("won"),
			"lives_remaining": result.get("lives_remaining"),
			"enemies_killed": result.get("enemies_killed"),
			"enemies_leaked": result.get("enemies_leaked"),
			"total_damage": result.get("total_damage"),
			"duration": result.get("duration"),
			"towers_placed": result.get("towers_placed"),
			"behavior": result.get("behavior", {}),
		},
	}
	if sim != null:
		if sim.get("initial_snapshot") != null:
			pkg["initial_snapshot"] = sim.initial_snapshot
		if records_actions(mode):
			pkg["action_log"] = sim.action_log.duplicate(true)
		if mode == MODE_DEEP:
			pkg["agent_decisions"] = (sim.agent_metrics.get("decisions", []) as Array).duplicate(true)
		elif mode != MODE_NONE:
			pkg["agent_decisions"] = (sim.agent_metrics.get("decisions", []) as Array).duplicate(true)
		if records_keyframes(mode):
			if sim.get("event_log") != null:
				pkg["event_log"] = sim.event_log.duplicate(true)
			if sim.get("keyframe_buffer") != null:
				pkg["keyframes"] = sim.keyframe_buffer.all()
	pkg["storage"] = storage_stats(pkg)
	return pkg


static func storage_stats(pkg: Dictionary) -> Dictionary:
	var encoded := JSON.stringify(pkg)
	return {
		"bytes": encoded.length(),
		"keyframe_count": (pkg.get("keyframes", []) as Array).size(),
		"action_count": (pkg.get("action_log", []) as Array).size(),
		"decision_count": (pkg.get("agent_decisions", []) as Array).size(),
		"event_count": (pkg.get("event_log", []) as Array).size(),
	}


static func compatible(pkg: Dictionary) -> bool:
	return int(pkg.get("schema_version", 0)) == SCHEMA_VERSION


static func incompatibility_message(pkg: Dictionary) -> String:
	return "Replay schema %s is no longer compatible with current simulation schema %d." % [
		str(pkg.get("schema_version", "?")), SCHEMA_VERSION
	]


static func sanitize(value):
	match typeof(value):
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"__v3": true, "x": v.x, "y": v.y, "z": v.z}
		TYPE_INT:
			# JSON numbers are IEEE-754 doubles; uint64 RNG state must not lose bits.
			if absi(value) > 9007199254740991:
				return {"__i64": true, "s": str(value)}
			return value
		TYPE_DICTIONARY:
			var d := {}
			for k in value.keys():
				d[str(k)] = sanitize(value[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for item in value:
				a.append(sanitize(item))
			return a
		_:
			return value


static func desanitize(value):
	if typeof(value) == TYPE_DICTIONARY:
		if bool(value.get("__v3", false)):
			return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
		if bool(value.get("__i64", false)):
			return int(str(value.get("s", "0")))
		var d := {}
		for k in value.keys():
			d[k] = desanitize(value[k])
		return d
	if typeof(value) == TYPE_ARRAY:
		var a: Array = []
		for item in value:
			a.append(desanitize(item))
		return a
	return value


static func tower_composition(result: Dictionary) -> Dictionary:
	var counts := {}
	for ts in result.get("tower_stats", []):
		var tid := str(ts.get("tower_type", ""))
		if tid.is_empty():
			continue
		counts[tid] = int(counts.get(tid, 0)) + 1
	return counts
