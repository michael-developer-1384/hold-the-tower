extends RefCounted

## Strategic sequence fingerprints and batch diversity.


static func action_token(entry) -> String:
	var row: Dictionary = entry if typeof(entry) == TYPE_DICTIONARY else {}
	var a: Dictionary = row.get("action", row)
	var action_type: String = str(a.get("type", ""))
	if action_type == "WAIT" or action_type.is_empty():
		return ""
	var bits: PackedStringArray = [action_type]
	for k in ["spot_id", "tower_id", "tower_type", "runtime_id"]:
		var v: String = str(a.get(k, ""))
		if not v.is_empty():
			bits.append(v)
	if action_type == "START_WAVE":
		var tm: float = float(row.get("time", 0.0))
		bits.append("%.1f" % (round(tm * 4.0) / 4.0))
	return "|".join(bits)


static func action_sequence(action_log: Array) -> String:
	var parts: PackedStringArray = []
	for entry in action_log:
		var tok: String = action_token(entry)
		if not tok.is_empty():
			parts.append(tok)
	return " > ".join(parts)


static func build_sequence(action_log: Array) -> String:
	var parts: PackedStringArray = []
	for entry in action_log:
		var row: Dictionary = entry if typeof(entry) == TYPE_DICTIONARY else {}
		var a: Dictionary = row.get("action", row)
		var action_type: String = str(a.get("type", ""))
		if action_type in ["PLACE_TOWER", "UPGRADE_TOWER"]:
			var tok: String = action_token(row)
			if not tok.is_empty():
				parts.append(tok)
	return " > ".join(parts)


static func final_build(result: Dictionary) -> String:
	var counts: Dictionary = load("res://scripts/sim/replay/replay_package.gd").tower_composition(result)
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s:%d" % [str(k), int(counts[k])])
	return ",".join(parts)


static func summarize(results: Array) -> Dictionary:
	var action_set: Dictionary = {}
	var build_set: Dictionary = {}
	var final_set: Dictionary = {}
	var seq_first: Dictionary = {}
	var tagged: Array = []
	for item in results:
		var r: Dictionary = item
		var entries: Array = r.get("action_log", [])
		var aseq: String = action_sequence(entries)
		var bseq: String = build_sequence(entries)
		var fin: String = final_build(r)
		action_set[aseq] = int(action_set.get(aseq, 0)) + 1
		build_set[bseq] = int(build_set.get(bseq, 0)) + 1
		final_set[fin] = int(final_set.get(fin, 0)) + 1
		var dup: String = ""
		if seq_first.has(aseq):
			dup = str(seq_first[aseq])
		else:
			seq_first[aseq] = str(r.get("seed", r.get("run_id", "")))
		var row: Dictionary = r.duplicate(false)
		row["action_sequence"] = aseq
		row["build_sequence"] = bseq
		row["final_build"] = fin
		row["strategic_duplicate_of"] = dup
		tagged.append(row)
	return {
		"unique_action_sequences": action_set.size(),
		"unique_build_sequences": build_set.size(),
		"unique_final_builds": final_set.size(),
		"runs": results.size(),
		"tagged": tagged,
	}


static func format_report(div: Dictionary, n: int) -> String:
	var lines: PackedStringArray = []
	lines.append("Strategy diversity:")
	lines.append("  Unique action sequences: %d" % int(div.get("unique_action_sequences", 0)))
	lines.append("  Unique build sequences:  %d" % int(div.get("unique_build_sequences", 0)))
	lines.append("  Unique final builds:     %d" % int(div.get("unique_final_builds", 0)))
	if int(div.get("unique_action_sequences", 0)) <= 1 and n > 1:
		lines.append("  STRATEGIC DUPLICATE: all runs share one action sequence.")
	lines.append("")
	lines.append("Sample size: %d" % n)
	lines.append("Useful for behavioral inspection, not statistical calibration.")
	return "\n".join(lines)


static func interesting_tags(results: Array) -> Dictionary:
	var out: Dictionary = {}
	if results.is_empty():
		return out
	var first_loss = null
	var lowest_core = null
	var highest_regret = null
	var most_divergent = null
	var max_build_len: int = -1
	for item in results:
		var r: Dictionary = item
		var beh: Dictionary = r.get("behavior", r.get("agent_metrics", {}).get("behavior", {}))
		var tags: Array = []
		if float(beh.get("best_action_rate", 0.0)) >= 0.999 and float(beh.get("average_decision_regret", 1.0)) <= 0.001:
			tags.append("PERFECT POLICY")
		if not bool(r.get("won", false)) and first_loss == null:
			first_loss = r
			tags.append("FIRST LOSS")
		if lowest_core == null or int(r.get("lives_remaining", 99)) < int(lowest_core.get("lives_remaining", 99)):
			lowest_core = r
		var prev_reg: float = 0.0
		if highest_regret != null:
			var prev_beh: Dictionary = highest_regret.get("behavior", highest_regret.get("agent_metrics", {}).get("behavior", {}))
			prev_reg = float(prev_beh.get("max_decision_regret", 0.0))
		if highest_regret == null or float(beh.get("max_decision_regret", 0.0)) > prev_reg:
			highest_regret = r
		var blen: int = build_sequence(r.get("action_log", [])).length()
		if blen > max_build_len:
			max_build_len = blen
			most_divergent = r
		var key: String = str(r.get("replay_id", r.get("seed", "")))
		out[key] = tags
	if lowest_core != null:
		_add_tag(out, str(lowest_core.get("replay_id", lowest_core.get("seed", ""))), "LOWEST CORE")
	if highest_regret != null:
		_add_tag(out, str(highest_regret.get("replay_id", highest_regret.get("seed", ""))), "HIGHEST REGRET")
	if most_divergent != null:
		_add_tag(out, str(most_divergent.get("replay_id", most_divergent.get("seed", ""))), "MOST DIVERGENT BUILD")
	return out


static func _add_tag(out: Dictionary, key: String, tag: String) -> void:
	var arr: Array = out.get(key, [])
	if not arr.has(tag):
		arr.append(tag)
	out[key] = arr
