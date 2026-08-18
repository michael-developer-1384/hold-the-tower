extends SceneTree

## Deterministic Balancing Lab CLI.
## godot --headless --path . --script res://scripts/tools/analyze_balance.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := _parse_args()
	print("=== Analyze Balance v0.18 ===")
	print(args)
	var Pressure = load("res://scripts/balance/difficulty_pressure_model.gd")
	var Isolated = load("res://scripts/balance/isolated_tower_benchmark.gd")
	var Matrix = load("res://scripts/balance/tower_benchmark_runner.gd")
	var Report = load("res://scripts/balance/balance_report.gd")
	var difficulty := str(args.get("difficulty_id", "normal"))
	var pressure: Dictionary = Pressure.report(difficulty)
	var matrix_opts := {
		"difficulty_id": difficulty,
		"seed": int(args.get("seed", 7)),
		"time_scale": float(args.get("time_scale", 40.0)),
		"build_wave": int(args.get("build_wave", 1)),
		"starting_gold": 1000,
	}
	if str(args.get("tower", "")) != "":
		matrix_opts["towers"] = PackedStringArray([str(args.get("tower"))])
	if str(args.get("spot", "")) != "":
		matrix_opts["spots"] = PackedStringArray([str(args.get("spot"))])
	if bool(args.get("quick", false)):
		matrix_opts["towers"] = matrix_opts.get("towers", PackedStringArray(["basic_tower", "guard_post", "lava_tower"]))
		matrix_opts["spots"] = PackedStringArray(["F1_C", "F2_B", "F3_D"])
	var matrix: Dictionary = await Matrix.run_matrix(self, matrix_opts)
	var timing_opts := matrix_opts.duplicate(true)
	var timing_spot := str(args.get("spot", ""))
	if timing_spot.is_empty():
		timing_spot = "F2_B"
	timing_opts["spots"] = PackedStringArray([timing_spot])
	if str(args.get("tower", "")) != "":
		timing_opts["towers"] = PackedStringArray([str(args.get("tower"))])
	var timing: Dictionary = await Matrix.run_timing(self, timing_opts)
	var ramp_spot := str(args.get("spot", ""))
	if ramp_spot.is_empty():
		ramp_spot = "F3_D"
	var ramp: Dictionary = await Isolated.run(self, {
		"tower_id": "lava_tower",
		"spot_id": ramp_spot,
		"build_wave": 1,
		"seed": int(args.get("seed", 7)),
		"difficulty_id": difficulty,
		"start_waves": false,
		"duration": 25.0,
		"time_scale": float(args.get("time_scale", 40.0)),
	})
	var parts := {
		"level_pressure": pressure,
		"matrix": matrix,
		"early_build": timing.get("by_tower", {}),
		"meltdown_ramp": ramp.get("lava", {}),
	}
	if str(args.get("counterfactual", "")) != "":
		var pkg := _load_json(str(args.get("counterfactual")))
		var CF = load("res://scripts/balance/counterfactual_runner.gd")
		var Syn = load("res://scripts/balance/synergy_analyzer.gd")
		var cf_opts := {
			"action_log": pkg.get("action_log", []),
			"seed": int(pkg.get("seed", args.get("seed", 7))),
			"difficulty_id": str(pkg.get("difficulty_id", difficulty)),
			"spot_id": str(args.get("spot", "")),
			"time_scale": float(args.get("time_scale", 40.0)),
		}
		if cf_opts["spot_id"] == "":
			var spots: PackedStringArray = CF.placed_spots(cf_opts["action_log"])
			if spots.size() > 0:
				cf_opts["spot_id"] = spots[0]
		parts["counterfactual"] = await CF.run(self, cf_opts)
		parts["synergy"] = await Syn.analyze(self, cf_opts)
		if bool(args.get("shapley", false)):
			var Sh = load("res://scripts/balance/shapley_analyzer.gd")
			parts["shapley"] = await Sh.analyze(self, cf_opts)
	var report: Dictionary = Report.assemble(parts)
	var text: String = str(Report.format_summary(report))
	print(text)
	var out_path := str(args.get("output", "res://balance_reports/latest_balance_report.json"))
	Report.write_json(out_path, report)
	print("Wrote %s" % out_path)
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
		i += 1
	return out


func _load_json(path: String) -> Dictionary:
	var p := path
	if not p.begins_with("res://") and not p.begins_with("user://"):
		p = "res://" + p.trim_prefix("./")
	if not FileAccess.file_exists(p):
		push_warning("Missing replay %s" % path)
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}
