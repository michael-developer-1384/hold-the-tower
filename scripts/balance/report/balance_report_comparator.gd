extends RefCounted

## Delta vs a previous latest report when the same analysis fingerprint applies.


static func compare(current: Dictionary, previous: Dictionary) -> Variant:
	if previous.is_empty():
		return null
	var a: Dictionary = current.get("report_meta", {})
	var b: Dictionary = previous.get("report_meta", {})
	if str(a.get("level_id", "")) != str(b.get("level_id", "")):
		return _skip()
	if str(a.get("difficulty_id", "")) != str(b.get("difficulty_id", "")):
		return _skip()
	if int(a.get("seed", -1)) != int(b.get("seed", -2)):
		return _skip()
	if str(a.get("parameter_fingerprint", "")) != str(b.get("parameter_fingerprint", "")):
		return _skip()
	var towers: Dictionary = {}
	var cur_t: Dictionary = current.get("towers", {})
	var prev_t: Dictionary = previous.get("towers", {})
	for tid in cur_t.keys():
		var c: Dictionary = cur_t[tid]
		var p: Dictionary = prev_t.get(tid, {})
		if p.is_empty():
			continue
		towers[tid] = {
			"median_delta": _sub(c.get("median_value_per_gold"), p.get("median_value_per_gold")),
			"relative_delta": _sub(c.get("relative_to_anchor_median"), p.get("relative_to_anchor_median")),
			"status_was": p.get("status"),
			"status_now": c.get("status"),
		}
	return {
		"comparable": true,
		"previous_report_id": b.get("report_id"),
		"towers": towers,
	}


static func _skip() -> Dictionary:
	return {
		"comparable": false,
		"message": "Previous report not directly comparable.",
	}


static func _sub(a: Variant, b: Variant) -> Variant:
	if a == null or b == null:
		return null
	return float(a) - float(b)
