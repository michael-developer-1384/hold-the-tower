extends SceneTree

## Optimizer determinism, profile reproducibility, competent seed variation.
## godot --headless --path . --script res://scripts/tools/validate_agent_profiles.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_agent_profiles: starting")
	var ok := true
	ok = (await _optimizer_same()) and ok
	ok = (await _competent_repeat()) and ok
	ok = (await _competent_varies()) and ok
	if ok:
		print("validate_agent_profiles: PASS")
		quit(0)
	else:
		print("validate_agent_profiles: FAIL")
		quit(1)


func _optimizer_same() -> bool:
	var a: Dictionary = await _one("optimizer", 1, false)
	var b: Dictionary = await _one("optimizer", 1, false)
	var c: Dictionary = await _one("optimizer", 2, false)
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var sa: String = Diversity.action_sequence(a.get("action_log", []))
	var sb: String = Diversity.action_sequence(b.get("action_log", []))
	var sc: String = Diversity.action_sequence(c.get("action_log", []))
	var same := sa == sb and sa == sc and not sa.is_empty()
	print("  optimizer seed1/seed1/seed2  same=%s  tokens=%d" % [str(same), sa.split(" > ").size()])
	if not same:
		print("    s1a=%s" % sa)
		print("    s1b=%s" % sb)
		print("    s2 =%s" % sc)
	return same


func _competent_repeat() -> bool:
	var a: Dictionary = await _one("competent", 42, false)
	var b: Dictionary = await _one("competent", 42, false)
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var sa: String = Diversity.action_sequence(a.get("action_log", []))
	var sb: String = Diversity.action_sequence(b.get("action_log", []))
	var same := sa == sb and not sa.is_empty()
	print("  competent seed42 repeat  same=%s  tokens=%d" % [str(same), sa.split(" > ").size()])
	if not same:
		print("    a=%s" % sa)
		print("    b=%s" % sb)
	return same


func _competent_varies() -> bool:
	var results: Array = []
	for s in [1, 2, 3, 4, 5]:
		results.append(await _one("competent", s, false))
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var div: Dictionary = Diversity.summarize(results)
	var n := int(div.get("unique_action_sequences", 0))
	var varied := n >= 2
	print("  competent seeds 1-5  unique_sequences=%d  pass=%s" % [n, str(varied)])
	return varied


func _one(profile: String, seed: int, lookahead: bool) -> Dictionary:
	var Batch = load("res://scripts/sim/balance/batch_runner.gd")
	return await Batch.run_one(self, {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"agent_id": "smart",
		"player_profile": profile,
		"seed": seed,
		"lookahead": lookahead,
		"record": "none",
		"time_scale": 40.0,
		"max_sim_seconds": 180.0,
	})
