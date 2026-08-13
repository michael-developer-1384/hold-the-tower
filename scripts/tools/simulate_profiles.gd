extends SceneTree

## Behavioral matrix: optimizer x1 + expert/competent/casual/beginner x5.
## godot --headless --path . --script res://scripts/tools/simulate_profiles.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Behavioral Profile Matrix ===")
	var Batch = load("res://scripts/sim/balance/batch_runner.gd")
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var groups := [
		{"profile": "optimizer", "runs": 1, "seed": 1, "lookahead": false},
		{"profile": "expert", "runs": 5, "seed": 1, "lookahead": false},
		{"profile": "competent", "runs": 5, "seed": 1, "lookahead": false},
		{"profile": "casual", "runs": 5, "seed": 1, "lookahead": false},
		{"profile": "beginner", "runs": 5, "seed": 1, "lookahead": false},
		{"profile": "competent", "runs": 5, "seed": 11, "lookahead": true},
	]
	var all_lines: PackedStringArray = []
	var watch: PackedStringArray = []
	for g in groups:
		var group: Dictionary = g
		var opts := {
			"level_id": "vertical_test",
			"difficulty_id": "normal",
			"agent_id": "smart",
			"player_profile": str(group.get("profile")),
			"seed": int(group.get("seed")),
			"runs": int(group.get("runs")),
			"lookahead": bool(group.get("lookahead")),
			"record": "deep",
			"time_scale": 40.0,
		}
		print("\n-- %s  runs=%d  lookahead=%s --" % [opts["player_profile"], opts["runs"], str(opts["lookahead"])])
		var batch: Dictionary = await Batch.run_batch(self, opts)
		var agg: Dictionary = batch.get("aggregate", {})
		var results: Array = batch.get("results", [])
		var div: Dictionary = batch.get("diversity", Diversity.summarize(results))
		all_lines.append(_format_group(str(group.get("profile")), bool(group.get("lookahead")), agg, results, div))
		print(batch.get("report", ""))
		var tags: Dictionary = Diversity.interesting_tags(results)
		for r in results:
			var run: Dictionary = r
			var key: String = str(run.get("replay_id", run.get("seed", "")))
			var tlist: Array = tags.get(key, [])
			if not tlist.is_empty() or not bool(run.get("won", true)):
				watch.append("%s  seed=%s  %s  core=%s  %s" % [
					str(group.get("profile")),
					str(run.get("seed")),
					"WIN" if bool(run.get("won")) else "LOSS",
					str(run.get("lives_remaining")),
					", ".join(tlist),
				])
	print("\n===== BEHAVIORAL SUMMARY =====\n")
	print("\n".join(all_lines))
	print("\n===== WATCH CANDIDATES =====")
	if watch.is_empty():
		print("No standout losses or tagged runs. Watch optimizer seed 1 and any competent seed that diverged.")
	else:
		print("\n".join(watch))
	print("\nSample size is small. Useful for behavioral inspection, not statistical calibration.")
	quit(0)


func _format_group(profile: String, lookahead: bool, agg: Dictionary, results: Array, div: Dictionary) -> String:
	var sentry := 0.0
	var guard := 0.0
	var best := 0.0
	var rank := 0.0
	var regret := 0.0
	var max_r := 0.0
	var n := maxi(results.size(), 1)
	for r in results:
		var counts: Dictionary = load("res://scripts/sim/replay/replay_package.gd").tower_composition(r)
		sentry += float(counts.get("basic_tower", 0))
		guard += float(counts.get("guard_post", 0))
		var beh: Dictionary = r.get("behavior", {})
		best += float(beh.get("best_action_rate", 0.0))
		rank += float(beh.get("average_chosen_rank", 1.0))
		regret += float(beh.get("average_decision_regret", 0.0))
		max_r = maxf(max_r, float(beh.get("max_decision_regret", 0.0)))
	var lines: PackedStringArray = []
	var title := profile.to_upper()
	if lookahead:
		title += "  (LOOKAHEAD ON)"
	lines.append(title)
	lines.append("Runs                    %d" % results.size())
	lines.append("Wins                    %d" % int(round(float(agg.get("winrate", 0.0)) * float(results.size()))))
	lines.append("Avg core                %.1f" % float(agg.get("avg_lives_remaining", 0.0)))
	lines.append("Avg duration            %.1fs" % float(agg.get("avg_duration", 0.0)))
	lines.append("Unique strategies       %d" % int(div.get("unique_action_sequences", 0)))
	lines.append("Unique builds           %d" % int(div.get("unique_final_builds", 0)))
	lines.append("Best-action rate        %.0f%%" % (best / float(n) * 100.0))
	lines.append("Average chosen rank     %.2f" % (rank / float(n)))
	lines.append("Average regret          %.2f" % (regret / float(n)))
	lines.append("Max regret              %.1f" % max_r)
	lines.append("Avg Sentry              %.1f" % (sentry / float(n)))
	lines.append("Avg Guard               %.1f" % (guard / float(n)))
	return "\n".join(lines)
