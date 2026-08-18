extends RefCounted

## Per-axis and combined pressure frontiers via bracket + binary search.

const Margin := preload("res://scripts/balance/defense_margin_search.gd")


static func run(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var replay_log: Array = opts.get("action_log", [])
	var iters := int(opts.get("iters", 5))
	var hi := float(opts.get("hi", 2.0))
	var wanted: Array = opts.get("axis_list", ["health", "speed", "enemy_count", "spawn_rate", "combined"])
	var health := {"max_survivable": null}
	var speed := {"max_survivable": null}
	var count := {"max_survivable": null}
	var spawn := {"max_survivable": null}
	var combined := {"max_survivable": null}
	if "health" in wanted:
		health = await Margin._search_axis(tree, opts, replay_log, "enemy_health", 1.0, hi, iters)
	if "speed" in wanted:
		speed = await Margin._search_axis(tree, opts, replay_log, "enemy_speed", 1.0, hi, iters)
	if "enemy_count" in wanted:
		count = await Margin._search_axis(tree, opts, replay_log, "enemy_count", 1.0, hi, iters)
	if "spawn_rate" in wanted:
		spawn = await Margin._search_axis(tree, opts, replay_log, "spawn_rate", 1.0, hi, iters)
	if "combined" in wanted:
		combined = await _combined(tree, opts, replay_log, iters, hi)
	var breaking := _first_break({
		"health": health,
		"speed": speed,
		"enemy_count": count,
		"spawn_rate": spawn,
		"combined": combined,
	})
	return {
		"measured": true,
		"health_frontier": _num(health.get("max_survivable")),
		"speed_frontier": _num(speed.get("max_survivable")),
		"count_frontier": _num(count.get("max_survivable")),
		"spawn_rate_frontier": _num(spawn.get("max_survivable")),
		"combined_frontier": _num(combined.get("max_survivable")),
		"first_breaking_dimension": breaking,
		"axes": {
			"health": health,
			"speed": speed,
			"enemy_count": count,
			"spawn_rate": spawn,
			"combined": combined,
		},
	}


static func _combined(tree: SceneTree, opts: Dictionary, replay_log: Array, iters: int, hi: float) -> Dictionary:
	var low := 1.0
	var high := hi
	var first_loss: Variant = null
	for _i in iters:
		var mid := (low + high) * 0.5
		var r: Dictionary = await Margin._replay_pressure(tree, opts, replay_log, mid, mid)
		if not bool(r.get("won", false)):
			first_loss = mid
			high = mid
		else:
			low = mid
	return {
		"axis": "combined_health_speed",
		"max_survivable": low,
		"failure_pressure": high,
		"first_loss_multiplier": first_loss,
	}


static func _first_break(axes: Dictionary) -> String:
	var best := ""
	var best_v := 999.0
	for k in axes.keys():
		var raw = axes[k].get("max_survivable")
		if raw == null:
			continue
		var v := float(raw)
		if v < best_v:
			best_v = v
			best = str(k)
	return best


static func _num(v: Variant) -> Variant:
	if v == null:
		return null
	return float(v)
