extends RefCounted

## Shared 0.18.1 analysis pipeline for CLI and the debug Balance Lab page.

const Report := preload("res://scripts/balance/balance_report.gd")
const Html := preload("res://scripts/balance/report/balance_html_reporter.gd")
const Ai := preload("res://scripts/balance/report/balance_ai_exporter.gd")
const Cmp := preload("res://scripts/balance/report/balance_report_comparator.gd")

const JSON_PATH := "res://balance_reports/latest_balance_report.json"
const HTML_PATH := "res://balance_reports/latest_balance_report.html"
const AI_PATH := "res://balance_reports/latest_balance_ai_export.json"


static func run(tree: SceneTree, args: Dictionary) -> Dictionary:
	var Pressure = load("res://scripts/balance/difficulty_pressure_model.gd")
	var Isolated = load("res://scripts/balance/isolated_tower_benchmark.gd")
	var Matrix = load("res://scripts/balance/tower_benchmark_runner.gd")
	var difficulty := str(args.get("difficulty_id", "normal"))
	var seed := int(args.get("seed", 7))
	var overrides: Dictionary = args.get("parameter_overrides", {})
	var config: Dictionary = {"starting_gold": 1000}
	for k in overrides.keys():
		config[str(k)] = overrides[k]
	var previous := load_json(JSON_PATH)
	var pressure: Dictionary = Pressure.report(difficulty)
	var matrix_opts := {
		"difficulty_id": difficulty,
		"seed": seed,
		"time_scale": float(args.get("time_scale", 40.0)),
		"build_wave": int(args.get("build_wave", 1)),
		"starting_gold": 1000,
		"config": config,
		"level_id": str(args.get("level_id", "vertical_test")),
	}
	if str(args.get("tower", "")) != "":
		matrix_opts["towers"] = PackedStringArray([str(args.get("tower"))])
	if str(args.get("spot", "")) != "":
		matrix_opts["spots"] = PackedStringArray([str(args.get("spot"))])
	if bool(args.get("quick", false)):
		matrix_opts["towers"] = matrix_opts.get("towers", PackedStringArray(["basic_tower", "guard_post", "lava_tower"]))
		matrix_opts["spots"] = PackedStringArray(["F1_C", "F2_B", "F3_D"])
	var matrix: Dictionary = await Matrix.run_matrix(tree, matrix_opts)
	var timing_opts := matrix_opts.duplicate(true)
	var timing_spot := str(args.get("spot", ""))
	if timing_spot.is_empty():
		timing_spot = "F2_B"
	timing_opts["spots"] = PackedStringArray([timing_spot])
	if str(args.get("tower", "")) != "":
		timing_opts["towers"] = PackedStringArray([str(args.get("tower"))])
	var timing: Dictionary = await Matrix.run_timing(tree, timing_opts)
	var ramp_spot := str(args.get("spot", ""))
	if ramp_spot.is_empty():
		ramp_spot = "F3_D"
	var ramp: Dictionary = await Isolated.run(tree, {
		"tower_id": "lava_tower",
		"spot_id": ramp_spot,
		"build_wave": 1,
		"seed": seed,
		"difficulty_id": difficulty,
		"level_id": str(args.get("level_id", "vertical_test")),
		"start_waves": false,
		"duration": 25.0,
		"time_scale": float(args.get("time_scale", 40.0)),
		"config": config,
		"balance_ramp_series": true,
	})
	var parts := {
		"level_pressure": pressure,
		"matrix": matrix,
		"early_build": timing.get("by_tower", {}),
		"meltdown_ramp": ramp.get("lava", {}),
		"full_builds": [],
		"defense_margin": null,
		"difficulty_frontier": null,
	}
	if str(args.get("counterfactual", "")) != "":
		var pkg := load_json(str(args.get("counterfactual")))
		var CF = load("res://scripts/balance/counterfactual_runner.gd")
		var Syn = load("res://scripts/balance/synergy_analyzer.gd")
		var cf_opts := {
			"action_log": pkg.get("action_log", []),
			"seed": int(pkg.get("seed", seed)),
			"difficulty_id": str(pkg.get("difficulty_id", difficulty)),
			"spot_id": str(args.get("spot", "")),
			"time_scale": float(args.get("time_scale", 40.0)),
			"config": config,
		}
		if cf_opts["spot_id"] == "":
			var spots: PackedStringArray = CF.placed_spots(cf_opts["action_log"])
			if spots.size() > 0:
				cf_opts["spot_id"] = spots[0]
		parts["counterfactual"] = await CF.run(tree, cf_opts)
		parts["synergy"] = await Syn.analyze(tree, cf_opts)
		if bool(args.get("shapley", false)):
			var Sh = load("res://scripts/balance/shapley_analyzer.gd")
			parts["shapley"] = await Sh.analyze(tree, cf_opts)
	var frozen_log: Array = []
	var want_fb := str(args.get("full_build", "")) != ""
	var want_margin := bool(args.get("defense_margin", false))
	var want_frontier := bool(args.get("difficulty_frontier", false))
	if want_fb or want_margin or want_frontier:
		var Full = load("res://scripts/balance/full_build_benchmark.gd")
		var fb_opts := {
			"seed": seed,
			"difficulty_id": difficulty,
			"level_id": str(args.get("level_id", "vertical_test")),
			"time_scale": float(args.get("time_scale", 40.0)),
			"config": config,
			"fixture_id": "scripted",
			"role": "COMPETENT",
			"source": "FIXTURE",
		}
		var fb_arg := str(args.get("full_build", "scripted"))
		if fb_arg != "" and fb_arg != "scripted" and (fb_arg.ends_with(".json") or FileAccess.file_exists(fb_arg) or FileAccess.file_exists("res://" + fb_arg.trim_prefix("./"))):
			var replay_pkg := load_json(fb_arg)
			fb_opts["action_log"] = replay_pkg.get("action_log", [])
			fb_opts["source"] = "PLAYER_REPLAY" if str(replay_pkg.get("source", "")) == "PLAYER_REPLAY" else "FIXTURE"
			fb_opts["role"] = str(replay_pkg.get("role", "PLAYER_REPLAY"))
			frozen_log = fb_opts["action_log"]
		else:
			var rec: Dictionary = await Full.record_scripted(tree, fb_opts)
			frozen_log = rec.get("action_log", [])
			fb_opts["action_log"] = frozen_log
		if want_fb or want_margin or want_frontier:
			var built: Dictionary = await Full.run(tree, fb_opts)
			parts["full_builds"] = [built]
		if want_margin:
			var Margin = load("res://scripts/balance/defense_margin_search.gd")
			var mopts := fb_opts.duplicate(true)
			mopts["action_log"] = frozen_log
			if args.has("margin_iters"):
				mopts["iters"] = int(args.get("margin_iters"))
			if args.has("margin_hi"):
				mopts["hi"] = float(args.get("margin_hi"))
			if args.has("margin_axes"):
				mopts["axes"] = args.get("margin_axes")
			parts["defense_margin"] = await Margin.run(tree, mopts)
		if want_frontier:
			var Front = load("res://scripts/balance/difficulty_frontier.gd")
			var fopts := fb_opts.duplicate(true)
			fopts["action_log"] = frozen_log
			if args.has("frontier_step"):
				fopts["step"] = float(args.get("frontier_step"))
			if args.has("health_min"):
				fopts["health_min"] = float(args.get("health_min"))
			if args.has("health_max"):
				fopts["health_max"] = float(args.get("health_max"))
			if args.has("speed_min"):
				fopts["speed_min"] = float(args.get("speed_min"))
			if args.has("speed_max"):
				fopts["speed_max"] = float(args.get("speed_max"))
			parts["difficulty_frontier"] = await Front.run(tree, fopts)
	var Tokens = load("res://scripts/app/ui_tokens.gd")
	var meta := {
		"game_version": str(Tokens.APP_VERSION),
		"level_id": str(args.get("level_id", "vertical_test")),
		"difficulty_id": difficulty,
		"seed": seed,
		"parameter_overrides": overrides,
		"benchmark": "isolated_matrix+timing+ramp",
	}
	var report: Dictionary = Report.assemble(parts, meta)
	report["previous_delta"] = Cmp.compare(report, previous)
	var json_path := str(args.get("output", JSON_PATH))
	var html_path := str(args.get("html_output", HTML_PATH))
	var ai_path := str(args.get("ai_output", AI_PATH))
	Report.write_json(json_path, report)
	var ai_export: Dictionary = {}
	if not bool(args.get("no_ai_export", false)):
		ai_export = Ai.export(report)
		Report.write_json(ai_path, ai_export)
	if not bool(args.get("no_html", false)):
		Report.write_text(html_path, Html.render(report))
	if bool(args.get("archive", false)):
		_archive(json_path, html_path, ai_path, str(report.get("report_meta", {}).get("report_id", "bal")))
	if bool(args.get("open_report", false)) and not bool(args.get("no_html", false)):
		OS.shell_open(ProjectSettings.globalize_path(html_path))
	return {
		"report": report,
		"ai_export": ai_export,
		"json_path": json_path,
		"html_path": html_path,
		"ai_path": ai_path,
		"summary": Report.format_summary(report),
	}


static func load_json(path: String) -> Dictionary:
	var p := path
	if p.is_empty():
		return {}
	if not p.begins_with("res://") and not p.begins_with("user://"):
		if FileAccess.file_exists(p):
			pass
		else:
			p = "res://" + path.trim_prefix("./")
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func _archive(json_path: String, html_path: String, ai_path: String, report_id: String) -> void:
	var stamp := report_id.validate_filename()
	var dest_dir := ProjectSettings.globalize_path("res://balance_reports/history")
	DirAccess.make_dir_recursive_absolute(dest_dir)
	_copy_if_exists(json_path, "res://balance_reports/history/%s.json" % stamp)
	_copy_if_exists(html_path, "res://balance_reports/history/%s.html" % stamp)
	_copy_if_exists(ai_path, "res://balance_reports/history/%s.ai.json" % stamp)


static func _copy_if_exists(src: String, dest: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var f := FileAccess.open(src, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	Report.write_text(dest, text)
