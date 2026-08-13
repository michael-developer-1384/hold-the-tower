extends RefCounted

## Thin wrapper around SimMetrics report helpers for batch tooling.


static func format_report(agg: Dictionary, title: String = "HODL THE TOWER – BALANCE REPORT") -> String:
	return load("res://scripts/sim/sim_metrics.gd").format_report(agg, title)


static func write_json(path: String, data: Dictionary) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
