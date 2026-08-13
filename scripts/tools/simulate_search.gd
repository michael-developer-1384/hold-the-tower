extends SceneTree

## Binary-search a difficulty multiplier toward a target winrate.
## godot --headless --path . --script res://scripts/tools/simulate_search.gd -- --param enemy_health --target-winrate 0.5 --agent smart --runs 20


func _initialize() -> void:
	_run()


func _run() -> void:
	var ParameterSearchScript = load("res://scripts/sim/balance/parameter_search.gd")
	var args := _parse_args()
	print("=== Parameter Search ===")
	print(args)
	var result: Dictionary = await ParameterSearchScript.search(
		self,
		str(args.get("param", "enemy_health")),
		float(args.get("target_winrate", 0.5)),
		args
	)
	print("Suggested multiplier: %.3f" % float(result.get("suggested", 1.0)))
	print(JSON.stringify(result, "\t"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://sim"))
	var f := FileAccess.open("user://sim/last_search.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()
	quit(0)


func _parse_args() -> Dictionary:
	var out := {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"agent_id": "smart",
		"runs": 20,
		"seed": 100,
		"time_scale": 40.0,
		"param": "enemy_health",
		"target_winrate": 0.5,
		"low": 1.0,
		"high": 2.0,
		"iterations": 6,
		"config": {},
	}
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var a := str(raw[i])
		match a:
			"--param":
				i += 1
				out["param"] = str(raw[i]) if i < raw.size() else out["param"]
			"--target-winrate":
				i += 1
				out["target_winrate"] = float(raw[i]) if i < raw.size() else out["target_winrate"]
			"--agent":
				i += 1
				out["agent_id"] = str(raw[i]) if i < raw.size() else out["agent_id"]
			"--runs":
				i += 1
				out["runs"] = int(raw[i]) if i < raw.size() else out["runs"]
			"--seed":
				i += 1
				out["seed"] = int(raw[i]) if i < raw.size() else out["seed"]
			"--low":
				i += 1
				out["low"] = float(raw[i]) if i < raw.size() else out["low"]
			"--high":
				i += 1
				out["high"] = float(raw[i]) if i < raw.size() else out["high"]
			"--iterations":
				i += 1
				out["iterations"] = int(raw[i]) if i < raw.size() else out["iterations"]
			_:
				pass
		i += 1
	return out
