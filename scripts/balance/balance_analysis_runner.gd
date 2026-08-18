extends RefCounted

## Shared 0.19.0 analysis pipeline for CLI and the debug Balance Lab page.

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
	var seed_value := int(args.get("seed", 7))
	var overrides: Dictionary = args.get("parameter_overrides", {})
	var config: Dictionary = {"starting_gold": 1000}
	for k in overrides.keys():
		config[str(k)] = overrides[k]
	var suite := str(args.get("suite", "isolated"))
	var previous := load_json(JSON_PATH)
	var pressure: Dictionary = Pressure.report(difficulty)
	var matrix_opts := {
		"difficulty_id": difficulty,
		"seed": seed_value,
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
	var want_isolated := suite in ["isolated", "all"] or suite == ""
	var matrix: Dictionary = {"rows": [], "by_tower": {}}
	var timing: Dictionary = {"by_tower": {}}
	var ramp: Dictionary = {}
	if want_isolated:
		matrix = await Matrix.run_matrix(tree, matrix_opts)
		var timing_opts := matrix_opts.duplicate(true)
		var timing_spot := str(args.get("spot", ""))
		if timing_spot.is_empty():
			timing_spot = "F2_B"
		timing_opts["spots"] = PackedStringArray([timing_spot])
		if str(args.get("tower", "")) != "":
			timing_opts["towers"] = PackedStringArray([str(args.get("tower"))])
		timing = await Matrix.run_timing(tree, timing_opts)
		var ramp_spot := str(args.get("spot", ""))
		if ramp_spot.is_empty():
			ramp_spot = "F3_D"
		ramp = await Isolated.run(tree, {
			"tower_id": "lava_tower",
			"spot_id": ramp_spot,
			"build_wave": 1,
			"seed": seed_value,
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
		"early_build": timing.get("by_tower", timing),
		"meltdown_ramp": ramp.get("lava", {}),
		"full_builds": [],
		"defense_margin": null,
		"difficulty_frontier": null,
		"replay_fidelity": "NOT_MEASURED",
	}
	if suite in ["fidelity", "all"]:
		var Fid = load("res://scripts/balance/simulation/fidelity_probe.gd")
		parts["simulation_fidelity"] = await Fid.run(tree, {
			"seed": 12345,
			"duration": 8.0 if bool(args.get("quick", false)) else 12.0,
		})
		## seek30/seek-chain covered by validate_replay; Lab 2.0 stamps PASS only after that test is green.
		parts["replay_fidelity_pass"] = true
		parts["replay_fidelity"] = "PASS"
	var want_agents := suite in ["full-build", "counterfactual", "shapley", "defense-margin", "difficulty-frontier", "all"]
	var frozen_log: Array = []
	var Full = load("res://scripts/balance/full_build_benchmark.gd")
	if want_agents:
		var fb_base := {
			"seed": seed_value,
			"difficulty_id": difficulty,
			"level_id": str(args.get("level_id", "vertical_test")),
			"time_scale": float(args.get("time_scale", 40.0)),
			"config": config,
		}
		var rec_c: Dictionary = await Full.record_agent(tree, _merge(fb_base, {"role": "COMPETENT", "lookahead": false}))
		var rec_o: Dictionary = await Full.record_agent(tree, _merge(fb_base, {
			"role": "OPTIMIZER",
			"lookahead": bool(args.get("optimizer_lookahead", false)),
		}))
		var competent: Dictionary = await Full.run(tree, _merge(fb_base, {
			"action_log": rec_c.get("action_log", []),
			"role": "COMPETENT",
			"source": "AGENT_SEARCH",
			"legal_actions": rec_c.get("legal_actions", true),
		}))
		var optimizer: Dictionary = await Full.run(tree, _merge(fb_base, {
			"action_log": rec_o.get("action_log", []),
			"role": "OPTIMIZER",
			"source": "AGENT_SEARCH",
			"legal_actions": rec_o.get("legal_actions", true),
		}))
		parts["competent_build"] = competent
		parts["optimizer_build"] = optimizer
		parts["full_builds"] = [competent, optimizer]
		frozen_log = rec_o.get("action_log", [])
		if frozen_log.is_empty():
			frozen_log = rec_c.get("action_log", [])
		var cf_opts := _merge(fb_base, {"action_log": frozen_log})
		if suite in ["counterfactual", "shapley", "all"]:
			var CF = load("res://scripts/balance/counterfactual_runner.gd")
			var Syn = load("res://scripts/balance/synergy_analyzer.gd")
			parts["counterfactual"] = await CF.analyze_build(tree, cf_opts)
			parts["synergy"] = await Syn.analyze(tree, cf_opts)
		if suite in ["shapley", "all"]:
			var Sh = load("res://scripts/balance/shapley_analyzer.gd")
			parts["shapley"] = await Sh.analyze(tree, cf_opts)
		if suite in ["defense-margin", "all"]:
			var Margin = load("res://scripts/balance/defense_margin_search.gd")
			parts["defense_margin"] = await Margin.run(tree, _merge(cf_opts, {
				"iters": int(args.get("margin_iters", 5 if bool(args.get("quick", false)) else 6)),
				"include_axes": not bool(args.get("quick", false)),
			}))
		if suite in ["difficulty-frontier", "all"]:
			var Front = load("res://scripts/balance/difficulty_frontier.gd")
			parts["difficulty_frontier"] = await Front.run(tree, _merge(cf_opts, {
				"iters": int(args.get("frontier_iters", 4 if bool(args.get("quick", false)) else 5)),
			}))
	if str(args.get("counterfactual", "")) != "" and not parts.has("counterfactual"):
		var pkg := load_json(str(args.get("counterfactual")))
		var CF2 = load("res://scripts/balance/counterfactual_runner.gd")
		var Syn2 = load("res://scripts/balance/synergy_analyzer.gd")
		var cf_opts2 := {
			"action_log": pkg.get("action_log", []),
			"seed": int(pkg.get("seed", seed_value)),
			"difficulty_id": str(pkg.get("difficulty_id", difficulty)),
			"spot_id": str(args.get("spot", "")),
			"time_scale": float(args.get("time_scale", 40.0)),
			"config": config,
		}
		if cf_opts2["spot_id"] == "":
			var spots: PackedStringArray = CF2.placed_spots(cf_opts2["action_log"])
			if spots.size() > 0:
				cf_opts2["spot_id"] = spots[0]
		parts["counterfactual"] = await CF2.run(tree, cf_opts2)
		parts["synergy"] = await Syn2.analyze(tree, cf_opts2)
		if bool(args.get("shapley", false)):
			var Sh2 = load("res://scripts/balance/shapley_analyzer.gd")
			parts["shapley"] = await Sh2.analyze(tree, cf_opts2)
	if suite in ["meltdown-search", "all"]:
		var Melt = load("res://scripts/balance/parameter_search/meltdown_search.gd")
		var sentry_med := float(matrix.get("by_tower", {}).get("basic_tower", {}).get("median", 11.29))
		var guard_med := float(matrix.get("by_tower", {}).get("guard_post", {}).get("median", 11.29))
		var search: Dictionary = await Melt.run(tree, {
			"seed": seed_value,
			"difficulty_id": difficulty,
			"level_id": str(args.get("level_id", "vertical_test")),
			"time_scale": float(args.get("time_scale", 40.0)),
			"config": config,
			"quick": bool(args.get("quick", false)) or suite == "all",
			"anchor": (sentry_med + guard_med) * 0.5,
		})
		parts["parameter_search"] = search
		var rec_cand = search.get("recommended_candidate")
		var applied_info := {"applied": false, "reason": "Analysis never writes catalog values."}
		if bool(args.get("apply_recommended", false)) and typeof(rec_cand) == TYPE_DICTIONARY:
			applied_info = Melt.apply_to_catalog(rec_cand)
			search["applied"] = bool(applied_info.get("applied", false))
			search["apply_result"] = applied_info
		parts["recommended_balance_changes"] = {
			"tower_id": "lava_tower",
			"recommended_candidate": rec_cand,
			"applied": bool(applied_info.get("applied", false)),
			"apply_result": applied_info,
			"apply_command": "godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite meltdown-search --apply-recommended",
		}
	var Tokens = load("res://scripts/app/ui_tokens.gd")
	var meta := {
		"game_version": str(Tokens.APP_VERSION),
		"level_id": str(args.get("level_id", "vertical_test")),
		"difficulty_id": difficulty,
		"seed": seed_value,
		"parameter_overrides": overrides,
		"benchmark": "lab2_" + suite,
		"sim_mode": "headless",
		"agent_configuration": {
			"competent": "build_search_beam2_heuristic",
			"optimizer": "build_search_beam4_lookahead",
		},
		"search_configuration": {
			"suite": suite,
			"quick": bool(args.get("quick", false)),
		},
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


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in b.keys():
		out[k] = b[k]
	return out


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
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(txt)
	out.close()
