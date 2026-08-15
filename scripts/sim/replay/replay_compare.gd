extends RefCounted

## First strategic divergence between two action logs.


static func first_divergence(log_a: Array, log_b: Array) -> Dictionary:
	var n := mini(log_a.size(), log_b.size())
	for i in n:
		var ea: Dictionary = log_a[i] if typeof(log_a[i]) == TYPE_DICTIONARY else {}
		var eb: Dictionary = log_b[i] if typeof(log_b[i]) == TYPE_DICTIONARY else {}
		var aa: Dictionary = ea.get("action", ea)
		var ab: Dictionary = eb.get("action", eb)
		var ta := float(ea.get("time", 0.0))
		var tb := float(eb.get("time", 0.0))
		var type_a := str(aa.get("type", ""))
		var type_b := str(ab.get("type", ""))
		if type_a != type_b:
			return _hit(i, ta, tb, "type", type_a, type_b)
		if str(aa.get("spot_id", "")) != str(ab.get("spot_id", "")):
			return _hit(i, ta, tb, "spot", str(aa.get("spot_id", "")), str(ab.get("spot_id", "")))
		if str(aa.get("tower_type", "")) != str(ab.get("tower_type", "")):
			return _hit(i, ta, tb, "tower", str(aa.get("tower_type", "")), str(ab.get("tower_type", "")))
		if str(aa.get("runtime_id", "")) != str(ab.get("runtime_id", "")):
			return _hit(i, ta, tb, "upgrade", str(aa.get("runtime_id", "")), str(ab.get("runtime_id", "")))
		if type_a == "START_WAVE" and absf(ta - tb) > 0.25:
			return _hit(i, ta, tb, "wave_time", "%.2f" % ta, "%.2f" % tb)
	if log_a.size() != log_b.size():
		var longer := log_a if log_a.size() > log_b.size() else log_b
		var extra: Dictionary = longer[n] if n < longer.size() and typeof(longer[n]) == TYPE_DICTIONARY else {}
		return {
			"found": true,
			"index": n,
			"time_a": float(log_a[n].get("time", 0.0)) if n < log_a.size() and typeof(log_a[n]) == TYPE_DICTIONARY else -1.0,
			"time_b": float(log_b[n].get("time", 0.0)) if n < log_b.size() and typeof(log_b[n]) == TYPE_DICTIONARY else -1.0,
			"field": "length",
			"a": str(log_a.size()),
			"b": str(log_b.size()),
			"extra": extra.get("action", extra),
		}
	return {"found": false}


static func first_decision_divergence(pkg_a: Dictionary, pkg_b: Dictionary) -> Dictionary:
	var da: Array = pkg_a.get("agent_decisions", [])
	var db: Array = pkg_b.get("agent_decisions", [])
	var n := mini(da.size(), db.size())
	for i in n:
		var a: Dictionary = da[i] if typeof(da[i]) == TYPE_DICTIONARY else {}
		var b: Dictionary = db[i] if typeof(db[i]) == TYPE_DICTIONARY else {}
		var aa: Dictionary = a.get("action", {})
		var ab: Dictionary = b.get("action", {})
		if str(aa.get("type")) != str(ab.get("type")) \
			or str(aa.get("spot_id", "")) != str(ab.get("spot_id", "")) \
			or str(aa.get("tower_type", aa.get("tower_id", ""))) != str(ab.get("tower_type", ab.get("tower_id", ""))) \
			or str(aa.get("runtime_id", "")) != str(ab.get("runtime_id", "")):
			return {
				"found": true,
				"index": i,
				"decision_id_a": int(a.get("decision_id", i + 1)),
				"decision_id_b": int(b.get("decision_id", i + 1)),
				"time_a": float(a.get("time", 0.0)),
				"time_b": float(b.get("time", 0.0)),
				"action_a": aa,
				"action_b": ab,
				"score_a": float(a.get("chosen_score", a.get("score", 0.0))),
				"score_b": float(b.get("chosen_score", b.get("score", 0.0))),
				"regret_a": float(a.get("score_gap", 0.0)),
				"regret_b": float(b.get("score_gap", 0.0)),
				"rank_a": int(a.get("chosen_rank", 1)),
				"rank_b": int(b.get("chosen_rank", 1)),
			}
	return {"found": false}


static func format_text(pkg_a: Dictionary, pkg_b: Dictionary) -> String:
	var div: Dictionary = first_divergence(pkg_a.get("action_log", []), pkg_b.get("action_log", []))
	var ddiv: Dictionary = first_decision_divergence(pkg_a, pkg_b)
	var lines: PackedStringArray = []
	lines.append("COMPARE  %s  vs  %s" % [str(pkg_a.get("run_id", "A")), str(pkg_b.get("run_id", "B"))])
	lines.append("A  seed=%s  %s  %s  core=%s  gold=%s  +/− %d/%d  dur=%.1fs" % [
		str(pkg_a.get("seed")), str(pkg_a.get("player_profile", "")), _wl(pkg_a),
		str(pkg_a.get("metrics", {}).get("lives_remaining")),
		str(_gold_end(pkg_a)),
		_gold_earned(pkg_a), _gold_spent(pkg_a),
		float(pkg_a.get("metrics", {}).get("duration", 0.0)),
	])
	lines.append("B  seed=%s  %s  %s  core=%s  gold=%s  +/− %d/%d  dur=%.1fs" % [
		str(pkg_b.get("seed")), str(pkg_b.get("player_profile", "")), _wl(pkg_b),
		str(pkg_b.get("metrics", {}).get("lives_remaining")),
		str(_gold_end(pkg_b)),
		_gold_earned(pkg_b), _gold_spent(pkg_b),
		float(pkg_b.get("metrics", {}).get("duration", 0.0)),
	])
	if bool(ddiv.get("found", false)):
		lines.append("FIRST DECISION DIVERGENCE  #%s  tA=%.2f  tB=%.2f" % [
			str(ddiv.get("decision_id_a")), float(ddiv.get("time_a", 0.0)), float(ddiv.get("time_b", 0.0)),
		])
		lines.append("  A: %s  score=%.1f  regret=%.1f  rank=%s" % [
			str(ddiv.get("action_a")), float(ddiv.get("score_a", 0.0)),
			float(ddiv.get("regret_a", 0.0)), str(ddiv.get("rank_a")),
		])
		lines.append("  B: %s  score=%.1f  regret=%.1f  rank=%s" % [
			str(ddiv.get("action_b")), float(ddiv.get("score_b", 0.0)),
			float(ddiv.get("regret_b", 0.0)), str(ddiv.get("rank_b")),
		])
	if not bool(div.get("found", false)):
		if not bool(ddiv.get("found", false)):
			lines.append("No strategic divergence.")
		return "\n".join(lines)
	lines.append("First action-log divergence @ action %d  tA=%.2f  tB=%.2f  field=%s" % [
		int(div.get("index", 0)), float(div.get("time_a", 0.0)), float(div.get("time_b", 0.0)),
		str(div.get("field")),
	])
	lines.append("  A: %s" % str(div.get("a")))
	lines.append("  B: %s" % str(div.get("b")))
	return "\n".join(lines)


static func _wl(pkg: Dictionary) -> String:
	return "WIN" if bool(pkg.get("metrics", {}).get("won", false)) else "LOSS"


static func _gold_end(pkg: Dictionary) -> int:
	var m: Dictionary = pkg.get("metrics", {})
	if m.has("gold"):
		return int(m.get("gold"))
	var fr: Dictionary = pkg.get("final_result", {})
	if fr.has("gold"):
		return int(fr.get("gold"))
	return 0


static func _gold_earned(pkg: Dictionary) -> int:
	var m: Dictionary = pkg.get("metrics", {})
	return int(m.get("gold_earned", m.get("credits_earned", 0)))


static func _gold_spent(pkg: Dictionary) -> int:
	var m: Dictionary = pkg.get("metrics", {})
	return int(m.get("gold_spent", m.get("credits_spent", 0)))


static func _hit(index: int, ta: float, tb: float, field: String, a, b) -> Dictionary:
	return {
		"found": true,
		"index": index,
		"time_a": ta,
		"time_b": tb,
		"field": field,
		"a": a,
		"b": b,
	}
