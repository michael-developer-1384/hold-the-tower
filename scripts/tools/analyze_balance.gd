extends SceneTree

## Deterministic Balancing Lab CLI (v0.19.0).
## godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite isolated
## Suites: isolated | full-build | counterfactual | shapley | meltdown-search | defense-margin | difficulty-frontier | fidelity | all


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := _parse_args()
	print("=== Analyze Balance v0.19.0 ===")
	print(args)
	var Runner = load("res://scripts/balance/balance_analysis_runner.gd")
	var out: Dictionary = await Runner.run(self, args)
	print(str(out.get("summary", "")))
	print("Wrote %s" % str(out.get("json_path", "")))
	if not bool(args.get("no_html", false)):
		print("Wrote %s" % str(out.get("html_path", "")))
	if not bool(args.get("no_ai_export", false)):
		print("Wrote %s" % str(out.get("ai_path", "")))
	print("Combat values were not automatically changed.")
	quit(0)


func _parse_args() -> Dictionary:
	var out := {
		"difficulty_id": "normal",
		"seed": 7,
		"time_scale": 40.0,
		"build_wave": 1,
		"tower": "",
		"spot": "",
		"counterfactual": "",
		"shapley": false,
		"quick": false,
		"output": "res://balance_reports/latest_balance_report.json",
		"html_output": "res://balance_reports/latest_balance_report.html",
		"ai_output": "res://balance_reports/latest_balance_ai_export.json",
		"no_html": false,
		"no_ai_export": false,
		"archive": false,
		"open_report": false,
		"full_build": "",
		"defense_margin": false,
		"difficulty_frontier": false,
		"parameter_overrides": {},
		"level_id": "vertical_test",
		"suite": "isolated",
		"apply_recommended": false,
		"optimizer_lookahead": false,
	}
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var a := str(raw[i])
		match a:
			"--tower":
				i += 1
				out["tower"] = str(raw[i]) if i < raw.size() else ""
			"--spot":
				i += 1
				out["spot"] = str(raw[i]) if i < raw.size() else ""
			"--difficulty":
				i += 1
				out["difficulty_id"] = str(raw[i]) if i < raw.size() else "normal"
			"--build-wave":
				i += 1
				out["build_wave"] = int(raw[i]) if i < raw.size() else 1
			"--counterfactual":
				i += 1
				out["counterfactual"] = str(raw[i]) if i < raw.size() else ""
			"--shapley":
				out["shapley"] = true
			"--quick":
				out["quick"] = true
			"--seed":
				i += 1
				out["seed"] = int(raw[i]) if i < raw.size() else 7
			"--format":
				i += 1
			"--output":
				i += 1
				out["output"] = str(raw[i]) if i < raw.size() else out["output"]
			"--time-scale":
				i += 1
				out["time_scale"] = float(raw[i]) if i < raw.size() else 40.0
			"--no-html":
				out["no_html"] = true
			"--no-ai-export":
				out["no_ai_export"] = true
			"--archive":
				out["archive"] = true
			"--open-report":
				out["open_report"] = true
			"--full-build":
				i += 1
				out["full_build"] = str(raw[i]) if i < raw.size() else "scripted"
				if str(out.get("suite", "isolated")) == "isolated":
					out["suite"] = "full-build"
			"--defense-margin":
				out["defense_margin"] = true
				if str(out.get("suite", "isolated")) == "isolated":
					out["suite"] = "defense-margin"
			"--difficulty-frontier":
				out["difficulty_frontier"] = true
				if str(out.get("suite", "isolated")) == "isolated":
					out["suite"] = "difficulty-frontier"
			"--suite":
				i += 1
				out["suite"] = str(raw[i]) if i < raw.size() else "isolated"
			"--isolated":
				out["suite"] = "isolated"
			"--all":
				out["suite"] = "all"
			"--apply-recommended":
				out["apply_recommended"] = true
			"--optimizer-lookahead":
				out["optimizer_lookahead"] = true
			"--set":
				i += 1
				var pair := str(raw[i]) if i < raw.size() else ""
				var eq := pair.find("=")
				if eq > 0:
					var key := pair.substr(0, eq)
					var val := pair.substr(eq + 1)
					(out["parameter_overrides"] as Dictionary)[key] = _parse_set_value(val)
			"--level":
				i += 1
				out["level_id"] = str(raw[i]) if i < raw.size() else "vertical_test"
		i += 1
	return out


func _parse_set_value(val: String) -> Variant:
	if val.is_valid_float():
		return float(val)
	if val == "true":
		return true
	if val == "false":
		return false
	return val
