extends SceneTree

## Headless balance batch runner.
## godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent basic --runs 100 --seed 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var BatchRunnerScript = load("res://scripts/sim/balance/batch_runner.gd")
	var args := _parse_args()
	print("=== Simulate Batch ===")
	print(args)

	if bool(args.get("compare", false)):
		var agents := ["random", "basic", "smart"]
		var lines: PackedStringArray = ["HODL THE TOWER – AGENT COMPARE", ""]
		for agent_id in agents:
			var opts := args.duplicate(true)
			opts["agent_id"] = agent_id
			opts["compare"] = false
			var batch: Dictionary = await BatchRunnerScript.run_batch(self, opts)
			var agg: Dictionary = batch.get("aggregate", {})
			lines.append("%-8s  winrate %.1f%%  avg_lives %.2f  avg_wave %.2f" % [
				agent_id,
				float(agg.get("winrate", 0.0)) * 100.0,
				float(agg.get("avg_lives_remaining", 0.0)),
				float(agg.get("avg_waves_reached", 0.0)),
			])
			_write_json("user://sim/batch_%s.json" % agent_id, batch)
		print("\n".join(lines))
		quit(0)
		return

	var batch2: Dictionary = await BatchRunnerScript.run_batch(self, args)
	print(batch2.get("report", ""))
	_write_json("user://sim/last_batch.json", batch2)
	quit(0)


func _parse_args() -> Dictionary:
	var out := {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"agent_id": "basic",
		"runs": 10,
		"seed": 1,
		"time_scale": 40.0,
		"compare": false,
		"config": {},
		"use_profile_research": false,
		"lookahead": false,
		"record": "none",
		"player_profile": "optimizer",
	}
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var a := str(raw[i])
		match a:
			"--level":
				i += 1
				out["level_id"] = str(raw[i]) if i < raw.size() else out["level_id"]
			"--difficulty":
				i += 1
				out["difficulty_id"] = str(raw[i]) if i < raw.size() else out["difficulty_id"]
			"--agent":
				i += 1
				out["agent_id"] = str(raw[i]) if i < raw.size() else out["agent_id"]
			"--runs":
				i += 1
				out["runs"] = int(raw[i]) if i < raw.size() else out["runs"]
			"--seed":
				i += 1
				out["seed"] = int(raw[i]) if i < raw.size() else out["seed"]
			"--time-scale":
				i += 1
				out["time_scale"] = float(raw[i]) if i < raw.size() else out["time_scale"]
			"--record":
				i += 1
				out["record"] = str(raw[i]).to_lower() if i < raw.size() else "none"
			"--profile":
				i += 1
				out["player_profile"] = str(raw[i]).to_lower() if i < raw.size() else "optimizer"
			"--lookahead":
				out["lookahead"] = true
			"--compare":
				out["compare"] = true
			"--research":
				i += 1
				out["use_profile_research"] = str(raw[i]) == "profile"
			"--enemy-health":
				i += 1
				(out["config"] as Dictionary)["enemy_health"] = float(raw[i]) if i < raw.size() else 1.0
			_:
				pass
		i += 1
	return out


func _write_json(path: String, data: Dictionary) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("Wrote %s" % path)
