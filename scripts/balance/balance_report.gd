extends RefCounted

## Assemble human + JSON balance reports. Warnings are diagnostic only.

const Pressure := preload("res://scripts/balance/difficulty_pressure_model.gd")
const Targets := preload("res://scripts/balance/balance_targets.gd")
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


static func format_summary(report: Dictionary) -> String:
	var p: Dictionary = report.get("level_pressure", {})
	var lines: PackedStringArray = PackedStringArray()
	lines.append("HODL THE TOWER — BALANCE REPORT")
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
	var eff: Dictionary = report.get("economic_efficiency", {})
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var row: Dictionary = eff.get(tid, {})
		lines.append("%-10s  v/g %.3f  relative %.2f  role %s" % [
			_name(tid),
			float(row.get("value_per_gold", 0.0)),
			float(row.get("relative_to_anchor_median", 0.0)),
			str(row.get("role", "")),
		])
	lines.append("")
	lines.append("PLACEMENT SENSITIVITY")
	var sens: Dictionary = report.get("placement_sensitivity", {})
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var s: Dictionary = sens.get(tid, {})
		lines.append("%-10s  %s  cv=%.2f  best %s  worst %s" % [
			_name(tid),
			str(s.get("placement_sensitivity_band", "?")),
			float(s.get("placement_sensitivity", 0.0)),
			str(s.get("best_spot", "")),
			str(s.get("worst_spot", "")),
		])
	lines.append("")
	lines.append("EARLY BUILD ROI")
	var timing: Dictionary = report.get("early_build", {})
	for tid in timing.keys():
		var t: Dictionary = timing[tid]
		lines.append("%-10s  early× %.2f" % [_name(str(tid)), float(t.get("early_build_multiplier", 0.0))])
	lines.append("")
	lines.append("TOP SPOTS")
	for row2 in report.get("top_spots", []):
		lines.append("  %s %s  v/g %.3f" % [str(row2.get("tower_id")), str(row2.get("spot_id")), float(row2.get("value_per_gold", 0.0))])
	lines.append("BOTTOM SPOTS")
	for row3 in report.get("bottom_spots", []):
		lines.append("  %s %s  v/g %.3f" % [str(row3.get("tower_id")), str(row3.get("spot_id")), float(row3.get("value_per_gold", 0.0))])
	lines.append("")
	lines.append("MELTDOWN")
	var melt: Dictionary = report.get("meltdown_ramp", {})
	lines.append("Ramp 25%% %.2fs  50%% %.2fs  90%% %.2fs" % [
		float(melt.get("t_25_percent_damage", -1.0)),
		float(melt.get("t_50_percent_damage", -1.0)),
		float(melt.get("t_90_percent_damage", -1.0)),
	])
	lines.append("Effective cells %.1f  Cross floor %d  Peak DPS %.2f" % [
		float(melt.get("effective_damage_area", 0.0)),
		int(melt.get("cross_floor_cells", 0)),
		float(melt.get("peak_cell_dps", 0.0)),
	])
	lines.append("")
	lines.append("WARNINGS")
	for w in report.get("warnings", []):
		lines.append("- %s" % str(w))
	if (report.get("warnings", []) as Array).is_empty():
		lines.append("- none")
	return "\n".join(lines)


static func assemble(parts: Dictionary) -> Dictionary:
	var matrix: Dictionary = parts.get("matrix", {})
	var by_tower: Dictionary = matrix.get("by_tower", {})
	var rows: Array = matrix.get("rows", [])
	var sentry_med := float(by_tower.get("basic_tower", {}).get("median", 0.0))
	var guard_med := float(by_tower.get("guard_post", {}).get("median", 0.0))
	var anchor := (sentry_med + guard_med) * 0.5
	var eff := {}
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var st: Dictionary = by_tower.get(tid, {})
		var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tid)
		eff[tid] = {
			"value_per_gold": float(st.get("median", 0.0)),
			"relative_to_anchor_median": float(st.get("median", 0.0)) / maxf(anchor, 0.0001),
			"role": str(def.role) if def else "",
			"display_name": str(def.display_name) if def else tid,
		}
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("value_per_gold", 0.0)) > float(b.get("value_per_gold", 0.0)))
	var top: Array = []
	var bottom: Array = []
	for i in mini(5, sorted.size()):
		top.append(sorted[i])
	for j in mini(5, sorted.size()):
		bottom.append(sorted[sorted.size() - 1 - j])
	var pressure: Dictionary = parts.get("level_pressure", Pressure.report("normal"))
	var warnings: Array = _warnings(eff, by_tower, pressure, parts.get("meltdown_ramp", {}))
	return {
		"version": "0.18.0",
		"title": "Deterministic Balancing Lab",
		"level_pressure": pressure,
		"economic_efficiency": eff,
		"anchor_median_value_per_gold": anchor,
		"anchor_formula": "mean(sentry_median_value_per_gold, guard_median_value_per_gold)",
		"placement_sensitivity": by_tower,
		"placement_sensitivity_formula": "coefficient of variation = stdev / mean of isolated value_per_gold across spots",
		"early_build": parts.get("early_build", {}),
		"matrix": matrix,
		"top_spots": top,
		"bottom_spots": bottom,
		"meltdown_ramp": parts.get("meltdown_ramp", {}),
		"synergy": parts.get("synergy", {}),
		"shapley": parts.get("shapley", {}),
		"warnings": warnings,
		"targets": Targets.all(),
	}


static func _warnings(eff: Dictionary, sens: Dictionary, pressure: Dictionary, ramp: Dictionary) -> Array:
	var w: Array = []
	var melt_rel := float(eff.get("lava_tower", {}).get("relative_to_anchor_median", 1.0))
	if melt_rel < 0.7:
		w.append("Meltdown significantly below anchor band (relative %.2f)" % melt_rel)
	var sentry: Dictionary = sens.get("basic_tower", {})
	if float(sentry.get("max", 0.0)) > float(sentry.get("median", 1.0)) * 1.4:
		w.append("%s unusually strong Sentry placement" % str(sentry.get("best_spot", "")))
	var min_dps := float(pressure.get("theoretical_minimum_sustained_dps", 0.0))
	if min_dps < 20.0:
		w.append("Normal run has very high defense margin vs incoming HP window")
	if float(ramp.get("t_90_percent_damage", -1.0)) < 0.0:
		w.append("Meltdown did not reach 90% of lava_damage on a peak cell during the ramp probe")
	return w


static func _name(tower_id: String) -> String:
	var def = TowerCatalogScript.find_by_id(TowerCatalogScript.create_all(), tower_id)
	if def:
		return str(def.display_name)
	return tower_id
