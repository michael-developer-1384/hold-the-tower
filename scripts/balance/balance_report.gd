extends RefCounted

## Assemble human + JSON balance reports. Warnings are diagnostic only.

const Model := preload("res://scripts/balance/report/balance_report_model.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")


static func write_json(path: String, data: Dictionary) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


static func write_text(path: String, text: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return
	f.store_string(text)
	f.close()


static func assemble(parts: Dictionary, meta: Dictionary = {}) -> Dictionary:
	return Model.build(parts, meta)


static func format_summary(report: Dictionary) -> String:
	var p: Dictionary = report.get("level", report.get("level_pressure", {}))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("HODL THE TOWER — BALANCE REPORT 0.19.0")
	lines.append("")
	lines.append(str(report.get("designer_summary", "")))
	lines.append("")
	lines.append("LEVEL")
	lines.append("Normal Pressure: %.2f" % float(p.get("whole_run_pressure_score", 0.0)))
	lines.append("Incoming HP: %.0f" % float(p.get("total_incoming_hp", 0.0)))
	lines.append("Enemies: %d" % int(p.get("total_enemy_count", 0)))
	lines.append("Path Travel Time: %.2fs" % float(p.get("path_travel_time", 0.0)))
	lines.append("Min sustained DPS: %.1f" % float(p.get("theoretical_minimum_sustained_dps", 0.0)))
	lines.append("Ranged HP×speed factor: %.2f" % float(p.get("ranged_pressure_factor", 1.0)))
	lines.append("")
	lines.append("TOWER ECONOMIC EFFICIENCY")
	var towers: Dictionary = report.get("towers", report.get("economic_efficiency", {}))
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var row: Dictionary = towers.get(tid, {})
		var rel = row.get("relative_to_anchor_median", row.get("relative_to_anchor_median"))
		lines.append("%-10s  v/g %s  relative %s  %s" % [
			_name(tid),
			_fmt_num(row.get("median_value_per_gold", row.get("value_per_gold"))),
			_fmt_num(rel),
			str(row.get("status_label", row.get("role", ""))),
		])
	lines.append("")
	lines.append("PLACEMENT SENSITIVITY")
	for tid2 in ["basic_tower", "guard_post", "lava_tower"]:
		var s: Dictionary = towers.get(tid2, {})
		lines.append("%-10s  %s  cv=%s  best %s  worst %s" % [
			_name(tid2),
			str(s.get("placement_classification", "?")),
			_fmt_num(s.get("placement_cv")),
			str(s.get("best_spot", "")),
			str(s.get("worst_spot", "")),
		])
	lines.append("")
	lines.append("WARNINGS")
	for w in report.get("warnings", []):
		if typeof(w) == TYPE_DICTIONARY:
			lines.append("- [%s] %s" % [str(w.get("severity", "")), str(w.get("message", ""))])
		else:
			lines.append("- %s" % str(w))
	if (report.get("warnings", []) as Array).is_empty():
		lines.append("- none")
	return "\n".join(lines)


static func _fmt_num(v: Variant) -> String:
	if v == null:
		return "null"
	return "%.3f" % float(v)


static func _name(tower_id: String) -> String:
	var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tower_id)
	if def:
		return str(def.display_name)
	return tower_id
